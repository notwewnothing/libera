import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Central platform predicates and safe system wrappers.
///
/// Everything here is web-safe: we never touch `dart:io`'s `Platform` (which
/// throws on web). `defaultTargetPlatform` is valid on every platform including
/// web, so all checks are guarded by [kIsWeb] first.

bool get isLinux => !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
bool get isWindows => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
bool get isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
bool get isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// True on Linux/Windows/macOS desktop builds (never on web).
bool get kIsDesktop => isLinux || isWindows || isMacOS;

/// True on phones/tablets (Android/iOS), where touch + system chrome apply.
bool get kIsMobile => isAndroid || isIOS;

/// Torrenting uses the native libtorrent FFI engine — impossible in a browser.
bool get supportsTorrents => !kIsWeb;

/// File downloads need a real filesystem (path_provider + dart:io) — no web.
bool get supportsFileDownloads => !kIsWeb;

/// Whether [SystemChrome] orientation / overlay calls are meaningful here.
/// They only matter (and only behave) on mobile; on web they can throw.
bool get _systemChromeApplies => kIsMobile;

/// How the website embed player ("Vidking" etc.) should be displayed.
enum EmbedMode {
  /// `webview_flutter` inline (Android / iOS / macOS).
  inlineWebView,

  /// `flutter_inappwebview` inline (Windows).
  inappWebView,

  /// HTML `<iframe>` via platform view (web).
  iframe,

  /// No inline webview available (Linux) — open in the system browser.
  externalBrowser,
}

EmbedMode get embedMode {
  if (kIsWeb) return EmbedMode.iframe;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return EmbedMode.inlineWebView;
    case TargetPlatform.windows:
      return EmbedMode.inappWebView;
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return EmbedMode.externalBrowser;
  }
}

/// On desktop the website embed player can't track progress / auto-advance, and
/// the native torrent → media_kit pipeline is the better watch path, so detail
/// screens should default the "Play" action to torrent sources there.
bool get prefersTorrentPlayback => kIsDesktop;

/// Lock/allow orientations without crashing on web/desktop.
void setOrientationsSafe(List<DeviceOrientation> orientations) {
  if (!_systemChromeApplies) return;
  SystemChrome.setPreferredOrientations(orientations);
}

/// Toggle immersive / edge-to-edge system UI without crashing off-mobile.
void setSystemUIModeSafe(SystemUiMode mode, {List<SystemUiOverlay>? overlays}) {
  if (!_systemChromeApplies) return;
  SystemChrome.setEnabledSystemUIMode(mode, overlays: overlays);
}
