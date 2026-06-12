import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:libera/common/media_widgets.dart';
import 'package:libera/common/utils.dart';
import 'package:libera/model/credits.dart';
import 'package:libera/model/media_list.dart';
import 'package:libera/model/movie_video.dart';
import 'package:libera/model/season_details.dart';
import 'package:libera/model/tv_details.dart';
import 'package:libera/model/watch_provider.dart';
import 'package:libera/screens/detail_widgets.dart';
import 'package:libera/screens/player_screen.dart';
import 'package:libera/services/api_service.dart';
import 'package:libera/services/continue_watching_service.dart';
import 'package:libera/services/watched_service.dart';
import 'package:libera/services/watchlist_service.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class TvShowDetailedScreen extends StatefulWidget {
  final int tvid;
  const TvShowDetailedScreen({super.key, required this.tvid});

  @override
  State<TvShowDetailedScreen> createState() => _TvShowDetailedScreenState();
}

class _TvShowDetailedScreenState extends State<TvShowDetailedScreen> {
  final ApiServices apiServices = ApiServices();
  late Future<TvDetails?> tvDetails;
  VideoPlayerController? _videoController;
  List<StreamingProvider> _providers = [];
  List<CastMember> _cast = [];
  List<MediaItem> _similar = [];
  List<MovieVideoResult> _videos = [];

  List<Episode> _episodes = [];
  int _selectedSeason = 1;
  bool _episodesLoading = true;

  bool _isVideoReady = false;
  bool _showVideo = false;
  bool isMuted = true;

  @override
  void initState() {
    super.initState();
    tvDetails = apiServices.tvDetails(widget.tvid);
    _fetchTrailer();
    _fetchProviders();
    _fetchCast();
    _fetchSimilar();
    _fetchEpisodes(_selectedSeason);
  }

  void _fetchEpisodes(int season) async {
    setState(() => _episodesLoading = true);
    try {
      final data = await apiServices.fetchSeasonDetails(widget.tvid, season);
      if (!mounted) return;
      setState(() {
        _episodes = data?.episodes ?? [];
        _episodesLoading = false;
      });
    } catch (e) {
      debugPrint("Failed to fetch episodes: $e");
      if (mounted) setState(() => _episodesLoading = false);
    }
  }

  void _onSeasonChanged(int season) {
    setState(() {
      _selectedSeason = season;
      _episodes = [];
    });
    _fetchEpisodes(season);
  }

