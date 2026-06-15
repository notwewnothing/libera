import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'package:libera/common/media_widgets.dart';
import 'package:libera/services/torrent/torrent_stream_service.dart';

/// One torrent being downloaded to disk.
class TorrentDownload {
  final int torrentId;
  final String hash;
  final String magnet;
  final String title;
  final MediaCardData? card;
  final int? season;
  final int? episode;

  double progress; // 0..1
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

/// Downloads torrents to disk via the shared libtorrent engine and tracks their
/// progress. Distinct from the HTTP [DownloadsService]; torrents can't go
/// through that pipeline. Mirrors the ChangeNotifier-singleton pattern.
class TorrentDownloadsService extends ChangeNotifier {
  TorrentDownloadsService._();
  static final TorrentDownloadsService instance = TorrentDownloadsService._();

  final List<TorrentDownload> _items = [];
  StreamSubscription? _sub;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  List<TorrentDownload> get all => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;

  static final _hashRe = RegExp(r'[0-9a-fA-F]{40}');
  String _hashOf(String magnet) =>
      _hashRe.firstMatch(magnet)?.group(0)?.toLowerCase() ?? magnet;

  bool has(String magnet) {
    final h = _hashOf(magnet);
    return _items.any((d) => d.hash == h);
  }

  /// Starts downloading [magnet] to disk. Returns false if the engine couldn't
  /// start. No-op (returns true) if this torrent is already in the list.
  Future<bool> add(
    String magnet,
    String title, {
    MediaCardData? card,
    int? season,
    int? episode,
  }) async {
    if (has(magnet)) return true;
    final ok = await TorrentStreamService.instance.start();
    if (!ok) return false;

    final dir = await getApplicationDocumentsDirectory();
    final savePath = '${dir.path}/TorrentDownloads';

    final id = LibtorrentFlutter.instance.addMagnet(magnet, savePath, false);
    _items.add(TorrentDownload(
      torrentId: id,
      hash: _hashOf(magnet),
      magnet: magnet,
      title: title,
      card: card,
      season: season,
      episode: episode,
    ));
    _ensureListening();
    notifyListeners();
    return true;
  }

  void remove(int torrentId) {
    final idx = _items.indexWhere((d) => d.torrentId == torrentId);
    if (idx < 0) return;
    _items.removeAt(idx);
    try {
      LibtorrentFlutter.instance.disposeTorrent(torrentId);
    } catch (e) {
      debugPrint('[TorrentDownloads] dispose failed: $e');
    }
    notifyListeners();
  }

  void _ensureListening() {
    _sub ??= LibtorrentFlutter.instance.torrentUpdates.listen((updates) {
      var changed = false;
      for (final d in _items) {
        final info = updates[d.torrentId];
        if (info == null) continue;
        d.progress = info.progress.clamp(0, 1).toDouble();
        d.speedMbps = info.downloadRate / 1024 / 1024;
        d.downloadedBytes = info.totalDone;
        d.totalBytes = info.totalWanted;
        d.peers = info.numPeers;
        final nowDone = info.progress >= 0.999;
        if (nowDone != d.done) {
          d.done = nowDone;
          changed = true;
        }
        changed = true;
      }
      if (changed) _notifyThrottled();
    });
  }

  void _notifyThrottled() {
    final now = DateTime.now();
    if (now.difference(_lastNotify).inMilliseconds >= 500) {
      _lastNotify = now;
      notifyListeners();
    }
  }
}
