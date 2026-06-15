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

  /// True when [fileName] is the file for [season]/[episode] of a series
  /// (handles SxxExx, NxNN, and looser episode-number matches).
  static bool isFileMatch(String fileName, int season, int episode) {
    final t = fileName.toLowerCase();
    if (!isVideoFile(t)) return false;

    final sXe = RegExp('s0*$season[ ._-]*e0*$episode\\b', caseSensitive: false);
    if (sXe.hasMatch(t)) return true;

    final xMatch = RegExp('\\b0*${season}x0*$episode\\b', caseSensitive: false);
    if (xMatch.hasMatch(t)) return true;

    final epOnly = RegExp('\\b0*$episode\\b');
    if (epOnly.hasMatch(t)) {
      final otherSxE = RegExp(r's\d+e\d+', caseSensitive: false);
      if (!otherSxE.hasMatch(t) || sXe.hasMatch(t)) return true;
    }

    final eOnly = RegExp('e0*$episode\\b', caseSensitive: false);
    if (eOnly.hasMatch(t)) return true;

    return false;
  }
}
