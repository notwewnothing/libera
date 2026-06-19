import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:libera/services/app_settings.dart';
import 'package:libera/services/downloads_service.dart';
import 'package:libera/services/torrent/torrent_downloads_service.dart';

/// Keeps downloads running in the background and shows a live progress
/// notification.
///
/// Listens to both download systems (HTTP [DownloadsService] and the torrent
/// [TorrentDownloadsService]); whenever anything is active it runs a `dataSync`
/// foreground service (via flutter_foreground_task) so Android won't kill the
/// process, and updates the ongoing notification with the combined progress.
/// When everything finishes, the service — and its notification — stop.
class DownloadNotificationService {
  DownloadNotificationService._();
  static final DownloadNotificationService instance =
      DownloadNotificationService._();

  static const _channelId = 'libera_downloads';

  bool _started = false;
  bool _serviceRunning = false;
  bool _busy = false; // guards async start/stop against the sync listener
  bool _permissionAsked = false;

  DateTime _lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  int _lastActiveCount = -1;

  // For deriving a combined throughput across both download systems.
  int _lastBytes = 0;
  DateTime _lastBytesAt = DateTime.now();
  double _speedMbps = 0;

  /// Configure the plugin (call once, after WidgetsFlutterBinding) and start
  /// listening. No-op off Android.
  void init() {
    if (_started || !Platform.isAndroid) return;
    _started = true;

    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: 'Downloads',
        channelDescription: 'Shows active download progress',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
        autoRunOnBoot: false,
      ),
    );

    DownloadsService.instance.addListener(_onChanged);
    TorrentDownloadsService.instance.addListener(_onChanged);
  }

  void _onChanged() {
    if (!Platform.isAndroid) return;
    // Respect the user's "background downloads" toggle — when off we never run
    // the foreground service (downloads still progress while the app is open).
    if (!AppSettings.instance.backgroundDownloads) {
      unawaited(_stop());
      return;
    }
    final snap = _aggregate();
    if (snap.activeCount > 0) {
      unawaited(_runOrUpdate(snap));
    } else {
      unawaited(_stop());
    }
  }

  _Progress _aggregate() {
    final http = DownloadsService.instance.downloading; // downloading + queued
    final torrents =
        TorrentDownloadsService.instance.all.where((d) => !d.done).toList();

    var received = 0;
    var total = 0;
    var progressSum = 0.0;
    var counted = 0;

    for (final e in http) {
      if (e.totalBytes > 0) {
        received += e.receivedBytes;
        total += e.totalBytes;
      }
      progressSum += e.progress.clamp(0.0, 1.0);
      counted++;
    }
    for (final d in torrents) {
      if (d.totalBytes > 0) {
        received += d.downloadedBytes;
        total += d.totalBytes;
      }
      progressSum += d.progress.clamp(0.0, 1.0);
      counted++;
    }

    final activeCount = http.length + torrents.length;
    final percent = total > 0
        ? ((received / total) * 100).round()
        : (counted > 0 ? ((progressSum / counted) * 100).round() : 0);

    _updateSpeed(received);
    return _Progress(activeCount, percent.clamp(0, 100), _speedMbps);
  }

  void _updateSpeed(int receivedBytes) {
    final now = DateTime.now();
    final dt = now.difference(_lastBytesAt).inMilliseconds;
    if (dt >= 800) {
      final delta = receivedBytes - _lastBytes;
      _speedMbps = delta > 0 ? (delta / (dt / 1000)) / (1024 * 1024) : 0;
      _lastBytes = receivedBytes;
      _lastBytesAt = now;
    }
  }

  Future<void> _runOrUpdate(_Progress p) async {
    if (_busy) return;
    final countChanged = p.activeCount != _lastActiveCount;
    final due = DateTime.now().difference(_lastUpdate).inMilliseconds >= 1000;
    if (_serviceRunning && !countChanged && !due) return;

    _busy = true;
    try {
      final title = 'Downloading ${p.activeCount} '
          '${p.activeCount == 1 ? 'item' : 'items'}';
      final speed = p.speedMbps >= 0.05
          ? ' · ${p.speedMbps >= 1 ? '${p.speedMbps.toStringAsFixed(1)} MB/s' : '${(p.speedMbps * 1024).toStringAsFixed(0)} KB/s'}'
          : '';
      final text = '${p.percent}%$speed';

      if (!_serviceRunning) {
        if (!_permissionAsked) {
          _permissionAsked = true;
          try {
            await FlutterForegroundTask.requestNotificationPermission();
          } catch (_) {}
        }
        if (!await FlutterForegroundTask.isRunningService) {
          await FlutterForegroundTask.startService(
            serviceId: 256,
            serviceTypes: const [ForegroundServiceTypes.dataSync],
            notificationTitle: title,
            notificationText: text,
          );
        }
        _serviceRunning = true;
      } else {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        );
      }
      _lastUpdate = DateTime.now();
      _lastActiveCount = p.activeCount;
    } catch (e) {
      debugPrint('[DownloadNotif] update failed: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _stop() async {
    if (!_serviceRunning || _busy) return;
    _busy = true;
    try {
      await FlutterForegroundTask.stopService();
    } catch (e) {
      debugPrint('[DownloadNotif] stop failed: $e');
    } finally {
      _serviceRunning = false;
      _lastActiveCount = -1;
      _lastBytes = 0;
      _speedMbps = 0;
      _busy = false;
    }
  }
}

class _Progress {
  final int activeCount;
  final int percent;
  final double speedMbps;
  const _Progress(this.activeCount, this.percent, this.speedMbps);
}
