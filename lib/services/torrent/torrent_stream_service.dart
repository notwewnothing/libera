// Torrent streaming engine (native libtorrent FFI). Impossible on web; web gets
// a no-op stub exposing only what non-torrent UI references.
export 'torrent_stream_service_stub.dart'
    if (dart.library.io) 'torrent_stream_service_io.dart';
