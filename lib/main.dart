import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:libera/common/desktop_window.dart';
import 'package:libera/common/platform.dart';
import 'package:libera/screens/intro.dart';
import 'package:libera/services/app_settings.dart';
import 'package:libera/services/continue_watching_service.dart';
import 'package:libera/services/download_notification_service.dart';
import 'package:libera/services/download_source_service.dart';
import 'package:libera/services/player_service.dart';
import 'package:libera/services/stremio/stremio_addons_service.dart';
import 'package:libera/services/watched_service.dart';
import 'package:libera/services/watchlist_service.dart';
import 'package:media_kit/media_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDesktopWindow();
  MediaKit.ensureInitialized();
  await Future.wait([
    AppSettings.instance.init(),
    WatchlistService.instance.init(),
    WatchedService.instance.init(),
    ContinueWatchingService.instance.init(),
    PlayerService.instance.init(),
    DownloadSourceService.instance.init(),
    StremioAddonsService.instance.init(),
  ]);
  // Android-only foreground service (keeps downloads alive). Guarded so web,
  // where touching dart:io's Platform throws, never reaches it.
  if (isAndroid) DownloadNotificationService.instance.init();
  runApp(const MyApp());
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  // Allow dragging scrollables with a mouse/trackpad (not just touch) so the
  // horizontal poster rows can be panned with the pointer on desktop/web.
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const IntroScreen(),
      debugShowCheckedModeBanner: false,
      title: "Libera",
      scrollBehavior: const _AppScrollBehavior(),
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0A84FF),
          surface: Colors.black,
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
            TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
    );
  }
}
