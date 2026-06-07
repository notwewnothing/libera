// A null-safe, lightweight paginated list used for "similar" / "recommended"
// movies and TV shows. Works for both /movie/{id}/similar and /tv/{id}/similar.

import 'dart:convert';

MediaList mediaListFromJson(String str) => MediaList.fromJson(json.decode(str));

class MediaList {
  final int page;
  final List<MediaItem> results;

  MediaList({required this.page, required this.results});

  factory MediaList.fromJson(Map<String, dynamic> json) => MediaList(
    page: json["page"] ?? 0,
    results: json["results"] != null
        ? List<MediaItem>.from(json["results"].map((x) => MediaItem.fromJson(x)))
        : [],
  );
}

class MediaItem {
  final int id;
  final String? title;
  final String? posterPath;
  final double voteAverage;

  MediaItem({
    required this.id,
    this.title,
    this.posterPath,
    required this.voteAverage,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
    id: json["id"] ?? 0,
    // movies use "title", tv shows use "name"
    title: json["title"] ?? json["name"],
    posterPath: json["poster_path"],
    voteAverage: json["vote_average"]?.toDouble() ?? 0.0,
  );
}
