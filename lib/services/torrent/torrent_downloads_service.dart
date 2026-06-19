// Torrent-to-disk downloader (native libtorrent + path_provider). Web gets a
// no-op stub that still exposes the TorrentDownload model + service API so the
// downloads UI compiles.
export 'torrent_downloads_service_stub.dart'
    if (dart.library.io) 'torrent_downloads_service_io.dart';
