import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libera/common/adaptive_dialog.dart';
import 'package:libera/common/media_widgets.dart';
import 'package:libera/common/platform.dart';
import 'package:libera/services/app_settings.dart';
import 'package:libera/services/continue_watching_service.dart';
import 'package:libera/services/watched_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

const _accent = Color(0xFF0A84FF);

/// Fully-featured offline player for downloaded files (mkv/mp4/…), backed by
/// media_kit (libmpv) so it plays the codecs the index ships. Supports
/// resume, ±10s skip, playback speed, audio- and subtitle-track selection,
/// fullscreen, gestures, and writes progress back to Continue Watching /
/// Watched just like the streaming player.
class OfflinePlayerScreen extends StatefulWidget {
  /// On-disk file to play (downloaded content). Null when [mediaUrl] is used.
  final String? filePath;

  /// Network URL to play instead of a file — used for torrent streaming, where
  /// the libtorrent engine serves the file over a local HTTP URL.
  final String? mediaUrl;
  final String title;
  final MediaCardData? card;
  final int? season;
  final int? episode;

  const OfflinePlayerScreen({
    super.key,
    this.filePath,
    this.mediaUrl,
    required this.title,
    this.card,
    this.season,
    this.episode,
  }) : assert(
         filePath != null || mediaUrl != null,
         'Provide either a filePath or a mediaUrl',
       );

  @override
  State<OfflinePlayerScreen> createState() => _OfflinePlayerScreenState();
}

class _OfflinePlayerScreenState extends State<OfflinePlayerScreen> {
  // A larger demuxer cache (vs the 32 MB default) lets mpv read further ahead
  // and keep filling the buffer even while paused — like Stremio, the stream
  // keeps downloading when you pause. For torrents this also keeps pulling
  // pieces from the libtorrent engine into cache.
  late final Player _player = Player(
    configuration: const PlayerConfiguration(bufferSize: 64 * 1024 * 1024),
  );
  late final VideoController _controller = VideoController(_player);
  final List<StreamSubscription> _subs = [];

  bool get _isStream => widget.mediaUrl != null;

  double _position = 0;
  double _duration = 0;
  double _startAt = 0;
  bool _seeked = false;
  bool _ended = false;
  bool _buffering = true;
  DateTime _lastSave = DateTime.now();

  MediaCardData? get _card => widget.card;

  @override
  void initState() {
    super.initState();

    // Auto-fullscreen: landscape + immersive for the player's whole lifetime.
    // We manage this ourselves (instead of media_kit's fullscreen route) so the
    // back button always exits the player in a single tap, never to a half-way
    // windowed state.
    setSystemUIModeSafe(SystemUiMode.immersiveSticky);
    setOrientationsSafe(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _startAt = _resumeFrom();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final card = _card;
      if (card != null) {
        ContinueWatchingService.instance.record(
          card,
          season: card.isMovie ? null : widget.season,
          episode: card.isMovie ? null : widget.episode,
        );
      }
    });

    _subs.add(
      _player.stream.duration.listen((d) {
        _duration = d.inMilliseconds / 1000.0;
        // Seek to the resume point once the media is loaded.
        if (!_seeked && _startAt > 1 && d > Duration.zero) {
          _seeked = true;
          _player.seek(Duration(milliseconds: (_startAt * 1000).round()));
        }
      }),
    );
    _subs.add(
      _player.stream.position.listen((p) {
        _position = p.inMilliseconds / 1000.0;
        if (DateTime.now().difference(_lastSave).inSeconds >= 10) {
          _saveProgress();
        }
      }),
    );
    _subs.add(
      _player.stream.completed.listen((done) {
        if (done) _onEnded();
      }),
    );
    _subs.add(
      _player.stream.buffering.listen((b) {
        if (mounted && b != _buffering) setState(() => _buffering = b);
      }),
    );

