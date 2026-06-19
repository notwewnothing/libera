import 'package:flutter/material.dart';
import 'package:libera/common/media_widgets.dart';

// Web stub for torrent playback — torrents need the native engine, which a
// browser can't run, so these surface a message instead. Torrent entry points
// are hidden on web (see `supportsTorrents`), so these are rarely reached.

void _notSupported(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Torrents aren’t available in the web version'),
      backgroundColor: Color(0xFF1A1A1A),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

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
  _notSupported(context);
}

Future<void> showMagnetStreamDialog(BuildContext context) async {
  _notSupported(context);
}
