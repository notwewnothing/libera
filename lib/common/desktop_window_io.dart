import 'package:flutter/widgets.dart';
import 'package:libera/common/platform.dart';
import 'package:window_manager/window_manager.dart';

/// Configures the desktop window (min size, title, centered). No-op unless this
/// is actually a desktop build — on mobile the plugin isn't present.
Future<void> setupDesktopWindow() async {
  if (!kIsDesktop) return;
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(1280, 820),
    minimumSize: Size(880, 600),
    center: true,
    title: 'Libera',
    backgroundColor: Color(0xFF000000),
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
