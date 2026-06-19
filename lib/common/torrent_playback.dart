import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart' show StreamInfo;

import 'package:libera/common/media_widgets.dart';
import 'package:libera/screens/offline_player_screen.dart';
import 'package:libera/services/app_settings.dart';
import 'package:libera/services/torrent/torrent_downloads_service.dart';
import 'package:libera/services/torrent/torrent_stream_service.dart';

const _accent = Color(0xFF0A84FF);

/// Stream a torrent (or a direct url) **without downloading it first**: the
/// libtorrent engine serves the file over a local HTTP url with a sliding cache
/// window, which the offline player opens immediately and plays while the rest
/// streams in. Shared by the sources sheet, the downloads list and the
/// paste-a-magnet flow.
Future<void> streamAndPlay(
  BuildContext context, {
  String? magnet,
  String? url,
  required String title,
  MediaCardData? card,
  int? season,
  int? episode,
  int? fileIdx,
}) async {
  // Capture the root navigator + messenger up front: the caller often pops a
  // bottom sheet right before calling this, so `context` may unmount during the
  // await. We must not depend on it afterwards or the loader gets stranded.
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);

  void openPlayer(String mediaUrl) {
    navigator.push(MaterialPageRoute(
      builder: (_) => OfflinePlayerScreen(
        mediaUrl: mediaUrl,
        title: title,
        card: card,
        season: season,
        episode: episode,
      ),
    ));
  }

  // Direct URL (not a torrent): nothing to buffer — open immediately.
  if (magnet == null || magnet.isEmpty) {
    if (url == null || url.isEmpty) {
      messenger.showSnackBar(_snackBar('Nothing to play'));
      return;
    }
    openPlayer(url);
    return;
  }

  final progress = ValueNotifier<StreamInfo?>(null);
  final ready = Completer<bool>();
  var cancelled = false;
  var loaderOpen = true;
  StreamSubscription<StreamInfo>? bufferSub;

  void closeLoader() {
    if (loaderOpen && navigator.canPop()) navigator.pop();
    loaderOpen = false;
  }

  void teardown() {
    bufferSub?.cancel();
    progress.dispose();
  }

  showDialog<void>(
    context: navigator.context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    builder: (_) => _StreamLoader(
      progress: progress,
      onCancel: () {
        cancelled = true;
        if (!ready.isCompleted) ready.complete(false);
        TorrentStreamService.instance.removeTorrent(magnet);
        closeLoader();
      },
    ),
  );

  TorrentStreamHandle? handle;
  try {
    handle = await TorrentStreamService.instance
        .openStream(magnet, season: season, episode: episode, fileIdx: fileIdx)
        .timeout(const Duration(seconds: 45), onTimeout: () => null);
  } catch (_) {
    handle = null;
  }

  if (cancelled) {
    teardown();
    return; // user backed out while metadata was resolving
  }

  if (handle == null) {
    teardown();
    TorrentStreamService.instance.removeTorrent(magnet);
    closeLoader();
    messenger.showSnackBar(_snackBar(
        'Couldn’t start the stream — no seeds yet, try another source'));
    return;
  }

  // Watch buffering and open the player as soon as a small amount of video is
  // buffered ahead (the user-tunable startup buffer) — or the engine reports
  // ready, whichever comes first. Waiting for the full readahead window made it
  // feel slow; a few seconds of head start is enough to play smoothly.
  final startBufferSeconds = AppSettings.instance.torrentStartBufferSeconds;
  bool enoughBuffered(StreamInfo info) =>
      info.isReady || info.bufferSeconds >= startBufferSeconds;

  progress.value = handle.initial;
  if (enoughBuffered(handle.initial)) {
    if (!ready.isCompleted) ready.complete(true);
  } else {
    bufferSub =
        TorrentStreamService.instance.bufferProgress(handle.streamId).listen((info) {
      progress.value = info;
      if (enoughBuffered(info) && !ready.isCompleted) ready.complete(true);
    });
  }

  final buffered = await ready.future
      .timeout(const Duration(seconds: 120), onTimeout: () => false);

  if (cancelled) {
    teardown();
    return;
  }
  final streamUrl = handle.url;
  teardown();
  closeLoader();

  if (!buffered) {
    TorrentStreamService.instance.removeTorrent(magnet);
    messenger.showSnackBar(
        _snackBar('Stream is taking too long — try another source'));
    return;
  }

  openPlayer(streamUrl);
}

/// Prompt for a magnet link / info-hash and either stream it directly or queue
/// it as a download.
Future<void> showMagnetStreamDialog(BuildContext context) async {
  final controller = TextEditingController();
  final action = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      title: const Text('Stream a magnet link',
          style: TextStyle(color: Colors.white, fontSize: 17)),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 1,
        maxLines: 3,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'magnet:?xt=urn:btih:… or a 40-char info-hash',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _accent)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'download'),
          child:
              const Text('Download', style: TextStyle(color: Colors.white70)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'stream'),
          child: const Text('Stream', style: TextStyle(color: _accent)),
        ),
      ],
    ),
  );
  if (action == null || !context.mounted) return;

  final magnet = _normalizeMagnet(controller.text.trim());
  if (magnet == null) {
    _snack(context, 'Enter a valid magnet link or 40-character info-hash');
    return;
  }

  if (action == 'stream') {
    await streamAndPlay(context, magnet: magnet, title: 'Magnet stream');
  } else {
    final ok = await TorrentDownloadsService.instance.add(magnet, 'Magnet download');
    if (context.mounted) {
      _snack(context, ok ? 'Downloading…' : 'Torrent engine failed to start');
    }
  }
}

/// Accepts a full magnet link, or a bare 40-hex info-hash (wraps it).
String? _normalizeMagnet(String input) {
  if (input.isEmpty) return null;
  if (input.startsWith('magnet:')) return input;
  if (RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(input)) {
    return 'magnet:?xt=urn:btih:$input';
  }
  return null;
}

/// Blocking buffering card with live buffer %, download speed and peer count,
/// plus a Cancel action so the user is never stuck if a torrent has no seeds.
class _StreamLoader extends StatelessWidget {
  final ValueListenable<StreamInfo?> progress;
  final VoidCallback onCancel;
  const _StreamLoader({required this.progress, required this.onCancel});

  String _speedLabel(int bytesPerSec) {
    final mbps = bytesPerSec / (1024 * 1024);
    return mbps >= 1
        ? '${mbps.toStringAsFixed(1)} MB/s'
        : '${(mbps * 1024).toStringAsFixed(0)} KB/s';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 260,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ValueListenableBuilder<StreamInfo?>(
          valueListenable: progress,
          builder: (context, info, _) {
            final peers = info?.activePeers ?? 0;
            final pct = (info?.bufferPct ?? 0).clamp(0.0, 1.0);
            // "Connecting" until we have a peer; "Buffering N%" once data flows.
            final connecting = info == null || peers == 0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.8,
                    value: connecting ? null : pct,
                    valueColor: const AlwaysStoppedAnimation(_accent),
                    backgroundColor: Colors.white12,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  connecting
                      ? 'Connecting to peers…'
                      : 'Buffering ${(pct * 100).round()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  connecting
                      ? 'Finding seeds'
                      : '${_speedLabel(info.downloadRate)} · $peers peers',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                ),
                TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white60)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

SnackBar _snackBar(String message) => SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFF1A1A1A),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    );

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(_snackBar(message));
}
