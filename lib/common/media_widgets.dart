import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
  // Tall cards crop landscape backdrops too hard; let them use the poster.
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
    return GestureDetector(
      onTap: onTap,
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
    placeholder: (_, _) => Container(color: Colors.grey.shade900),
    errorWidget: (_, _, _) => Container(
      color: Colors.grey.shade900,
      child: Icon(fallbackIcon, color: Colors.white24, size: 40),
    ),
  );
}
