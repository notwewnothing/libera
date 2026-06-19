import 'package:flutter/foundation.dart';
import 'package:libera/common/media_widgets.dart';
import 'package:libera/services/index_scraper.dart';

// Web stub for DownloadsService. Web has no filesystem, so downloads are hidden
// in the UI (see `supportsFileDownloads`); this exists so the download models +
// service API still compile. Mirrors the public surface of downloads_service_io.

enum DownloadStatus { queued, downloading, completed, failed }

/// A single downloadable unit — either a movie or one episode of a show.
class DownloadEntry {
  final String key;
  final MediaCardData parent;
  final bool isMovie;
  final int? season;
  final int? episode;
  final String title;
  final String? thumbnailPath;
  final String? runtimeLabel;
  final Uri? sourceUrl;
  final String? fileName;
  final String? qualityLabel;

  DownloadStatus status;
  double progress;
  int totalBytes;
  int receivedBytes;
  String? localPath;
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
    if (runtimeLabel != null && runtimeLabel!.isNotEmpty) {
      parts.add(runtimeLabel!);
    }
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

/// A grouped library item shown on the Downloads screen.
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

/// No-op DownloadsService for web — never has any entries.
class DownloadsService extends ChangeNotifier {
  DownloadsService._();
  static final DownloadsService instance = DownloadsService._();

  static String movieKey(int id) => "movie:$id";
  static String episodeKey(int showId, int season, int episode) =>
      "tv:$showId:s$season:e$episode";

  List<DownloadEntry> get all => const [];
  List<DownloadEntry> get downloading => const [];
  List<DownloadEntry> get completed => const [];
  int get downloadingCount => 0;
  int get completedCount => 0;
  bool get isEmpty => true;

  DownloadEntry? entry(String key) => null;
  bool has(String key) => false;
  List<DownloadGroup> get library => const [];
  List<DownloadEntry> episodesFor(int showId, int season) => const [];
  List<int> seasonsFor(int showId) => const [];

  void downloadMovie(MediaCardData card,
      {String? runtimeLabel, VideoFile? source}) {}
  void downloadEpisode(MediaCardData show,
      {required int season,
      required int episode,
      required String name,
      String? stillPath,
      String? runtimeLabel,
      VideoFile? source}) {}
  void retry(String key) {}
  void remove(String key) {}
  void removeAll(Iterable<String> keys) {}
  void removeShow(int showId) {}
}
