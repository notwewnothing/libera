// Web stub for TorrentStreamService. No native torrent engine in a browser, so
// every method is a no-op. Only the members referenced by non-torrent UI (e.g.
// settings' applyConnectionsLimit) need to exist.
class TorrentStreamService {
  TorrentStreamService._();
  static final TorrentStreamService _instance = TorrentStreamService._();
  factory TorrentStreamService() => _instance;
  static TorrentStreamService get instance => _instance;

  Future<bool> start() async => false;
  Future<void> applyConnectionsLimit() async {}
  void removeTorrent(String magnetOrHash) {}
  Future<void> stop() async {}
  Future<void> cleanup() async {}
}
