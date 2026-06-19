import 'package:flutter/foundation.dart';
import 'package:libera/common/media_widgets.dart';

// Web stub for TorrentDownloadsService — torrents can't run in a browser, so
// this never holds items. Mirrors the public surface used by the downloads UI.

/// One torrent being downloaded to disk.
class TorrentDownload {
  final int torrentId;
  final String hash;
  final String magnet;
  final String title;
  final MediaCardData? card;
  final int? season;
  final int? episode;

  double progress;
  double speedMbps;
  int downloadedBytes;
  int totalBytes;
  int peers;
  bool done;

  TorrentDownload({
    required this.torrentId,
    required this.hash,
    required this.magnet,
    required this.title,
    this.card,
    this.season,
    this.episode,
    this.progress = 0,
    this.speedMbps = 0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.peers = 0,
    this.done = false,
  });

  String get speedLabel => speedMbps >= 1
      ? '${speedMbps.toStringAsFixed(1)} MB/s'
      : '${(speedMbps * 1024).toStringAsFixed(0)} KB/s';
}

class TorrentDownloadsService extends ChangeNotifier {
  TorrentDownloadsService._();
  static final TorrentDownloadsService instance = TorrentDownloadsService._();

  List<TorrentDownload> get all => const [];
  bool get isEmpty => true;

  bool has(String magnet) => false;

  Future<bool> add(
    String magnet,
    String title, {
    MediaCardData? card,
    int? season,
    int? episode,
  }) async =>
      false;

  void remove(int torrentId) {}
}
