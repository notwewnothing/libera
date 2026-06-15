import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libera/common/download_widgets.dart';
import 'package:libera/common/media_widgets.dart';
import 'package:libera/common/utils.dart';
import 'package:libera/model/credits.dart';
import 'package:libera/model/movie_video.dart';
import 'package:libera/model/season_details.dart';
import 'package:libera/model/watch_provider.dart';
import 'package:libera/screens/trailer_player.dart';
import 'package:libera/services/downloads_service.dart';
import 'package:libera/services/download_manager.dart';
import 'package:media_kit/ffi/src/allocation.dart';

class DetailCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double iconSize;

  const DetailCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(icon, color: Colors.white, size: iconSize),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

class ProviderLogos extends StatelessWidget {
  final List<StreamingProvider> providers;
  const ProviderLogos({super.key, required this.providers});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: providers.map((p) {
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: p.logoPath != null
                ? CachedNetworkImage(
                    imageUrl: "https://image.tmdb.org/t/p/w45${p.logoPath}",
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      width: 32,
                      height: 32,
                      color: Colors.grey.shade800,
                    ),
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  )
                : const SizedBox.shrink(),
          ),
        );
      }).toList(),
    );
  }
}

class MetaRow extends StatelessWidget {
  final String? year;
  final double voteAverage;
  final int? runtime;
  final String? extraLabel;
  final List<String> genres;

  const MetaRow({
    super.key,
    required this.year,
    required this.voteAverage,
    this.runtime,
    this.extraLabel,
    required this.genres,
  });

  String _formatRuntime(int r) {
    if (r <= 0) return "";
    final hours = r ~/ 60;
    final minutes = r % 60;
    if (hours > 0) return "${hours}h ${minutes}m";
    return "${minutes}m";
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    );
    final dim = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Colors.white.withValues(alpha: 0.6),
    );
    final runtimeText = runtime != null ? _formatRuntime(runtime!) : "";

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (year != null) Text(year!, style: style),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 18),
            const SizedBox(width: 4),
            Text(
              voteAverage <= 0 ? "Not Rated" : voteAverage.toStringAsFixed(1),
              style: style,
            ),
          ],
        ),
        if (runtimeText.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer, color: Colors.white, size: 18),
              const SizedBox(width: 4),
              Text(runtimeText, style: style),
            ],
          ),
        if (extraLabel != null && extraLabel!.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tv, color: Colors.white, size: 18),
              const SizedBox(width: 4),
              Text(extraLabel!, style: style),
            ],
          ),
        if (genres.isNotEmpty) Text(genres.join(" • "), style: dim),
      ],
    );
  }
}

