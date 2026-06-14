// Fast, deterministic, offline tests for the download-source backend's pure
// parsing/grouping logic (no network). Run with: flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:libera/services/index_scraper.dart';

// A realistic slice of an index directory page (two episodes, two releases
// each, plus a sample file that must be ignored). Mirrors the live markup:
// `<tr data-entry="true" data-name=".." data-url="..">..<td class="size"
// data-sort="BYTES">LABEL</td></tr>`.
String _row(String name, String url, int bytes, String label) =>
    '<tr data-entry="true" data-name="$name" data-url="$url">'
    '<td class="select-col"><input type="checkbox"></td>'
    '<td><a href="$url">$name</a></td>'
    '<td class="size" data-sort="$bytes">$label</td></tr>';

void main() {
  final base = Uri.parse('https://a.111477.xyz/tvs/Better%20Call%20Saul/Season%201/');

  group('parseListing', () {
    test('extracts name, resolved url, size and dir flag; decodes entities', () {
      final html = '<table><tbody>'
          '<tr data-parent="true"><td class="size" data-sort="-1">-</td></tr>'
          '${_row("Season 1", "/tvs/X/Season%201/", -1, "-")}'
          '${_row("&amp; After &#39;25.mkv", "/tvs/X/%26%20After.mkv", 12345, "12.1 KB")}'
          '</tbody></table>';
      final entries = parseListing(html, base);

      expect(entries.length, 2);
      final dir = entries[0];
      expect(dir.name, 'Season 1');
      expect(dir.isDir, isTrue);

      final file = entries[1];
      expect(file.name, "& After '25.mkv"); // entities decoded
      expect(file.isDir, isFalse);
      expect(file.isVideo, isTrue);
      expect(file.sizeBytes, 12345);
      expect(file.sizeLabel, '12.1 KB');
      expect(file.url.toString(), contains('%26%20After.mkv'));
    });

    test('ignores rows without data-entry', () {
      final html = '<tr data-parent="true"><td>../</td></tr>';
      expect(parseListing(html, base), isEmpty);
    });
  });

  group('parseQuality', () {
    test('bracketed TV release (Remux/AVC)', () {
      final q = parseQuality(
        'Better Call Saul (2015) - S01E01 - Uno [Bluray-1080p Remux][DTS-HD MA 5.1][AVC]-FraMeSToR.mkv',
      );
      expect(q.resolution, '1080p');
      expect(q.source, 'Bluray Remux');
      expect(q.codec, 'AVC');
      expect(q.group, 'FraMeSToR');
    });

    test('bracketed TV release (Bluray/x264)', () {
      final q = parseQuality(
        'Better Call Saul (2015) - S01E01 - Uno [Bluray-1080p][DTS 5.1][x264]-SHORTBREHD.mkv',
      );
      expect(q.resolution, '1080p');
      expect(q.source, 'Bluray');
      expect(q.codec, 'x264');
    });

    test('dot-separated 2160p WEB-DL with DV', () {
      final q = parseQuality(
        'Dune.2021.2160p.MAX.WEB-DL.DDP5.1.Atmos.DV.HDR.H.265-PMI.mkv',
      );
      expect(q.resolution, '2160p');
      expect(q.source, 'WEB-DL');
      expect(q.codec, 'H265');
      expect(q.hdr, 'DV');
      expect(q.audio, contains('DDP'));
    });

    test('WEBRip x265 movie', () {
      final q = parseQuality('Iron.Lung.2026.1080p.10bit.WEBRip.6CH.x265.HEVC-PSA.mkv');
      expect(q.resolution, '1080p');
      expect(q.source, 'WEBRip');
      expect(q.codec, 'x265');
    });

    test('variantKey groups by resolution + codec, ignoring audio/group', () {
      final a = parseQuality('Show - S01E01 [Bluray-1080p][DTS 5.1][x264]-AAA.mkv');
      final b = parseQuality('Show - S01E02 [Bluray-1080p][AC3 5.1][x264]-BBB.mkv');
      expect(a.variantKey, b.variantKey); // same set despite diff audio/group
      final c = parseQuality('Show - S01E01 [Bluray-1080p Remux][DTS-HD MA][AVC]-CCC.mkv');
      expect(a.variantKey, isNot(c.variantKey)); // diff codec => diff set
    });

    test('higher quality scores higher (Remux 2160 > WEBRip 1080)', () {
      final hi = parseQuality('M.2021.2160p.BluRay.REMUX.HEVC.DV-X.mkv');
      final lo = parseQuality('M.2021.1080p.WEBRip.x265-Y.mkv');
      expect(hi.score, greaterThan(lo.score));
    });
  });

  group('videoFilesFrom (TV)', () {
    test('parses S/E, episode title, drops samples', () {
      final entries = [
        DirEntry(name: 'Show - S02E05 - The Reveal [Bluray-1080p][x264]-G.mkv', url: base.resolve('a.mkv'), isDir: false, sizeBytes: 100, sizeLabel: ''),
        DirEntry(name: 'Show - S02E05 - sample.mkv', url: base.resolve('s.mkv'), isDir: false, sizeBytes: 1, sizeLabel: ''),
        DirEntry(name: 'poster.jpg', url: base.resolve('p.jpg'), isDir: false, sizeBytes: 1, sizeLabel: ''),
      ];
      final vids = IndexScraper.videoFilesFrom(entries, tv: true);
      expect(vids.length, 1); // sample + non-video dropped
      expect(vids.first.season, 2);
      expect(vids.first.episode, 5);
      expect(vids.first.episodeTitle, 'The Reveal');
    });
  });

  group('groupVariants', () {
    // Build a 4-episode season: every episode has an x264 release; episodes
    // 1-2 also have a Remux/AVC release, 3-4 fall back to HDTV/AVC.
    List<VideoFile> season() {
      final names = <String>[
        'S - S01E01 - A [Bluray-1080p Remux][AVC]-R.mkv',
        'S - S01E01 - A [Bluray-1080p][x264]-X.mkv',
        'S - S01E02 - B [Bluray-1080p Remux][AVC]-R.mkv',
        'S - S01E02 - B [Bluray-1080p][x264]-X.mkv',
        'S - S01E03 - C [HDTV-1080p][AVC]-H.mkv',
        'S - S01E03 - C [Bluray-1080p][x264]-X.mkv',
        'S - S01E04 - D [HDTV-1080p][AVC]-H.mkv',
        'S - S01E04 - D [Bluray-1080p][x264]-X.mkv',
      ];
      return IndexScraper.videoFilesFrom([
        for (final n in names)
          DirEntry(name: n, url: base.resolve(Uri.encodeComponent(n)), isDir: false, sizeBytes: 1000, sizeLabel: '1 KB'),
      ], tv: true);
    }

    test('clusters into consistent sets with coverage', () {
      final variants = IndexScraper.groupVariants(season());

      // x264 set is complete (4/4); AVC set is incomplete (mixed res/codec key).
      final x264 = variants.firstWhere((v) => v.key.contains('x264'));
      expect(x264.episodeCount, 4);
      expect(x264.isComplete, isTrue);
      expect(x264.seasonEpisodeCount, 4);

      // AVC files all share resolution+codec key so they form one 4-ep set too.
      final avc = variants.firstWhere((v) => v.key.contains('avc'));
      expect(avc.episodeCount, 4);

      // Most complete first.
      expect(variants.first.episodeCount, 4);
      // One file per episode within a set, episode-ordered.
      expect(x264.files.map((f) => f.episode), [1, 2, 3, 4]);
    });

    test('dedupes to the largest file per episode within a set', () {
      final dupes = IndexScraper.videoFilesFrom([
        DirEntry(name: 'S - S01E01 [Bluray-1080p][x264]-A.mkv', url: base.resolve('a'), isDir: false, sizeBytes: 100, sizeLabel: ''),
        DirEntry(name: 'S - S01E01 [Bluray-1080p][x264]-B.mkv', url: base.resolve('b'), isDir: false, sizeBytes: 500, sizeLabel: ''),
      ], tv: true);
      final variants = IndexScraper.groupVariants(dupes);
      expect(variants.single.files.single.sizeBytes, 500);
    });
  });
}
