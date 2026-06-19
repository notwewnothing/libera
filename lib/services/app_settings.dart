import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central, persisted user preferences — the single source of truth that the
/// player, torrent engine, download engine and notification service read from.
///
/// Modelled on Stremio's settings (Player / Streaming Server / Downloads
/// sections). Consumers pull values from here; nothing is pushed back, so this
/// has no dependency on the services it configures.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  // ── Player ────────────────────────────────────────────────────────────────
  bool autoplayNext = true;
  bool resumePlayback = true;
  double defaultPlaybackSpeed = 1.0; // 0.5 .. 2.0
  double subtitleScale = 1.0; // 0.5 .. 2.0
  int skipSeconds = 10; // 10 / 15 / 30 — the ±skip buttons
  bool subtitleBackground = false; // dim box behind subtitles (off = outlined)

  // ── Interface ───────────────────────────────────────────────────────────────
  bool autoplayTrailer = true; // auto-play the trailer on a detail page

  // ── Streaming (torrents) ───────────────────────────────────────────────────
  bool torrentCacheToRam = true; // true = RAM, false = disk
  int torrentRamCacheMb = 200; // 100/200/400/800
  // Stremio's streaming server defaults to btMaxConnections=55 — fewer, stable
  // connections handshake faster and churn less on mobile than a large pool.
  int torrentMaxConnections = 55; // 20 .. 200
  // Seconds of video buffered ahead before playback starts. Lower = faster
  // start (Stremio-style), higher = fewer early stutters on slow swarms.
  double torrentStartBufferSeconds = 5.0; // 1 .. 20

  // ── Downloads ──────────────────────────────────────────────────────────────
  int maxConcurrentDownloads = 2; // 1 .. 5
  bool backgroundDownloads = true;

  bool _loaded = false;

  static const _kAutoplayNext = 'set_autoplay_next';
  static const _kResume = 'set_resume_playback';
  static const _kSpeed = 'set_default_speed';
  static const _kSubScale = 'set_subtitle_scale';
  static const _kSkipSeconds = 'set_skip_seconds';
  static const _kSubBackground = 'set_subtitle_background';
  static const _kAutoplayTrailer = 'set_autoplay_trailer';
  static const _kCacheRam = 'set_torrent_cache_ram';
  static const _kRamMb = 'set_torrent_ram_mb';
  static const _kMaxConn = 'set_torrent_max_conn';
  static const _kStartBuffer = 'set_torrent_start_buffer_secs';
  static const _kMaxConcurrent = 'set_max_concurrent_downloads';
  static const _kBgDownloads = 'set_background_downloads';

  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      autoplayNext = p.getBool(_kAutoplayNext) ?? autoplayNext;
      resumePlayback = p.getBool(_kResume) ?? resumePlayback;
      defaultPlaybackSpeed = p.getDouble(_kSpeed) ?? defaultPlaybackSpeed;
      subtitleScale = p.getDouble(_kSubScale) ?? subtitleScale;
      skipSeconds = p.getInt(_kSkipSeconds) ?? skipSeconds;
      subtitleBackground = p.getBool(_kSubBackground) ?? subtitleBackground;
      autoplayTrailer = p.getBool(_kAutoplayTrailer) ?? autoplayTrailer;
      torrentCacheToRam = p.getBool(_kCacheRam) ?? torrentCacheToRam;
      torrentRamCacheMb = p.getInt(_kRamMb) ?? torrentRamCacheMb;
      torrentMaxConnections = p.getInt(_kMaxConn) ?? torrentMaxConnections;
      torrentStartBufferSeconds =
          p.getDouble(_kStartBuffer) ?? torrentStartBufferSeconds;
      maxConcurrentDownloads = p.getInt(_kMaxConcurrent) ?? maxConcurrentDownloads;
      backgroundDownloads = p.getBool(_kBgDownloads) ?? backgroundDownloads;
    } catch (e) {
      debugPrint('[AppSettings] load failed: $e');
    }
    notifyListeners();
  }

  Future<void> _setBool(String k, bool v) async {
    notifyListeners();
    try {
      (await SharedPreferences.getInstance()).setBool(k, v);
    } catch (_) {}
  }

  Future<void> _setInt(String k, int v) async {
    notifyListeners();
    try {
      (await SharedPreferences.getInstance()).setInt(k, v);
    } catch (_) {}
  }

  Future<void> _setDouble(String k, double v) async {
    notifyListeners();
    try {
      (await SharedPreferences.getInstance()).setDouble(k, v);
    } catch (_) {}
  }

  void setAutoplayNext(bool v) {
    autoplayNext = v;
    _setBool(_kAutoplayNext, v);
  }

  void setResumePlayback(bool v) {
    resumePlayback = v;
    _setBool(_kResume, v);
  }

  void setDefaultPlaybackSpeed(double v) {
    defaultPlaybackSpeed = v;
    _setDouble(_kSpeed, v);
  }

  void setSubtitleScale(double v) {
    subtitleScale = v;
    _setDouble(_kSubScale, v);
  }

  void setSkipSeconds(int v) {
    skipSeconds = v;
    _setInt(_kSkipSeconds, v);
  }

  void setSubtitleBackground(bool v) {
    subtitleBackground = v;
    _setBool(_kSubBackground, v);
  }

  void setAutoplayTrailer(bool v) {
    autoplayTrailer = v;
    _setBool(_kAutoplayTrailer, v);
  }

  void setTorrentCacheToRam(bool v) {
    torrentCacheToRam = v;
    _setBool(_kCacheRam, v);
  }

  void setTorrentRamCacheMb(int v) {
    torrentRamCacheMb = v;
    _setInt(_kRamMb, v);
  }

  void setTorrentMaxConnections(int v) {
    torrentMaxConnections = v.clamp(20, 200);
    _setInt(_kMaxConn, torrentMaxConnections);
  }

  void setTorrentStartBufferSeconds(double v) {
    torrentStartBufferSeconds = v.clamp(1.0, 20.0);
    _setDouble(_kStartBuffer, torrentStartBufferSeconds);
  }

  void setMaxConcurrentDownloads(int v) {
    maxConcurrentDownloads = v.clamp(1, 5);
    _setInt(_kMaxConcurrent, maxConcurrentDownloads);
  }

  void setBackgroundDownloads(bool v) {
    backgroundDownloads = v;
    _setBool(_kBgDownloads, v);
  }
}