// whyyyyy
class BlurPill extends StatelessWidget {
  final List<Widget> children;
  const BlurPill({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

class HeroActionButtons extends StatelessWidget {
  final String playLabel;
  final VoidCallback? onPlay;
  final VoidCallback? onPlayLongPress;
  final VoidCallback? onMyList;
  final bool inMyList;
  final VoidCallback? onWatched;
  final bool inWatched;

  const HeroActionButtons({
    super.key,
    this.playLabel = "Play",
    this.onPlay,
    this.onPlayLongPress,
    this.onMyList,
    this.inMyList = false,
    this.onWatched,
    this.inWatched = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Pressable(
          onTap: onPlay,
          onLongPress: onPlayLongPress,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 28),

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.translate(
                  offset: const Offset(-3, 0),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  playLabel,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Pressable(
          onTap: onMyList,
          pressedScale: 0.9,
          child: Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade800.withValues(alpha: 0.75),
            ),
            child: _AnimatedToggleIcon(
              icon: inMyList ? Icons.check : Icons.add,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
        if (onWatched != null) ...[
          const SizedBox(width: 14),
          Pressable(
            onTap: onWatched,
            pressedScale: 0.9,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: inWatched
                    ? Colors.white
                    : Colors.grey.shade800.withValues(alpha: 0.75),
              ),
              child: _AnimatedToggleIcon(
                icon: inWatched ? Icons.visibility : Icons.visibility_outlined,
                color: inWatched ? Colors.black : Colors.white,
                size: 26,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AnimatedToggleIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _AnimatedToggleIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: Icon(icon, key: ValueKey(icon), color: color, size: size),
    );
  }
}

class ExpandableOverview extends StatefulWidget {
  final String text;
  const ExpandableOverview({super.key, required this.text});

  @override
  State<ExpandableOverview> createState() => _ExpandableOverviewState();
}

class _ExpandableOverviewState extends State<ExpandableOverview> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final showMore = !_expanded && widget.text.length > 140;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Text(
            widget.text,
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? null : TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ),
        if (showMore) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _expanded = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade800.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                "MORE",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class TrailersSection extends StatelessWidget {
  final List<MovieVideoResult> videos;
  const TrailersSection({super.key, required this.videos});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: "Trailers"),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: videos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final video = videos[index];
              return Pressable(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrailerPlayerScreen(
                      title: video.name,
                      youtubeKey: video.key,
                    ),
                  ),
                ),
                child: Container(
                  width: 300,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl:
                            "https://img.youtube.com/vi/${video.key}/hqdefault.jpg",
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: Colors.grey.shade900),
                        errorWidget: (_, _, _) => Container(
                          color: Colors.grey.shade900,
                          child: const Icon(
                            Icons.play_circle_outline,
                            color: Colors.white24,
                            size: 40,
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.center,
                            colors: [
                              Colors.black.withValues(alpha: 0.75),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              video.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(
                                  Icons.play_arrow,
                                  color: Colors.white70,
                                  size: 15,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  video.type,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
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
            },
          ),
        ),
      ],
    );
  }
}

class CastSection extends StatelessWidget {
  final List<CastMember> cast;
  const CastSection({super.key, required this.cast});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: "Cast"),
        SizedBox(
          height: 170,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemCount: cast.length,
            itemBuilder: (context, index) {
              final member = cast[index];
              return Container(
                width: 90,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: member.profilePath != null
                          ? CachedNetworkImage(
                              imageUrl:
                                  "https://image.tmdb.org/t/p/w185${member.profilePath}",
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey.shade800,
                              ),
                              errorWidget: (_, _, _) => _avatarFallback(),
                            )
                          : _avatarFallback(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (member.character != null &&
                        member.character!.isNotEmpty)
                      Text(
                        member.character!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _avatarFallback() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey.shade800,
      child: const Icon(Icons.person, color: Colors.white30, size: 40),
    );
  }
}

class SeasonEpisodesSection extends StatelessWidget {
  final int seasonCount;
  final int selectedSeason;
  final List<Episode> episodes;
  final bool loading;
  final ValueChanged<int> onSeasonChanged;
  final ValueChanged<Episode> onPlayEpisode;
  final bool Function(Episode)? isEpisodeWatched;
  final ValueChanged<Episode>? onToggleWatched;
  final DownloadEntry? Function(Episode)? downloadStateOf;
  final ValueChanged<Episode>? onDownloadEpisode;
  final ValueChanged<Episode>? onRemoveDownload;
  final ValueChanged<Episode>? onTorrentEpisode;
  final VoidCallback? onOpenDownloadMenu;

  const SeasonEpisodesSection({
    super.key,
    required this.seasonCount,
    required this.selectedSeason,
    required this.episodes,
    required this.loading,
    required this.onSeasonChanged,
    required this.onPlayEpisode,
    this.isEpisodeWatched,
    this.onToggleWatched,
    this.downloadStateOf,
    this.onDownloadEpisode,
    this.onRemoveDownload,
    this.onTorrentEpisode,
    this.onOpenDownloadMenu,
  });

  String _runtime(int? r) => (r == null || r <= 0) ? "" : "${r}m";

  PopupMenuItem<String> _menuRow(
    String value,
    String label,
    IconData icon, {
    Color color = Colors.white,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 46,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          Icon(icon, color: color, size: 20),
        ],
      ),
    );
  }

  void _openEpisodeMenu(BuildContext context, Episode e) async {
    final entry = downloadStateOf?.call(e);
    final watched = isEpisodeWatched?.call(e) ?? false;

    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final position = (box != null && overlay != null)
        ? RelativeRect.fromRect(
            Rect.fromPoints(
              box.localToGlobal(Offset.zero, ancestor: overlay),
              box.localToGlobal(
                box.size.bottomRight(Offset.zero),
                ancestor: overlay,
              ),
            ),
            Offset.zero & overlay.size,
          )
        : const RelativeRect.fromLTRB(100, 300, 16, 0);

    final downloadLabel = entry == null
        ? "Download"
        : (entry.isCompleted ? "Remove Download" : "Cancel Download");
    final downloadIcon = entry == null
        ? Icons.arrow_circle_down_outlined
        : Icons.delete_outline;

    final result = await showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF2C2C2E),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: [
        _menuRow(
          "download",
          downloadLabel,
          downloadIcon,
          color: entry != null && entry.isCompleted
              ? Colors.redAccent
              : Colors.white,
        ),
        _menuRow("play", "Go to Episode", Icons.info_outline),
        _menuRow(
          "watched",
          watched ? "Mark as Unwatched" : "Mark as Watched",
          watched ? Icons.visibility_off_outlined : Icons.check_circle_outline,
        ),
      ],
    );
    if (!context.mounted) return;
    switch (result) {
      case "download":
        if (entry == null) {
          onDownloadEpisode?.call(e);
        } else {
          onRemoveDownload?.call(e);
        }
      case "play":
        onPlayEpisode(e);
      case "watched":
        onToggleWatched?.call(e);
      case "share_ep":
      case "share_show":
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sharing isn't available yet"),
            backgroundColor: Color(0xFF1A1A1A),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
    }
  }

