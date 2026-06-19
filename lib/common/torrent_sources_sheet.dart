import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:libera/common/media_widgets.dart';
import 'package:libera/common/torrent_playback.dart';
import 'package:libera/models/stremio_stream.dart';
import 'package:libera/services/api_service.dart';
import 'package:libera/services/stremio/stremio_addons_service.dart';
import 'package:libera/services/torrent/torrent_downloads_service.dart';
import 'package:libera/common/utils.dart';

const _accent = Color(0xFF0A84FF);
const _sheetBg = Color(0xFF1C1C1E);

/// Resolves [card] to its Stremio (AIOStreams) torrent sources and presents a
/// picker. Each source can be streamed (via the libtorrent engine → offline
/// player) or downloaded to disk. For TV pass [season]/[episode].
/// Bulk-download every [episodes] of [season] via torrents: for each episode it
/// resolves the addon torrent sources and queues the best one (top result, which
/// addons rank by seeders/quality). Mirrors the website "download season" batch
/// but for the torrent engine. Shows live progress with a Cancel.
Future<void> downloadSeasonTorrents(
  BuildContext context, {
  required MediaCardData card,
  required int tmdbId,
  required int season,
  required List<int> episodes,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (episodes.isEmpty) {
    showSnackBar(context, 'No episodes to download');
    return;
  }

  var cancelled = false;
  final progress = ValueNotifier<int>(0);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => _SeasonDownloadProgress(
      total: episodes.length,
      progress: progress,
      onCancel: () => cancelled = true,
    ),
  );

  final imdb = await ApiServices().getImdbId(tmdbId, isMovie: false);
  var queued = 0;
  var missing = 0;

  if (imdb != null) {
    for (var i = 0; i < episodes.length; i++) {
      if (cancelled) break;
      final ep = episodes[i];
      progress.value = i;
      try {
        final streams = await StremioAddonsService.instance
            .getStreams(type: 'series', id: '$imdb:$season:$ep');
        StremioStream? torrent;
        for (final s in streams) {
          if (s.isTorrent) {
            torrent = s;
            break;
          }
        }
        if (torrent == null) {
          missing++;
          continue;
        }
        final ok = await TorrentDownloadsService.instance.add(
          torrent.magnet,
          '${card.title} · S$season E$ep',
          card: card,
          season: season,
          episode: ep,
        );
        ok ? queued++ : missing++;
      } catch (_) {
        missing++;
      }
    }
  }

  progress.dispose();
  if (context.mounted && Navigator.of(context).canPop()) {
    Navigator.of(context).pop(); // dismiss progress dialog
  }
  if (!context.mounted) return;

  final summary = cancelled
      ? 'Stopped — queued $queued episode${queued == 1 ? '' : 's'}'
      : imdb == null
          ? 'Couldn’t resolve this show'
          : 'Queued $queued episode${queued == 1 ? '' : 's'}'
              '${missing > 0 ? ' · $missing had no torrents' : ''}';
  messenger.showSnackBar(SnackBar(
    content: Text(summary),
    backgroundColor: const Color(0xFF1A1A1A),
    behavior: SnackBarBehavior.floating,
  ));
}

Future<void> showTorrentSources(
  BuildContext context, {
  required MediaCardData card,
  required int tmdbId,
  required bool isMovie,
  int? season,
  int? episode,
  String? title,
}) async {
  final label = title ?? card.title;
  _showBlocking(context, 'Finding torrents for “$label”…');

  List<StremioStream> streams = const [];
  try {
    final imdb = await ApiServices().getImdbId(tmdbId, isMovie: isMovie);
    if (imdb != null) {
      final type = isMovie ? 'movie' : 'series';
      final id = isMovie ? imdb : '$imdb:$season:$episode';
      streams = await StremioAddonsService.instance.getStreams(
        type: type,
        id: id,
      );
    }
  } catch (_) {
    // fall through to the empty-state message
  }

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop(); // dismiss loader

  if (streams.isEmpty) {
    showSnackBar(context, 'No torrent sources found for “$label”');
    return;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: _sheetBg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetCtx) => _SourcesSheet(
      label: label,
      streams: streams,
      card: card,
      season: season,
      episode: episode,
    ),
  );
}

class _SourcesSheet extends StatelessWidget {
  final String label;
  final List<StremioStream> streams;
  final MediaCardData card;
  final int? season;
  final int? episode;

  const _SourcesSheet({
    required this.label,
    required this.streams,
    required this.card,
    this.season,
    this.episode,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${streams.length} torrent sources',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap ▶ to stream instantly · ⬇ to save offline',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: streams.length,
                separatorBuilder: (_, _) => Divider(
                  color: Colors.white.withValues(alpha: 0.06),
                  height: 1,
                ),
                itemBuilder: (_, i) => _row(context, streams[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, StremioStream s) {
    final chips = <String>[
      if (s.qualityLabel != null) s.qualityLabel!,
      if (s.sizeLabel != null) s.sizeLabel!,
      if (s.seeders > 0) '▲ ${s.seeders}',
      if (s.peers > 0) '▼ ${s.peers}',
    ];
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => _play(context, s),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.play_arrow_rounded, color: _accent, size: 24),
      ),
      title: Text(
        s.title.replaceAll('\n', ' ').trim(),
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            for (final c in chips)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  c,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            Expanded(
              child: Text(
                s.addonName,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.download_rounded, color: _accent),
        tooltip: 'Download',
        onPressed: () => _download(context, s),
      ),
    );
  }

  Future<void> _play(BuildContext context, StremioStream s) async {
    Navigator.pop(context); // close the sheet
    // Stream directly — plays immediately while the rest downloads in the
    // background (no full download required).
    await streamAndPlay(
      context,
      magnet: s.isTorrent ? s.magnet : null,
      url: s.isTorrent ? null : s.url,
      title: label,
      card: card,
      season: season,
      episode: episode,
      fileIdx: s.fileIdx,
    );
  }

  Future<void> _download(BuildContext context, StremioStream s) async {
    if (!s.isTorrent) {
      showSnackBar(context, 'Only torrent sources can be downloaded');
      return;
    }
    Navigator.pop(context);
    final ok = await TorrentDownloadsService.instance.add(
      s.magnet,
      label,
      card: card,
      season: season,
      episode: episode,
    );
    if (!context.mounted) return;
    showSnackBar(
      context,
      ok
          ? 'Downloading “$label” via torrent'
          : 'Torrent engine failed to start',
    );
  }
}

void _showBlocking(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        decoration: BoxDecoration(
          color: _sheetBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation(_accent),
              ),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Live progress card for [downloadSeasonTorrents] — "Queuing episode X of N"
/// with a Cancel that stops after the current episode.
class _SeasonDownloadProgress extends StatelessWidget {
  final int total;
  final ValueListenable<int> progress;
  final VoidCallback onCancel;
  const _SeasonDownloadProgress({
    required this.total,
    required this.progress,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 280,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        decoration: BoxDecoration(
          color: _sheetBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ValueListenableBuilder<int>(
          valueListenable: progress,
          builder: (context, done, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.8,
                    value: total > 0 ? (done / total).clamp(0.0, 1.0) : null,
                    valueColor: const AlwaysStoppedAnimation(_accent),
                    backgroundColor: Colors.white12,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Finding torrents…',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Episode ${(done + 1).clamp(1, total)} of $total',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12),
                ),
                TextButton(
                  onPressed: onCancel,
                  child:
                      const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
