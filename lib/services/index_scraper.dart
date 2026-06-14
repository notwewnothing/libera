import 'dart:async';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

/// Download-source backend.
///
/// Scrapes the open directory index at [IndexScraper.base] (standard "tvs/" and
/// "movies/" layout) and turns it into structured, pickable download sources:
///
///  * a movie -> one or more [VideoFile]s (the user picks when there are 2+);
///  * a season -> every episode with all its sources, plus [SeasonVariant] sets
///    grouped by release (resolution/codec/source) so a whole season can be
///    pulled in one consistent quality.
///
/// The actual file URL on the index 307/302-redirects to a CDN worker that
/// serves the bytes with `Accept-Ranges: bytes` (resumable). A downloader can
/// either hand the page URL straight to an HTTP client that follows redirects,
/// or call [resolveDownloadUrl] to pin the final URL first.
///
/// This file depends only on `http` + dart core so it can be exercised in a
/// plain Dart test against the live site, no Flutter engine required.

const String _userAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0 Safari/537.36';

const Set<String> _videoExtensions = {
  'mkv', 'mp4', 'avi', 'm4v', 'mov', 'wmv', 'flv', 'webm', 'ts', 'mpg', 'mpeg',
};

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

/// One row in an index directory listing (a file or a sub-directory).
class DirEntry {
  final String name;
  final Uri url;
  final bool isDir;
  final int sizeBytes; // -1 when unknown (directories)
  final String sizeLabel; // "9.9 GB" / ""

  const DirEntry({
    required this.name,
    required this.url,
    required this.isDir,
    required this.sizeBytes,
    required this.sizeLabel,
  });

  bool get isVideo {
    if (isDir) return false;
    final dot = name.lastIndexOf('.');
    if (dot < 0) return false;
    return _videoExtensions.contains(name.substring(dot + 1).toLowerCase());
  }
}

/// Quality metadata parsed out of a release filename.
class QualityInfo {
  final String? resolution; // 2160p / 1080p / 720p / 480p
  final String? source; // Bluray Remux / Bluray / WEB-DL / WEBRip / HDTV ...
  final String? codec; // x265 / x264 / HEVC / AVC / H265 / H264
  final String? hdr; // DV / HDR10 / HDR
  final String? audio; // e.g. "TrueHD Atmos 7.1"
  final String? group; // release group

  const QualityInfo({
    this.resolution,
    this.source,
    this.codec,
    this.hdr,
    this.audio,
    this.group,
  });

  /// Stable key used to cluster a season's files into [SeasonVariant] sets.
  /// Resolution + codec is the axis that stays consistent across a release;
  /// audio and release group vary episode-to-episode and are excluded.
  String get variantKey {
    final res = resolution ?? '?';
    final cod = codec?.toLowerCase() ?? source?.toLowerCase() ?? '?';
    return '$res|$cod';
  }

  /// Higher = better. Used to pick a sensible default and order pickers.
  int get score {
    int s = 0;
    switch (resolution) {
      case '2160p':
        s += 4000;
      case '1080p':
        s += 3000;
      case '720p':
        s += 2000;
      case '480p':
        s += 1000;
    }
    final src = source ?? '';
    if (src.contains('Remux')) {
      s += 500;
    } else if (src.startsWith('Bluray')) {
      s += 400;
    } else if (src == 'WEB-DL') {
      s += 300;
    } else if (src == 'WEBRip') {
      s += 200;
    } else if (src == 'HDTV' || src == 'HDRip') {
      s += 100;
    }
    if (hdr == 'DV') s += 30;
    if (hdr == 'HDR10' || hdr == 'HDR') s += 20;
    return s;
  }

  String get label {
    final parts = <String>[?resolution, ?source, ?codec, ?hdr];
    return parts.isEmpty ? 'Unknown' : parts.join(' · ');
  }
}

/// A concrete downloadable video file with its parsed metadata.
class VideoFile {
  final String fileName;
  final Uri pageUrl; // index URL (redirects to the CDN file)
  final int sizeBytes;
  final String sizeLabel;
  final QualityInfo quality;
  final int? season;
  final int? episode;
  final String? episodeTitle;

  const VideoFile({
    required this.fileName,
    required this.pageUrl,
    required this.sizeBytes,
    required this.sizeLabel,
    required this.quality,
    this.season,
    this.episode,
    this.episodeTitle,
  });
}

