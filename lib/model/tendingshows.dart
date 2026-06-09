// To parse this JSON data, do
//
//     final trendingShows = trendingShowsFromJson(jsonString);

import 'dart:convert';

TrendingShows trendingShowsFromJson(String str) =>
    TrendingShows.fromJson(json.decode(str));

String trendingShowsToJson(TrendingShows data) => json.encode(data.toJson());

class TrendingShows {
  int page;
  List<Result> results;
  int totalPages;
  int totalResults;

  TrendingShows({
    required this.page,
    required this.results,
    required this.totalPages,
    required this.totalResults,
  });

  factory TrendingShows.fromJson(Map<String, dynamic> json) => TrendingShows(
    page: json["page"],
    results: List<Result>.from(json["results"].map((x) => Result.fromJson(x))),
    totalPages: json["total_pages"],
    totalResults: json["total_results"],
  );

  Map<String, dynamic> toJson() => {
    "page": page,
    "results": List<dynamic>.from(results.map((x) => x.toJson())),
    "total_pages": totalPages,
    "total_results": totalResults,
  };
}

class Result {
  bool adult;
  String backdropPath;
  int id;
  String name;
  String originalName;
  String overview;
  String posterPath;
  String mediaType;
  String originalLanguage;
  List<int> genreIds;
  double popularity;
  DateTime? firstAirDate;
  bool softcore;
  double voteAverage;
  int voteCount;
  List<String> originCountry;

  Result({
    required this.adult,
    required this.backdropPath,
    required this.id,
    required this.name,
    required this.originalName,
    required this.overview,
    required this.posterPath,
    required this.mediaType,
    required this.originalLanguage,
    required this.genreIds,
    required this.popularity,
    this.firstAirDate,
    required this.softcore,
    required this.voteAverage,
    required this.voteCount,
    required this.originCountry,
  });

  factory Result.fromJson(Map<String, dynamic> json) => Result(
    adult: json["adult"],
    backdropPath: json["backdrop_path"],
    id: json["id"],
    name: json["name"],
    originalName: json["original_name"],
    overview: json["overview"],
    posterPath: json["poster_path"],
    mediaType: json["media_type"] ?? "",
    originalLanguage: json["original_language"] ?? "",
    genreIds: List<int>.from(json["genre_ids"].map((x) => x)),
    popularity: json["popularity"]?.toDouble(),
    firstAirDate: json["first_air_date"] != null && json["first_air_date"].toString().isNotEmpty
        ? DateTime.tryParse(json["first_air_date"])
        : null,
    softcore: json["softcore"],
    voteAverage: json["vote_average"]?.toDouble(),
    voteCount: json["vote_count"],
    originCountry: json["origin_country"] == null
        ? []
        : List<String>.from(json["origin_country"].map((x) => x.toString())),
  );

  Map<String, dynamic> toJson() => {
    "adult": adult,
    "backdrop_path": backdropPath,
    "id": id,
    "name": name,
    "original_name": originalName,
    "overview": overview,
    "poster_path": posterPath,
    "media_type": mediaType,
    "original_language": originalLanguage,
    "genre_ids": List<dynamic>.from(genreIds.map((x) => x)),
    "popularity": popularity,
    "first_air_date": firstAirDate == null ? null
        : "${firstAirDate!.year.toString().padLeft(4, '0')}-${firstAirDate!.month.toString().padLeft(2, '0')}-${firstAirDate!.day.toString().padLeft(2, '0')}",
    "softcore": softcore,
    "vote_average": voteAverage,
    "vote_count": voteCount,
    "origin_country": List<dynamic>.from(originCountry.map((x) => x)),
  };
}


