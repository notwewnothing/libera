import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libera/screens/detail_widgets.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class TrailerPlayerScreen extends StatefulWidget {
  final String title;
  final String youtubeKey;

  const TrailerPlayerScreen({
    super.key,
    required this.title,
    required this.youtubeKey,
  });

  @override
  State<TrailerPlayerScreen> createState() => _TrailerPlayerScreenState();
}

class _TrailerPlayerScreenState extends State<TrailerPlayerScreen> {
  VideoPlayerController? _controller;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _load();
  }

  Future<void> _load() async {
    final yt = YoutubeExplode();
    try {
      final manifest =
          await yt.videos.streamsClient.getManifest(widget.youtubeKey);
      final muxed = manifest.muxed.toList();
      if (muxed.isEmpty) throw Exception("No playable stream");
      muxed.sort(
        (a, b) => a.videoQuality.index.compareTo(b.videoQuality.index),
      );
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(muxed.last.url.toString()));
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      controller.play();
      setState(() => _controller = controller);
    } catch (e) {
      debugPrint("Failed to play trailer: $e");
      if (mounted) setState(() => _error = true);
    } finally {
      yt.close();
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _togglePlay,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Center(
              child: _error
                  ? Text(
                      "Couldn't play this trailer",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    )
                  : c == null
                      ? const CircularProgressIndicator(color: Colors.white24)
                      : AspectRatio(
                          aspectRatio: c.value.aspectRatio,
                          child: VideoPlayer(c),
                        ),
            ),
            if (c != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.paddingOf(context).bottom + 16,
                child: VideoProgressIndicator(
                  c,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white.withValues(alpha: 0.3),
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
            Positioned(
              left: 15,
              top: MediaQuery.paddingOf(context).top + 8,
              child: DetailCircleButton(
                icon: Icons.close,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
