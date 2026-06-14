import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:libera/common/media_widgets.dart';
import 'package:libera/services/index_scraper.dart';
import 'package:path_provider/path_provider.dart';

enum DownloadStatus { queued, downloading, completed, failed }

const String _downloadUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0 Safari/537.36';

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

  // Real-download wiring (null for legacy placeholder entries).
  final Uri? sourceUrl; // index page URL; redirects to the CDN file
  final String? fileName; // on-disk file name
  final String? qualityLabel; // "1080p · Bluray · x264"

  DownloadStatus status;
  double progress; // 0..1
  int totalBytes; // -1 unknown
  int receivedBytes;
  String? localPath; // set once completed
  String? error;

  DownloadEntry({
    required this.key,
    required this.parent,
    required this.isMovie,
    required this.title,
    this.season,
    this.episode,
    this.thumbnailPath,
    this.runtimeLabel,
    this.sourceUrl,
    this.fileName,
    this.qualityLabel,
    this.status = DownloadStatus.downloading,
    this.progress = 0.0,
    this.totalBytes = -1,
    this.receivedBytes = 0,
    this.localPath,
    this.error,
  });

  bool get isCompleted => status == DownloadStatus.completed;
  bool get isFailed => status == DownloadStatus.failed;
  bool get isReal => sourceUrl != null;

  String get subtitle {
    final size = _sizeProgressLabel();
    if (isMovie) {
      return <String>[?runtimeLabel, ?size].join(" · ").ifEmptyThen("Movie");
    }
    final parts = <String>["Episode $episode"];
    if (runtimeLabel != null && runtimeLabel!.isNotEmpty) parts.add(runtimeLabel!);
    if (size != null) parts.add(size);
    return parts.join(" · ");
  }

  String? _sizeProgressLabel() {
    if (isFailed) return "Failed";
    if (totalBytes <= 0) return qualityLabel;
    final total = _humanSize(totalBytes);
    if (isCompleted) return total;
    return "${_humanSize(receivedBytes)} / $total";
  }
}

