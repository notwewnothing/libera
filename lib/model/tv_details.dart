// To parse this JSON data, do
//
//     final tvDetails = tvDetailsFromJson(jsonString);

import 'dart:convert';

TvDetails tvDetailsFromJson(String str) =>
    TvDetails.fromJson(json.decode(str));

class TvDetails {
  final bool adult;
  final String? backdropPath;
  final List<TvGenre> genres;
  final int id;
  final String name;
  final String originalName;
  final String overview;
  final double popularity;
  final String? posterPath;
  final DateTime? firstAirDate;
  final DateTime? lastAirDate;
  final int numberOfSeasons;
  final int numberOfEpisodes;
  final List<int> episodeRunTime;
  final String status;
  final String tagline;
  final double voteAverage;
  final int voteCount;

  TvDetails({
    required this.adult,
    this.backdropPath,
    required this.genres,
    required this.id,
    required this.name,
    required this.originalName,
    required this.overview,
    required this.popularity,
    this.posterPath,
    this.firstAirDate,
    this.lastAirDate,
    required this.numberOfSeasons,
    required this.numberOfEpisodes,
    required this.episodeRunTime,
    required this.status,
    required this.tagline,
    required this.voteAverage,
    required this.voteCount,
  });

  factory TvDetails.fromJson(Map<String, dynamic> json) => TvDetails(
    adult: json["adult"] ?? false,
    backdropPath: json["backdrop_path"],
    genres: json["genres"] != null
        ? List<TvGenre>.from(json["genres"].map((x) => TvGenre.fromJson(x)))
        : [],
    id: json["id"] ?? 0,
    name: json["name"] ?? "",
    originalName: json["original_name"] ?? "",
    overview: json["overview"] ?? "",
    popularity: json["popularity"]?.toDouble() ?? 0.0,
    posterPath: json["poster_path"],
    firstAirDate: json["first_air_date"] != null && json["first_air_date"] != ""
        ? DateTime.tryParse(json["first_air_date"])
        : null,
    lastAirDate: json["last_air_date"] != null && json["last_air_date"] != ""
        ? DateTime.tryParse(json["last_air_date"])
        : null,
    numberOfSeasons: json["number_of_seasons"] ?? 0,
    numberOfEpisodes: json["number_of_episodes"] ?? 0,
    episodeRunTime: json["episode_run_time"] != null
        ? List<int>.from(json["episode_run_time"].map((x) => x))
        : [],
    status: json["status"] ?? "",
    tagline: json["tagline"] ?? "",
    voteAverage: json["vote_average"]?.toDouble() ?? 0.0,
    voteCount: json["vote_count"] ?? 0,
  );
}

class TvGenre {
  final int id;
  final String name;

  TvGenre({required this.id, required this.name});

  factory TvGenre.fromJson(Map<String, dynamic> json) =>
      TvGenre(id: json["id"] ?? 0, name: json["name"] ?? "");
}
