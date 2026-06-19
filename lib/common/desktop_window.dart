// Desktop window setup (min size, title). Uses window_manager on native builds;
// a no-op stub on web so the desktop-only package never compiles there.
export 'desktop_window_stub.dart'
    if (dart.library.io) 'desktop_window_io.dart';
