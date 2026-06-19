import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';

import 'package:libera/services/app_settings.dart';
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

/// Result of opening a torrent stream: a playable local HTTP [url] plus the
/// native [streamId], which callers pass to [TorrentStreamService.bufferProgress]
/// to watch buffering before they hand the url to the player.
class TorrentStreamHandle {
  final String url;
  final int streamId;
  final String? hash;
  final StreamInfo initial;
  const TorrentStreamHandle({
    required this.url,
    required this.streamId,
    required this.hash,
    required this.initial,
  });
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

  // User-configurable via AppSettings (Stremio-style streaming server prefs).
  bool get _saveToRam => AppSettings.instance.torrentCacheToRam;
  int get _ramCacheMb => AppSettings.instance.torrentRamCacheMb;
  int get _connectionsLimit => AppSettings.instance.torrentMaxConnections;

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

  /// Live-apply the current connection limit from [AppSettings] to a running
  /// session (call after the user changes it in settings).
  Future<void> applyConnectionsLimit() async {
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
  /// or [fileIdx]), starts the local HTTP stream, primes the head+tail cache and
  /// returns a [TorrentStreamHandle]. Callers gate playback on [bufferProgress]
  /// so the player only opens once enough is buffered (Stremio-style fast start).
  Future<TorrentStreamHandle?> openStream(
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

      // Prime head + tail so the player can start instantly (TorrServer-style).
      try {
        LibtorrentFlutter.instance.preloadStream(streamInfo.id);
        _log('Preloading head+tail for stream ${streamInfo.id}');
      } catch (e) {
        _log('preloadStream failed (non-fatal): $e');
      }

      return TorrentStreamHandle(
        url: streamInfo.url,
        streamId: streamInfo.id,
        hash: hash,
        initial: streamInfo,
      );
    } catch (e) {
      _log('openStream error: $e');
      return null;
    }
  }

  /// Backward-compatible helper: just the playable URL, no buffer gating.
  Future<String?> streamTorrent(
    String magnetLink, {
    int? season,
    int? episode,
    int? fileIdx,
  }) async {
    final handle = await openStream(magnetLink,
        season: season, episode: episode, fileIdx: fileIdx);
    return handle?.url;
  }

  /// Live buffering telemetry for an active [streamId] — buffer %, download
  /// rate, peer count and ready/buffering state. Drives the loading screen.
  Stream<StreamInfo> bufferProgress(int streamId) =>
      LibtorrentFlutter.instance.streamUpdates
          .map((streams) => streams[streamId])
          .where((info) => info != null)
          .cast<StreamInfo>();

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
    // 1. Trust the addon-supplied file index FIRST. Stremio/AIOStreams resolve
    //    the exact file for the requested episode and hand it over as fileIdx;
    //    this is authoritative. Season packs frequently also bundle the movie
    //    or specials (often the LARGEST file), so any size/name heuristic risks
    //    grabbing "<Show> The Movie" instead of the episode — which is exactly
    //    the bug this avoids.
    if (preferredIdx != null) {
      final exact =
          files.where((f) => f.index == preferredIdx && f.isStreamable).toList();
      if (exact.isNotEmpty) {
        _log('Using addon fileIdx=$preferredIdx: ${exact.first.name}');
        return exact.first.index;
      }
      _log('addon fileIdx=$preferredIdx not found among files; falling back');
    }

    final videoFiles = files
        .where((f) => f.isStreamable && TorrentFilter.isVideoFile(f.name))
        .toList();
    if (videoFiles.isEmpty) {
      final streamable = files.where((f) => f.isStreamable).toList();
      if (streamable.isEmpty) return null;
      streamable.sort((a, b) => b.size.compareTo(a.size));
      return streamable.first.index;
    }

    // 2. Match the requested season/episode by filename (skips the movie /
    //    specials in a pack). Only the largest match is kept (sample files etc).
    if (season != null && episode != null) {
      final matches = videoFiles
          .where((f) => TorrentFilter.isFileMatch(f.name, season, episode))
          .toList();
      if (matches.isNotEmpty) {
        matches.sort((a, b) => b.size.compareTo(a.size));
        _log('Episode name-match S${season}E$episode: ${matches.first.name}');
        return matches.first.index;
      }
      // A season/episode was requested but nothing matched. If this looks like
      // a multi-file pack, refuse to blindly grab the largest file (that's how
      // the movie gets picked) — there's nothing sensible to return.
      if (videoFiles.length > 1) {
        _log('No file matched S${season}E$episode in a ${videoFiles.length}-file '
            'pack — not falling back to largest to avoid the wrong title');
        return null;
      }
    }

    // 3. Single-file / movie torrent — the largest video is the right call.
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
