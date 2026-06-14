// Live smoke test for the download-source backend.
//
//   dart run testing/scraper_smoke.dart
//
// Hits the real index site and exercises every path (listing, show/season/
// episode resolution, variant grouping, movie multi-source, fuzzy fallback,
// final download-URL resolution) while printing timings so we can confirm the
// backend is fast, accurate and responsive before wiring it into the app.

import 'package:libera/services/index_scraper.dart';

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
  final s = IndexScraper();
  final total = Stopwatch()..start();

  try {
    // 1) Root listing -------------------------------------------------------
    print('\n[1] TV root listing');
    final tvRoot = await timed('list tvs/', () => s.listDir(IndexScraper.tvsRoot));
    check('tvs root has many entries', tvRoot.length > 1000, '${tvRoot.length} entries');
    check('all tvs root entries are dirs', tvRoot.every((e) => e.isDir));

    // 2) Show -> seasons ----------------------------------------------------
    print('\n[2] resolveShow("Better Call Saul")');
    final show = await timed('resolveShow', () => s.resolveShow('Better Call Saul'));
    check('show resolved', show != null, show?.dirUrl.toString() ?? 'null');
    final seasonNums = show!.seasons.map((e) => e.number).toList();
    check('found 6 numbered seasons', show.seasons.where((e) => e.number != null).length == 6, '$seasonNums');

    // 3) Season -> episodes + variants -------------------------------------
    print('\n[3] resolveSeason(Season 1)');
    final s1ref = show.seasons.firstWhere((e) => e.number == 1);
    final season = await timed('resolveSeason', () => s.resolveSeason(s1ref));
    check('10 episodes', season.episodes.length == 10, '${season.episodes.length}');
    check('every episode has >=1 source', season.episodes.every((e) => e.sources.isNotEmpty));
    final multi = season.episodes.where((e) => e.hasChoice).length;
    check('episodes offer a choice of source', multi >= 8, '$multi/10 with 2+ sources');
    check('episode titles parsed', season.episodes.first.title != null,
        'E1 title="${season.episodes.first.title}"');

    print('    variant sets:');
    for (final v in season.variants) {
      final gb = (v.totalBytes / (1 << 30)).toStringAsFixed(1);
      print('      • ${v.label}  [${v.coverageLabel}, ${gb} GB]${v.isComplete ? '  COMPLETE' : ''}');
    }
    check('variants grouped', season.variants.isNotEmpty, '${season.variants.length} sets');
    check('a complete variant exists', season.variants.any((v) => v.isComplete));

    print('    episode 1 sources (best-first):');
    for (final src in season.episodes.first.sources) {
      print('      - ${src.quality.label}  ${src.sizeLabel}  [${src.quality.group}]');
    }

    // 4) Movie (single source) ---------------------------------------------
    print('\n[4] resolveMovie("Iron Lung", year: 2026)');
    final iron = await timed('resolveMovie', () => s.resolveMovie('Iron Lung', year: 2026));
    check('movie resolved', iron != null, iron?.dirUrl.toString() ?? 'null');
    check('has a source', (iron?.sources.length ?? 0) >= 1);
    if (iron != null) {
      print('      ${iron.best.quality.label}  ${iron.best.sizeLabel}');
    }

    // 5) Movie (many sources -> user picks) --------------------------------
    print('\n[5] resolveMovie("Dune", year: 2021) — multi-source');
    final dune = await timed('resolveMovie', () => s.resolveMovie('Dune', year: 2021));
    check('movie resolved', dune != null);
    check('offers multiple sources', (dune?.sources.length ?? 0) > 1, '${dune?.sources.length} sources');
    if (dune != null) {
      for (final src in dune.sources.take(6)) {
        print('      - ${src.quality.label}  ${src.sizeLabel}');
      }
    }

    // 6) Fuzzy fallback (deliberately imperfect title) ----------------------
    print('\n[6] fuzzy fallback: resolveShow("breaking bad")');
    final bb = await timed('resolveShow (fuzzy)', () => s.resolveShow('breaking bad'));
    check('fuzzy show resolved', bb != null, bb?.title ?? 'null');

    // 7) Final download URL -------------------------------------------------
    print('\n[7] resolveDownloadUrl (Iron Lung file)');
    if (iron != null) {
      final dl = await timed('resolveDownloadUrl', () => s.resolveDownloadUrl(iron.best.pageUrl));
      check('reports total size', dl.contentLength > 0,
          '${(dl.contentLength / (1 << 20)).toStringAsFixed(0)} MB');
      check('resumable (range supported)', dl.resumable);
      check('size matches listing', dl.contentLength == iron.best.sizeBytes,
          'range=${dl.contentLength} vs listing=${iron.best.sizeBytes}');
    }
  } finally {
    total.stop();
    s.close();
  }

  print('\n${'=' * 60}');
  print('RESULT: $_passed passed, $_failed failed  —  total ${total.elapsedMilliseconds} ms');
  print('=' * 60);
}
