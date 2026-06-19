// Inline WebView embed player. Uses the real `webview_flutter`-backed
// implementation on platforms with `dart:io` (Android/iOS/macOS, and desktop
// where it simply isn't selected as the embed mode), and a no-op stub on web so
// the web build never compiles `webview_flutter`.
export 'inline_webview_player_stub.dart'
    if (dart.library.io) 'inline_webview_player_io.dart';
