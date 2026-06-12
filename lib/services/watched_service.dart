import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:libera/common/media_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WatchedShow {
  final MediaCardData card;
  // Episode keys formatted "season:episode".
  final Set<String> episodes;

  WatchedShow({required this.card, required this.episodes});

  factory WatchedShow.fromJson(Map<String, dynamic> json) => WatchedShow(
    card: MediaCardData.fromJson(json["card"]),
    episodes: ((json["episodes"] ?? []) as List).cast<String>().toSet(),
  );

  Map<String, dynamic> toJson() => {
    "card": card.toJson(),
    "episodes": episodes.toList(),
  };
}

/// Locally persisted watch history: whole movies, and series tracked per
/// episode. A show is listed as soon as one of its episodes is marked.
class WatchedService extends ChangeNotifier {
  WatchedService._();
  static final WatchedService instance = WatchedService._();

  static const _prefsKey = "watched";

  List<MediaCardData> _movies = [];
  List<WatchedShow> _shows = [];
  bool _loaded = false;

  List<MediaCardData> get movies => List.unmodifiable(_movies);
  List<WatchedShow> get shows => List.unmodifiable(_shows);

  int get titleCount => _movies.length + _shows.length;

  Future<void> init() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _movies = ((data["movies"] ?? []) as List)
            .map((e) => MediaCardData.fromJson(e as Map<String, dynamic>))
            .toList();
        _shows = ((data["shows"] ?? []) as List)
            .map((e) => WatchedShow.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint("Failed to load watched history: $e");
      _movies = [];
      _shows = [];
    }
    _loaded = true;
    notifyListeners();
  }

  // ------------------------------------------------------------- movies

  bool isMovieWatched(int id) => _movies.any((e) => e.id == id);

  /// Returns true if the movie ended up marked as watched.
  Future<bool> toggleMovie(MediaCardData card) async {
    final added = !isMovieWatched(card.id);
    if (added) {
      _movies.insert(0, card);
    } else {
      _movies.removeWhere((e) => e.id == card.id);
    }
    notifyListeners();
    await _persist();
    return added;
  }

  /// Idempotent variant used by automatic tracking (e.g. playback finished).
  Future<void> markMovieWatched(MediaCardData card) async {
    if (isMovieWatched(card.id)) return;
    await toggleMovie(card);
  }

  Future<void> removeMovie(int id) async {
    _movies.removeWhere((e) => e.id == id);
    notifyListeners();
    await _persist();
  }

  // ------------------------------------------------------------ episodes

  static String _episodeKey(int season, int episode) => "$season:$episode";

  bool isEpisodeWatched(int showId, int season, int episode) {
    for (final s in _shows) {
      if (s.card.id == showId) {
        return s.episodes.contains(_episodeKey(season, episode));
      }
    }
    return false;
  }

  int episodeCount(int showId) {
    for (final s in _shows) {
      if (s.card.id == showId) return s.episodes.length;
    }
    return 0;
  }

  /// Marks/unmarks one episode. The show entry is created on first mark and
  /// dropped once its last episode is unmarked. Returns true if the episode
  /// ended up watched.
  Future<bool> toggleEpisode(MediaCardData show, int season, int episode) async {
    final key = _episodeKey(season, episode);
    var entry = _shows.where((s) => s.card.id == show.id).firstOrNull;
    bool added;
    if (entry == null) {
      _shows.insert(0, WatchedShow(card: show, episodes: {key}));
      added = true;
    } else if (entry.episodes.contains(key)) {
      entry.episodes.remove(key);
      if (entry.episodes.isEmpty) {
        _shows.removeWhere((s) => s.card.id == show.id);
      }
      added = false;
    } else {
      entry.episodes.add(key);
      added = true;
    }
    notifyListeners();
    await _persist();
    return added;
  }

  /// Idempotent variant used by automatic tracking (episode finished or the
  /// player moved on to a later episode).
  Future<void> markEpisodeWatched(
    MediaCardData show,
    int season,
    int episode,
  ) async {
    if (isEpisodeWatched(show.id, season, episode)) return;
    await toggleEpisode(show, season, episode);
  }

  Future<void> removeShow(int id) async {
    _shows.removeWhere((s) => s.card.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          "movies": _movies.map((e) => e.toJson()).toList(),
          "shows": _shows.map((e) => e.toJson()).toList(),
        }),
      );
    } catch (e) {
      debugPrint("Failed to save watched history: $e");
    }
  }
}
