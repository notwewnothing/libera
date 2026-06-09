import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class PlayerScreen extends StatefulWidget {
  final String title;
  final String embedUrl;

  const PlayerScreen({super.key, required this.title, required this.embedUrl});

  factory PlayerScreen.movie({
    Key? key,
    required int tmdbId,
    required String title,
  }) => PlayerScreen(
    key: key,
    title: title,
    embedUrl: 'https://www.vidking.net/embed/movie/$tmdbId'
        '?color=e50914&autoPlay=true&nextEpisode=true&episodeSelector=true',
  );

  factory PlayerScreen.episode({
    Key? key,
    required int tmdbId,
    required int season,
    required int episode,
    required String title,
  }) => PlayerScreen(
    key: key,
    title: title,
    embedUrl: 'https://www.vidking.net/embed/tv/$tmdbId/$season/$episode'
        '?color=e50914&autoPlay=true&nextEpisode=true&episodeSelector=true',
  );

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _isLandscape = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (url.contains('google.')) {
              _controller.loadRequest(Uri.parse(widget.embedUrl));
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
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

  @override
  void dispose() {
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
                widget.title,
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
