import 'dart:convert';

WatchProviders watchProvidersFromJson(String str) =>
    WatchProviders.fromJson(json.decode(str));

class WatchProviders {
  final int id;
  final Map<String, WatchProviderRegion> results;

  WatchProviders({required this.id, required this.results});

  factory WatchProviders.fromJson(Map<String, dynamic> json) => WatchProviders(
    id: json['id'] ?? 0,
    results: (json['results'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, WatchProviderRegion.fromJson(v as Map<String, dynamic>)),
    ),
  );
}

class WatchProviderRegion {
  final String? link;
  final List<StreamingProvider> flatrate;
  final List<StreamingProvider> rent;
  final List<StreamingProvider> buy;

  WatchProviderRegion({
    this.link,
    required this.flatrate,
    required this.rent,
    required this.buy,
  });

  factory WatchProviderRegion.fromJson(Map<String, dynamic> json) =>
      WatchProviderRegion(
        link: json['link'],
        flatrate: json['flatrate'] != null
            ? List<StreamingProvider>.from(
                json['flatrate'].map((x) => StreamingProvider.fromJson(x)),
              )
            : [],
        rent: json['rent'] != null
            ? List<StreamingProvider>.from(
                json['rent'].map((x) => StreamingProvider.fromJson(x)),
              )
            : [],
        buy: json['buy'] != null
            ? List<StreamingProvider>.from(
                json['buy'].map((x) => StreamingProvider.fromJson(x)),
              )
            : [],
      );

  List<StreamingProvider> get allProviders {
    final seen = <int>{};
    return [...flatrate, ...rent, ...buy]
        .where((p) => seen.add(p.providerId))
        .toList()
      ..sort((a, b) => a.displayPriority.compareTo(b.displayPriority));
  }
}

class StreamingProvider {
  final String? logoPath;
  final int providerId;
  final String providerName;
  final int displayPriority;

  StreamingProvider({
    this.logoPath,
    required this.providerId,
    required this.providerName,
    required this.displayPriority,
  });

  factory StreamingProvider.fromJson(Map<String, dynamic> json) =>
      StreamingProvider(
        logoPath: json['logo_path'],
        providerId: json['provider_id'] ?? 0,
        providerName: json['provider_name'] ?? '',
        displayPriority: json['display_priority'] ?? 999,
      );
}