  void _play(
    MediaCardData card,
    String showName,
    int episodeNumber,
    String? episodeName, {
    int? season,
  }) {
    final s = season ?? _selectedSeason;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen.episode(
          card: card,
          season: s,
          episode: episodeNumber,
          title: episodeName != null && episodeName.isNotEmpty
              ? "$showName · $episodeName"
              : "$showName · S$s E$episodeNumber",
          startAt: ContinueWatchingService.instance.resumePosition(
            card.id,
            isMovie: false,
            season: s,
            episode: episodeNumber,
          ),
        ),
      ),
    );
  }

  void _playResume(MediaCardData card, ContinueWatchingEntry entry) {
    final season = entry.season ?? 1;
    final episode = entry.episode ?? 1;
    String? episodeName;
    if (season == _selectedSeason) {
      for (final e in _episodes) {
        if (e.episodeNumber == episode) {
          episodeName = e.name;
          break;
        }
      }
    }
    _play(card, card.title, episode, episodeName, season: season);
  }

  void _fetchProviders() async {
    try {
      final data = await apiServices.fetchTvWatchProviders(widget.tvid);
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
      final credits = await apiServices.fetchTvCredits(widget.tvid);
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
      final data = await apiServices.fetchSimilarTvShows(widget.tvid);
      if (data == null || !mounted) return;
      setState(
        () =>
            _similar = data.results.where((m) => m.posterPath != null).toList(),
      );
    } catch (e) {
      debugPrint("Failed to fetch similar tv shows: $e");
    }
  }

  void _fetchTrailer() async {
    try {
      final videosResponse = await apiServices.fetchTvVideo(widget.tvid);
      if (videosResponse == null || videosResponse.results.isEmpty) return;

      final youtubeVideos = videosResponse.results
          .where((v) => v.site.toLowerCase() == 'youtube' && v.key.isNotEmpty)
          .toList();
      if (youtubeVideos.isEmpty) return;

      var sectionVideos = youtubeVideos
          .where((v) {
            final t = v.type.toLowerCase();
            return t == 'trailer' || t == 'teaser';
          })
          .take(6)
          .toList();
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
      debugPrint("Failed to fetch tv trailer: $e");
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

  void _toggleEpisodeWatched(MediaCardData card, Episode e) async {
    final added = await WatchedService.instance.toggleEpisode(
      card,
      _selectedSeason,
      e.episodeNumber,
    );
    if (!added) return;
    final idx = _episodes.indexWhere((x) => x.episodeNumber == e.episodeNumber);
    final next = (idx >= 0 && idx + 1 < _episodes.length)
        ? _episodes[idx + 1].episodeNumber
        : e.episodeNumber;
    ContinueWatchingService.instance.record(
      card,
      season: _selectedSeason,
      episode: next,
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

  Widget _fadeSwitch(Widget child) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final headerHeight = size.height * 0.62;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: FutureBuilder<TvDetails?>(
          future: tvDetails,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _fadeSwitch(
                SizedBox(
                  key: const ValueKey("loading"),
                  height: size.height,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
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

            final show = snapshot.data!;
            final year = show.firstAirDate?.year.toString();
            final genreNames = show.genres.map((g) => g.name).toList();
            final seasonsLabel = show.numberOfSeasons > 0
                ? "${show.numberOfSeasons} "
                      "${show.numberOfSeasons == 1 ? "Season" : "Seasons"}"
                : null;
            final metaLine = ["TV Show", ...genreNames.take(2)].join("  ·  ");
            final card = MediaCardData(
              id: show.id,
              title: show.name,
              posterPath: show.posterPath,
              backdropPath: show.backdropPath,
              genreLabel: genreNames.isNotEmpty ? genreNames.first : null,
              typeLabel: "TV Show",
              isMovie: false,
              overview: show.overview,
            );

            return _fadeSwitch(
              Column(
                key: const ValueKey("content"),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(
                    context,
                    headerHeight,
                    posterPath: show.posterPath,
                    title: show.name,
                    metaLine: metaLine,
                    card: card,
                    onPlay: () => _play(
                      card,
                      show.name,
                      _episodes.isNotEmpty ? _episodes.first.episodeNumber : 1,
                      _episodes.isNotEmpty ? _episodes.first.name : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (show.overview.isNotEmpty) ...[
                          ExpandableOverview(text: show.overview),
                          const SizedBox(height: 16),
                        ],
                        MetaRow(
                          year: year,
                          voteAverage: show.voteAverage,
                          extraLabel: seasonsLabel,
                          genres: genreNames,
                        ),
                      ],
                    ),
                  ),
                  ListenableBuilder(
                    listenable: WatchedService.instance,
                    builder: (context, _) => SeasonEpisodesSection(
                      seasonCount: show.numberOfSeasons,
                      selectedSeason: _selectedSeason,
                      episodes: _episodes,
                      loading: _episodesLoading,
                      onSeasonChanged: _onSeasonChanged,
                      onPlayEpisode: (e) =>
                          _play(card, show.name, e.episodeNumber, e.name),
                      isEpisodeWatched: (e) =>
                          WatchedService.instance.isEpisodeWatched(
                            card.id,
                            _selectedSeason,
                            e.episodeNumber,
                          ),
                      onToggleWatched: (e) => _toggleEpisodeWatched(card, e),
                    ),
                  ),
                  if (_videos.isNotEmpty) TrailersSection(videos: _videos),
                  if (_cast.isNotEmpty) CastSection(cast: _cast),
                  if (_similar.isNotEmpty) _SimilarSection(items: _similar),
                  const SizedBox(height: 30),
                ],
              ),
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
                        Icons.tv,
                        color: Colors.white24,
                        size: 64,
                      ),
                    ),
                  )
                : Container(
                    color: Colors.grey.shade900,
                    child: const Icon(
                      Icons.tv,
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
                      ContinueWatchingService.instance,
                    ]),
                    builder: (context, _) {
                      final resume = ContinueWatchingService.instance.entryFor(
                        card.id,
                        isMovie: false,
                      );
                      final hasResume = resume != null && resume.episode != null;
                      return HeroActionButtons(
                        playLabel: hasResume
                            ? "Resume S${resume.season ?? 1} E${resume.episode}"
                            : "Play First Episode",
                        onPlay: hasResume
                            ? () => _playResume(card, resume)
                            : onPlay,
                        inMyList: WatchlistService.instance.contains(
                          card.id,
                          isMovie: false,
                        ),
                        onMyList: () => _toggleMyList(card),
                      );
                    },
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
              return Pressable(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TvShowDetailedScreen(tvid: item.id),
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
                      child: const Icon(Icons.tv, color: Colors.white24),
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
