import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';

import 'torrent_filter.dart';

/// Rich torrent statistics snapshot for the UI.
class TorrentStats {
  final double speedMbps;
  final int activePeers;
  final int totalPeers;
  final double cachePercent;
  final int loadedBytes;
  final int totalBytes;
  final String hash;
  final bool isConnected;

  const TorrentStats({
    required this.speedMbps,
    required this.activePeers,
    required this.totalPeers,
    required this.cachePercent,
    required this.loadedBytes,
    required this.totalBytes,
    required this.hash,
    required this.isConnected,
  });

  double get speedKbps => speedMbps * 1024;
  String get speedLabel => speedMbps >= 1.0
      ? '${speedMbps.toStringAsFixed(2)} MB/s'
      : '${speedKbps.toStringAsFixed(0)} KB/s';
  String get peersLabel => '$activePeers / $totalPeers';
  String get cacheLabel => '${cachePercent.toStringAsFixed(1)}%';
}

/// Engine lifecycle states.
enum EngineState { stopped, starting, ready, error }

/// Streams (and downloads) torrents via the `libtorrent_flutter` native engine.
///
/// `streamTorrent(magnet)` adds the magnet, waits for metadata, selects the
/// right video file and returns a **local HTTP URL** that any player (media_kit)
/// can open. The same running torrent fills its on-disk/RAM cache, so a download
/// is just letting it run to completion.
///
/// Ported from PlayTorrioV2's TorrentStreamService; settings are inlined as
/// constants (RAM cache, 200 MB window, 200 peer connections) instead of its
/// SettingsService.
class TorrentStreamService {
  TorrentStreamService._internal();
  static final TorrentStreamService _instance =
      TorrentStreamService._internal();
  factory TorrentStreamService() => _instance;
  static TorrentStreamService get instance => _instance;

  // Inlined defaults (were SettingsService in PlayTorrioV2).
  static const bool _saveToRam = true;
  static const int _ramCacheMb = 200;
  int _connectionsLimit = 200;

  EngineState _state = EngineState.stopped;
  EngineState get state => _state;

  void Function(EngineState state)? onStateChanged;
  void Function(String line)? onLogLine;

  final Map<String, int> _activeTorrents = {}; // info-hash -> torrent id
  final Map<String, int> _activeStreams = {}; // info-hash -> stream id
  final Set<int> _disposedTorrentIds = {};
  final Set<int> _disposedStreamIds = {};

  StreamSubscription? _torrentUpdatesSub;
  final Map<int, TorrentInfo> _latestUpdates = {};

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Initialises the libtorrent engine. Safe to call multiple times.
  Future<bool> start() async {
    if (_state == EngineState.ready) return true;
    if (_state == EngineState.starting) {
      for (int i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_state == EngineState.ready) return true;
        if (_state == EngineState.error) return false;
      }
      return false;
    }

