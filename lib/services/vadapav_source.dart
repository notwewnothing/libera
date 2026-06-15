import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:libera/services/index_scraper.dart';

/// Download-source backend for **vadapav.mov** — a single-host open directory
/// exposed as a clean JSON API (documented at vadapav.mov/developers):
///
///  * `GET /api/s/{query}`        search (min 4 chars) → `{ "items": [...] }`
///  * `GET /api/d/{idOrPath}`     list a folder by UUID → `{ "items": [...] }`
///  * `GET /f/{id}`               stream a file, `Accept-Ranges: bytes`
///
/// Each `item` is `{ id, name, type: "folder"|"file", size, mimeType, ... }`.
/// File ids map to a directly-resumable URL (`/f/{id}`), so a resolved
/// [VideoFile.pageUrl] drops straight into [DownloadsService] with no extra
/// resolution step. Filenames are standard scene/p2p releases, so the metadata
/// parsing ([parseQuality], the SxxExx detection, sample-dropping, variant
/// grouping) is reused wholesale from [IndexScraper].
///
/// Depends only on `http` + dart core (and the pure models in index_scraper),
/// so it can be exercised by `dart run` without the Flutter engine.

const String _userAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0 Safari/537.36';

class VadapavSource implements DownloadSource {
  VadapavSource({
    http.Client? client,
    this.minRequestGap = const Duration(milliseconds: 300),
    this.maxRetries = 4,
    this.maxRetryWait = const Duration(seconds: 12),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration minRequestGap;
  final int maxRetries;
  final Duration maxRetryWait;

  static final Uri base = Uri.parse('https://vadapav.mov/');

  // Request serialization + spacing (be polite; the host sits behind CF).
  Future<void> _gate = Future<void>.value();
  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  String get id => 'vadapav';

  @override
  String get name => 'Vadapav';

  @override
  void close() => _client.close();

  // ---- DownloadSource -----------------------------------------------------

  @override
  Future<MovieResult?> resolveMovie(String title, {int? year}) async {
    final hits = await _search(title);
    final folder = _bestFolder(hits, title, year: year);

    List<DirEntry> files;
    String name;
    Uri dirUrl;
    if (folder != null) {
      files = await _collectVideos(folder.url);
      name = folder.name;
      dirUrl = folder.url;
    } else {
      // No folder matched — fall back to any direct video hits from search.
      files = hits.where((e) => !e.isDir).toList();
      name = title;
      dirUrl = base;
    }

    final sources = IndexScraper.videoFilesFrom(files, tv: false)
      ..sort(IndexScraper.compareQuality);
    if (sources.isEmpty) return null;
    return MovieResult(title: name, dirUrl: dirUrl, sources: sources);
  }

  @override
  Future<ShowResult?> resolveShow(String title) async {
    final hits = await _search(title);
    final folder = _bestFolder(hits, title);
    if (folder == null) return null;

    final entries = await _listDir(folder.url);
    final dirs = entries.where((e) => e.isDir).toList();
    final seasons = dirs.isNotEmpty
        ? ([for (final d in dirs) _toSeasonRef(d)]
            ..sort((a, b) => (a.number ?? 9999).compareTo(b.number ?? 9999)))
        // No season sub-folders: treat the show folder itself as one season
        // (resolveSeason still parses SxxExx straight off the filenames).
        : [SeasonRef(number: 1, name: folder.name, url: folder.url)];
    return ShowResult(title: folder.name, dirUrl: folder.url, seasons: seasons);
  }

  @override
  Future<SeasonResult> resolveSeason(SeasonRef ref) async {
    final files = await _collectVideos(ref.url);
    final videos = IndexScraper.videoFilesFrom(files, tv: true);

    final byEpisode = <int, List<VideoFile>>{};
    for (final v in videos) {
      byEpisode.putIfAbsent(v.episode ?? 0, () => []).add(v);
    }
    final episodes = <EpisodeResult>[];
    for (final ep in byEpisode.keys.toList()..sort()) {
      final sources = byEpisode[ep]!..sort(IndexScraper.compareQuality);
      episodes.add(
        EpisodeResult(
          season: ref.number ?? 0,
          episode: ep,
          title: sources.first.episodeTitle,
          sources: sources,
        ),
      );
    }
    return SeasonResult(
      season: ref.number ?? 0,
      dirUrl: ref.url,
      episodes: episodes,
      variants: IndexScraper.groupVariants(videos),
    );
  }

  // ---- HTTP ---------------------------------------------------------------

  Future<String> _get(Uri url) {
    final prior = _gate;
    final completer = Completer<String>();
    _gate = completer.future.then((_) {}, onError: (_) {});
    prior.whenComplete(() async {
      try {
        final wait = minRequestGap - DateTime.now().difference(_lastRequest);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
        final body = await _send(url);
        _lastRequest = DateTime.now();
        completer.complete(body);
      } catch (e, st) {
        _lastRequest = DateTime.now();
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<String> _send(Uri url) async {
    for (var attempt = 0; ; attempt++) {
      final r = await _client.get(url, headers: const {'User-Agent': _userAgent});
      if (r.statusCode == 200) return r.body;
      if ((r.statusCode == 429 || r.statusCode == 503) && attempt < maxRetries) {
        final ra = int.tryParse(r.headers['retry-after'] ?? '');
        final d = ra != null
            ? Duration(seconds: ra)
            : Duration(milliseconds: 600 * (1 << attempt));
        await Future<void>.delayed(d > maxRetryWait ? maxRetryWait : d);
        continue;
      }
      throw HttpStatusException(url, r.statusCode);
    }
  }

  Future<List<DirEntry>> _search(String query) async {
    final q = query.trim();
    if (q.length < 4) return const []; // API requires >= 4 chars
    return parseItems(await _get(base.resolve('api/s/${Uri.encodeComponent(q)}')));
  }

  Future<List<DirEntry>> _listDir(Uri dirUrl) async =>
      parseItems(await _get(dirUrl));

  /// Gather the video files under [dirUrl]. Most folders hold the files
  /// directly; when a folder only nests sub-folders (e.g. quality variants) we
  /// descend one level to find them.
  Future<List<DirEntry>> _collectVideos(Uri dirUrl, {int depth = 1}) async {
    final entries = await _listDir(dirUrl);
    final files = entries.where((e) => !e.isDir).toList();
    if (files.isNotEmpty || depth <= 0) return files;
    for (final sub in entries.where((e) => e.isDir).take(8)) {
      files.addAll(await _collectVideos(sub.url, depth: depth - 1));
    }
    return files;
  }

  // ---- Matching -----------------------------------------------------------

  /// Best-matching folder for [query]: requires a reasonable name match,
  /// prefers a folder whose name carries the requested [year], then the
  /// largest (most complete) one.
  DirEntry? _bestFolder(List<DirEntry> entries, String query, {int? year}) {
    final nq = _norm(query);
    DirEntry? best;
    double bestScore = -1;
    for (final e in entries.where((e) => e.isDir)) {
      final nc = _norm(_stripYear(e.name));
      var s = _similarity(nq, nc);
      if (s < 0.5 && !nc.contains(nq) && !nq.contains(nc)) continue;
      if (year != null && e.name.contains('($year)')) s += 1.0; // year bonus
      // Size as a sub-tie-breaker so the more complete library wins.
      s += (e.sizeBytes > 0 ? e.sizeBytes : 0) / 1e15;
      if (s > bestScore) {
        bestScore = s;
        best = e;
      }
    }
    return best;
  }

  SeasonRef _toSeasonRef(DirEntry e) {
    final m = RegExp(r's(?:eason)?\s*0*(\d+)', caseSensitive: false)
        .firstMatch(e.name);
    return SeasonRef(
      number: m != null ? int.tryParse(m.group(1)!) : null,
      name: e.name,
      url: e.url,
    );
  }

  // ---- Parsing (pure + testable) ------------------------------------------

  /// Parse an `/api/d` or `/api/s` JSON body into [DirEntry]s. Folders point at
  /// their `/api/d/{id}` listing; files point at their `/f/{id}` download URL.
  static List<DirEntry> parseItems(String body) {
    final out = <DirEntry>[];
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return out;
    }
    final items = decoded is Map ? decoded['items'] : decoded;
    if (items is! List) return out;
    for (final raw in items) {
      if (raw is! Map) continue;
      final id = raw['id']?.toString();
      final name = raw['name']?.toString();
      if (id == null || name == null || id.isEmpty || name.isEmpty) continue;
      final isDir = raw['type'] == 'folder' || raw['mimeType'] == 'drive/folder';
      final size = raw['size'] is num ? (raw['size'] as num).toInt() : -1;
      out.add(
        DirEntry(
          name: name,
          url: isDir ? base.resolve('api/d/$id') : base.resolve('f/$id'),
          isDir: isDir,
          sizeBytes: isDir ? -1 : size,
          sizeLabel: isDir || size < 0 ? '' : _humanSize(size),
        ),
      );
    }
    return out;
  }
}

// ---- string utilities (mirrors index_scraper's matching) -------------------

String _humanSize(int bytes) {
  if (bytes <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
}

String _stripYear(String name) =>
    name.replaceAll(RegExp(r'\s*\(\d{4}\)\s*$'), '').trim();

String _norm(String s) {
  final t = s
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Token-set overlap (Jaccard) — good enough since vadapav's search already
/// did the heavy matching server-side; this just ranks the returned folders.
double _similarity(String a, String b) {
  if (a == b) return 1.0;
  if (a.isEmpty || b.isEmpty) return 0.0;
  final ta = a.split(' ').toSet();
  final tb = b.split(' ').toSet();
  final inter = ta.intersection(tb).length;
  final union = ta.union(tb).length;
  return union == 0 ? 0.0 : inter / union;
}
