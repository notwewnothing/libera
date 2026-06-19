import 'package:flutter/material.dart';
import 'package:libera/common/media_widgets.dart';
import 'package:libera/common/platform.dart';
import 'package:libera/common/web_embed.dart';
import 'package:libera/screens/embed/inline_webview_player.dart';
import 'package:libera/services/continue_watching_service.dart';
import 'package:libera/services/player_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Plays a website "embed" player (Vidking, VidSrc, …) for [card].
///
/// The presentation adapts to the platform's [embedMode]:
/// - mobile / macOS → inline WebView with full progress tracking;
/// - web → the site embedded in an `<iframe>`;
/// - Linux/other desktop → opened in the system browser (no inline WebView),
///   where the native torrent → media_kit pipeline is the better watch path.
class PlayerScreen extends StatelessWidget {
  final String title;
  final String embedUrl;
  final String ogUrl;
  final String allowedDomain;
  final MediaCardData? card;
  final int? season;
  final int? episode;
  final double startAt;

  const PlayerScreen({
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

  factory PlayerScreen.movie({
    Key? key,
    required MediaCardData card,
    double startAt = 0,
    MediaPlayer? player,
  }) {
    final p = player ?? PlayerService.instance.current;
    return PlayerScreen(
      key: key,
      title: card.title,
      card: card,
      startAt: startAt,
      allowedDomain: p.baseDomain,
      embedUrl: p.movieUrl(card.id, startAt: startAt),
      // why tf doing nothing somehow makes it work
      ogUrl: p.movieUrl(card.id),
    );
  }

  factory PlayerScreen.episode({
    Key? key,
    required MediaCardData card,
    required int season,
    required int episode,
    required String title,
    double startAt = 0,
    MediaPlayer? player,
  }) {
    final p = player ?? PlayerService.instance.current;
    return PlayerScreen(
      key: key,
      title: title,
      card: card,
      season: season,
      episode: episode,
      startAt: startAt,
      allowedDomain: p.baseDomain,
      embedUrl: p.episodeUrl(card.id, season, episode, startAt: startAt),
      ogUrl: p.episodeUrl(card.id, season, episode),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (embedMode) {
      case EmbedMode.inlineWebView:
      case EmbedMode.inappWebView:
        return InlineWebViewPlayer(
          title: title,
          embedUrl: embedUrl,
          ogUrl: ogUrl,
          allowedDomain: allowedDomain,
          card: card,
          season: season,
          episode: episode,
          startAt: startAt,
        );
      case EmbedMode.iframe:
        return _IframePlayer(title: title, embedUrl: embedUrl, card: _record());
      case EmbedMode.externalBrowser:
        return _ExternalBrowserPlayer(
          title: title,
          embedUrl: embedUrl,
          card: _record(),
        );
    }
  }

  /// Records the open in Continue Watching (no on-site progress is available in
  /// these modes) and returns the card for convenience.
  MediaCardData? _record() {
    final c = card;
    if (c != null) {
      ContinueWatchingService.instance.record(
        c,
        season: c.isMovie ? null : season,
        episode: c.isMovie ? null : episode,
      );
    }
    return c;
  }
}

/// Web: the embed site rendered in an `<iframe>` filling the screen.
class _IframePlayer extends StatelessWidget {
  final String title;
  final String embedUrl;
  final MediaCardData? card;

  const _IframePlayer({
    required this.title,
    required this.embedUrl,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: buildWebIframe(embedUrl),
    );
  }
}

/// Desktop without an inline WebView (Linux): open the player in the browser.
class _ExternalBrowserPlayer extends StatefulWidget {
  final String title;
  final String embedUrl;
  final MediaCardData? card;

  const _ExternalBrowserPlayer({
    required this.title,
    required this.embedUrl,
    required this.card,
  });

  @override
  State<_ExternalBrowserPlayer> createState() => _ExternalBrowserPlayerState();
}

class _ExternalBrowserPlayerState extends State<_ExternalBrowserPlayer> {
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    // Auto-open once; the user can re-open from the button afterwards.
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    setState(() => _opened = true);
    try {
      await launchUrl(
        Uri.parse(widget.embedUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {/* surfaced by the still-visible button */}
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.open_in_browser, color: Colors.white54, size: 64),
              const SizedBox(height: 18),
              Text(
                _opened ? "Opened in your browser" : "Opening in your browser…",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "This player runs as a website. On desktop, the in-app torrent "
                "player usually gives a smoother experience.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _open,
                style: FilledButton.styleFrom(backgroundColor: accent),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text("Open again"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
