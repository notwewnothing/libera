// To parse this JSON data, do
//
//     final movieVideo = movieVideoFromJson(jsonString);

import 'dart:convert';

MovieVideo movieVideoFromJson(String str) =>
    MovieVideo.fromJson(json.decode(str));

String movieVideoToJson(MovieVideo data) => json.encode(data.toJson());

class MovieVideo {
  int id;
  List<MovieVideoResult> results;

  MovieVideo({
    required this.id,
    required this.results,
  });

  factory MovieVideo.fromJson(Map<String, dynamic> json) => MovieVideo(
        id: json["id"] ?? 0,
        results: json["results"] == null
            ? []
            : List<MovieVideoResult>.from(
                json["results"].map((x) => MovieVideoResult.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "results": List<dynamic>.from(results.map((x) => x.toJson())),
      };
}

class MovieVideoResult {
  String name;
  String key;
  String site;
  String type;
  bool official;
  String id;

  MovieVideoResult({
    required this.name,
    required this.key,
    required this.site,
    required this.type,
    required this.official,
    required this.id,
  });

  factory MovieVideoResult.fromJson(Map<String, dynamic> json) => MovieVideoResult(
        name: json["name"] ?? "",
        key: json["key"] ?? "",
        site: json["site"] ?? "",
        type: json["type"] ?? "",
        official: json["official"] ?? false,
        id: json["id"] ?? "",
      );

  Map<String, dynamic> toJson() => {
        "name": name,
        "key": key,
        "site": site,
        "type": type,
        "official": official,
        "id": id,
      };
}
