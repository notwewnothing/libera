// Torrent stream-and-play helpers. The real implementation drives the native
// libtorrent engine; web gets a no-op stub (torrents can't run in a browser).
export 'torrent_playback_stub.dart'
    if (dart.library.io) 'torrent_playback_io.dart';
