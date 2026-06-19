import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libera/common/provider_badge.dart';
import 'package:libera/common/utils.dart';

class MediaCardData {
  final int id;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String? genreLabel;
  final String? typeLabel;
  final bool isMovie;
  final String overview;

  const MediaCardData({
    required this.id,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.genreLabel,
    this.typeLabel,
    required this.isMovie,
    this.overview = "",
  });

  factory MediaCardData.fromJson(Map<String, dynamic> json) => MediaCardData(
    id: json["id"],
    title: json["title"] ?? "",
    posterPath: json["posterPath"],
    backdropPath: json["backdropPath"],
    genreLabel: json["genreLabel"],
    typeLabel: json["typeLabel"],
    isMovie: json["isMovie"] ?? true,
    overview: json["overview"] ?? "",
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "title": title,
    "posterPath": posterPath,
    "backdropPath": backdropPath,
    "genreLabel": genreLabel,
    "typeLabel": typeLabel,
    "isMovie": isMovie,
    "overview": overview,
  };
}

class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;

  /// Whether pointer hover lifts the child slightly (desktop affordance).
  final bool hoverLift;

  /// Shape of the keyboard-focus ring. Pass a large radius for circular buttons.
  final BorderRadius focusBorderRadius;

  /// Auto-focus this element when the surrounding scope first builds (e.g. the
  /// primary action on a screen) so keyboard users land somewhere sensible.
  final bool autofocus;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.hoverLift = true,
    this.focusBorderRadius = const BorderRadius.all(Radius.circular(14)),
    this.autofocus = false,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (_pressed != value) {
      if (value) HapticFeedback.lightImpact();
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final scale = _pressed
        ? widget.pressedScale
        : (_hovered && widget.hoverLift && _enabled ? 1.03 : 1.0);

    Widget child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onLongPress: widget.onLongPress,
      onLongPressEnd:
          widget.onLongPress != null ? (_) => _setPressed(false) : null,
      child: AnimatedScale(
        scale: scale,
        duration: Duration(milliseconds: _pressed ? 90 : 220),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 120),
          // Focus ring is painted over the child (no layout shift).
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            foregroundDecoration: BoxDecoration(
              borderRadius: widget.focusBorderRadius,
              border: Border.all(
                color: _focused ? accent : Colors.transparent,
                width: 2,
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );

    return FocusableActionDetector(
      enabled: _enabled,
      autofocus: widget.autofocus,
      mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowHoverHighlight: (v) {
        if (_hovered != v) setState(() => _hovered = v);
      },
      onShowFocusHighlight: (v) {
        if (_focused != v) setState(() => _focused = v);
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: child,
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  const SectionHeader({super.key, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 14),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Colors.white, size: 26),
            ],
          ],
        ),
      ),
    );
  }
}

class PosterCard extends StatelessWidget {
  final MediaCardData item;
  final double width;
  final VoidCallback onTap;
  final bool showBadge;

  const PosterCard({
    super.key,
    required this.item,
    required this.onTap,
    this.width = 120,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: poster(item.posterPath, fallbackIcon: Icons.movie),
                ),
              ),
              if (showBadge)
                Positioned(
                  top: 6,
                  right: 6,
                  child: ProviderBadge(
                    id: item.id,
                    isMovie: item.isMovie,
                    size: width * 0.17,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeaturedLandscapeCard extends StatelessWidget {
  final MediaCardData item;
  final VoidCallback onTap;
  final double? width;
  final double height;
  final bool preferPoster;

  const FeaturedLandscapeCard({
    super.key,
    required this.item,
    required this.onTap,
    this.width,
    this.height = 210,
    this.preferPoster = false,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.975,
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            poster(
              preferPoster
                  ? item.posterPath ?? item.backdropPath
                  : item.backdropPath ?? item.posterPath,
              fallbackIcon: Icons.movie,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ProviderBadge(id: item.id, isMovie: item.isMovie, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          [
                            item.typeLabel,
                            item.genreLabel,
                          ].where((e) => e != null && e.isNotEmpty).join("  ·  "),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget poster(String? path, {required IconData fallbackIcon}) {
  if (path == null || path.isEmpty) {
    return Container(
      color: Colors.grey.shade900,
      child: Icon(fallbackIcon, color: Colors.white24, size: 40),
    );
  }
  return CachedNetworkImage(
    imageUrl: "$imageUrl$path",
    fit: BoxFit.cover,
    memCacheWidth: 360,
    fadeInDuration: const Duration(milliseconds: 220),
    fadeInCurve: Curves.easeOut,
    fadeOutDuration: Duration.zero,
    placeholder: (_, _) => Container(color: Colors.grey.shade900),
    errorWidget: (_, _, _) => Container(
      color: Colors.grey.shade900,
      child: Icon(fallbackIcon, color: Colors.white24, size: 40),
    ),
  );
}
