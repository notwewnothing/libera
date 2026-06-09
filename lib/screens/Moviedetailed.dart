import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:libera/common/utils.dart';
import 'package:libera/model/credits.dart';
import 'package:libera/model/media_list.dart';
import 'package:libera/model/movie_details.dart';
import 'package:libera/model/watch_provider.dart';
import 'package:libera/screens/detail_widgets.dart';
import 'package:libera/screens/player_screen.dart';
import 'package:libera/services/api_service.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class MovieDetailedScreen extends StatefulWidget {
  final int movieid;
  const MovieDetailedScreen({super.key, required this.movieid});

  @override
  State<MovieDetailedScreen> createState() => _MovieDetailedScreenState();
}

class _MovieDetailedScreenState extends State<MovieDetailedScreen> {
  final ApiServices apiServices = ApiServices();
  late Future<MovieDetails?> movieDetails;
  VideoPlayerController? _videoController;
  List<StreamingProvider> _providers = [];
  List<CastMember> _cast = [];
  List<MediaItem> _similar = [];

  bool _isVideoReady = false;
  bool _showVideo = false;
  bool isMuted = true;

  @override
  void initState() {
    super.initState();
    movieDetails = apiServices.movieDetails(widget.movieid);
    _fetchTrailer();
    _fetchProviders();
    _fetchCast();
    _fetchSimilar();
  }

  void _fetchProviders() async {
    try {
      final data = await apiServices.fetchWatchProviders(widget.movieid);
      if (data == null || !mounted) return;
      final region =
          data.results['US'] ??
          (data.results.isNotEmpty ? data.results.values.first : null);
      if (region != null && mounted) {
        setState(() => _providers = region.allProviders.take(4).toList());
      }
    } catch (e) {
      debugPrint("Failed to fetch watch providers: $e");
    }
  }

  void _fetchCast() async {
    try {
      final credits = await apiServices.fetchMovieCredits(widget.movieid);
      if (credits == null || !mounted) return;
      final cast = credits.cast.toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      setState(() => _cast = cast.take(15).toList());
    } catch (e) {
      debugPrint("Failed to fetch cast: $e");
    }
  }

  void _fetchSimilar() async {
    try {
      final data = await apiServices.fetchSimilarMovies(widget.movieid);
      if (data == null || !mounted) return;
      setState(() => _similar =
          data.results.where((m) => m.posterPath != null).toList());
    } catch (e) {
      debugPrint("Failed to fetch similar movies: $e");
    }
  }

  void _fetchTrailer() async {
    try {
      final videosResponse = await apiServices.fetchMovieVideo(widget.movieid);
      if (videosResponse == null || videosResponse.results.isEmpty) return;

      final youtubeVideos = videosResponse.results
          .where((v) => v.site.toLowerCase() == 'youtube' && v.key.isNotEmpty)
          .toList();
      if (youtubeVideos.isEmpty) return;

      final trailer = youtubeVideos.firstWhere(
        (v) => v.type.toLowerCase() == 'trailer',
        orElse: () => youtubeVideos.first,
      );

      final yt = YoutubeExplode();
      try {
        final manifest = await yt.videos.streamsClient.getManifest(trailer.key);
        final muxed = manifest.muxed.toList();
        if (muxed.isEmpty) return;
        muxed.sort(
          (a, b) => a.videoQuality.index.compareTo(b.videoQuality.index),
        );
        final streamUrl = muxed.last.url.toString();

        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(streamUrl),
        );
        await _videoController!.initialize();
        _videoController!.setLooping(true);
        _videoController!.setVolume(0);
        _videoController!.play();

        if (mounted) {
          setState(() => _isVideoReady = true);
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) setState(() => _showVideo = true);
          });
        }
      } finally {
        yt.close();
      }
    } catch (e) {
      debugPrint("Failed to fetch movie trailer: $e");
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final headerHeight = size.height * 0.45;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: FutureBuilder<MovieDetails?>(
          future: movieDetails,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: size.height,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return SizedBox(
                height: size.height,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white54,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Something Went Wrong",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (snapshot.hasError)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            "${snapshot.error}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }

            final movie = snapshot.data!;
            final year = movie.releaseDate?.year.toString();
            final genreNames = movie.genres.map((g) => g.name).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, size, headerHeight, movie.posterPath),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 12, 15, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Line 1: title (left) + providers (right)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              movie.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (_providers.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            ProviderLogos(providers: _providers),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Line 2: year, rating, runtime, genres
                      MetaRow(
                        year: year,
                        voteAverage: movie.voteAverage,
                        runtime: movie.runtime,
                        genres: genreNames,
                      ),
                      const SizedBox(height: 16),
                      // Action buttons
                      DetailActionButtons(
                        onPlay: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlayerScreen.movie(
                                tmdbId: movie.id,
                                title: movie.title,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      // Description
                      if (movie.overview.isNotEmpty) ...[
                        const Text(
                          "Overview",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          movie.overview,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
                // Cast slider
                if (_cast.isNotEmpty) CastSection(cast: _cast),
                // Similar movies slider
                if (_similar.isNotEmpty)
                  _SimilarSection(items: _similar),
                const SizedBox(height: 30),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Size size,
    double headerHeight,
    String? posterPath,
  ) {
    return SizedBox(
      height: headerHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_isVideoReady && _videoController != null)
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            ),
          AnimatedOpacity(
            opacity: _showVideo ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 1000),
            child: posterPath != null
                ? CachedNetworkImage(
                    imageUrl: "$imageUrl$posterPath",
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: Colors.grey.shade900),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.shade900,
                      child: const Icon(
                        Icons.movie,
                        color: Colors.white24,
                        size: 64,
                      ),
                    ),
                  )
                : Container(
                    color: Colors.grey.shade900,
                    child: const Icon(
                      Icons.movie,
                      color: Colors.white24,
                      size: 64,
                    ),
                  ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: headerHeight * 0.5,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black,
                    Color(0xCC000000),
                    Color(0x66000000),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.3, 0.65, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            left: 15,
            top: 50,
            child: DetailCircleButton(
              icon: Icons.close,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (_isVideoReady)
            Positioned(
              right: 15,
              top: 50,
              child: DetailCircleButton(
                icon: isMuted ? Icons.volume_off : Icons.volume_up,
                iconSize: 22,
                onPressed: () {
                  setState(() {
                    isMuted = !isMuted;
                    _videoController?.setVolume(isMuted ? 0 : 1);
                  });
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SimilarSection extends StatelessWidget {
  final List<MediaItem> items;
  const _SimilarSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 15, top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "More Like This",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MovieDetailedScreen(movieid: item.id),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: CachedNetworkImage(
                        imageUrl: "$imageUrl${item.posterPath}",
                        width: 120,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(width: 120, color: Colors.grey.shade900),
                        errorWidget: (_, _, _) => Container(
                          width: 120,
                          color: Colors.grey.shade900,
                          child: const Icon(Icons.movie, color: Colors.white24),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
