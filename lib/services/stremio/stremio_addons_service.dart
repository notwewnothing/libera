import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:libera/models/stremio_stream.dart';
import 'package:libera/services/stremio/stremio_service.dart';

/// An installed Stremio addon (its base url + cached manifest bits).
class StremioAddon {
  final String id;
  final String name;
  final String icon;
  final String baseUrl; // clean base, config query preserved
  final Map<String, dynamic>? manifest;

  const StremioAddon({
    required this.id,
    required this.name,
    required this.icon,
    required this.baseUrl,
    this.manifest,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'baseUrl': baseUrl,
        'manifest': manifest,
      };

  factory StremioAddon.fromJson(Map<String, dynamic> j) => StremioAddon(
        id: j['id'].toString(),
        name: (j['name'] ?? 'Addon').toString(),
        icon: (j['icon'] ?? '').toString(),
        baseUrl: j['baseUrl'].toString(),
        manifest: (j['manifest'] as Map?)?.cast<String, dynamic>(),
      );
}

/// Manages installed Stremio addons and aggregates their `/stream` results.
///
/// Seeded once with the user's AIOStreams addon. Persists to SharedPreferences.
/// Mirrors the ChangeNotifier-singleton pattern of PlayerService.
class StremioAddonsService extends ChangeNotifier {
  StremioAddonsService._();
  static final StremioAddonsService instance = StremioAddonsService._();

  static const _prefsKey = 'stremio_addons';
  static const _seededKey = 'stremio_addons_seeded';

  /// The AIOStreams addon the user asked to pre-install.
  static const String defaultAddonUrl =
      'https://aiostreamsfortheweebsstable.midnightignite.me/stremio/8f77ad70-3d14-4d1b-b58f-d99601b23a84/eyJpIjoib1o2TExBcjRBaG1aaGNtSnhqZDUyZz09IiwiZSI6Inh3YzBGb1Y4cEVvVFBYaS9Pd0dFTExRUDBJWjNwTTEyaWRtWGxLeXdVWXc9IiwidCI6ImEifQ/manifest.json';

  final StremioService _service = StremioService();
  final List<StremioAddon> _addons = [];
  bool _loaded = false;

  List<StremioAddon> get addons => List.unmodifiable(_addons);

  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey) ?? const [];
      _addons
        ..clear()
        ..addAll(raw.map((s) => StremioAddon.fromJson(jsonDecode(s))));
      // First-run: install the default AIOStreams addon once.
      if (!(prefs.getBool(_seededKey) ?? false)) {
        await prefs.setBool(_seededKey, true);
        if (_addons.isEmpty) {
          await addAddon(defaultAddonUrl);
        }
      }
    } catch (e) {
      debugPrint('[StremioAddons] init failed: $e');
    }
    notifyListeners();
  }

  /// Validates and installs an addon by manifest URL. Returns the addon, or
  /// null if the manifest couldn't be fetched/parsed (it is still installed
  /// with a fallback name so streams can be attempted).
  Future<StremioAddon?> addAddon(String url) async {
    final info = await _service.fetchManifest(url);
    final StremioAddon addon;
    if (info != null) {
      addon = StremioAddon(
        id: _idFor(info.baseUrl),
        name: info.name,
        icon: info.icon,
        baseUrl: info.baseUrl,
        manifest: info.manifest,
      );
    } else {
      // Couldn't fetch the manifest — still install with the resolved base.
      final parts = StremioService.splitAddonUrl(url.trim());
      final base = parts.queryParams != null
          ? '${parts.baseUrl}?${parts.queryParams}'
          : parts.baseUrl;
      addon = StremioAddon(
        id: _idFor(base),
        name: 'Stremio Addon',
        icon: '',
        baseUrl: base,
      );
    }
    _addons.removeWhere((a) => a.id == addon.id); // replace if re-added
    _addons.add(addon);
    await _persist();
    notifyListeners();
    return info != null ? addon : null;
  }

  Future<void> removeAddon(String id) async {
    _addons.removeWhere((a) => a.id == id);
    await _persist();
    notifyListeners();
  }

  /// Aggregates streams for [type] ('movie'|'series') and Stremio [id]
  /// (`tt...` or `tt...:s:e`) across every installed addon, best-first.
  Future<List<StremioStream>> getStreams({
    required String type,
    required String id,
  }) async {
    final results = <StremioStream>[];
    await Future.wait(_addons.map((addon) async {
      try {
        final raw =
            await _service.getStreams(baseUrl: addon.baseUrl, type: type, id: id);
        for (final s in raw) {
          if (s is Map<String, dynamic>) {
            results.add(StremioStream.fromJson(s, addonName: addon.name));
          } else if (s is Map) {
            results.add(StremioStream.fromJson(
                s.cast<String, dynamic>(),
                addonName: addon.name));
          }
        }
      } catch (e) {
        debugPrint('[StremioAddons] getStreams(${addon.name}) failed: $e');
      }
    }));
    results.sort((a, b) {
      final q = _qualityScore(b.qualityLabel).compareTo(_qualityScore(a.qualityLabel));
      if (q != 0) return q;
      return b.seeders.compareTo(a.seeders);
    });
    return results;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefsKey,
        _addons.map((a) => jsonEncode(a.toJson())).toList(),
      );
    } catch (e) {
      debugPrint('[StremioAddons] persist failed: $e');
    }
  }

  static String _idFor(String baseUrl) =>
      baseUrl.hashCode.toRadixString(16);

  static int _qualityScore(String? q) {
    switch (q) {
      case '2160p':
        return 4;
      case '1080p':
        return 3;
      case '720p':
        return 2;
      case '480p':
        return 1;
      default:
        return 0;
    }
  }
}
