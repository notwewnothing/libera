import 'package:flutter_test/flutter_test.dart';
import 'package:libera/services/torrent/torrent_filter.dart';

void main() {
  group('isFileMatch — episode is selected, movie is not', () {
    test('anime "Show - 05" matches S1E5', () {
      expect(
        TorrentFilter.isFileMatch('Cowboy Bebop - 05 [1080p].mkv', 1, 5),
        isTrue,
      );
    });

    test('movie file in the pack does NOT match S1E5 (5.1 audio guard)', () {
      expect(
        TorrentFilter.isFileMatch(
          'Cowboy.Bebop.The.Movie.1998.1080p.BluRay.DTS-HD.MA.5.1.x264.mkv',
          1,
          5,
        ),
        isFalse,
      );
    });

    test('standard SxxExx matches', () {
      expect(TorrentFilter.isFileMatch('Show.S01E05.1080p.WEB.mkv', 1, 5),
          isTrue);
    });

    test('SxxExx does not match a different episode', () {
      expect(TorrentFilter.isFileMatch('Show.S01E05.1080p.mkv', 1, 6), isFalse);
      expect(TorrentFilter.isFileMatch('Show.S01E05.mkv', 1, 50), isFalse);
    });

    test('1x05 form matches', () {
      expect(TorrentFilter.isFileMatch('Show 1x05 720p.mkv', 1, 5), isTrue);
    });

    test('"Episode 5" / "E05" / "EP05" match', () {
      expect(TorrentFilter.isFileMatch('Show - Episode 5.mkv', 1, 5), isTrue);
      expect(TorrentFilter.isFileMatch('Show.E05.mkv', 1, 5), isTrue);
      expect(TorrentFilter.isFileMatch('Show EP05.mkv', 1, 5), isTrue);
    });

    test('resolution/codec tokens do not false-match', () {
      // 1080p must not match episode 8 or 10; x265 must not match 5
      expect(TorrentFilter.isFileMatch('Movie.1998.1080p.x265.mkv', 1, 8),
          isFalse);
      expect(TorrentFilter.isFileMatch('Movie.1998.1080p.x265.mkv', 1, 10),
          isFalse);
      expect(TorrentFilter.isFileMatch('Movie.1998.1080p.x265.mkv', 1, 5),
          isFalse);
    });

    test('bare two-digit episode 10 matches but not inside 1080p', () {
      expect(TorrentFilter.isFileMatch('Show - 10 [720p].mkv', 1, 10), isTrue);
    });

    test('non-video extensions never match', () {
      expect(TorrentFilter.isFileMatch('Show - 05.nfo', 1, 5), isFalse);
      expect(TorrentFilter.isFileMatch('Show - 05.srt', 1, 5), isFalse);
    });
  });
}