String _humanSize(int bytes) {
  if (bytes <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return "${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}";
}

extension _StringFallback on String {
  String ifEmptyThen(String fallback) => isEmpty ? fallback : this;
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

/// Tracks downloads and runs the real download engine: each [DownloadEntry]
/// with a [DownloadEntry.sourceUrl] is streamed to disk (resumable via HTTP
/// range requests), at most [maxConcurrent] at a time. Legacy entries created
/// without a source fall back to the old simulated progress so existing call
/// sites keep working.
class DownloadsService extends ChangeNotifier {
  DownloadsService._();
  static final DownloadsService instance = DownloadsService._();

  final List<DownloadEntry> _entries = [];
  final http.Client _client = http.Client();

  // Real-download engine state.
  int maxConcurrent = 2;
  final List<String> _queue = [];
  final Set<String> _active = {};
  final Map<String, StreamSubscription<List<int>>> _subs = {};
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  // Legacy simulated-progress ticker.
  Timer? _ticker;

  static String movieKey(int id) => "movie:$id";
  static String episodeKey(int showId, int season, int episode) =>
      "tv:$showId:s$season:e$episode";

  List<DownloadEntry> get all => List.unmodifiable(_entries);
  List<DownloadEntry> get downloading => _entries
      .where((e) =>
          e.status == DownloadStatus.downloading ||
          e.status == DownloadStatus.queued)
      .toList();
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

  /// Enqueue a movie download. When [source] is provided the real file is
  /// fetched; otherwise a simulated placeholder is shown (legacy behaviour).
  void downloadMovie(
    MediaCardData card, {
    String? runtimeLabel,
    VideoFile? source,
  }) {
    final key = movieKey(card.id);
    if (has(key)) return;
    final e = DownloadEntry(
      key: key,
      parent: card,
      isMovie: true,
      title: card.title,
      thumbnailPath: card.backdropPath ?? card.posterPath,
      runtimeLabel: runtimeLabel,
      sourceUrl: source?.pageUrl,
      fileName: source?.fileName,
      qualityLabel: source?.quality.label,
      totalBytes: source?.sizeBytes ?? -1,
      status: source != null ? DownloadStatus.queued : DownloadStatus.downloading,
    );
    _entries.add(e);
    _start(e);
    notifyListeners();
  }

  void downloadEpisode(
    MediaCardData show, {
    required int season,
    required int episode,
    required String name,
    String? stillPath,
    String? runtimeLabel,
    VideoFile? source,
  }) {
    final key = episodeKey(show.id, season, episode);
    if (has(key)) return;
    final e = DownloadEntry(
      key: key,
      parent: show,
      isMovie: false,
      season: season,
      episode: episode,
      title: name.isEmpty ? "Episode $episode" : name,
      thumbnailPath: stillPath ?? show.backdropPath ?? show.posterPath,
      runtimeLabel: runtimeLabel,
      sourceUrl: source?.pageUrl,
      fileName: source?.fileName,
      qualityLabel: source?.quality.label,
      totalBytes: source?.sizeBytes ?? -1,
      status: source != null ? DownloadStatus.queued : DownloadStatus.downloading,
    );
    _entries.add(e);
    _start(e);
    notifyListeners();
  }

  /// Retry a failed entry.
  void retry(String key) {
    final e = entry(key);
    if (e == null || !e.isReal || e.status == DownloadStatus.downloading) return;
    e.error = null;
    e.status = DownloadStatus.queued;
    _start(e);
    notifyListeners();
  }

  void remove(String key) {
    _subs.remove(key)?.cancel();
    _active.remove(key);
    _queue.remove(key);
    final e = entry(key);
    _entries.removeWhere((x) => x.key == key);
    if (e?.localPath != null) {
      unawaited(_deleteFileQuietly(e!.localPath!));
    }
    _pump();
    notifyListeners();
  }

  void removeAll(Iterable<String> keys) {
    for (final k in keys.toList()) {
      _subs.remove(k)?.cancel();
      _active.remove(k);
      _queue.remove(k);
      final e = entry(k);
      if (e?.localPath != null) unawaited(_deleteFileQuietly(e!.localPath!));
    }
    final set = keys.toSet();
    _entries.removeWhere((e) => set.contains(e.key));
    _pump();
    notifyListeners();
  }

  void removeShow(int showId) {
    final keys = _entries
        .where((e) => !e.isMovie && e.parent.id == showId)
        .map((e) => e.key)
        .toList();
    removeAll(keys);
  }

  // ---- engine -------------------------------------------------------------

  void _start(DownloadEntry e) {
    if (e.isReal) {
      if (!_queue.contains(e.key)) _queue.add(e.key);
      _pump();
    } else {
      _ensureTicker();
    }
  }

  void _pump() {
    while (_active.length < maxConcurrent && _queue.isNotEmpty) {
      final key = _queue.removeAt(0);
      final e = entry(key);
      if (e == null) continue;
      _active.add(key);
      unawaited(_run(e));
    }
  }

  Future<void> _run(DownloadEntry e) async {
    IOSink? sink;
    try {
      final dir = await _downloadsDir();
      final file = File('${dir.path}/${_safeName(e.fileName ?? '${e.key}.mkv')}');
      var existing = await file.exists() ? await file.length() : 0;
      if (e.totalBytes > 0 && existing >= e.totalBytes) {
        _finish(e, file);
        return;
      }

      final resp = await _sendWithRetry(e.sourceUrl!, existing);
      if (resp.statusCode == 200) existing = 0; // server ignored the range
      final total = e.totalBytes > 0
          ? e.totalBytes
          : ((resp.contentLength ?? -1) >= 0
              ? resp.contentLength! + existing
              : -1);

      e.status = DownloadStatus.downloading;
      e.totalBytes = total;
      e.receivedBytes = existing;
      e.progress = total > 0 ? existing / total : 0;
      _notify(force: true);

      sink = file.openWrite(
        mode: existing > 0 ? FileMode.append : FileMode.write,
      );
      var received = existing;
      final completer = Completer<void>();
      final sub = resp.stream.listen(
        (chunk) {
          sink!.add(chunk);
          received += chunk.length;
          e.receivedBytes = received;
          if (total > 0) e.progress = (received / total).clamp(0.0, 1.0);
          _notify();
        },
        onDone: () => completer.complete(),
        onError: completer.completeError,
        cancelOnError: true,
      );
      _subs[e.key] = sub;
      await completer.future;
      await sink.flush();
      await sink.close();
      sink = null;
      _finish(e, file);
    } catch (err) {
      await sink?.close();
      // A cancel (entry removed) drops the entry; nothing to mark.
      if (has(e.key)) {
        e.status = DownloadStatus.failed;
        e.error = '$err';
      }
    } finally {
      _subs.remove(e.key);
      _active.remove(e.key);
      _pump();
      _notify(force: true);
    }
  }

  Future<http.StreamedResponse> _sendWithRetry(Uri url, int from) async {
    for (var attempt = 0; ; attempt++) {
      final req = http.Request('GET', url)
        ..followRedirects = true
        ..maxRedirects = 10
        ..headers['User-Agent'] = _downloadUserAgent;
      if (from > 0) req.headers['Range'] = 'bytes=$from-';
      final resp = await _client.send(req);
      if (resp.statusCode == 200 || resp.statusCode == 206) return resp;
      await resp.stream.drain<void>();
      if ((resp.statusCode == 429 || resp.statusCode == 503) && attempt < 4) {
        final ra = int.tryParse(resp.headers['retry-after'] ?? '');
        await Future<void>.delayed(
          ra != null
              ? Duration(seconds: ra.clamp(1, 15))
              : Duration(milliseconds: 600 * (1 << attempt)),
        );
        continue;
      }
      throw HttpStatusException(url, resp.statusCode);
    }
  }

  void _finish(DownloadEntry e, File file) {
    e.status = DownloadStatus.completed;
    e.progress = 1.0;
    e.localPath = file.path;
    if (e.totalBytes <= 0) e.totalBytes = e.receivedBytes;
  }

  Future<Directory> _downloadsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/Downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _deleteFileQuietly(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Notify listeners, throttled to ~3/sec while bytes stream in.
  void _notify({bool force = false}) {
    final now = DateTime.now();
    if (force || now.difference(_lastNotify).inMilliseconds >= 300) {
      _lastNotify = now;
      notifyListeners();
    }
  }

  void _ensureTicker() {
    if (_ticker != null) return;
    _ticker = Timer.periodic(const Duration(milliseconds: 350), (t) {
      var active = false;
      for (final e in _entries) {
        if (e.isReal || e.status != DownloadStatus.downloading) continue;
        active = true;
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

  static String _safeName(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}
