/// File-matching helpers used by [TorrentStreamService] to pick the right
/// video out of a multi-file torrent. Ported (trimmed) from PlayTorrioV2's
/// TorrentFilter — only the two members the streaming engine needs.
class TorrentFilter {
  static const _videoExtensions = [
    '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.mpg',
    '.mpeg', '.m2ts', '.ts', '.vob', '.ogv', '.3gp', '.3g2', '.f4v', '.asf',
    '.rm', '.rmvb', '.divx',
  ];

  static bool isVideoFile(String fileName) {
    final t = fileName.toLowerCase();
    return _videoExtensions.any((ext) => t.endsWith(ext));
  }

  /// True when [fileName] is the file for [season]/[episode] of a series.
  ///
  /// Handles `SxxExx`, `NxNN`, explicit `E05`/`EP05`/`Episode 5`, and
  /// anime-style bare episode numbers (`Show - 05`, `[05]`). The bare-number
  /// case is guarded so resolutions (`720p`/`1080p`), codecs (`x264`/`x265`),
  /// audio layouts (`5.1`/`7.1`) and years can't be mistaken for an episode —
  /// that false match is how a season-pack's movie file gets picked.
  static bool isFileMatch(String fileName, int season, int episode) {
    final t = fileName.toLowerCase();
    if (!isVideoFile(t)) return false;

    final s = season.toString();
    final e = episode.toString();

    // SxxExx / S x E
    if (RegExp('s0*$s[ ._-]*e0*$e(?![0-9])', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    // NxNN  (e.g. 1x05)
    if (RegExp('(?<![0-9])0*${s}x0*$e(?![0-9])', caseSensitive: false)
        .hasMatch(t)) {
      return true;
    }
    // Explicit episode marker: E05 / EP05 / Episode 5 (season may be absent).
    if (RegExp('(?:^|[ ._\\-\\[(])e(?:p|pisode)?[ ._-]*0*$e(?![0-9])',
            caseSensitive: false)
        .hasMatch(t)) {
      return true;
    }
    // Anime-style bare episode number as a delimited token.
    final bare = RegExp(
      '(?:^|[ ._\\-\\[(])' // delimiter before the number
      '0*$e' //              the (optionally zero-padded) episode number
      '(?![0-9pi])' //       not part of a larger number / 1080p / 1080i
      '(?![.,][0-9])' //     not audio like 5.1 / 7.1
      '(?:[ ._\\-\\])]|\$)', // delimiter (or end) after the number
      caseSensitive: false,
    );
    // Ignore a bare number when the name carries a real SxxExx token (which, if
    // it were this episode, would have matched above).
    final hasSxe = RegExp(r's\d+e\d+', caseSensitive: false).hasMatch(t);
    if (!hasSxe && bare.hasMatch(t)) return true;

    return false;
  }
}
