import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:libera/common/platform.dart';
import 'package:libera/common/web_embed.dart';
import 'package:libera/screens/detail_widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Video;

/// Full-screen trailer player.
///
/// On native platforms it resolves the YouTube stream with `youtube_explode`
/// and plays it through media_kit (works on mobile AND desktop, unlike
/// video_player). On web — where youtube_explode is blocked by CORS — it embeds
/// YouTube's own iframe player instead.
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
  Player? _player;
  VideoController? _controller;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    setOrientationsSafe([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!kIsWeb) _load();
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
      final player = Player();
      final controller = VideoController(player);
      await player.open(Media(muxed.last.url.toString()));
      if (!mounted) {
        player.dispose();
        return;
      }
      setState(() {
        _player = player;
        _controller = controller;
      });
    } catch (e) {
      debugPrint("Failed to play trailer: $e");
      if (mounted) setState(() => _error = true);
    } finally {
      yt.close();
    }
  }

  @override
  void dispose() {
    setOrientationsSafe([DeviceOrientation.portraitUp]);
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _content()),
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
    );
  }

  Widget _content() {
    if (kIsWeb) {
      // YouTube's iframe player handles its own controls on web.
      return buildWebIframe(
        'https://www.youtube.com/embed/${widget.youtubeKey}'
        '?autoplay=1&rel=0&playsinline=1',
      );
    }
    if (_error) {
      return Center(
        child: Text(
          "Couldn't play this trailer",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
      );
    }
    final controller = _controller;
    if (controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white24),
      );
    }
    return Video(
      controller: controller,
      controls: MaterialVideoControls,
      fit: BoxFit.contain,
    );
  }
}
