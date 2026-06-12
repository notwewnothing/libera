import 'package:flutter/foundation.dart';
import 'package:libera/common/media_widgets.dart';

/// Tracks downloads. Storage/engine wiring is not implemented yet — for now this
/// just holds the in-memory lists the Downloads UI listens to.
class DownloadsService extends ChangeNotifier {
  DownloadsService._();
  static final DownloadsService instance = DownloadsService._();

  final List<MediaCardData> _downloading = [];
  final List<MediaCardData> _completed = [];

  List<MediaCardData> get downloading => List.unmodifiable(_downloading);
  List<MediaCardData> get completed => List.unmodifiable(_completed);

  int get downloadingCount => _downloading.length;
  int get completedCount => _completed.length;
}
