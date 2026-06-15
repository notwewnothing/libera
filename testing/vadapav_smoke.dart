// Live smoke test for the vadapav.mov download source.
//
//   dart run testing/vadapav_smoke.dart
//
// Hits the real API end-to-end (search → show/season/episode resolution,
// variant grouping, movie resolution) and confirms a resolved file URL streams
// with Range support (resumable) before we trust it in the app.

// ignore_for_file: avoid_print
import 'package:http/http.dart' as http;
import 'package:libera/services/vadapav_source.dart';

int _passed = 0;
int _failed = 0;

void check(String what, bool ok, [String detail = '']) {
  if (ok) {
    _passed++;
    print('  ✓ $what${detail.isEmpty ? '' : '  ($detail)'}');
  } else {
    _failed++;
    print('  ✗ $what${detail.isEmpty ? '' : '  ($detail)'}');
  }
}

Future<T> timed<T>(String label, Future<T> Function() body) async {
  final sw = Stopwatch()..start();
  final r = await body();
  sw.stop();
  print('  ⏱  $label: ${sw.elapsedMilliseconds} ms');
  return r;
}

Future<void> main() async {
  final s = VadapavSource();
  final total = Stopwatch()..start();

  try {
    // 1) Show -> seasons ----------------------------------------------------
    print('\n[1] resolveShow("Breaking Bad")');
    final show = await timed('resolveShow', () => s.resolveShow('Breaking Bad'));
    check('show resolved', show != null, show?.title ?? 'null');
    check('found season folders', (show?.seasons.length ?? 0) >= 1,
        '${show?.seasons.map((e) => e.number).toList()}');

    // 2) Season -> episodes + variants -------------------------------------
    if (show != null && show.seasons.any((e) => e.number == 1)) {
      print('\n[2] resolveSeason(Season 1)');
      final ref = show.seasons.firstWhere((e) => e.number == 1);
      final season = await timed('resolveSeason', () => s.resolveSeason(ref));
      check('has episodes', season.episodes.isNotEmpty,
          '${season.episodes.length} episodes');
      check('every episode has a source',
          season.episodes.every((e) => e.sources.isNotEmpty));
      check('variants grouped', season.variants.isNotEmpty,
          '${season.variants.length} sets');
      print('    variant sets:');
      for (final v in season.variants) {
        final gb = (v.totalBytes / (1 << 30)).toStringAsFixed(1);
        print('      • ${v.label}  [${v.coverageLabel}, $gb GB]');
      }
    }

    // 3) Movie --------------------------------------------------------------
    print('\n[3] resolveMovie("Fight Club", year: 1999)');
    final movie =
        await timed('resolveMovie', () => s.resolveMovie('Fight Club', year: 1999));
    check('movie resolved', movie != null, movie?.title ?? 'null');
    check('has a source', (movie?.sources.length ?? 0) >= 1);
    if (movie != null) {
      print('      best: ${movie.best.quality.label}  ${movie.best.sizeLabel}');

      // 4) Download URL is resumable ---------------------------------------
      print('\n[4] file URL is a resumable stream');
      final req = http.Request('GET', movie.best.pageUrl)
        ..followRedirects = true
        ..headers['Range'] = 'bytes=0-1'
        ..headers['User-Agent'] = 'Mozilla/5.0';
      final resp = await timed('ranged GET', () => http.Client().send(req));
      await resp.stream.drain<void>();
      check('partial content (206)', resp.statusCode == 206,
          'status ${resp.statusCode}');
      final totalSize = resp.headers['content-range']?.split('/').last;
      check(
          'reports total size',
          totalSize != null && int.tryParse(totalSize) != null,
          'content-range: ${resp.headers['content-range']}');
    }
  } finally {
    total.stop();
    s.close();
  }

  print('\n${'=' * 60}');
  print('RESULT: $_passed passed, $_failed failed  —  total ${total.elapsedMilliseconds} ms');
  print('=' * 60);
}