  void _pickSeason(BuildContext context) {
    if (seasonCount <= 1) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: seasonCount,
            itemBuilder: (context, index) {
              final season = index + 1;
              final selected = season == selectedSeason;
              return ListTile(
                title: Text(
                  "Season $season",
                  style: TextStyle(
                    color: selected ? const Color(0xFFE50914) : Colors.white,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: selected
                    ? const Icon(Icons.check, color: Color(0xFFE50914))
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  if (!selected) onSeasonChanged(season);
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (seasonCount <= 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 24, 15, 12),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _pickSeason(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Season $selectedSeason",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                if (seasonCount > 1)
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 26,
                  ),
                // newly added downlaod button
                if (onOpenDownloadMenu != null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onOpenDownloadMenu,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 250,
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white24),
                )
              : episodes.isEmpty
              ? Center(
                  child: Text(
                    "No episodes found",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: episodes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final e = episodes[index];
                    final watched = isEpisodeWatched?.call(e) ?? false;
                    return Pressable(
                      onTap: () => onPlayEpisode(e),
                      child: SizedBox(
                        width: 240,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    e.stillPath != null
                                        ? CachedNetworkImage(
                                            imageUrl: "$imageUrl${e.stillPath}",
                                            fit: BoxFit.cover,
                                            memCacheWidth: 480,
                                            placeholder: (_, _) => Container(
                                              color: Colors.grey.shade900,
                                            ),
                                            errorWidget: (_, _, _) => Container(
                                              color: Colors.grey.shade900,
                                            ),
                                          )
                                        : Container(
                                            color: Colors.grey.shade900,
                                            child: const Icon(
                                              Icons.tv,
                                              color: Colors.white24,
                                            ),
                                          ),
                                    Center(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.45,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                    if (isEpisodeWatched != null &&
                                        onToggleWatched != null)
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: GestureDetector(
                                          onTap: () => onToggleWatched!(e),
                                          child: Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: watched
                                                  ? Colors.white
                                                  : Colors.black.withValues(
                                                      alpha: 0.55,
                                                    ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.check,
                                              color: watched
                                                  ? Colors.black
                                                  : Colors.white70,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  _runtime(e.runtime).isNotEmpty
                                      ? "EPISODE ${e.episodeNumber}  ·  ${_runtime(e.runtime)}"
                                      : "EPISODE ${e.episodeNumber}",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const Spacer(),
                                if (onDownloadEpisode != null) ...[
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      final entry = downloadStateOf?.call(e);
                                      if (entry == null) {
                                        onDownloadEpisode!(e);
                                      }
                                    },
                                    child: DownloadStateIcon(
                                      entry: downloadStateOf?.call(e),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (onTorrentEpisode != null) ...[
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => onTorrentEpisode!(e),
                                      child: Icon(
                                        Icons.bolt_rounded,
                                        color: Colors.white.withValues(
                                          alpha: 0.55,
                                        ),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Builder(
                                    builder: (btnContext) => GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () =>
                                          _openEpisodeMenu(btnContext, e),
                                      child: Icon(
                                        Icons.more_horiz,
                                        color: Colors.white.withValues(
                                          alpha: 0.55,
                                        ),
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              e.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (e.overview.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                e.overview,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// Bottom-sheet submenu for downloading a whole season or individual episodes
// from any season. Opened from the season header / hero download buttons.
Future<void> showDownloadSheet(
  BuildContext context, {
  required MediaCardData show,
  required int seasonCount,
  required int currentSeason,
  required List<Episode> currentEpisodes,
  required Future<List<Episode>> Function(int season) fetchSeasonEpisodes,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1C1C1E),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _DownloadSheet(
      show: show,
      seasonCount: seasonCount,
      currentSeason: currentSeason,
      currentEpisodes: currentEpisodes,
      fetchSeasonEpisodes: fetchSeasonEpisodes,
    ),
  );
}

class _DownloadSheet extends StatefulWidget {
  final MediaCardData show;
  final int seasonCount;
  final int currentSeason;
  final List<Episode> currentEpisodes;
  final Future<List<Episode>> Function(int season) fetchSeasonEpisodes;

  const _DownloadSheet({
    required this.show,
    required this.seasonCount,
    required this.currentSeason,
    required this.currentEpisodes,
    required this.fetchSeasonEpisodes,
  });

  @override
  State<_DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends State<_DownloadSheet> {
  final Map<int, List<Episode>> _cache = {};
  final Set<int> _expanded = {};
  final Set<int> _loading = {};

  @override
  void initState() {
    super.initState();
    if (widget.currentEpisodes.isNotEmpty) {
      _cache[widget.currentSeason] = widget.currentEpisodes;
    }
    _expanded.add(widget.currentSeason);
    if (!_cache.containsKey(widget.currentSeason)) {
      _ensure(widget.currentSeason);
    }
  }

  String? _rt(Episode e) =>
      (e.runtime == null || e.runtime! <= 0) ? null : "${e.runtime}m";

  DownloadEntry? _entry(int season, int episode) => DownloadsService.instance
      .entry(DownloadsService.episodeKey(widget.show.id, season, episode));

  Future<List<Episode>> _ensure(int season) async {
    if (_cache.containsKey(season)) return _cache[season]!;
    if (_loading.contains(season)) return const [];
    setState(() => _loading.add(season));
    List<Episode> eps = const [];
    try {
      eps = await widget.fetchSeasonEpisodes(season);
    } catch (_) {}
    if (!mounted) return eps;
    setState(() {
      _cache[season] = eps;
      _loading.remove(season);
    });
    return eps;
  }

  void _toggleExpand(int season) {
    setState(() {
      if (!_expanded.add(season)) _expanded.remove(season);
    });
    if (_expanded.contains(season)) _ensure(season);
  }

  void _downloadEpisode(Episode e, int season) {
    DownloadManager.instance.downloadEpisode(
      context,
      widget.show,
      season: season,
      episode: e.episodeNumber,
      name: e.name,
      stillPath: e.stillPath,
      runtimeLabel: _rt(e),
    );
  }

  Future<void> _downloadSeason(int season) async {
    final eps = await _ensure(season);
    final meta = {
      for (final e in eps)
        e.episodeNumber: EpisodeMeta(
          name: e.name,
          stillPath: e.stillPath,
          runtimeLabel: _rt(e),
        ),
    };
    if (!mounted) return;
    await DownloadManager.instance.downloadSeason(
      context,
      widget.show,
      season,
      meta: meta,
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.7;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
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
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  const Text(
                    "Download",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.show.title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListenableBuilder(
                listenable: DownloadsService.instance,
                builder: (context, _) {
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: widget.seasonCount,
                    itemBuilder: (context, index) => _seasonTile(index + 1),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seasonTile(int season) {
    final expanded = _expanded.contains(season);
    final cached = _cache[season];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _toggleExpand(season),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Season $season",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _seasonDownloadControl(season, cached),
              ],
            ),
          ),
        ),
        if (expanded) _episodesList(season, cached),
        Divider(
          height: 1,
          color: Colors.white.withValues(alpha: 0.07),
          indent: 16,
          endIndent: 16,
        ),
      ],
    );
  }

  Widget _seasonDownloadControl(int season, List<Episode>? cached) {
    if (_loading.contains(season)) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(downloadAccent),
        ),
      );
    }
    bool allDownloaded = false;
    if (cached != null && cached.isNotEmpty) {
      allDownloaded = cached.every(
        (e) => _entry(season, e.episodeNumber)?.isCompleted ?? false,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: allDownloaded ? null : () => _downloadSeason(season),
      child: allDownloaded
          ? Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: downloadAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Season",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_circle_down_outlined,
                  color: downloadAccent,
                  size: 26,
                ),
              ],
            ),
    );
  }

  Widget _episodesList(int season, List<Episode>? cached) {
    if (_loading.contains(season) && cached == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white24,
            ),
          ),
        ),
      );
    }
    if (cached == null) return const SizedBox.shrink();
    if (cached.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(46, 0, 16, 14),
        child: Text(
          "No episodes found",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        ),
      );
    }
    return Column(
      children: [
        for (final e in cached) _episodeRow(season, e),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _episodeRow(int season, Episode e) {
    final entry = _entry(season, e.episodeNumber);
    return InkWell(
      onTap: () {
        if (entry == null) {
          _downloadEpisode(e, season);
        } else if (entry.isCompleted) {
          DownloadsService.instance.remove(entry.key);
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(46, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.runtime != null && e.runtime! > 0
                        ? "Episode ${e.episodeNumber}  ·  ${e.runtime}m"
                        : "Episode ${e.episodeNumber}",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    e.name.isEmpty ? "Episode ${e.episodeNumber}" : e.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            DownloadStateIcon(entry: entry, size: 24),
          ],
        ),
      ),
    );
  }
}
