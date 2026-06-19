import 'package:flutter/material.dart';
import 'package:libera/common/adaptive_dialog.dart';
import 'package:libera/common/media_widgets.dart';
import 'package:libera/common/platform.dart';

const _accent = Color(0xFF0A84FF);

/// Asks whether to use **website sources** or **torrents**, for either playing
/// or downloading — the single entry point for both the Play and Download
/// actions. Presented as a bottom sheet on phones and a centered dialog on
/// desktop. On web (no torrent engine) it skips straight to websites.
Future<void> showSourceChooser(
  BuildContext context, {
  required String title,
  required bool forDownload, // false = play
  required VoidCallback onWebsites,
  required VoidCallback onTorrents,
}) {
  if (!supportsTorrents) {
    onWebsites();
    return Future<void>.value();
  }
  return showAdaptiveSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1C1C1E),
    builder: (ctx) => SafeArea(
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
                forDownload ? 'Download “$title”' : 'Watch “$title”',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          _Option(
            icon: Icons.public_rounded,
            title: 'Websites',
            subtitle: forDownload
                ? 'Direct download (faster / smaller files / lower quality)'
                : 'Direct stream (  faster / lower quality )',
            onTap: () {
              Navigator.pop(ctx);
              onWebsites();
            },
          ),
          _Option(
            icon: Icons.bolt_rounded,
            title: 'Torrents',
            subtitle: forDownload
                ? 'Direct download (slower / larger files / higher quality)'
                : 'Direct stream (slower / higher quality) ',
            onTap: () {
              Navigator.pop(ctx);
              onTorrents();
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    ),
  );
}

class _Option extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _accent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
