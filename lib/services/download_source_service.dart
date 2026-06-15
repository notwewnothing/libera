import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:libera/services/index_scraper.dart';
import 'package:libera/services/vadapav_source.dart';

/// The download sites the app can pull files from. Each is a [DownloadSource]
/// with its own dedicated scraper; the user picks the active one (mirrors how
/// [PlayerService] manages streaming players). Order = picker order.
final List<DownloadSource> kDownloadSources = [
  IndexScraper(),
  VadapavSource(),
];

/// Persists which download source is active and exposes it to [DownloadManager].
class DownloadSourceService extends ChangeNotifier {
  DownloadSourceService._();
  static final DownloadSourceService instance = DownloadSourceService._();

  static const _prefsKey = 'selected_download_source';

  String _selectedId = kDownloadSources.first.id;
  bool _loaded = false;

  List<DownloadSource> get sources => kDownloadSources;

  DownloadSource get current => kDownloadSources.firstWhere(
    (s) => s.id == _selectedId,
    orElse: () => kDownloadSources.first,
  );

  Future<void> init() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && kDownloadSources.any((s) => s.id == saved)) {
        _selectedId = saved;
      }
    } catch (e) {
      debugPrint('Failed to load selected download source: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> select(String id) async {
    if (id == _selectedId || !kDownloadSources.any((s) => s.id == id)) return;
    _selectedId = id;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, id);
    } catch (e) {
      debugPrint('Failed to save selected download source: $e');
    }
  }
}
