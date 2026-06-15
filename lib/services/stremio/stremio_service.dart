import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Minimal Stremio addon protocol client — streams-only scope.
///
/// Ported/trimmed from PlayTorrioV2's StremioService: just manifest validation
/// and `/stream/{type}/{id}.json`, which is all AIOStreams needs to hand us
/// torrent + direct sources. Catalogs/meta/search were intentionally dropped.
class StremioService {
  /// Splits an addon URL into its base and any embedded config query params.
  static ({String baseUrl, String? queryParams}) splitAddonUrl(String url) {
    final qIdx = url.indexOf('?');
    var path = qIdx >= 0 ? url.substring(0, qIdx) : url;
    final query = qIdx >= 0 ? url.substring(qIdx + 1) : null;
    path = path
        .replaceAll(RegExp(r'/manifest\.json$'), '')
        .replaceAll(RegExp(r'/$'), '');
    if (!path.startsWith('http')) path = 'https://$path';
    return (baseUrl: path, queryParams: query);
  }

  static String _buildResourceUrl(String addonBaseUrl, String resourcePath) {
    final parts = splitAddonUrl(addonBaseUrl);
    final qp = parts.queryParams;
    return qp != null
        ? '${parts.baseUrl}$resourcePath?$qp'
        : '${parts.baseUrl}$resourcePath';
  }

  /// GET with small exponential backoff (no retry on 404).
  Future<http.Response?> _retryGet(Uri uri,
      {int retries = 2,
      Duration timeout = const Duration(seconds: 15)}) async {
    http.Response? last;
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final r = await http.get(uri).timeout(timeout);
        if (r.statusCode == 200) return r;
        last = r;
        if (r.statusCode == 404) break;
      } catch (_) {
        // network error — retry
      }
      if (attempt < retries) {
        await Future.delayed(Duration(milliseconds: 500 * (1 << attempt)));
      }
    }
    return last;
  }

  /// Fetches and validates an addon manifest. Returns a record with the clean
  /// base url (config query preserved) and the parsed manifest, or null.
  Future<({String baseUrl, Map<String, dynamic> manifest, String name, String icon})?>
      fetchManifest(String url) async {
    var manifestUrl = url.trim();
    if (manifestUrl.isEmpty) return null;
    if (manifestUrl.startsWith('stremio://')) {
      manifestUrl = manifestUrl.replaceFirst('stremio://', 'https://');
    }
    if (!manifestUrl.contains('/manifest.json')) {
      manifestUrl = manifestUrl.endsWith('/')
          ? '${manifestUrl}manifest.json'
          : '$manifestUrl/manifest.json';
    }
    try {
      final resp =
          await http.get(Uri.parse(manifestUrl)).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final manifest = json.decode(resp.body) as Map<String, dynamic>;
        final parts = splitAddonUrl(manifestUrl);
        final baseUrl = parts.queryParams != null
            ? '${parts.baseUrl}?${parts.queryParams}'
            : parts.baseUrl;
        return (
          baseUrl: baseUrl,
          manifest: manifest,
          name: (manifest['name'] ?? 'Unknown Addon').toString(),
          icon: (manifest['logo'] ?? '').toString(),
        );
      }
    } catch (e) {
      debugPrint('[StremioService] Manifest fetch error: $e');
    }
    return null;
  }

  /// Fetches the raw stream list for [type] ('movie'|'series') and [id]
  /// (`tt...` or `tt...:season:episode`) from one addon.
  Future<List<dynamic>> getStreams({
    required String baseUrl,
    required String type,
    required String id,
  }) async {
    final encodedId = id.contains('/') ? Uri.encodeComponent(id) : id;
    final url = _buildResourceUrl(baseUrl, '/stream/$type/$encodedId.json');
    try {
      final resp = await _retryGet(Uri.parse(url));
      if (resp != null && resp.statusCode == 200) {
        final data = json.decode(resp.body);
        return (data['streams'] as List?) ?? const [];
      }
    } catch (e) {
      debugPrint('[StremioService] Stream fetch error ($url): $e');
    }
    return const [];
  }
}
