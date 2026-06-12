import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:libera/common/media_widgets.dart';
import 'package:libera/common/utils.dart';
import 'package:libera/model/credits.dart';
import 'package:libera/model/media_list.dart';
import 'package:libera/model/movie_details.dart';
import 'package:libera/model/movie_video.dart';
import 'package:libera/model/watch_provider.dart';
import 'package:libera/screens/detail_widgets.dart';
import 'package:libera/screens/player_screen.dart';
import 'package:libera/services/api_service.dart';
import 'package:libera/services/continue_watching_service.dart';
import 'package:libera/services/watched_service.dart';
import 'package:libera/services/watchlist_service.dart';
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
  List<MovieVideoResult> _videos = [];

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

      // Trailers/teasers feed the Trailers section below the fold.
      var sectionVideos = youtubeVideos.where((v) {
        final t = v.type.toLowerCase();
        return t == 'trailer' || t == 'teaser';
      }).take(6).toList();
      if (sectionVideos.isEmpty) {
        sectionVideos = youtubeVideos.take(6).toList();
      }
      if (mounted) setState(() => _videos = sectionVideos);

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

  void _onDownload() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Downloads are coming soon"),
        backgroundColor: Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onPlay(MovieDetails movie, MediaCardData card) {
    ContinueWatchingService.instance.record(card);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen.movie(
          tmdbId: movie.id,
          title: movie.title,
        ),
      ),
    );
  }

  void _toggleWatched(MediaCardData card) async {
    final added = await WatchedService.instance.toggleMovie(card);
    // A finished movie has no business on the Continue Watching rail.
    if (added) {
      ContinueWatchingService.instance.remove(card.id, isMovie: true);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added ? "Marked as watched" : "Marked as unwatched"),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _toggleMyList(MediaCardData card) async {
    final added = await WatchlistService.instance.toggle(card);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added ? "Added to your watchlist" : "Removed from your watchlist",
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final headerHeight = size.height * 0.62;

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
            final metaLine =
                ["Movie", ...genreNames.take(2)].join("  ·  ");
            final card = MediaCardData(
              id: movie.id,
              title: movie.title,
              posterPath: movie.posterPath,
              backdropPath: movie.backdropPath,
              genreLabel: genreNames.isNotEmpty ? genreNames.first : null,
              typeLabel: "Movie",
              isMovie: true,
              overview: movie.overview,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(
                  context,
                  headerHeight,
                  posterPath: movie.posterPath,
                  title: movie.title,
                  metaLine: metaLine,
                  card: card,
                  onPlay: () => _onPlay(movie, card),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (movie.overview.isNotEmpty) ...[
                        ExpandableOverview(text: movie.overview),
                        const SizedBox(height: 16),
                      ],
                      MetaRow(
                        year: year,
                        voteAverage: movie.voteAverage,
                        runtime: movie.runtime,
                        genres: genreNames,
                      ),
                    ],
                  ),
                ),
                if (_videos.isNotEmpty) TrailersSection(videos: _videos),
                if (_cast.isNotEmpty) CastSection(cast: _cast),
                if (_similar.isNotEmpty) _SimilarSection(items: _similar),
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
    double headerHeight, {
    required String? posterPath,
    required String title,
    required String metaLine,
    required MediaCardData card,
    required VoidCallback onPlay,
  }) {
    final topPad = MediaQuery.paddingOf(context).top;
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
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black,
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                  ],
                  stops: const [0, 0.14, 0.42, 0.86, 1],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IgnorePointer(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.05,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 12),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  IgnorePointer(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            metaLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_providers.isNotEmpty)
                          ProviderLogos(providers: _providers),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      WatchlistService.instance,
                      WatchedService.instance,
                    ]),
                    builder: (context, _) => HeroActionButtons(
                      onPlay: onPlay,
                      inMyList: WatchlistService.instance.contains(
                        card.id,
                        isMovie: true,
                      ),
                      onMyList: () => _toggleMyList(card),
                      inWatched: WatchedService.instance.isMovieWatched(
                        card.id,
                      ),
                      onWatched: () => _toggleWatched(card),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 15,
            top: topPad + 8,
            child: DetailCircleButton(
              icon: Icons.chevron_left,
              iconSize: 28,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            right: 15,
            top: topPad + 8,
            child: BlurPill(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.arrow_downward_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: _onDownload,
                ),
                if (_isVideoReady)
                  IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () {
                      setState(() {
                        isMuted = !isMuted;
                        _videoController?.setVolume(isMuted ? 0 : 1);
                      });
                    },
                  ),
              ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: "More Like This"),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return GestureDetector(
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
                  borderRadius: BorderRadius.circular(10),
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
              );
            },
          ),
        ),
      ],
    );
  }
}
