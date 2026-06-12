import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:libera/common/media_widgets.dart';
import 'package:libera/common/utils.dart';
import 'package:libera/model/credits.dart';
import 'package:libera/model/movie_video.dart';
import 'package:libera/model/season_details.dart';
import 'package:libera/model/watch_provider.dart';
import 'package:libera/screens/trailer_player.dart';

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
  final VoidCallback? onMyList;
  final bool inMyList;
  final VoidCallback? onWatched;
  final bool inWatched;

  const HeroActionButtons({
    super.key,
    this.playLabel = "Play",
    this.onPlay,
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
  });

  String _runtime(int? r) => (r == null || r <= 0) ? "" : "${r}m";

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
                                  "EPISODE ${e.episodeNumber}",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (_runtime(e.runtime).isNotEmpty) ...[
                                  const Spacer(),
                                  Text(
                                    _runtime(e.runtime),
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
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
