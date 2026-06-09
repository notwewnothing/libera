import 'dart:convert';

SeasonDetails seasonDetailsFromJson(String str) =>
    SeasonDetails.fromJson(json.decode(str));

class SeasonDetails {
  final int id;
  final String name;
  final int seasonNumber;
  final List<Episode> episodes;

  SeasonDetails({
    required this.id,
    required this.name,
    required this.seasonNumber,
    required this.episodes,
  });

  factory SeasonDetails.fromJson(Map<String, dynamic> json) => SeasonDetails(
    id: json["id"] ?? 0,
    name: json["name"] ?? "",
    seasonNumber: json["season_number"] ?? 0,
    episodes: json["episodes"] != null
        ? List<Episode>.from(json["episodes"].map((x) => Episode.fromJson(x)))
        : [],
  );
}

class Episode {
  final int id;
  final int episodeNumber;
  final String name;
  final String overview;
  final String? stillPath;
  final int? runtime;
  final double voteAverage;
  final String? airDate;

  Episode({
    required this.id,
    required this.episodeNumber,
    required this.name,
    required this.overview,
    this.stillPath,
    this.runtime,
    required this.voteAverage,
    this.airDate,
  });

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
    id: json["id"] ?? 0,
    episodeNumber: json["episode_number"] ?? 0,
    name: json["name"] ?? "",
    overview: json["overview"] ?? "",
    stillPath: json["still_path"],
    runtime: json["runtime"],
    voteAverage: json["vote_average"]?.toDouble() ?? 0.0,
    airDate: json["air_date"],
  );
}
