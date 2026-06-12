import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:libera/common/media_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContinueWatchingEntry {
  final MediaCardData card;
  // Set for TV shows only; null for movies.
  final int? season;
  final int? episode;
  // Playback position reported by the player; 0 when unknown.
  final double positionSeconds;
  final double durationSeconds;

  const ContinueWatchingEntry({
    required this.card,
    this.season,
    this.episode,
    this.positionSeconds = 0,
    this.durationSeconds = 0,
  });

  double get progress => durationSeconds > 0
      ? (positionSeconds / durationSeconds).clamp(0.0, 1.0)
      : 0;

  factory ContinueWatchingEntry.fromJson(Map<String, dynamic> json) =>
      ContinueWatchingEntry(
        card: MediaCardData.fromJson(json["card"]),
        season: json["season"],
        episode: json["episode"],
        positionSeconds: (json["positionSeconds"] as num?)?.toDouble() ?? 0,
        durationSeconds: (json["durationSeconds"] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
    "card": card.toJson(),
    "season": season,
    "episode": episode,
    "positionSeconds": positionSeconds,
    "durationSeconds": durationSeconds,
  };
}

/// Locally persisted "Continue Watching" rail. Every playback start upserts
/// an entry to the front, so the rail stays ordered by recency.
class ContinueWatchingService extends ChangeNotifier {
  ContinueWatchingService._();
  static final ContinueWatchingService instance = ContinueWatchingService._();

  static const _prefsKey = "continue_watching";
  static const _maxEntries = 20;

  List<ContinueWatchingEntry> _entries = [];
  bool _loaded = false;

  List<ContinueWatchingEntry> get entries => List.unmodifiable(_entries);

  Future<void> init() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        _entries = (jsonDecode(raw) as List)
            .map(
              (e) => ContinueWatchingEntry.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
    } catch (e) {
      debugPrint("Failed to load continue watching: $e");
      _entries = [];
    }
    _loaded = true;
    notifyListeners();
  }

  ContinueWatchingEntry? entryFor(int id, {required bool isMovie}) {
    for (final e in _entries) {
      if (e.card.id == id && e.card.isMovie == isMovie) return e;
    }
    return null;
  }

  /// Saved position to restart from, or 0 when there's nothing meaningful to
  /// resume (too early, nearly finished, or a different episode).
  double resumePosition(
    int id, {
    required bool isMovie,
    int? season,
    int? episode,
  }) {
    final entry = entryFor(id, isMovie: isMovie);
    if (entry == null) return 0;
    if (!isMovie && (entry.season != season || entry.episode != episode)) {
      return 0;
    }
    if (entry.positionSeconds < 15) return 0;
    if (entry.durationSeconds > 0 &&
        entry.positionSeconds > entry.durationSeconds * 0.95) {
      return 0;
    }
    return entry.positionSeconds;
  }

  /// Pass null position/duration to keep the saved ones (when still on the
  /// same episode); explicit values overwrite them.
  Future<void> record(
    MediaCardData card, {
    int? season,
    int? episode,
    double? positionSeconds,
    double? durationSeconds,
  }) async {
    final existing = entryFor(card.id, isMovie: card.isMovie);
    var position = positionSeconds ?? 0.0;
    var duration = durationSeconds ?? 0.0;
    if (positionSeconds == null &&
        existing != null &&
        existing.season == season &&
        existing.episode == episode) {
      position = existing.positionSeconds;
      duration = existing.durationSeconds;
    }
    _entries.removeWhere(
      (e) => e.card.id == card.id && e.card.isMovie == card.isMovie,
    );
    _entries.insert(
      0,
      ContinueWatchingEntry(
        card: card,
        season: season,
        episode: episode,
        positionSeconds: position,
        durationSeconds: duration,
      ),
    );
    if (_entries.length > _maxEntries) {
      _entries = _entries.sublist(0, _maxEntries);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> remove(int id, {required bool isMovie}) async {
    _entries.removeWhere((e) => e.card.id == id && e.card.isMovie == isMovie);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_entries.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint("Failed to save continue watching: $e");
    }
  }
}
