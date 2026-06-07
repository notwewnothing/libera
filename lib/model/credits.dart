// To parse this JSON data, do
//
//     final credits = creditsFromJson(jsonString);

import 'dart:convert';

Credits creditsFromJson(String str) => Credits.fromJson(json.decode(str));

class Credits {
  final int id;
  final List<CastMember> cast;

  Credits({required this.id, required this.cast});

  factory Credits.fromJson(Map<String, dynamic> json) => Credits(
    id: json["id"] ?? 0,
    cast: json["cast"] != null
        ? List<CastMember>.from(
            json["cast"].map((x) => CastMember.fromJson(x)),
          )
        : [],
  );
}

class CastMember {
  final int id;
  final String name;
  final String? character;
  final String? profilePath;
  final int order;

  CastMember({
    required this.id,
    required this.name,
    this.character,
    this.profilePath,
    required this.order,
  });

  factory CastMember.fromJson(Map<String, dynamic> json) => CastMember(
    id: json["id"] ?? 0,
    name: json["name"] ?? "",
    character: json["character"],
    profilePath: json["profile_path"],
    order: json["order"] ?? 999,
  );
}
