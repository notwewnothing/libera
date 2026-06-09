import 'dart:async';

import 'package:flutter/material.dart';
import 'package:libera/common/adapters.dart';
import 'package:libera/common/media_widgets.dart';
import 'package:libera/common/navigation.dart';
import 'package:libera/screens/top10_screen.dart';
import 'package:libera/services/api_service.dart';

/// Libera "Search" tab: a live search box over a grid of browse-by-genre tiles.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiServices _api = ApiServices();
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  String _query = "";
  bool _loading = false;
  List<MediaCardData> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _query = "";
        _results = [];
        _loading = false;
      });
      return;
    }
    setState(() {
      _query = q;
      _loading = true;
    });
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    try {
      final data = await _api.searchMulti(q);
      if (!mounted || q != _query) return;
      final items = (data?.results ?? [])
          .where((e) =>
              (e.mediaType == 'movie' || e.mediaType == 'tv') &&
              e.posterPath != null)
          .map(trendingToCard)
          .toList();
      setState(() {
        _results = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Search",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            _searchBar(),
            const SizedBox(height: 12),
            Expanded(
              child: _query.isEmpty ? _categoryGrid() : _resultsView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: Colors.white.withValues(alpha: 0.7)),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                autocorrect: false,
                textInputAction: TextInputAction.search,
                cursorColor: Colors.blue,
                style: const TextStyle(color: Colors.white, fontSize: 17),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: "Movies, Shows, and More",
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 17,
                  ),
                ),
              ),
            ),
            if (_query.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _controller.clear();
                  _onChanged("");
                },
                child: Icon(
                  Icons.close,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _resultsView() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white24));
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          'No results for "$_query"',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 2 / 3,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        return PosterCard(
          item: item,
          width: double.infinity,
          // No provider badge here: one watch-provider request per visible
          // result would flood the network and stall the grid as you type.
          showBadge: false,
          onTap: () =>
              openDetail(context, id: item.id, isMovie: item.isMovie),
        );
      },
    );
  }

  Widget _categoryGrid() {
    return GridView.count(
      crossAxisCount: 3,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 0.62,
      children:
          _categories.map((c) => _CategoryTile(category: c)).toList(),
    );
  }
}

class _Category {
  final String label;
  final List<Color> colors;
  final IconData icon;
  final int genreId;
  const _Category(this.label, this.colors, this.icon, this.genreId);
}

const _categories = [
  _Category("Action", [Color(0xFFEB3349), Color(0xFFF45C43)], Icons.local_fire_department, 28),
  _Category("Comedy", [Color(0xFF11998E), Color(0xFF38EF7D)], Icons.sentiment_very_satisfied, 35),
  _Category("Drama", [Color(0xFF232526), Color(0xFF414345)], Icons.theater_comedy, 18),
  _Category("Horror", [Color(0xFF8E2DE2), Color(0xFF4A0000)], Icons.dark_mode, 27),
  _Category("Sci-Fi", [Color(0xFF000428), Color(0xFF004E92)], Icons.rocket_launch, 878),
  _Category("Romance", [Color(0xFFDA22FF), Color(0xFF9733EE)], Icons.favorite, 10749),
  _Category("Thriller", [Color(0xFF373B44), Color(0xFF4286F4)], Icons.bolt, 53),
  _Category("Animation", [Color(0xFFFF6FD8), Color(0xFF3813C2)], Icons.animation, 16),
  _Category("Documentary", [Color(0xFF0F2027), Color(0xFF2C5364)], Icons.public, 99),
];

class _CategoryTile extends StatelessWidget {
  final _Category category;
  const _CategoryTile({required this.category});

  Future<void> _open(BuildContext context) async {
    final navigator = Navigator.of(context);
    try {
      final data = await ApiServices().discoverByGenre(category.genreId);
      final items = (data?.results ?? [])
          .map((r) => actionToCard(r, genreLabel: category.label))
          .toList();
      if (items.isEmpty) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => Top10Screen(title: category.label, items: items),
        ),
      );
    } catch (_) {
      // Ignore network errors on a browse tap.
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: category.colors,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -8,
              top: -8,
              child: Icon(
                category.icon,
                size: 70,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Text(
                category.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
