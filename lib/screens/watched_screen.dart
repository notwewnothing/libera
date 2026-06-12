import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:libera/common/media_widgets.dart';
import 'package:libera/common/navigation.dart';
import 'package:libera/common/utils.dart';
import 'package:libera/services/watched_service.dart';

class WatchedScreen extends StatelessWidget {
  const WatchedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade800.withValues(alpha: 0.6),
              ),
              child: const Icon(Icons.chevron_left, color: Colors.white),
            ),
          ),
        ),
        title: const Text(
          "Watched",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: WatchedService.instance,
        builder: (context, _) {
          final service = WatchedService.instance;
          if (service.titleCount == 0) return _empty();
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final movie in service.movies)
                _row(
                  context,
                  movie,
                  subtitle: "Movie",
                  onRemove: () => service.removeMovie(movie.id),
                ),
              for (final show in service.shows)
                _row(
                  context,
                  show.card,
                  subtitle:
                      "${show.episodes.length} "
                      "${show.episodes.length == 1 ? "episode" : "episodes"} "
                      "watched",
                  onRemove: () => service.removeShow(show.card.id),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(
    BuildContext context,
    MediaCardData item, {
    required String subtitle,
    required VoidCallback onRemove,
  }) {
    return InkWell(
      onTap: () => openDetail(context, id: item.id, isMovie: item.isMovie),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 80,
                child: item.posterPath != null
                    ? CachedNetworkImage(
                        imageUrl: "$imageUrl${item.posterPath}",
                        fit: BoxFit.cover,
                        memCacheWidth: 168,
                        placeholder: (_, _) =>
                            Container(color: Colors.grey.shade900),
                        errorWidget: (_, _, _) =>
                            Container(color: Colors.grey.shade900),
                      )
                    : Container(color: Colors.grey.shade900),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                color: Colors.white.withValues(alpha: 0.55),
                size: 22,
              ),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.eye, color: Colors.white24, size: 56),
          const SizedBox(height: 14),
          Text(
            "Nothing watched yet",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Mark movies or episodes as watched to track them here.",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
