import 'package:flutter/material.dart';

import 'package:libera/services/download_source_service.dart';
import 'package:libera/services/player_service.dart';
import 'package:libera/services/stremio/stremio_addons_service.dart';

const _accent = Color(0xFF0A84FF);
const String kAppVersion = '1.0.0';

/// About / info page: app identity, version, capabilities and a disclaimer.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final players = PlayerService.instance.players.length;
    final sources = kDownloadSources.length;
    final addons = StremioAddonsService.instance.addons.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('About', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_accent, Color(0xFF5E5CE6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.movie_filter_rounded,
                      color: Colors.white, size: 44),
                ),
                const SizedBox(height: 14),
                const Text('Libera',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Version $kAppVersion',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13)),
                const SizedBox(height: 10),
                Text(
                  'Stream and download movies & TV — from embed players, '
                  'direct-download sites and torrents, all in one place.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _Card([
            _InfoRow(Icons.play_circle_outline, 'Streaming players', '$players'),
            _InfoRow(Icons.download_rounded, 'Download sources', '$sources'),
            _InfoRow(Icons.extension_rounded, 'Stremio addons', '$addons'),
          ]),
          const SizedBox(height: 16),
          _Card([
            _FeatureRow('Embed players', 'Multi-server website streaming'),
            _FeatureRow('Direct downloads', 'Resumable downloads from indexes'),
            _FeatureRow('Torrents',
                'Stream or download via the built-in libtorrent engine'),
            _FeatureRow('Stremio addons',
                'AIOStreams and other addons as torrent/stream sources'),
            _FeatureRow('Offline player', 'media_kit player with subtitles & tracks'),
          ]),
          const SizedBox(height: 24),
          Text(
            'Libera does not host, store or distribute any content. It only '
            'locates and plays media made available by third-party providers '
            'and addons you choose to add. You are responsible for how you use it.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
                height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card(this.children);

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(
            height: 1, color: Colors.white.withValues(alpha: 0.06), indent: 16));
      }
      rows.add(children[i]);
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: _accent),
        title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
        trailing: Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      );
}

class _FeatureRow extends StatelessWidget {
  final String title;
  final String subtitle;
  const _FeatureRow(this.title, this.subtitle);

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const Icon(Icons.check_circle, color: _accent, size: 20),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
      );
}
