import 'package:flutter/material.dart';
import 'package:libera/common/adapters.dart';
import 'package:libera/common/media_widgets.dart';
import 'package:libera/common/navigation.dart';
import 'package:libera/common/provider_badge.dart';
import 'package:libera/screens/player_screen.dart';
import 'package:libera/screens/top10_screen.dart';
import 'package:libera/services/api_service.dart';
import 'package:libera/services/continue_watching_service.dart';
import 'package:libera/services/watchlist_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiServices apiServices = ApiServices();

  late Future<List<MediaCardData>> trendingCards;
  late Future<List<MediaCardData>> topMovies;
  late Future<List<MediaCardData>> topShows;
  late Future<List<MediaCardData>> actionMovies;
  late Future<List<MediaCardData>> comedyMovies;
  late Future<List<MediaCardData>> horrorMovies;
  late Future<List<MediaCardData>> dramaMovies;

  final PageController _heroController = PageController(initialPage: 4000);
  int _heroPage = 0;

  static const int _heroCount = 8;

  @override
  void initState() {
    super.initState();
    trendingCards = apiServices.fetchTrending().then(
      (d) => (d?.results ?? [])
          .where((e) => e.posterPath != null)
          .map(trendingToCard)
          .toList(),
    );
    topMovies = apiServices.popularMovies().then(
      (d) => (d?.results ?? []).map(popularToCard).toList(),
    );
    topShows = apiServices.trendingshows().then(
      (d) => (d?.results ?? []).map(showToCard).toList(),
    );
    actionMovies = apiServices.actionMovies().then(
      (d) => (d?.results ?? [])
          .map((r) => actionToCard(r, genreLabel: "Action"))
          .toList(),
    );
    comedyMovies = apiServices.comedyMovies().then(
      (d) => (d?.results ?? [])
          .map((r) => comedyToCard(r, genreLabel: "Comedy"))
          .toList(),
    );
    horrorMovies = apiServices.horrorMovies().then(
      (d) => (d?.results ?? [])
          .map((r) => horrorToCard(r, genreLabel: "Horror"))
          .toList(),
    );
    dramaMovies = apiServices.dramaMovies().then(
      (d) => (d?.results ?? [])
          .map((r) => dramaToCard(r, genreLabel: "Drama"))
          .toList(),
    );
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _hero(context),
            _continueWatching(context),
            _myList(context),
            _numberedRow("Trending Movies", topMovies),
            _numberedRow("Trending Shows", topShows),
            _nextWatch(context),
            _posterRow("Action", actionMovies),
            _posterRow("Comedy", comedyMovies),
            _posterRow("Horror", horrorMovies),
            _posterRow("Drama", dramaMovies),
            // Clears the floating nav pill.
            const SizedBox(height: 110),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- hero

  Widget _hero(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final topPad = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: size.height * 0.72,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<List<MediaCardData>>(
            future: trendingCards,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white24),
                );
              }
              final items = (snapshot.data ?? []).take(_heroCount).toList();
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    snapshot.hasError ? "Error: ${snapshot.error}" : "No Data",
                    style: const TextStyle(color: Colors.white54),
                  ),
                );
              }
              final current = items[_heroPage];
              return Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _heroController,
                    itemCount: 8000,
                    onPageChanged: (i) =>
                        setState(() => _heroPage = i % items.length),
                    itemBuilder: (context, index) {
                      final item = items[index % items.length];
                      return GestureDetector(
                        onTap: () => openDetail(
                          context,
                          id: item.id,
                          isMovie: item.isMovie,
                        ),
                        child: poster(
                          item.posterPath,
                          fallbackIcon: Icons.movie,
                        ),
                      );
                    },
                  ),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black,
                            Colors.black.withValues(alpha: 0.55),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                          ],
                          stops: const [0, 0.12, 0.38, 0.88, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IgnorePointer(child: _heroMeta(current)),
                        const SizedBox(height: 16),
                        _heroButtons(current),
                        const SizedBox(height: 18),
                        IgnorePointer(child: _heroDots(items.length)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            top: topPad + 4,
            left: 20,
            child: const IgnorePointer(
              child: Text(
                "Dih 🥀",
                style: TextStyle(
                  color: Color.fromARGB(255, 255, 0, 0),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 12)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroMeta(MediaCardData item) {
    final label = [
      item.typeLabel,
      item.genreLabel,
    ].where((e) => e != null && e.isNotEmpty).join("  ·  ");
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ProviderBadge(id: item.id, isMovie: item.isMovie, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _heroButtons(MediaCardData item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => openDetail(context, id: item.id, isMovie: item.isMovie),
          child: Container(
            height: 50,
            width: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
                SizedBox(width: 4),
                Text(
                  "Play",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        ListenableBuilder(
          listenable: WatchlistService.instance,
          builder: (context, _) {
            final inList = WatchlistService.instance.contains(
              item.id,
              isMovie: item.isMovie,
            );
            return GestureDetector(
              onTap: () => WatchlistService.instance.toggle(item),
              child: Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade800.withValues(alpha: 0.75),
                ),
                child: Icon(
                  inList ? Icons.check : Icons.add,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _heroDots(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == _heroPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3.5),
          height: active ? 8 : 6,
          width: active ? 8 : 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.35),
          ),
        );
      }),
    );
  }

  // ---------------------------------------------------------------- rows

  Widget _numberedRow(String title, Future<List<MediaCardData>> future) {
    return FutureBuilder<List<MediaCardData>>(
      future: future,
      builder: (context, snapshot) {
        final items = (snapshot.data ?? []).take(10).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: title,
              onTap: items.isEmpty
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Top10Screen(title: title, items: items),
                      ),
                    ),
            ),
            SizedBox(
              height: 256,
              child: _rowBody(
                snapshot,
                items,
                itemBuilder: (context, index) =>
                    _NumberedCard(rank: index + 1, item: items[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _posterRow(String title, Future<List<MediaCardData>> future) {
    return FutureBuilder<List<MediaCardData>>(
      future: future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: title,
              onTap: items.isEmpty
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Top10Screen(title: title, items: items),
                      ),
                    ),
            ),
            SizedBox(
              height: 180,
              child: _rowBody(
                snapshot,
                items,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return PosterCard(
                    item: item,
                    onTap: () =>
                        openDetail(context, id: item.id, isMovie: item.isMovie),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _rowBody(
    AsyncSnapshot snapshot,
    List<MediaCardData> items, {
    required IndexedWidgetBuilder itemBuilder,
  }) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white24),
      );
    }
    if (items.isEmpty) {
      return Center(
        child: Text(
          snapshot.hasError ? "Error: ${snapshot.error}" : "No Data",
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: itemBuilder,
    );
  }

  Widget _continueWatching(BuildContext context) {
    return ListenableBuilder(
      listenable: ContinueWatchingService.instance,
      builder: (context, _) {
        final entries = ContinueWatchingService.instance.entries;
        if (entries.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: "Continue Watching"),
            SizedBox(
              height: 256,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _ContinueCard(entry: entries[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _myList(BuildContext context) {
    return ListenableBuilder(
      listenable: WatchlistService.instance,
      builder: (context, _) {
        final items = WatchlistService.instance.items;
        if (items.isEmpty) return const SizedBox.shrink();
        final cardWidth = MediaQuery.sizeOf(context).width - 56;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: "My List"),
            SizedBox(
              height: 420,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return FeaturedLandscapeCard(
                    item: item,
                    width: cardWidth,
                    height: 420,
                    preferPoster: true,
                    onTap: () =>
                        openDetail(context, id: item.id, isMovie: item.isMovie),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _nextWatch(BuildContext context) {
    return FutureBuilder<List<MediaCardData>>(
      future: trendingCards,
      builder: (context, snapshot) {
        final items = (snapshot.data ?? []).skip(_heroCount).take(6).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        final cardWidth = MediaQuery.sizeOf(context).width - 56;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: "Must Watch"),
            SizedBox(
              height: 420,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return FeaturedLandscapeCard(
                    item: item,
                    width: cardWidth,
                    height: 420,
                    preferPoster: true,
                    onTap: () =>
                        openDetail(context, id: item.id, isMovie: item.isMovie),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// Same look as the Trending Movies cards, but tapping resumes playback and a
// long press removes the entry from the rail.
class _ContinueCard extends StatelessWidget {
  final ContinueWatchingEntry entry;

  const _ContinueCard({required this.entry});

  void _resume(BuildContext context) {
    final card = entry.card;
    final startAt = ContinueWatchingService.instance.resumePosition(
      card.id,
      isMovie: card.isMovie,
      season: entry.season,
      episode: entry.episode,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => card.isMovie
            ? PlayerScreen.movie(card: card, startAt: startAt)
            : PlayerScreen.episode(
                card: card,
                season: entry.season ?? 1,
                episode: entry.episode ?? 1,
                title:
                    "${card.title} · S${entry.season ?? 1} "
                    "E${entry.episode ?? 1}",
                startAt: startAt,
              ),
      ),
    );
  }

  void _remove(BuildContext context) {
    ContinueWatchingService.instance.remove(
      entry.card.id,
      isMovie: entry.card.isMovie,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Removed from Continue Watching"),
        backgroundColor: Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final caption = entry.card.isMovie
        ? "Movie"
        : "S${entry.season ?? 1} · E${entry.episode ?? 1}";
    return SizedBox(
      width: 150,
      child: GestureDetector(
        onLongPress: () => _remove(context),
        child: Column(
          children: [
            Stack(
              children: [
                PosterCard(
                  item: entry.card,
                  width: 150,
                  onTap: () => _resume(context),
                ),
                if (entry.progress > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(12),
                        ),
                        child: Container(
                          height: 4,
                          color: Colors.white.withValues(alpha: 0.25),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: entry.progress,
                            child: Container(color: const Color(0xFFE50914)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberedCard extends StatelessWidget {
  final int rank;
  final MediaCardData item;

  const _NumberedCard({required this.rank, required this.item});

  @override
  Widget build(BuildContext context) {
    final caption = item.genreLabel ?? item.typeLabel ?? "";
    return SizedBox(
      width: 150,
      child: Column(
        children: [
          Stack(
            children: [
              PosterCard(
                item: item,
                width: 150,
                onTap: () =>
                    openDetail(context, id: item.id, isMovie: item.isMovie),
              ),
              Positioned(
                top: 2,
                left: 10,
                child: IgnorePointer(
                  child: Text(
                    "$rank",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.8),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
