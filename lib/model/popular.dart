// To parse this JSON data, do
//
//     final popularMovies = popularMoviesFromJson(jsonString);

import 'dart:convert';

PopularMovies popularMoviesFromJson(String str) =>
    PopularMovies.fromJson(json.decode(str));

String popularMoviesToJson(PopularMovies data) => json.encode(data.toJson());

class PopularMovies {
  int page;
  List<Result> results;
  int totalPages;
  int totalResults;

  PopularMovies({
    required this.page,
    required this.results,
    required this.totalPages,
    required this.totalResults,
  });

  factory PopularMovies.fromJson(Map<String, dynamic> json) => PopularMovies(
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
  String? backdropPath;
  int id;
  String title;
  String originalTitle;
  String overview;
  String? posterPath;
  String mediaType;
  String originalLanguage;
  List<int> genreIds;
  double popularity;
  DateTime? releaseDate;
  bool video;
  double voteAverage;
  int voteCount;

  Result({
    required this.adult,
    this.backdropPath,
    required this.id,
    required this.title,
    required this.originalTitle,
    required this.overview,
    this.posterPath,
    required this.mediaType,
    required this.originalLanguage,
    required this.genreIds,
    required this.popularity,
    this.releaseDate,
    required this.video,
    required this.voteAverage,
    required this.voteCount,
  });

  factory Result.fromJson(Map<String, dynamic> json) => Result(
    adult: json["adult"] ?? false,
    backdropPath: json["backdrop_path"],
    id: json["id"] ?? 0,
    title: json["title"] ?? "",
    originalTitle: json["original_title"] ?? "",
    overview: json["overview"] ?? "",
    posterPath: json["poster_path"],
    mediaType: json["media_type"] ?? "",
    originalLanguage: json["original_language"] ?? "",
    genreIds: json["genre_ids"] != null
        ? List<int>.from(json["genre_ids"].map((x) => x))
        : [],
    popularity: json["popularity"]?.toDouble() ?? 0.0,
    releaseDate: json["release_date"] != null && json["release_date"] != ""
        ? DateTime.tryParse(json["release_date"])
        : null,
    video: json["video"] ?? false,
    voteAverage: json["vote_average"]?.toDouble() ?? 0.0,
    voteCount: json["vote_count"] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    "adult": adult,
    "backdrop_path": backdropPath,
    "id": id,
    "title": title,
    "original_title": originalTitle,
    "overview": overview,
    "poster_path": posterPath,
    "media_type": mediaType,
    "original_language": originalLanguage,
    "genre_ids": List<dynamic>.from(genreIds.map((x) => x)),
    "popularity": popularity,
    "release_date": releaseDate != null
        ? "${releaseDate!.year.toString().padLeft(4, '0')}-${releaseDate!.month.toString().padLeft(2, '0')}-${releaseDate!.day.toString().padLeft(2, '0')}"
        : null,
    "video": video,
    "vote_average": voteAverage,
    "vote_count": voteCount,
  };
}


