import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:libera/common/utils.dart';
import 'package:libera/services/downloads_service.dart';

const downloadAccent = Color(0xFF0A84FF);

/// Apple-TV style download glyph: an outlined download circle when not yet
/// downloaded, a progress ring (with a stop square) while downloading, and a
/// filled glyph once complete.
class DownloadStateIcon extends StatelessWidget {
  final DownloadEntry? entry;
  final double size;

  const DownloadStateIcon({super.key, required this.entry, this.size = 26});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    if (e == null) {
      return Icon(
        Icons.arrow_circle_down_outlined,
        color: Colors.white.withValues(alpha: 0.55),
        size: size,
      );
    }
    if (e.isCompleted) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: downloadAccent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.arrow_downward_rounded,
          color: Colors.white,
          size: size * 0.62,
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: e.progress.clamp(0.02, 1.0),
              strokeWidth: 2,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation(downloadAccent),
            ),
          ),
          Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

/// A 16:9 thumbnail + title + subtitle row used by the Downloads screens.
/// In edit mode a selection circle is shown on the left.
class DownloadRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? thumbnailPath;
  final IconData fallbackIcon;
  final DownloadEntry? entry; // drives the trailing status glyph
  final bool selectionMode;
  final bool selected;
  final bool showProgressBar;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  const DownloadRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.thumbnailPath,
    this.fallbackIcon = Icons.movie,
    this.entry,
    this.selectionMode = false,
    this.selected = false,
    this.showProgressBar = false,
    this.onTap,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final entry = this.entry;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (selectionMode) ...[
              _SelectionDot(selected: selected),
              const SizedBox(width: 12),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: SizedBox(
                width: 104,
                height: 60,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    thumbnailPath != null
                        ? CachedNetworkImage(
                            imageUrl: "$imageUrl$thumbnailPath",
                            fit: BoxFit.cover,
                            memCacheWidth: 280,
                            placeholder: (_, _) =>
                                Container(color: Colors.grey.shade900),
                            errorWidget: (_, _, _) => Container(
                              color: Colors.grey.shade900,
                              child: Icon(fallbackIcon, color: Colors.white24),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade900,
                            child: Icon(fallbackIcon, color: Colors.white24),
                          ),
                    if (showProgressBar &&
                        entry != null &&
                        !entry.isCompleted)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                          value: entry.progress.clamp(0.02, 1.0),
                          minHeight: 3,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation(
                            downloadAccent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (!selectionMode && entry != null) ...[
              const SizedBox(width: 10),
              DownloadStateIcon(entry: entry, size: 24),
            ],
            if (!selectionMode && onMore != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onMore,
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  Icons.more_horiz,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 24,
                ),
              ),
            ],
            if (!selectionMode && entry == null && onMore == null)
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.35),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectionDot extends StatelessWidget {
  final bool selected;
  const _SelectionDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? downloadAccent : Colors.transparent,
        border: Border.all(
          color: selected ? downloadAccent : Colors.white.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : null,
    );
  }
}
