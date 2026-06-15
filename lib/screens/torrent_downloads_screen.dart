import 'package:flutter/material.dart';

import 'package:libera/screens/offline_player_screen.dart';
import 'package:libera/services/torrent/torrent_downloads_service.dart';
import 'package:libera/services/torrent/torrent_stream_service.dart';

const _accent = Color(0xFF0A84FF);

/// Lists in-progress / completed torrent downloads (libtorrent → disk), with
/// live progress. Tapping a row streams it through the offline player.
class TorrentDownloadsScreen extends StatelessWidget {
  const TorrentDownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Torrent downloads',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListenableBuilder(
        listenable: TorrentDownloadsService.instance,
        builder: (context, _) {
          final items = TorrentDownloadsService.instance.all;
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No torrent downloads yet.\nUse the ⚡ button on a movie or episode.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, _) =>
                Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
            itemBuilder: (context, i) => _row(context, items[i]),
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, TorrentDownload d) {
    final pct = (d.progress * 100).clamp(0, 100).toStringAsFixed(d.done ? 0 : 1);
    final sub = d.done
        ? 'Completed'
        : '$pct%  ·  ${d.speedLabel}  ·  ${d.peers} peers';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: () => _play(context, d),
      title: Text(d.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: d.progress > 0 ? d.progress : null,
                minHeight: 4,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(_accent),
              ),
            ),
            const SizedBox(height: 4),
            Text(sub,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
          ],
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.white54),
        onPressed: () =>
            TorrentDownloadsService.instance.remove(d.torrentId),
      ),
    );
  }

  Future<void> _play(BuildContext context, TorrentDownload d) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: _accent),
      ),
    );
    final url = await TorrentStreamService.instance.streamTorrent(
      d.magnet,
      season: d.season,
      episode: d.episode,
    );
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (url == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfflinePlayerScreen(
          mediaUrl: url,
          title: d.title,
          card: d.card,
          season: d.season,
          episode: d.episode,
        ),
      ),
    );
  }
}
