/// One stream result from a Stremio addon's `/stream` endpoint (e.g. AIOStreams).
///
/// A stream is either a **torrent** (has [infoHash]) or a **direct URL** (has
/// [url]). For torrents we build a magnet from the info-hash, the display name
/// and any `tracker:` entries in [sources] — exactly how Stremio clients do it.
class StremioStream {
  final String name; // short label, often "Addon\n1080p"
  final String description; // detailed: filename / size / seeders
  final String? infoHash; // torrent hash (40-hex) when this is a torrent
  final int? fileIdx; // file index within the torrent, if specified
  final String? url; // direct http(s) url when not a torrent
  final List<String> sources; // "tracker:..."/"dht:..." entries
  final Map<String, String> headers; // proxy headers for direct urls
  final String addonName;

  const StremioStream({
    required this.name,
    required this.description,
    required this.infoHash,
    required this.fileIdx,
    required this.url,
    required this.sources,
    required this.headers,
    required this.addonName,
  });

  bool get isTorrent => infoHash != null && infoHash!.isNotEmpty;

  /// A label line (filename / size), preferring the richer field.
  String get title => description.isNotEmpty ? description : name;

  factory StremioStream.fromJson(Map<String, dynamic> j, {String addonName = 'Addon'}) {
    final rawSources = j['sources'];
    final sources = <String>[
      if (rawSources is List)
        for (final s in rawSources)
          if (s is String) s,
    ];
    final ph = j['behaviorHints']?['proxyHeaders']?['request'];
    final headers = <String, String>{
      if (ph is Map)
        for (final e in ph.entries) e.key.toString(): e.value.toString(),
    };
    return StremioStream(
      name: (j['name'] ?? '').toString(),
      description: (j['title'] ?? j['description'] ?? '').toString(),
      infoHash: (j['infoHash'])?.toString(),
      fileIdx: j['fileIdx'] is num ? (j['fileIdx'] as num).toInt() : null,
      url: (j['url'])?.toString(),
      sources: sources,
      headers: headers,
      addonName: addonName,
    );
  }

  /// Magnet link for a torrent stream (empty string when not a torrent).
  String get magnet {
    if (!isTorrent) return '';
    final dn = title.isNotEmpty ? '&dn=${Uri.encodeComponent(title)}' : '';
    final trackers = StringBuffer();
    for (final s in sources) {
      if (s.startsWith('tracker:')) {
        trackers.write('&tr=${Uri.encodeComponent(s.substring(8))}');
      }
    }
    return 'magnet:?xt=urn:btih:$infoHash$dn$trackers';
  }

  /// Best-effort resolution label parsed from the name/description.
  String? get qualityLabel {
    final t = '$name $description'.toLowerCase();
    if (t.contains('2160p') || t.contains('4k') || t.contains('uhd')) return '2160p';
    if (t.contains('1080p')) return '1080p';
    if (t.contains('720p')) return '720p';
    if (t.contains('480p')) return '480p';
    return null;
  }

  /// Best-effort size label (e.g. "12.4 GB") parsed from the text, if present.
  String? get sizeLabel {
    final m = RegExp(r'(\d+(?:\.\d+)?)\s?(GB|MB|GiB|MiB|TB)', caseSensitive: false)
        .firstMatch('$name $description');
    return m == null ? null : '${m.group(1)} ${m.group(2)!.toUpperCase()}';
  }

  /// Approximate seeder count parsed from common "👤 1,234" / "Seeders: 123" forms.
  int get seeders {
    final m = RegExp(r'(?:👤|seeders?\D{0,3})\s*([\d,]+)', caseSensitive: false)
        .firstMatch('$name $description');
    return m == null ? 0 : int.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0;
  }

  /// Approximate peer/leecher count parsed from "👥 1,234" / "Peers: 123" / "Leechers: 123" forms.
  int get peers {
    final m = RegExp(r'(?:👥|peers?\D{0,3}|leechers?\D{0,3})\s*([\d,]+)', caseSensitive: false)
        .firstMatch('$name $description');
    return m == null ? 0 : int.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0;
  }
}