/// A movie folder resolved to its candidate sources (pick one when 2+).
class MovieResult {
  final String title;
  final Uri dirUrl;
  final List<VideoFile> sources; // best-first

  const MovieResult({
    required this.title,
    required this.dirUrl,
    required this.sources,
  });

  bool get hasChoice => sources.length > 1;
  VideoFile get best => sources.first;
}

/// One episode and every source available for it (pick one when 2+).
class EpisodeResult {
  final int season;
  final int episode;
  final String? title;
  final List<VideoFile> sources; // best-first

  const EpisodeResult({
    required this.season,
    required this.episode,
    this.title,
    required this.sources,
  });

  bool get hasChoice => sources.length > 1;
  VideoFile get best => sources.first;
}

/// A consistent release "set" spanning (some of) a season's episodes — what the
/// user chooses between when downloading a whole season.
class SeasonVariant {
  final String key;
  final String label; // "1080p · Bluray · x264"
  final List<VideoFile> files; // one per episode, episode-ordered
  final int seasonEpisodeCount; // total distinct episodes in the season

  const SeasonVariant({
    required this.key,
    required this.label,
    required this.files,
    required this.seasonEpisodeCount,
  });

  int get episodeCount => files.length;
  bool get isComplete => episodeCount >= seasonEpisodeCount;
  int get totalBytes =>
      files.fold(0, (a, f) => a + (f.sizeBytes < 0 ? 0 : f.sizeBytes));
  String get coverageLabel => '$episodeCount/$seasonEpisodeCount episodes';
}

/// A season resolved to its episodes and grouped release variants.
class SeasonResult {
  final int season;
  final Uri dirUrl;
  final List<EpisodeResult> episodes; // episode-ordered
  final List<SeasonVariant> variants; // best/most-complete first

  const SeasonResult({
    required this.season,
    required this.dirUrl,
    required this.episodes,
    required this.variants,
  });
}

/// A pointer to a season directory inside a show.
class SeasonRef {
  final int? number; // null for "Specials"/unparseable
  final String name;
  final Uri url;

  const SeasonRef({required this.number, required this.name, required this.url});
}

/// A show folder resolved to its season directories.
class ShowResult {
  final String title;
  final Uri dirUrl;
  final List<SeasonRef> seasons;

  const ShowResult({
    required this.title,
    required this.dirUrl,
    required this.seasons,
  });
}

// ---------------------------------------------------------------------------
// Scraper
// ---------------------------------------------------------------------------

class IndexScraper {
  IndexScraper({
    http.Client? client,
    this.minRequestGap = const Duration(milliseconds: 1200),
    this.maxRetries = 4,
    this.maxRetryWait = const Duration(seconds: 12),
  }) : _client = client ?? http.Client();

  final http.Client _client;

  /// The index sits behind an aggressive rate limit (≈3 requests / 10s, then
  /// `429` with `Retry-After`). Requests are serialized and spaced by at least
  /// [minRequestGap]; a `429`/`503` is retried up to [maxRetries] times,
  /// honouring `Retry-After` (capped at [maxRetryWait]).
  final Duration minRequestGap;
  final int maxRetries;
  final Duration maxRetryWait;

  static final Uri base = Uri.parse('https://a.111477.xyz/');
  static final Uri tvsRoot = base.resolve('tvs/');
  static final Uri moviesRoot = base.resolve('movies/');

  // Session caches of the (large) root listings, only fetched when a direct
  // guess misses and we need a fuzzy search.
  List<DirEntry>? _tvCache;
  List<DirEntry>? _movieCache;

