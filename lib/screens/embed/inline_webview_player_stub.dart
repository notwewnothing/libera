import 'package:flutter/material.dart';
import 'package:libera/common/media_widgets.dart';

/// Web stub for the inline WebView player. The web build routes embeds through
/// `EmbedMode.iframe` instead, so this is never instantiated — it exists only so
/// the web compilation never pulls in `webview_flutter`.
class InlineWebViewPlayer extends StatelessWidget {
  final String title;
  final String embedUrl;
  final String ogUrl;
  final String allowedDomain;
  final MediaCardData? card;
  final int? season;
  final int? episode;
  final double startAt;

  const InlineWebViewPlayer({
    super.key,
    required this.title,
    required this.embedUrl,
    required this.ogUrl,
    required this.allowedDomain,
    this.card,
    this.season,
    this.episode,
    this.startAt = 0,
  });

  @override
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: Colors.black);
}