    _setState(EngineState.starting);
    try {
      await LibtorrentFlutter.init(
        fetchTrackers: true,
        pollInterval: const Duration(milliseconds: 200),
      );
      try {
        final engine = LibtorrentFlutter.instance;
        engine.configureSession(engine.getDefaultConfig().copyWith(
              connectionsLimit: _connectionsLimit,
              forceEncrypt: false,
              disableDht: false,
              downloadRateLimit: 0,
              uploadRateLimit: 0,
            ));
        _log('Session configured: conns=$_connectionsLimit');
      } catch (e) {
        _log('configureSession failed (non-fatal): $e');
      }
      _torrentUpdatesSub =
          LibtorrentFlutter.instance.torrentUpdates.listen((updates) {
        _latestUpdates.addAll(updates);
      });
      _setState(EngineState.ready);
      _log('Engine ready (libtorrent_flutter)');
      return true;
    } catch (e, st) {
      _log('Failed to start engine: $e\n$st');
      _setState(EngineState.error);
      return false;
    }
  }

  /// Live-update the per-torrent peer connection limit.
  Future<void> applyConnectionsLimit(int limit) async {
    _connectionsLimit = limit.clamp(5, 200);
    if (_state != EngineState.ready) return;
    try {
      final engine = LibtorrentFlutter.instance;
      engine.configureSession(engine.getDefaultConfig().copyWith(
            connectionsLimit: _connectionsLimit,
            forceEncrypt: false,
            disableDht: false,
            downloadRateLimit: 0,
            uploadRateLimit: 0,
          ));
      _log('Connections limit updated: $_connectionsLimit');
    } catch (e) {
      _log('applyConnectionsLimit failed: $e');
    }
  }

  // ── Stream a torrent — main entry point ────────────────────────────────────

  /// Adds [magnetLink], waits for metadata, picks the file (season/episode aware,
  /// or [fileIdx]), starts the local HTTP stream and returns its URL.
  Future<String?> streamTorrent(
    String magnetLink, {
    int? season,
    int? episode,
    int? fileIdx,
  }) async {
    if (_state != EngineState.ready) {
      final started = await start();
      if (!started) {
        _log('Cannot stream: engine failed to start.');
        return null;
      }
    }

    final hash = _extractHash(magnetLink);

    // Dispose previous torrent with same hash if any.
    if (hash != null && _activeTorrents.containsKey(hash)) {
      try {
        final oldId = _activeTorrents[hash]!;
        if (_activeStreams.containsKey(hash)) {
          _safeStopStream(_activeStreams[hash]!);
          _activeStreams.remove(hash);
        }
        _safeDisposeTorrent(oldId);
        _activeTorrents.remove(hash);
      } catch (e) {
        _log('Cleanup old torrent error: $e');
      }
    }

    try {
      final torrentId =
          LibtorrentFlutter.instance.addMagnet(magnetLink, null, _saveToRam);
      if (hash != null) _activeTorrents[hash] = torrentId;
      _log('Added magnet, torrentId=$torrentId');

      final files = await _waitForMetadata(torrentId);
      if (files == null || files.isEmpty) {
        _log('No files found in torrent');
        return null;
      }

      final selectedIndex = _selectFile(files,
          season: season, episode: episode, preferredIdx: fileIdx);
      if (selectedIndex == null) {
        _log('No suitable video file found');
        return null;
      }
      _log('Selected file index $selectedIndex: '
          '${files.firstWhere((f) => f.index == selectedIndex).name}');

      final maxCacheBytes = _saveToRam ? (_ramCacheMb * 1024 * 1024) : 0;
      final streamInfo = LibtorrentFlutter.instance.startStream(
        torrentId,
        fileIndex: selectedIndex,
        maxCacheBytes: maxCacheBytes,
      );
      if (hash != null) _activeStreams[hash] = streamInfo.id;
      _log('Stream started: ${streamInfo.url}');
      return streamInfo.url;
    } catch (e) {
      _log('streamTorrent error: $e');
      return null;
    }
  }

  // ── Metadata polling ────────────────────────────────────────────────────────

  Future<List<FileInfo>?> _waitForMetadata(int torrentId,
      {Duration timeout = const Duration(seconds: 30)}) async {
    final completer = Completer<List<FileInfo>?>();
    StreamSubscription? sub;

    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        _log('Metadata timeout after ${timeout.inSeconds}s');
        sub?.cancel();
        completer.complete(null);
      }
    });

    sub = LibtorrentFlutter.instance.torrentUpdates.listen((updates) {
      if (completer.isCompleted) return;
      final info = updates[torrentId];
      if (info != null && info.hasMetadata) {
        timer.cancel();
        sub?.cancel();
        completer.complete(LibtorrentFlutter.instance.getFiles(torrentId));
      }
    });

    // Metadata may already be available.
    try {
      final files = LibtorrentFlutter.instance.getFiles(torrentId);
      if (files.isNotEmpty) {
        timer.cancel();
        sub.cancel();
        if (!completer.isCompleted) completer.complete(files);
      }
    } catch (_) {
      // Not ready yet — wait for updates.
    }

    return completer.future;
  }

  // ── File selection ──────────────────────────────────────────────────────────

  int? _selectFile(List<FileInfo> files,
      {int? season, int? episode, int? preferredIdx}) {
    final videoFiles = files
        .where((f) => f.isStreamable && TorrentFilter.isVideoFile(f.name))
        .toList();
    if (videoFiles.isEmpty) {
      final streamable = files.where((f) => f.isStreamable).toList();
      if (streamable.isEmpty) return null;
      streamable.sort((a, b) => b.size.compareTo(a.size));
      return streamable.first.index;
    }

    if (season != null && episode != null) {
      final matches = videoFiles
          .where((f) => TorrentFilter.isFileMatch(f.name, season, episode))
          .toList();
      if (matches.isNotEmpty) {
        matches.sort((a, b) => b.size.compareTo(a.size));
        return matches.first.index;
      }
    }

    if (preferredIdx != null) {
      final match = videoFiles.where((f) => f.index == preferredIdx).toList();
      if (match.isNotEmpty) return match.first.index;
    }

    videoFiles.sort((a, b) => b.size.compareTo(a.size));
    return videoFiles.first.index;
  }

  // ── Torrent management ──────────────────────────────────────────────────────

  void removeTorrent(String magnetOrHash) {
    final hash = _extractHash(magnetOrHash);
    final key = hash ?? magnetOrHash;
    if (_activeStreams.containsKey(key)) {
      _safeStopStream(_activeStreams[key]!);
      _activeStreams.remove(key);
    }
    if (_activeTorrents.containsKey(key)) {
      final torrentId = _activeTorrents[key]!;
      _safeDisposeTorrent(torrentId);
      _activeTorrents.remove(key);
      _latestUpdates.remove(torrentId);
      _log('Removed torrent $key');
    }
  }

  // ── Statistics ──────────────────────────────────────────────────────────────

  TorrentStats? getTorrentStats(String magnetOrHash) {
    final hash = _extractHash(magnetOrHash);
    final key = hash ?? magnetOrHash;
    final torrentId = _activeTorrents[key];
    if (torrentId == null) return null;
    final info = _latestUpdates[torrentId];
    if (info == null) return null;

    return TorrentStats(
      speedMbps: info.downloadRate / 1024 / 1024,
      activePeers: info.numPeers,
      totalPeers: info.numPeers,
      cachePercent: info.progress * 100,
      loadedBytes: info.totalDone,
      totalBytes: info.totalWanted,
      hash: key,
      isConnected: info.numPeers > 0,
    );
  }

  Stream<TorrentStats> statsStream(String magnetOrHash,
      {Duration interval = const Duration(seconds: 1)}) {
    final controller = StreamController<TorrentStats>();
    Timer? timer;
    controller.onListen = () {
      timer = Timer.periodic(interval, (_) {
        final stats = getTorrentStats(magnetOrHash);
        if (stats != null && !controller.isClosed) controller.add(stats);
      });
    };
    controller.onCancel = () {
      timer?.cancel();
      controller.close();
    };
    return controller.stream;
  }

  // ── Stop / cleanup ──────────────────────────────────────────────────────────

  Future<void> stop() async {
    for (final streamId in _activeStreams.values) {
      _safeStopStream(streamId);
    }
    _activeStreams.clear();
    for (final torrentId in _activeTorrents.values) {
      _safeDisposeTorrent(torrentId);
    }
    _activeTorrents.clear();
    _latestUpdates.clear();
    _log('All torrents stopped.');
  }

  Future<void> cleanup() async {
    await stop();
    _torrentUpdatesSub?.cancel();
    _torrentUpdatesSub = null;
    _disposedTorrentIds.clear();
    _disposedStreamIds.clear();
    _setState(EngineState.stopped);
    _log('Engine cleaned up.');
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _safeStopStream(int streamId) {
    if (_disposedStreamIds.contains(streamId)) return;
    _disposedStreamIds.add(streamId);
    try {
      LibtorrentFlutter.instance.stopStream(streamId);
    } catch (e) {
      _log('Stop stream error: $e');
    }
  }

  void _safeDisposeTorrent(int torrentId) {
    if (_disposedTorrentIds.contains(torrentId)) return;
    _disposedTorrentIds.add(torrentId);
    try {
      LibtorrentFlutter.instance.disposeTorrent(torrentId);
    } catch (e) {
      _log('Dispose torrent error: $e');
    }
  }

  static final _hashRegExp = RegExp(r'[0-9a-fA-F]{40}');

  String? _extractHash(String magnetOrHash) =>
      _hashRegExp.firstMatch(magnetOrHash)?.group(0)?.toLowerCase();

  void _setState(EngineState s) {
    if (_state == s) return;
    _state = s;
    onStateChanged?.call(s);
  }

  void _log(String message) {
    debugPrint('[TorrentStream] $message');
    onLogLine?.call(message);
  }
}