  // Request serialization + spacing.
  Future<void> _gate = Future<void>.value();
  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);

  void close() => _client.close();

  /// Run [action] serialized behind the request gate, after honouring the
  /// minimum inter-request gap.
  Future<T> _scheduled<T>(Future<T> Function() action) {
    final prior = _gate;
    final completer = Completer<T>();
    _gate = completer.future.then((_) {}, onError: (_) {});
    prior.whenComplete(() async {
      try {
        final wait =
            minRequestGap - DateTime.now().difference(_lastRequest);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
        final r = await action();
        _lastRequest = DateTime.now();
        completer.complete(r);
      } catch (e, st) {
        _lastRequest = DateTime.now();
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<http.Response> _send(Uri url) async {
    for (var attempt = 0; ; attempt++) {
      final r =
          await _client.get(url, headers: const {'User-Agent': _userAgent});
      if (r.statusCode == 200) return r;
      if ((r.statusCode == 429 || r.statusCode == 503) &&
          attempt < maxRetries) {
        await Future<void>.delayed(_retryDelay(r.headers, attempt));
        continue;
      }
      throw HttpStatusException(url, r.statusCode);
    }
  }

  Duration _retryDelay(Map<String, String> headers, int attempt) {
    final ra = int.tryParse(headers['retry-after'] ?? '');
    final base = ra != null
        ? Duration(seconds: ra)
        : Duration(milliseconds: 600 * (1 << attempt));
    return base > maxRetryWait ? maxRetryWait : base;
  }

  Future<String> _get(Uri url) async {
    final r = await _scheduled(() => _send(url));
    return r.body;
  }

  /// Parse + return the entries of a directory listing page.
  Future<List<DirEntry>> listDir(Uri url) async =>
      parseListing(await _get(url), url);

  // ---- Movies -------------------------------------------------------------

  /// Resolve a movie by [title] (and optional [year]) to its sources.
  /// Tries direct folder guesses first, falls back to a fuzzy root search.
  Future<MovieResult?> resolveMovie(String title, {int? year}) async {
    final dir = await _findDir(
      title,
      year: year,
      root: moviesRoot,
      cacheGetter: _loadMovieCache,
    );
    if (dir == null) return null;
    final sources = videoFilesFrom(await listDir(dir.url), tv: false)
      ..sort(compareQuality);
    if (sources.isEmpty) return null;
    return MovieResult(title: dir.name, dirUrl: dir.url, sources: sources);
  }

  /// All movie folders whose name fuzzily matches [query] (for a chooser UI).
  Future<List<DirEntry>> searchMovies(String query, {int limit = 20}) async =>
      _rankMatches(query, await _loadMovieCache(), limit: limit);

  // ---- TV -----------------------------------------------------------------

  /// Resolve a show by [title] to its season directories.
  Future<ShowResult?> resolveShow(String title) async {
    final dir = await _findDir(
      title,
      root: tvsRoot,
      cacheGetter: _loadTvCache,
    );
    if (dir == null) return null;
    final entries = (await listDir(dir.url)).where((e) => e.isDir).toList();
    final seasons = [for (final e in entries) _toSeasonRef(e)]
      ..sort((a, b) => (a.number ?? 9999).compareTo(b.number ?? 9999));
    return ShowResult(title: dir.name, dirUrl: dir.url, seasons: seasons);
  }

  /// All show folders whose name fuzzily matches [query] (for a chooser UI).
  Future<List<DirEntry>> searchShows(String query, {int limit = 20}) async =>
      _rankMatches(query, await _loadTvCache(), limit: limit);

  /// Resolve a single season directory to episodes + grouped variants.
  Future<SeasonResult> resolveSeason(SeasonRef ref) async {
    final videos = videoFilesFrom(await listDir(ref.url), tv: true);

    // Group sources by episode number.
    final byEpisode = <int, List<VideoFile>>{};
    for (final v in videos) {
      byEpisode.putIfAbsent(v.episode ?? 0, () => []).add(v);
    }
    final episodes = <EpisodeResult>[];
    final epNumbers = byEpisode.keys.toList()..sort();
    for (final ep in epNumbers) {
      final sources = byEpisode[ep]!..sort(compareQuality);
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
      variants: groupVariants(videos),
    );
  }

  // ---- Download URL -------------------------------------------------------

  /// Pre-flight a file: confirm it is reachable, get its total size and whether
  /// it supports range requests (resumable downloads).
  ///
  /// [pageUrl] (the index URL) is the stable address to download from — it
  /// 307/302-redirects to a fresh CDN worker link on every request, so the
  /// downloader should keep using [pageUrl] and follow redirects rather than
  /// caching the ephemeral CDN URL. Size is read from the `Content-Range` of a
  /// 1-byte ranged GET (the CDN does not return `Content-Length` on `HEAD`).
  Future<ResolvedDownload> resolveDownloadUrl(Uri pageUrl) {
    return _scheduled(() async {
      for (var attempt = 0; ; attempt++) {
        final req = http.Request('GET', pageUrl)
          ..followRedirects = true
          ..maxRedirects = 10
          ..headers['User-Agent'] = _userAgent
          ..headers['Range'] = 'bytes=0-0';
        final streamed = await _client.send(req);
        await streamed.stream.drain<void>();
        if ((streamed.statusCode == 429 || streamed.statusCode == 503) &&
            attempt < maxRetries) {
          await Future<void>.delayed(_retryDelay(streamed.headers, attempt));
          continue;
        }
        if (streamed.statusCode != 200 && streamed.statusCode != 206) {
          throw HttpStatusException(pageUrl, streamed.statusCode);
        }
        final resumable = streamed.statusCode == 206 ||
            (streamed.headers['accept-ranges'] ?? '')
                .toLowerCase()
                .contains('bytes');
        return ResolvedDownload(
          url: pageUrl,
          contentLength: _totalFromContentRange(streamed.headers) ??
              streamed.contentLength ??
              -1,
          resumable: resumable,
        );
      }
    });
  }

  static int? _totalFromContentRange(Map<String, String> headers) {
    final cr = headers['content-range'];
    if (cr == null) return null;
    final slash = cr.lastIndexOf('/');
    if (slash < 0) return null;
    return int.tryParse(cr.substring(slash + 1).trim());
  }

  // ---- Internals ----------------------------------------------------------

  Future<List<DirEntry>> _loadTvCache() async =>
      _tvCache ??= await listDir(tvsRoot);

  Future<List<DirEntry>> _loadMovieCache() async =>
      _movieCache ??= await listDir(moviesRoot);

  /// Direct-guess a folder, then fall back to a fuzzy search of the root.
  Future<DirEntry?> _findDir(
    String title, {
    int? year,
    required Uri root,
    required Future<List<DirEntry>> Function() cacheGetter,
  }) async {
    for (final name in _candidateNames(title, year: year)) {
      final guess = root.resolve('${Uri.encodeComponent(name)}/');
      try {
        final body = await _get(guess);
        final entries = parseListing(body, guess);
        if (entries.isNotEmpty) {
          return DirEntry(
            name: name,
            url: guess,
            isDir: true,
            sizeBytes: -1,
            sizeLabel: '',
          );
        }
      } on HttpStatusException {
        // try next candidate
      }
    }
    final ranked = _rankMatches(title, await cacheGetter(), limit: 1);
    return ranked.isEmpty ? null : ranked.first;
  }

  /// Candidate folder names to try directly before falling back to search.
  List<String> _candidateNames(String title, {int? year}) {
    final out = <String>[];
    void add(String s) {
      final t = s.trim();
      if (t.isNotEmpty && !out.contains(t)) out.add(t);
    }

    final sanitized = _sanitizeTitle(title);
    if (year != null) {
      add('$title ($year)');
      add('$sanitized ($year)');
    }
    add(title);
    add(sanitized);
    return out;
  }

  /// Turn raw directory entries into parsed [VideoFile]s, dropping samples.
  static List<VideoFile> videoFilesFrom(
    Iterable<DirEntry> files, {
    required bool tv,
  }) {
    return [
      for (final f in files)
        if (f.isVideo && !_isSample(f.name)) videoFileFrom(f, tv: tv),
    ];
  }

  static VideoFile videoFileFrom(DirEntry e, {required bool tv}) {
    final q = parseQuality(e.name);
    int? season, episode;
    String? epTitle;
    if (tv) {
      final m = _episodeRe.firstMatch(e.name);
      if (m != null) {
        season = int.tryParse(m.group(1)!);
        episode = int.tryParse(m.group(2)!);
        epTitle = _episodeTitle(e.name, m.end);
      }
    }
    return VideoFile(
      fileName: e.name,
      pageUrl: e.url,
      sizeBytes: e.sizeBytes,
      sizeLabel: e.sizeLabel,
      quality: q,
      season: season,
      episode: episode,
      episodeTitle: epTitle,
    );
  }

  /// Cluster a season's files into consistent release "sets" (one file per
  /// episode), keyed by resolution+codec. Best/most-complete set first.
  static List<SeasonVariant> groupVariants(List<VideoFile> videos) {
    final episodeCount =
        videos.map((v) => v.episode ?? 0).toSet().length;
    final groups = <String, List<VideoFile>>{};
    for (final v in videos) {
      groups.putIfAbsent(v.quality.variantKey, () => []).add(v);
    }
    final variants = <SeasonVariant>[];
    groups.forEach((key, list) {
      // Keep a single (largest) file per episode within the set.
      final byEp = <int, VideoFile>{};
      for (final v in list) {
        final ep = v.episode ?? 0;
        final cur = byEp[ep];
        if (cur == null || v.sizeBytes > cur.sizeBytes) byEp[ep] = v;
      }
      final files = byEp.values.toList()
        ..sort((a, b) => (a.episode ?? 0).compareTo(b.episode ?? 0));
      variants.add(
        SeasonVariant(
          key: key,
          label: files.first.quality.label,
          files: files,
          seasonEpisodeCount: episodeCount,
        ),
      );
    });
    // Most complete first, then best quality.
    variants.sort((a, b) {
      final c = b.episodeCount.compareTo(a.episodeCount);
      if (c != 0) return c;
      return b.files.first.quality.score.compareTo(a.files.first.quality.score);
    });
    return variants;
  }

  SeasonRef _toSeasonRef(DirEntry e) {
    final m = RegExp(r'season\s*0*(\d+)', caseSensitive: false).firstMatch(e.name);
    return SeasonRef(
      number: m != null ? int.tryParse(m.group(1)!) : null,
      name: e.name,
      url: e.url,
    );
  }

  /// Order two sources best-first (quality score, then size).
  static int compareQuality(VideoFile a, VideoFile b) {
    final c = b.quality.score.compareTo(a.quality.score);
    if (c != 0) return c;
    return b.sizeBytes.compareTo(a.sizeBytes);
  }

  /// Rank cache entries by similarity to [query]; only reasonable matches.
  List<DirEntry> _rankMatches(
    String query,
    List<DirEntry> entries, {
    required int limit,
  }) {
    final nq = _normalize(query);
    final scored = <_Scored>[];
    for (final e in entries) {
      final cand = _stripYear(e.name);
      final nc = _normalize(cand);
      final s = _similarity(nq, nc);
      if (s > 0.55 || nc.contains(nq) || nq.contains(nc)) {
        scored.add(_Scored(e, s));
      }
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return [for (final s in scored.take(limit)) s.entry];
  }

  static bool _isSample(String name) {
    final n = name.toLowerCase();
    return n.contains('sample') || n.contains('trailer');
  }
}

class ResolvedDownload {
  final Uri url;
  final int contentLength;
  final bool resumable;
  const ResolvedDownload({
    required this.url,
    required this.contentLength,
    required this.resumable,
  });
}

class HttpStatusException implements Exception {
  final Uri url;
  final int status;
  const HttpStatusException(this.url, this.status);
  @override
  String toString() => 'HTTP $status for $url';
}

class _Scored {
  final DirEntry entry;
  final double score;
  const _Scored(this.entry, this.score);
}

// ---------------------------------------------------------------------------
// Parsing helpers (top-level + testable)
// ---------------------------------------------------------------------------

final RegExp _episodeRe = RegExp(
  r'[Ss](\d{1,2})[ ._-]*[Ee](\d{1,3})|(?<!\d)(\d{1,2})x(\d{1,3})(?!\d)',
);

/// Parse a directory listing HTML page into [DirEntry]s.
/// Resolves relative `data-url`s against [pageUrl].
List<DirEntry> parseListing(String html, Uri pageUrl) {
  final entries = <DirEntry>[];
  final chunks = html.split('data-entry="true"');
  final nameRe = RegExp(r'data-name="([^"]*)"');
  final urlRe = RegExp(r'data-url="([^"]*)"');
  final sizeRe = RegExp(
    r'<td class="size"[^>]*data-sort="(-?\d+)"[^>]*>([^<]*)</td>',
  );
  for (var i = 1; i < chunks.length; i++) {
    final c = chunks[i];
    final n = nameRe.firstMatch(c);
    final u = urlRe.firstMatch(c);
    if (n == null || u == null) continue;
    final name = _decodeEntities(n.group(1)!);
    final rel = _decodeEntities(u.group(1)!);
    Uri url;
    try {
      url = pageUrl.resolve(rel);
    } catch (_) {
      continue;
    }
    final s = sizeRe.firstMatch(c);
    final sizeBytes = s != null ? (int.tryParse(s.group(1)!) ?? -1) : -1;
    final sizeLabel = s != null ? s.group(2)!.trim() : '';
    entries.add(
      DirEntry(
        name: name,
        url: url,
        isDir: rel.endsWith('/'),
        sizeBytes: sizeBytes,
        sizeLabel: sizeLabel == '-' ? '' : sizeLabel,
      ),
    );
  }
  return entries;
}

/// Extract resolution / source / codec / hdr / audio / group from a filename.
QualityInfo parseQuality(String fileName) {
  // Drop extension, normalise separators so tokens are space-delimited.
  var base = fileName;
  final dot = base.lastIndexOf('.');
  if (dot > 0 && base.length - dot <= 5) base = base.substring(0, dot);
  final norm = base
      .replaceAll(RegExp(r'[\.\_\[\]\(\)]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final low = norm.toLowerCase();

  String? resolution;
  final res = RegExp(r'\b(2160|1080|720|480)p\b').firstMatch(low);
  if (res != null) {
    resolution = '${res.group(1)}p';
  } else if (RegExp(r'\b(4k|uhd)\b').hasMatch(low)) {
    resolution = '2160p';
  }

  final remux = RegExp(r'\bremux\b').hasMatch(low);
  String? source;
  if (RegExp(r'\b(blu-?ray|bdrip|bdremux|brrip)\b').hasMatch(low)) {
    source = remux ? 'Bluray Remux' : 'Bluray';
  } else if (RegExp(r'\bweb[ -]?dl\b').hasMatch(low)) {
    source = 'WEB-DL';
  } else if (RegExp(r'\bweb-?rip\b').hasMatch(low)) {
    source = 'WEBRip';
  } else if (RegExp(r'\bweb\b').hasMatch(low)) {
    source = 'WEB-DL';
  } else if (RegExp(r'\bhdtv\b').hasMatch(low)) {
    source = 'HDTV';
  } else if (RegExp(r'\bhdrip\b').hasMatch(low)) {
    source = 'HDRip';
  } else if (RegExp(r'\bdvdrip\b').hasMatch(low)) {
    source = 'DVDRip';
  } else if (remux) {
    source = 'Remux';
  }

  String? codec;
  if (RegExp(r'\bx265\b').hasMatch(low)) {
    codec = 'x265';
  } else if (RegExp(r'\bx264\b').hasMatch(low)) {
    codec = 'x264';
  } else if (RegExp(r'\bhevc\b').hasMatch(low)) {
    codec = 'HEVC';
  } else if (RegExp(r'\bh ?265\b').hasMatch(low)) {
    codec = 'H265';
  } else if (RegExp(r'\bavc\b').hasMatch(low)) {
    codec = 'AVC';
  } else if (RegExp(r'\bh ?264\b').hasMatch(low)) {
    codec = 'H264';
  }

  String? hdr;
  if (RegExp(r'\b(dv|dovi|dolby vision)\b').hasMatch(low)) {
    hdr = 'DV';
  } else if (RegExp(r'\bhdr10\b').hasMatch(low)) {
    hdr = 'HDR10';
  } else if (RegExp(r'\bhdr\b').hasMatch(low)) {
    hdr = 'HDR';
  }

  // Audio tokens often carry trailing channel digits joined by dots
  // (e.g. "DDP5.1", "DD+5.1") so detect them on the raw lowercased name
  // where the dots are still intact.
  final raw = fileName.toLowerCase();
  final audioParts = <String>[];
  if (RegExp(r'\btruehd\b').hasMatch(raw)) audioParts.add('TrueHD');
  if (RegExp(r'\batmos\b').hasMatch(raw)) audioParts.add('Atmos');
  if (RegExp(r'\bdts-?hd').hasMatch(raw)) {
    audioParts.add('DTS-HD MA');
  } else if (RegExp(r'\bdts\b').hasMatch(raw)) {
    audioParts.add('DTS');
  }
  if (RegExp(r'\b(ddp|dd\+|eac3)').hasMatch(raw)) {
    audioParts.add('DDP');
  } else if (RegExp(r'\b(ac3|dd)\b').hasMatch(raw)) {
    audioParts.add('AC3');
  }
  if (RegExp(r'\baac\b').hasMatch(raw)) audioParts.add('AAC');
  final ch = RegExp(r'\b([257])\.([01])\b').firstMatch(raw);
  if (ch != null && audioParts.isNotEmpty) {
    audioParts.add('${ch.group(1)}.${ch.group(2)}');
  }
  final audio = audioParts.isEmpty ? null : audioParts.join(' ');

  // Release group: trailing "-GROUP" on the original name (before extension).
  String? group;
  final gm = RegExp(r'-([A-Za-z0-9]{2,})$').firstMatch(base.trim());
  if (gm != null) group = gm.group(1);

  return QualityInfo(
    resolution: resolution,
    source: source,
    codec: codec,
    hdr: hdr,
    audio: audio,
    group: group,
  );
}

/// Episode title between the `SxxExx` marker and the first quality token.
String? _episodeTitle(String fileName, int afterMatch) {
  var rest = fileName.substring(afterMatch);
  // Drop extension.
  final dot = rest.lastIndexOf('.');
  if (dot > 0 && rest.length - dot <= 5) rest = rest.substring(0, dot);
  // Cut at the first bracket / quality marker.
  final cut = RegExp(
    r'[\[\(]|\b(2160p|1080p|720p|480p|blu-?ray|web[ -]?dl|web-?rip|hdtv|remux|x26[45]|hevc|avc)\b',
    caseSensitive: false,
  ).firstMatch(rest);
  if (cut != null) rest = rest.substring(0, cut.start);
  rest = rest.replaceAll(RegExp(r'^[ \-_.]+|[ \-_.]+$'), '').trim();
  return rest.isEmpty ? null : rest;
}

// ---- string utilities -----------------------------------------------------

const Map<String, String> _namedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
};

String _decodeEntities(String s) {
  if (!s.contains('&')) return s;
  return s.replaceAllMapped(RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);'), (m) {
    final body = m.group(1)!;
    if (body.startsWith('#x') || body.startsWith('#X')) {
      final code = int.tryParse(body.substring(2), radix: 16);
      return code != null ? String.fromCharCode(code) : m.group(0)!;
    }
    if (body.startsWith('#')) {
      final code = int.tryParse(body.substring(1));
      return code != null ? String.fromCharCode(code) : m.group(0)!;
    }
    return _namedEntities[body.toLowerCase()] ?? m.group(0)!;
  });
}

/// Site folder names drop characters that are illegal/awkward on disk.
String _sanitizeTitle(String title) {
  return title
      .replaceAll(':', ' -')
      .replaceAll(RegExp(r'[\\/*?"<>|]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _stripYear(String name) =>
    name.replaceAll(RegExp(r'\s*\(\d{4}\)\s*$'), '').trim();

/// Lowercase, strip diacritics & punctuation, normalise "&"->"and".
String _normalize(String s) {
  var t = s.toLowerCase();
  t = _stripDiacritics(t);
  t = t.replaceAll('&', ' and ');
  t = t.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

const _diacritic = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
const _plain = 'aaaaaaceeeeiiiinooooouuuuyy';
String _stripDiacritics(String s) {
  final sb = StringBuffer();
  for (final ch in s.split('')) {
    final i = _diacritic.indexOf(ch);
    sb.write(i >= 0 ? _plain[i] : ch);
  }
  return sb.toString();
}

/// Similarity in [0,1]: blended token-set overlap (Jaccard) and edit distance,
/// so word reordering and minor spelling both score reasonably.
double _similarity(String a, String b) {
  if (a == b) return 1.0;
  if (a.isEmpty || b.isEmpty) return 0.0;
  final ta = a.split(' ').toSet();
  final tb = b.split(' ').toSet();
  final inter = ta.intersection(tb).length;
  final union = ta.union(tb).length;
  final jaccard = union == 0 ? 0.0 : inter / union;
  final dist = _levenshtein(a, b);
  final edit = 1.0 - dist / math.max(a.length, b.length);
  return 0.6 * jaccard + 0.4 * edit;
}

int _levenshtein(String a, String b) {
  final m = a.length, n = b.length;
  if (m == 0) return n;
  if (n == 0) return m;
  var prev = List<int>.generate(n + 1, (i) => i);
  var cur = List<int>.filled(n + 1, 0);
  for (var i = 1; i <= m; i++) {
    cur[0] = i;
    for (var j = 1; j <= n; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = math.min(
        math.min(cur[j - 1] + 1, prev[j] + 1),
        prev[j - 1] + cost,
      );
    }
    final tmp = prev;
    prev = cur;
    cur = tmp;
  }
  return prev[n];
}
