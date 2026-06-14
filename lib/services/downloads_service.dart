import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:libera/common/media_widgets.dart';

enum DownloadStatus { downloading, completed }

/// A single downloadable unit — either a movie or one episode of a show.
class DownloadEntry {
  final String key;
  final MediaCardData parent; // the movie itself, or the parent show
  final bool isMovie;
  final int? season;
  final int? episode;
  final String title; // episode name, or movie title
  final String? thumbnailPath;
  final String? runtimeLabel; // e.g. "56m" / "1h 2m"
  DownloadStatus status;
  double progress; // 0..1

  DownloadEntry({
    required this.key,
    required this.parent,
    required this.isMovie,
    required this.title,
    this.season,
    this.episode,
    this.thumbnailPath,
    this.runtimeLabel,
    this.status = DownloadStatus.downloading,
    this.progress = 0.0,
  });

  bool get isCompleted => status == DownloadStatus.completed;

  String get subtitle {
    if (isMovie) return runtimeLabel ?? "Movie";
    final parts = <String>["Episode $episode"];
    if (runtimeLabel != null && runtimeLabel!.isNotEmpty) parts.add(runtimeLabel!);
    return parts.join(" · ");
  }
}

/// A grouped library item shown on the Downloads screen — a whole show (with
/// its downloaded episodes) or a single downloaded movie.
class DownloadGroup {
  final MediaCardData media;
  final bool isMovie;
  final List<DownloadEntry> entries;

  DownloadGroup({
    required this.media,
    required this.isMovie,
    required this.entries,
  });
}

/// Tracks downloads. Storage/engine wiring is not implemented yet — this is a
/// UI placeholder that keeps everything in memory and fakes download progress
/// so the interface can be exercised end to end.
class DownloadsService extends ChangeNotifier {
  DownloadsService._();
  static final DownloadsService instance = DownloadsService._();

  final List<DownloadEntry> _entries = [];
  Timer? _ticker;

  static String movieKey(int id) => "movie:$id";
  static String episodeKey(int showId, int season, int episode) =>
      "tv:$showId:s$season:e$episode";

  List<DownloadEntry> get all => List.unmodifiable(_entries);
  List<DownloadEntry> get downloading =>
      _entries.where((e) => e.status == DownloadStatus.downloading).toList();
  List<DownloadEntry> get completed =>
      _entries.where((e) => e.isCompleted).toList();

  int get downloadingCount => downloading.length;
  int get completedCount => completed.length;
  bool get isEmpty => _entries.isEmpty;

  DownloadEntry? entry(String key) {
    for (final e in _entries) {
      if (e.key == key) return e;
    }
    return null;
  }

  bool has(String key) => entry(key) != null;

  /// All downloads grouped into library items, preserving the order in which
  /// each title was first downloaded.
  List<DownloadGroup> get library {
    final order = <String>[];
    final byKey = <String, DownloadGroup>{};
    for (final e in _entries) {
      final groupKey = e.isMovie ? "movie:${e.parent.id}" : "tv:${e.parent.id}";
      var group = byKey[groupKey];
      if (group == null) {
        group = DownloadGroup(
          media: e.parent,
          isMovie: e.isMovie,
          entries: [],
        );
        byKey[groupKey] = group;
        order.add(groupKey);
      }
      group.entries.add(e);
    }
    return [for (final k in order) byKey[k]!];
  }

  /// Episodes of [showId] downloaded for [season], in episode order.
  List<DownloadEntry> episodesFor(int showId, int season) {
    final list = _entries
        .where((e) => !e.isMovie && e.parent.id == showId && e.season == season)
        .toList();
    list.sort((a, b) => (a.episode ?? 0).compareTo(b.episode ?? 0));
    return list;
  }

  /// Distinct downloaded season numbers for [showId], ascending.
  List<int> seasonsFor(int showId) {
    final seasons = _entries
        .where((e) => !e.isMovie && e.parent.id == showId)
        .map((e) => e.season ?? 0)
        .toSet()
        .toList();
    seasons.sort();
    return seasons;
  }

  void downloadMovie(MediaCardData card, {String? runtimeLabel}) {
    final key = movieKey(card.id);
    if (has(key)) return;
    _entries.add(
      DownloadEntry(
        key: key,
        parent: card,
        isMovie: true,
        title: card.title,
        thumbnailPath: card.backdropPath ?? card.posterPath,
        runtimeLabel: runtimeLabel,
      ),
    );
    _ensureTicker();
    notifyListeners();
  }

  void downloadEpisode(
    MediaCardData show, {
    required int season,
    required int episode,
    required String name,
    String? stillPath,
    String? runtimeLabel,
  }) {
    final key = episodeKey(show.id, season, episode);
    if (has(key)) return;
    _entries.add(
      DownloadEntry(
        key: key,
        parent: show,
        isMovie: false,
        season: season,
        episode: episode,
        title: name.isEmpty ? "Episode $episode" : name,
        thumbnailPath: stillPath ?? show.backdropPath ?? show.posterPath,
        runtimeLabel: runtimeLabel,
      ),
    );
    _ensureTicker();
    notifyListeners();
  }

  void remove(String key) {
    _entries.removeWhere((e) => e.key == key);
    notifyListeners();
  }

  void removeAll(Iterable<String> keys) {
    final set = keys.toSet();
    _entries.removeWhere((e) => set.contains(e.key));
    notifyListeners();
  }

  void removeShow(int showId) {
    _entries.removeWhere((e) => !e.isMovie && e.parent.id == showId);
    notifyListeners();
  }

  void _ensureTicker() {
    if (_ticker != null) return;
    _ticker = Timer.periodic(const Duration(milliseconds: 350), (t) {
      var active = false;
      for (final e in _entries) {
        if (e.status != DownloadStatus.downloading) continue;
        active = true;
        // Slight per-item variation so the rings don't move in lockstep.
        e.progress += 0.03 + (e.key.hashCode % 4) * 0.006;
        if (e.progress >= 1.0) {
          e.progress = 1.0;
          e.status = DownloadStatus.completed;
        }
      }
      if (!active) {
        t.cancel();
        _ticker = null;
      }
      notifyListeners();
    });
  }
}
