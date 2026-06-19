// Android foreground-service download notifier. The real implementation pulls
// in dart:io + flutter_foreground_task (not web-compatible); web gets a no-op
// stub so main.dart can reference it unconditionally.
export 'download_notification_service_stub.dart'
    if (dart.library.io) 'download_notification_service_io.dart';
