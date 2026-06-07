import 'dart:convert';

TrendingAll trendingAllFromJson(String str) =>
    TrendingAll.fromJson(json.decode(str));

class TrendingAll {
  final int page;
  final List<TrendingItem> results;
  final int totalPages;
  final int totalResults;

  TrendingAll({
    required this.page,
    required this.results,
    required this.totalPages,
    required this.totalResults,
  });

  factory TrendingAll.fromJson(Map<String, dynamic> json) => TrendingAll(
    page: json["page"] ?? 0,
    results: json["results"] != null
        ? List<TrendingItem>.from(
            json["results"].map((x) => TrendingItem.fromJson(x)),
          )
        : [],
    totalPages: json["total_pages"] ?? 0,
    totalResults: json["total_results"] ?? 0,
  );
}

class TrendingItem {
  final int id;
  // "movie" or "tv"
  final String mediaType;
  // Movies have "title", TV shows have "name"
  final String? title;
  final String? name;
  final String? posterPath;
  final String? backdropPath;
  final String overview;
  final String originalLanguage;
  final List<int> genreIds;
  final double popularity;
  final double voteAverage;
  final int voteCount;
  final bool adult;
  final DateTime? releaseDate;
  final DateTime? firstAirDate;

  TrendingItem({
    required this.id,
    required this.mediaType,
    this.title,
    this.name,
    this.posterPath,
    this.backdropPath,
    required this.overview,
    required this.originalLanguage,
    required this.genreIds,
    required this.popularity,
    required this.voteAverage,
    required this.voteCount,
    required this.adult,
    this.releaseDate,
    this.firstAirDate,
  });

  bool get isMovie => mediaType == 'movie';

  /// The display-ready title regardless of whether it's a movie or TV show.
  String get displayTitle => title ?? name ?? '';

  factory TrendingItem.fromJson(Map<String, dynamic> json) => TrendingItem(
    id: json["id"] ?? 0,
    mediaType: json["media_type"] ?? "",
    title: json["title"],
    name: json["name"],
    posterPath: json["poster_path"],
    backdropPath: json["backdrop_path"],
    overview: json["overview"] ?? "",
    originalLanguage: json["original_language"] ?? "",
    genreIds: json["genre_ids"] != null
        ? List<int>.from(json["genre_ids"].map((x) => x))
        : [],
    popularity: json["popularity"]?.toDouble() ?? 0.0,
    voteAverage: json["vote_average"]?.toDouble() ?? 0.0,
    voteCount: json["vote_count"] ?? 0,
    adult: json["adult"] ?? false,
    releaseDate: json["release_date"] != null && json["release_date"] != ""
        ? DateTime.tryParse(json["release_date"])
        : null,
    firstAirDate:
        json["first_air_date"] != null && json["first_air_date"] != ""
            ? DateTime.tryParse(json["first_air_date"])
            : null,
  );
}
