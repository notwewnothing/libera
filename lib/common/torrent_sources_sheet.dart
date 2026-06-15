import 'package:flutter/material.dart';

import 'package:libera/common/media_widgets.dart';
import 'package:libera/models/stremio_stream.dart';
import 'package:libera/screens/offline_player_screen.dart';
import 'package:libera/services/api_service.dart';
import 'package:libera/services/stremio/stremio_addons_service.dart';
import 'package:libera/services/torrent/torrent_downloads_service.dart';
import 'package:libera/services/torrent/torrent_stream_service.dart';

const _accent = Color(0xFF0A84FF);
const _sheetBg = Color(0xFF1C1C1E);

/// Resolves [card] to its Stremio (AIOStreams) torrent sources and presents a
/// picker. Each source can be streamed (via the libtorrent engine → offline
/// player) or downloaded to disk. For TV pass [season]/[episode].
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
      streams = await StremioAddonsService.instance.getStreams(type: type, id: id);
    }
  } catch (_) {
    // fall through to the empty-state message
  }

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop(); // dismiss loader

  if (streams.isEmpty) {
    _snack(context, 'No torrent sources found for “$label”');
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
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.78),
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
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${streams.length} torrent sources',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: streams.length,
                separatorBuilder: (_, _) =>
                    Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
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
    ];
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => _play(context, s),
      title: Text(
        s.title.replaceAll('\n', ' ').trim(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
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
                child: Text(c,
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
    _showBlocking(context, 'Starting torrent engine…');
    String? url;
    try {
      if (s.isTorrent) {
        url = await TorrentStreamService.instance.streamTorrent(
          s.magnet,
          season: season,
          episode: episode,
          fileIdx: s.fileIdx,
        );
      } else {
        url = s.url;
      }
    } catch (_) {
      url = null;
    }
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss loader
    if (url == null) {
      _snack(context, 'Could not start that source');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfflinePlayerScreen(
          mediaUrl: url,
          title: label,
          card: card,
          season: season,
          episode: episode,
        ),
      ),
    );
  }

  Future<void> _download(BuildContext context, StremioStream s) async {
    if (!s.isTorrent) {
      _snack(context, 'Only torrent sources can be downloaded');
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
    _snack(context, ok ? 'Downloading “$label” via torrent' : 'Torrent engine failed to start');
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
                  strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(_accent)),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Text(message,
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ],
        ),
      ),
    ),
  );
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFF1A1A1A),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}
