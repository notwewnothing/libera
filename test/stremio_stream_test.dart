// Offline tests for StremioStream parsing + magnet construction, using the
// shape AIOStreams actually returns (verified live). Run with: flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:libera/models/stremio_stream.dart';

void main() {
  group('StremioStream', () {
    test('parses a torrent stream and builds a magnet with dn + trackers', () {
      final s = StremioStream.fromJson({
        'name': '🧲 FHD ⌜BLURAY⌟',
        'title': 'Fight.Club.1999.1080p.BluRay.x264 👤 320 💾 12.4 GB',
        'infoHash': '4759632F94838BE272667BF4709BC27BFBA5C401',
        'fileIdx': 0,
        'sources': [
          'tracker:udp://tracker.opentrackr.org:1337/announce',
          'tracker:http://tracker.example/announce',
          'dht:something', // not a tracker → ignored
        ],
      }, addonName: 'AIOStreams');

      expect(s.isTorrent, isTrue);
      expect(s.fileIdx, 0);
      expect(s.addonName, 'AIOStreams');
      expect(s.qualityLabel, '1080p');
      expect(s.sizeLabel, '12.4 GB');
      expect(s.seeders, 320);

      final magnet = s.magnet;
      expect(magnet, startsWith('magnet:?xt=urn:btih:4759632F94838BE272667BF4709BC27BFBA5C401'));
      expect(magnet, contains('&dn='));
      // Two tracker: entries become &tr=, the dht: entry does not.
      expect('&tr='.allMatches(magnet).length, 2);
      expect(magnet, contains(Uri.encodeComponent('udp://tracker.opentrackr.org:1337/announce')));
      expect(magnet, isNot(contains('dht')));
    });

    test('parses a direct-url (non-torrent) stream', () {
      final s = StremioStream.fromJson({
        'name': 'Direct 2160p',
        'description': 'Some.Movie.2160p 💾 30 GB',
        'url': 'https://cdn.example/file.mkv',
        'behaviorHints': {
          'proxyHeaders': {
            'request': {'Cookie': 'abc', 'Referer': 'https://x'},
          },
        },
      });

      expect(s.isTorrent, isFalse);
      expect(s.url, 'https://cdn.example/file.mkv');
      expect(s.magnet, isEmpty);
      expect(s.qualityLabel, '2160p');
      expect(s.headers['Cookie'], 'abc');
      expect(s.headers['Referer'], 'https://x');
    });
  });
}
