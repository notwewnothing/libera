import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libera/common/media_widgets.dart';
import 'package:libera/services/continue_watching_service.dart';
import 'package:libera/services/watched_service.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class PlayerScreen extends StatefulWidget {
  final String title;
  final String embedUrl;
  // Watch-progress tracking is enabled when a card is provided.
  final MediaCardData? card;
  final int? season;
  final int? episode;
  final double startAt;

  const PlayerScreen({
    super.key,
    required this.title,
    required this.embedUrl,
    this.card,
    this.season,
    this.episode,
    this.startAt = 0,
  });

  static String _params(double startAt) =>
      '?color=e50914&autoPlay=true&nextEpisode=true&episodeSelector=true'
      '${startAt > 0 ? "&progress=${startAt.round()}" : ""}';

  factory PlayerScreen.movie({
    Key? key,
    required MediaCardData card,
    double startAt = 0,
  }) => PlayerScreen(
    key: key,
    title: card.title,
    card: card,
    startAt: startAt,
    embedUrl:
        'https://www.vidking.net/embed/movie/${card.id}${_params(startAt)}',
  );

  factory PlayerScreen.episode({
    Key? key,
    required MediaCardData card,
    required int season,
    required int episode,
    required String title,
    double startAt = 0,
  }) => PlayerScreen(
    key: key,
    title: title,
    card: card,
    season: season,
    episode: episode,
    startAt: startAt,
    embedUrl:
        'https://www.vidking.net/embed/tv/${card.id}/$season/$episode'
        '${_params(startAt)}',
  );

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _isLandscape = false;

  late String _title = widget.title;
  late int _season = widget.season ?? 1;
  late int _episode = widget.episode ?? 1;
  late double _position = widget.startAt;
  double _duration = 0;
  DateTime _lastSave = DateTime.now();

  MediaCardData? get _card => widget.card;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final card = _card;
    if (card != null) {
      ContinueWatchingService.instance.record(
        card,
        season: card.isMovie ? null : _season,
        episode: card.isMovie ? null : _episode,
      );
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'LiberaProgress',
        onMessageReceived: (message) => _onPlayerMessage(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (url.contains('google.')) {
              _controller.loadRequest(Uri.parse(widget.embedUrl));
            }
          },
          onUrlChange: (change) => _onUrlChanged(change.url),
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
            _hookPlayerEvents();
          },
          onWebResourceError: (error) {
            debugPrint("WebView error: ${error.description}");
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (!url.startsWith('http://') && !url.startsWith('https://')) {
              return NavigationDecision.prevent;
            }
            if (!url.contains('vidking.net') && !url.contains('google.')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.embedUrl));

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
  }

  // The embed posts PLAYER_EVENT messages to its parent window; since the
  // embed is our top document here, a window message listener catches them
  // and forwards them over the JavaScript channel.
  void _hookPlayerEvents() {
    _controller.runJavaScript('''
      if (!window.__liberaProgressHooked) {
        window.__liberaProgressHooked = true;
        window.addEventListener('message', function (e) {
          var d = e.data;
          if (typeof d !== 'string') {
            try { d = JSON.stringify(d); } catch (err) { return; }
          }
          if (window.LiberaProgress) { LiberaProgress.postMessage(d); }
        });
      }
    ''');
  }

  void _onPlayerMessage(String raw) {
    final card = _card;
    if (card == null) return;

    Map<String, dynamic>? data;
    try {
      final msg = jsonDecode(raw);
      if (msg is Map<String, dynamic> && msg["type"] == "PLAYER_EVENT") {
        data = (msg["data"] as Map?)?.cast<String, dynamic>();
      }
    } catch (_) {
      return;
    }
    if (data == null) return;

    if (!card.isMovie) {
      final season = (data["season"] as num?)?.toInt() ?? _season;
      final episode = (data["episode"] as num?)?.toInt() ?? _episode;
      if (season != _season || episode != _episode) {
        _handleEpisodeChange(season, episode);
      }
    }

    _position = (data["currentTime"] as num?)?.toDouble() ?? _position;
    _duration = (data["duration"] as num?)?.toDouble() ?? _duration;

    switch (data["event"]?.toString()) {
      case "ended":
        _onEnded(card);
      case "play":
      case "pause":
      case "seeked":
        _saveProgress();
      case "timeupdate":
        // timeupdate fires continuously; don't hammer storage.
        if (DateTime.now().difference(_lastSave).inSeconds >= 10) {
          _saveProgress();
        }
    }
  }

  // Fallback detection: the next-episode button / episode selector navigate
  // the embed to a new /embed/tv/<id>/<season>/<episode> URL.
  void _onUrlChanged(String? url) {
    final card = _card;
    if (url == null || card == null || card.isMovie) return;
    final match = RegExp(r'/embed/tv/\d+/(\d+)/(\d+)').firstMatch(url);
    if (match == null) return;
    final season = int.parse(match.group(1)!);
    final episode = int.parse(match.group(2)!);
    if (season != _season || episode != _episode) {
      _handleEpisodeChange(season, episode);
    }
  }

  void _handleEpisodeChange(int season, int episode) {
    final card = _card!;
    // Moving forward means the previous episode was finished.
    final forward =
        season > _season || (season == _season && episode > _episode);
    if (forward) {
      WatchedService.instance.markEpisodeWatched(card, _season, _episode);
    }
    _season = season;
    _episode = episode;
    _position = 0;
    _duration = 0;
    _lastSave = DateTime.now();
    if (mounted) {
      setState(() => _title = "${card.title} · S$season E$episode");
    }
    ContinueWatchingService.instance.record(
      card,
      season: season,
      episode: episode,
      positionSeconds: 0,
      durationSeconds: 0,
    );
  }

  void _saveProgress() {
    final card = _card;
    if (card == null) return;
    _lastSave = DateTime.now();
    ContinueWatchingService.instance.record(
      card,
      season: card.isMovie ? null : _season,
      episode: card.isMovie ? null : _episode,
      positionSeconds: _position,
      durationSeconds: _duration,
    );
  }

  void _onEnded(MediaCardData card) {
    if (card.isMovie) {
      WatchedService.instance.markMovieWatched(card);
      ContinueWatchingService.instance.remove(card.id, isMovie: true);
    } else {
      WatchedService.instance.markEpisodeWatched(card, _season, _episode);
      // Keep the rail entry: auto-advance fires an episode change next.
      _saveProgress();
    }
  }

  @override
  void dispose() {
    // Flush the last known position so leaving mid-playback still resumes.
    if (_card != null && _position > 0) _saveProgress();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    if (isLandscape != _isLandscape) {
      _isLandscape = isLandscape;
      SystemChrome.setEnabledSystemUIMode(
        isLandscape ? SystemUiMode.immersiveSticky : SystemUiMode.manual,
        overlays: isLandscape ? const [] : SystemUiOverlay.values,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: isLandscape
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              title: Text(
                _title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
            ),
      body: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _controller)),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)),
            ),
        ],
      ),
    );
  }
}
