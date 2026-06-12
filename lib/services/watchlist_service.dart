import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:libera/common/media_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Locally persisted favorites / watchlist. A single app-wide instance keeps
/// every listening widget (home row, library, detail buttons) in sync.
class WatchlistService extends ChangeNotifier {
  WatchlistService._();
  static final WatchlistService instance = WatchlistService._();

  static const _prefsKey = "watchlist";

  List<MediaCardData> _items = [];
  bool _loaded = false;

  /// Newest additions first.
  List<MediaCardData> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  Future<void> init() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        _items = (jsonDecode(raw) as List)
            .map((e) => MediaCardData.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint("Failed to load watchlist: $e");
      _items = [];
    }
    _loaded = true;
    notifyListeners();
  }

  // Movies and TV shows can share TMDB ids, so membership is keyed on both.
  bool contains(int id, {required bool isMovie}) =>
      _items.any((e) => e.id == id && e.isMovie == isMovie);

  /// Adds the item if absent, removes it otherwise. Returns true if the item
  /// ended up in the list.
  Future<bool> toggle(MediaCardData item) async {
    final added = !contains(item.id, isMovie: item.isMovie);
    if (added) {
      _items.insert(0, item);
    } else {
      _items.removeWhere((e) => e.id == item.id && e.isMovie == item.isMovie);
    }
    notifyListeners();
    await _persist();
    return added;
  }

  Future<void> remove(int id, {required bool isMovie}) async {
    _items.removeWhere((e) => e.id == id && e.isMovie == isMovie);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_items.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint("Failed to save watchlist: $e");
    }
  }
}
