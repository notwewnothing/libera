import 'dart:async';

import 'package:flutter/material.dart';
import 'package:libera/common/media_widgets.dart';
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
  final String filePath;
  final String title;
  final MediaCardData? card;
  final int? season;
  final int? episode;

  const OfflinePlayerScreen({
    super.key,
    required this.filePath,
    required this.title,
    this.card,
    this.season,
    this.episode,
  });

  @override
  State<OfflinePlayerScreen> createState() => _OfflinePlayerScreenState();
}

class _OfflinePlayerScreenState extends State<OfflinePlayerScreen> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);
  final List<StreamSubscription> _subs = [];

  double _position = 0;
  double _duration = 0;
  double _startAt = 0;
  bool _seeked = false;
  bool _ended = false;
  DateTime _lastSave = DateTime.now();

  MediaCardData? get _card => widget.card;

  @override
  void initState() {
    super.initState();
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

    _subs.add(_player.stream.duration.listen((d) {
      _duration = d.inMilliseconds / 1000.0;
      // Seek to the resume point once the media is loaded.
      if (!_seeked && _startAt > 1 && d > Duration.zero) {
        _seeked = true;
        _player.seek(Duration(milliseconds: (_startAt * 1000).round()));
      }
    }));
    _subs.add(_player.stream.position.listen((p) {
      _position = p.inMilliseconds / 1000.0;
      if (DateTime.now().difference(_lastSave).inSeconds >= 10) {
        _saveProgress();
      }
    }));
    _subs.add(_player.stream.completed.listen((done) {
      if (done) _onEnded();
    }));

    _player.open(Media(Uri.file(widget.filePath).toString()));
  }

  double _resumeFrom() {
    final card = _card;
    if (card == null) return 0;
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

  Future<void> _skip(int seconds) async {
    final target = _player.state.position + Duration(seconds: seconds);
    final dur = _player.state.duration;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (dur > Duration.zero && target > dur ? dur : target);
    await _player.seek(clamped);
  }

  @override
  void dispose() {
    if (!_ended) _saveProgress();
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _controlsTheme(context, fullscreen: false);
    final fsTheme = _controlsTheme(context, fullscreen: true);

    return Scaffold(
      backgroundColor: Colors.black,
      body: MaterialVideoControlsTheme(
        normal: theme,
        fullscreen: fsTheme,
        child: Video(
          controller: _controller,
          controls: MaterialVideoControls,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  MaterialVideoControlsThemeData _controlsTheme(
    BuildContext context, {
    required bool fullscreen,
  }) {
    return MaterialVideoControlsThemeData(
      seekBarThumbColor: _accent,
      seekBarPositionColor: _accent,
      seekBarBufferColor: Colors.white24,
      seekOnDoubleTap: true,
      volumeGesture: true,
      brightnessGesture: true,
      buttonBarButtonColor: Colors.white,
      topButtonBar: [
        MaterialCustomButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (fullscreen) {
              exitFullscreen(context);
            } else {
              Navigator.maybePop(context);
            }
          },
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
          icon: const Icon(Icons.replay_10, color: Colors.white),
          iconSize: 32,
          onPressed: () => _skip(-10),
        ),
        const SizedBox(width: 8),
        const MaterialPlayOrPauseButton(iconSize: 52),
        const SizedBox(width: 8),
        MaterialCustomButton(
          icon: const Icon(Icons.forward_10, color: Colors.white),
          iconSize: 32,
          onPressed: () => _skip(10),
        ),
        const Spacer(),
      ],
      bottomButtonBar: const [
        MaterialPositionIndicator(),
        Spacer(),
        MaterialFullscreenButton(),
      ],
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
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
