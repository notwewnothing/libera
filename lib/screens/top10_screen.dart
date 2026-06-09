import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:libera/common/media_widgets.dart';
import 'package:libera/common/navigation.dart';
import 'package:libera/common/utils.dart';

class Top10Screen extends StatelessWidget {
  final String title;
  final List<MediaCardData> items;

  const Top10Screen({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final top = items.take(10).toList();
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
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: top.length,
        separatorBuilder: (_, _) => Divider(
          color: Colors.white.withValues(alpha: 0.08),
          height: 1,
        ),
        itemBuilder: (context, index) {
          final item = top[index];
          return InkWell(
            onTap: () =>
                openDetail(context, id: item.id, isMovie: item.isMovie),
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
                  Text(
                    "${index + 1}",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
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
                          item.typeLabel ?? "",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                          ),
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
    );
  }
}
