// Fast, deterministic, offline tests for the vadapav.mov download source's
// pure JSON parsing, plus its reuse of the shared release-metadata parsing.
// Run with: flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:libera/services/index_scraper.dart';
import 'package:libera/services/vadapav_source.dart';

// A realistic slice of an /api/d or /api/s response: one folder, two episodes
// with two releases each, a sample that must be ignored, plus a malformed item.
String _item(
  String id,
  String name,
  String type, {
  int? size,
  String? category,
}) {
  final parts = <String>[
    '"id":"$id"',
    '"name":"$name"',
    '"type":"$type"',
    if (size != null) '"size":$size',
    if (category != null) '"category":"$category"',
    '"mimeType":"${type == 'folder' ? 'drive/folder' : 'video/x-matroska'}"',
  ];
  return '{${parts.join(',')}}';
}

void main() {
  group('VadapavSource.parseItems', () {
    test('maps folders to /api/d and files to /f, with sizes', () {
      final json =
          '{"items":['
          '${_item('aaa', 'Breaking Bad (2008)', 'folder', size: 97723928191)},'
          '${_item('bbb', 'Breaking.Bad.S01E01.1080p.BluRay.x265-iVy.mkv', 'file', size: 3192667327, category: 'video')},'
          '{"id":"","name":"broken","type":"file"},' // skipped: empty id
          '{"name":"noid","type":"file"}' // skipped: no id
          ']}';
      final entries = VadapavSource.parseItems(json);

      expect(entries.length, 2);

      final dir = entries[0];
      expect(dir.name, 'Breaking Bad (2008)');
      expect(dir.isDir, isTrue);
      expect(dir.url.toString(), 'https://vadapav.mov/api/d/aaa');
      expect(dir.sizeBytes, -1); // folders report no per-file size

      final file = entries[1];
      expect(file.isDir, isFalse);
      expect(file.isVideo, isTrue);
      expect(file.url.toString(), 'https://vadapav.mov/f/bbb');
      expect(file.sizeBytes, 3192667327);
      expect(file.sizeLabel, isNotEmpty); // humanised ("3.0 GB")
    });

    test('returns empty on malformed/empty bodies', () {
      expect(VadapavSource.parseItems('not json'), isEmpty);
      expect(VadapavSource.parseItems('{"items":null}'), isEmpty);
      expect(VadapavSource.parseItems('{}'), isEmpty);
    });

    test('reuses shared release parsing: S/E, quality, sample-dropping', () {
      final json =
          '{"items":['
          '${_item('e1a', 'Show.S01E01.Pilot.1080p.BluRay.x265-RG.mkv', 'file', size: 3000000000)},'
          '${_item('e1b', 'Show.S01E01.Pilot.720p.WEB-DL.x264-RG.mkv', 'file', size: 1500000000)},'
          '${_item('e2a', 'Show.S01E02.Cat.in.the.Bag.1080p.BluRay.x265-RG.mkv', 'file', size: 3100000000)},'
          '${_item('e2b', 'Show.S01E02.Cat.in.the.Bag.720p.WEB-DL.x264-RG.mkv', 'file', size: 1600000000)},'
          '${_item('s', 'Show.S01E01.sample.mkv', 'file', size: 20000000)}'
          ']}';
      final entries = VadapavSource.parseItems(json);
      final videos = IndexScraper.videoFilesFrom(entries, tv: true);

      // 4 real episode files; the sample is dropped.
      expect(videos.length, 4);
      expect(videos.every((v) => v.season == 1), isTrue);
      expect(videos.map((v) => v.episode).toSet(), {1, 2});
      expect(videos.first.episodeTitle, isNotNull);

      // Two consistent release sets across both episodes.
      final variants = IndexScraper.groupVariants(videos);
      expect(variants.length, 2);
      expect(variants.every((v) => v.isComplete), isTrue); // 2/2 episodes each
      final labels = variants.map((v) => v.label).toList();
      expect(labels.any((l) => l.contains('1080p')), isTrue);
      expect(labels.any((l) => l.contains('720p')), isTrue);
    });
  });
}