    final source = widget.mediaUrl ?? Uri.file(widget.filePath!).toString();
    _player.open(Media(source));
    final speed = AppSettings.instance.defaultPlaybackSpeed;
    if (speed != 1.0) _player.setRate(speed);
    if (_isStream) _tuneStreamCache();
  }

  /// For network/torrent streams, tell mpv to keep a large look-ahead cache and
  /// keep filling it (even while paused) so the stream downloads ahead like
  /// Stremio. Best-effort: silently ignored on platforms without libmpv.
  Future<void> _tuneStreamCache() async {
    // libmpv-only tuning; the web player has no setProperty. Skip on web and
    // call via dynamic so the method resolves at runtime only where it exists.
    if (kIsWeb) return;
    final dynamic platform = _player.platform;
    try {
      await platform.setProperty('cache', 'yes');
      await platform.setProperty('cache-secs', '3600');
      await platform.setProperty('cache-pause', 'no');
    } catch (_) {
      // Property not supported on this build — buffering still works.
    }
  }

  double _resumeFrom() {
    final card = _card;
    if (card == null || !AppSettings.instance.resumePlayback) return 0;
    return ContinueWatchingService.instance.resumePosition(
      card.id,
      isMovie: card.isMovie,
      season: widget.season,
      episode: widget.episode,
    );
  }

  void _saveProgress() {
    final card = _card;
    if (card == null || _duration <= 0) return;
    _lastSave = DateTime.now();
    ContinueWatchingService.instance.record(
      card,
      season: card.isMovie ? null : widget.season,
      episode: card.isMovie ? null : widget.episode,
      positionSeconds: _position,
      durationSeconds: _duration,
    );
  }

  void _onEnded() {
    if (_ended) return;
    _ended = true;
    final card = _card;
    if (card == null) return;
    if (card.isMovie) {
      WatchedService.instance.markMovieWatched(card);
      ContinueWatchingService.instance.remove(card.id, isMovie: true);
    } else {
      WatchedService.instance.markEpisodeWatched(
        card,
        widget.season ?? 1,
        widget.episode ?? 1,
      );
    }
  }

  int get _skipSeconds => AppSettings.instance.skipSeconds;
  IconData get _skipBackIcon =>
      _skipSeconds >= 30 ? Icons.replay_30 : Icons.replay_10;
  IconData get _skipFwdIcon =>
      _skipSeconds >= 30 ? Icons.forward_30 : Icons.forward_10;

  Future<void> _skip(int seconds) async {
    final target = _player.state.position + Duration(seconds: seconds);
    final dur = _player.state.duration;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (dur > Duration.zero && target > dur ? dur : target);
    await _player.seek(clamped);
  }

  void _togglePlay() => _player.playOrPause();

  void _adjustVolume(double delta) {
    final v = (_player.state.volume + delta).clamp(0.0, 100.0);
    _player.setVolume(v);
  }

  /// Desktop/web keyboard controls (no-op effect on touch, harmless there).
  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.space): _togglePlay,
    const SingleActivator(LogicalKeyboardKey.keyK): _togglePlay,
    const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
        _skip(-_skipSeconds),
    const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
        _skip(_skipSeconds),
    const SingleActivator(LogicalKeyboardKey.keyJ): () => _skip(-_skipSeconds),
    const SingleActivator(LogicalKeyboardKey.keyL): () => _skip(_skipSeconds),
    const SingleActivator(LogicalKeyboardKey.arrowUp): () => _adjustVolume(10),
    const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
        _adjustVolume(-10),
    const SingleActivator(LogicalKeyboardKey.escape): () =>
        Navigator.maybePop(context),
  };

  @override
  void dispose() {
    if (!_ended) _saveProgress();
    // Restore portrait/normal UI on the way out.
    setSystemUIModeSafe(SystemUiMode.edgeToEdge);
    setOrientationsSafe(DeviceOrientation.values);
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _controlsTheme(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: CallbackShortcuts(
        bindings: _shortcuts,
        child: Focus(
          autofocus: true,
          child: MaterialVideoControlsTheme(
            normal: theme,
            fullscreen: theme,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Video(
                  controller: _controller,
                  controls: MaterialVideoControls,
                  fit: BoxFit.contain,
                  subtitleViewConfiguration: _subtitleConfig(),
                ),
                if (_buffering)
                  const IgnorePointer(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _accent,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Stylised subtitles — white text with a crisp black outline + soft drop
  /// shadow (Stremio-style) so they read on any background. The dim box is now
  /// optional (off by default) rather than the only style.
  SubtitleViewConfiguration _subtitleConfig() {
    final scale = AppSettings.instance.subtitleScale;
    final withBox = AppSettings.instance.subtitleBackground;
    const outline = [
      Shadow(offset: Offset(1.2, 1.2), blurRadius: 2.5, color: Colors.black),
      Shadow(offset: Offset(-1.2, 1.2), blurRadius: 2.5, color: Colors.black),
      Shadow(offset: Offset(1.2, -1.2), blurRadius: 2.5, color: Colors.black),
      Shadow(offset: Offset(-1.2, -1.2), blurRadius: 2.5, color: Colors.black),
      Shadow(blurRadius: 7, color: Colors.black87),
    ];
    return SubtitleViewConfiguration(
      style: TextStyle(
        fontSize: 32.0 * scale,
        height: 1.3,
        color: Colors.white,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        backgroundColor: withBox
            ? const Color(0x99000000)
            : const Color(0x00000000),
        shadows: outline,
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
    );
  }

  MaterialVideoControlsThemeData _controlsTheme(BuildContext context) {
    return MaterialVideoControlsThemeData(
      seekBarThumbColor: _accent,
      seekBarPositionColor: _accent,
      seekBarBufferColor: Colors.white24,
      seekOnDoubleTap: true,
      volumeGesture: true,
      brightnessGesture: true,
      buttonBarButtonColor: Colors.white,
      // Lift the seek bar / bottom button row off the very bottom edge.
      seekBarMargin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      bottomButtonBarMargin: const EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: 22,
      ),
      topButtonBar: [
        MaterialCustomButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          // Always exit the player in one tap — we own the fullscreen state,
          // so there is no half-way windowed mode to fall back to.
          onPressed: () => Navigator.maybePop(context),
        ),
        Expanded(
          child: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        MaterialCustomButton(
          icon: const Icon(Icons.audiotrack, color: Colors.white),
          onPressed: _showAudioMenu,
        ),
        MaterialCustomButton(
          icon: const Icon(Icons.closed_caption, color: Colors.white),
          onPressed: _showSubtitleMenu,
        ),
        MaterialCustomButton(
          icon: const Icon(Icons.speed, color: Colors.white),
          onPressed: _showSpeedMenu,
        ),
      ],
      primaryButtonBar: [
        const Spacer(),
        MaterialCustomButton(
          icon: Icon(_skipBackIcon, color: Colors.white),
          iconSize: 32,
          onPressed: () => _skip(-_skipSeconds),
        ),
        const SizedBox(width: 8),
        const MaterialPlayOrPauseButton(iconSize: 52),
        const SizedBox(width: 8),
        MaterialCustomButton(
          icon: Icon(_skipFwdIcon, color: Colors.white),
          iconSize: 32,
          onPressed: () => _skip(_skipSeconds),
        ),
        const Spacer(),
      ],
      bottomButtonBar: const [MaterialPositionIndicator(), Spacer()],
    );
  }

  // ---- track / speed sheets ----------------------------------------------

  void _showSpeedMenu() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final current = _player.state.rate;
    _sheet(
      title: "Playback speed",
      children: [
        for (final s in speeds)
          _option(
            label: s == 1.0 ? "Normal" : "${s}x",
            selected: (current - s).abs() < 0.01,
            onTap: () {
              _player.setRate(s);
              Navigator.pop(context);
            },
          ),
      ],
    );
  }

  void _showAudioMenu() {
    final tracks = _player.state.tracks.audio;
    final current = _player.state.track.audio;
    _sheet(
      title: "Audio",
      children: [
        for (final t in tracks)
          _option(
            label: _trackLabel(t.title, t.language, t.id, "Audio"),
            selected: t.id == current.id,
            onTap: () {
              _player.setAudioTrack(t);
              Navigator.pop(context);
            },
          ),
      ],
    );
  }

  void _showSubtitleMenu() {
    final tracks = _player.state.tracks.subtitle;
    final current = _player.state.track.subtitle;
    _sheet(
      title: "Subtitles",
      children: [
        for (final t in tracks)
          _option(
            label: t.id == "no"
                ? "Off"
                : _trackLabel(t.title, t.language, t.id, "Subtitle"),
            selected: t.id == current.id,
            onTap: () {
              _player.setSubtitleTrack(t);
              Navigator.pop(context);
            },
          ),
      ],
    );
  }

  String _trackLabel(String? title, String? lang, String id, String kind) {
    final parts = <String>[
      if (title != null && title.isNotEmpty) title,
      if (lang != null && lang.isNotEmpty && lang != title) lang.toUpperCase(),
    ];
    if (parts.isEmpty) {
      if (id == "auto") return "Default";
      if (id == "no") return "Off";
      return "$kind $id";
    }
    return parts.join(" · ");
  }

  void _sheet({required String title, required List<Widget> children}) {
    showAdaptiveSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: children.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          "None available",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    : ListView(shrinkWrap: true, children: children),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _option({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      title: Text(
        label,
        style: TextStyle(
          color: selected ? _accent : Colors.white,
          fontSize: 15,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check, color: _accent, size: 20)
          : null,
    );
  }
}
