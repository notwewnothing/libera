import 'package:flutter/material.dart';
import 'package:libera/common/download_picker.dart';
import 'package:libera/common/media_widgets.dart';
import 'package:libera/services/download_source_service.dart';
import 'package:libera/services/downloads_service.dart';
import 'package:libera/services/index_scraper.dart';

/// TMDB-side metadata for an episode, used to label real downloads nicely.
class EpisodeMeta {
  final String name;
  final String? stillPath;
  final String? runtimeLabel;
  const EpisodeMeta({required this.name, this.stillPath, this.runtimeLabel});
}

/// Bridges the scraper backend, the choose-a-source UI and the download engine.
///
/// Flow: resolve the title on the index → if there is more than one file, ask
/// the user to pick → hand the chosen [VideoFile] to [DownloadsService] which
/// streams it to disk.
class DownloadManager {
  DownloadManager._();
  static final DownloadManager instance = DownloadManager._();

  /// The active download backend (user-selectable, see DownloadSourceService).
  DownloadSource get _scraper => DownloadSourceService.instance.current;

  // Per-title caches so picking several episodes only resolves the season once.
  // Keyed by source id too, so switching sources never returns stale results.
  final Map<String, Future<ShowResult?>> _shows = {};
  final Map<String, Future<SeasonResult>> _seasons = {};

  Future<ShowResult?> _show(MediaCardData show) => _shows.putIfAbsent(
    '${_scraper.id}:${show.id}',
    () => _scraper.resolveShow(show.title),
  );

  Future<SeasonResult>? _seasonCached(int showId, int season) =>
      _seasons['${_scraper.id}:$showId:$season'];

  // ---- Movies -------------------------------------------------------------

  Future<void> downloadMovie(
    BuildContext context,
    MediaCardData card, {
    int? year,
    String? runtimeLabel,
  }) async {
    if (DownloadsService.instance.has(DownloadsService.movieKey(card.id))) {
      _snack(context, "Already in downloads");
      return;
    }
    final result = await _resolving(
      context,
      "Finding “${card.title}”…",
      () => _scraper.resolveMovie(card.title, year: year),
    );
    if (!context.mounted) return;
    if (result == null || result.sources.isEmpty) {
      _snack(context, "Couldn’t find “${card.title}” to download");
      return;
    }
    final chosen = await _chooseSource(context, card.title, result.sources);
    if (chosen == null || !context.mounted) return;
    DownloadsService.instance.downloadMovie(
      card,
      runtimeLabel: runtimeLabel,
      source: chosen,
    );
    _snack(context, "Downloading “${card.title}”");
  }

  // ---- Single episode -----------------------------------------------------

  Future<void> downloadEpisode(
    BuildContext context,
    MediaCardData show, {
    required int season,
    required int episode,
    required String name,
    String? stillPath,
    String? runtimeLabel,
  }) async {
    final key = DownloadsService.episodeKey(show.id, season, episode);
    if (DownloadsService.instance.has(key)) {
      _snack(context, "Already in downloads");
      return;
    }
    final result = await _resolving(
      context,
      "Finding “${show.title}” S$season·E$episode…",
      () => _resolveSeason(show, season),
    );
    if (!context.mounted) return;
    EpisodeResult? ep;
    for (final e in result?.episodes ?? const <EpisodeResult>[]) {
      if (e.episode == episode) {
        ep = e;
        break;
      }
    }
    if (ep == null || ep.sources.isEmpty) {
      _snack(context, "Couldn’t find that episode to download");
      return;
    }
    final label = "${show.title} · S$season E$episode";
    final chosen = await _chooseSource(context, label, ep.sources);
    if (chosen == null || !context.mounted) return;
    DownloadsService.instance.downloadEpisode(
      show,
      season: season,
      episode: episode,
      name: name,
      stillPath: stillPath,
      runtimeLabel: runtimeLabel,
      source: chosen,
    );
    _snack(context, "Downloading “$name”");
  }

  // ---- Whole season -------------------------------------------------------

  Future<void> downloadSeason(
    BuildContext context,
    MediaCardData show,
    int season, {
    Map<int, EpisodeMeta> meta = const {},
  }) async {
    final result = await _resolving(
      context,
      "Finding “${show.title}” Season $season…",
      () => _resolveSeason(show, season),
    );
    if (!context.mounted) return;
    if (result == null || result.variants.isEmpty) {
      _snack(context, "Couldn’t find Season $season to download");
      return;
    }
    final variant = result.variants.length == 1
        ? result.variants.first
        : await pickSeasonVariant(context, show.title, season, result.variants);
    if (variant == null || !context.mounted) return;

    var queued = 0;
    for (final file in variant.files) {
      final ep = file.episode;
      if (ep == null) continue;
      final key = DownloadsService.episodeKey(show.id, season, ep);
      if (DownloadsService.instance.has(key)) continue;
      final m = meta[ep];
      DownloadsService.instance.downloadEpisode(
        show,
        season: season,
        episode: ep,
        name: m?.name ?? file.episodeTitle ?? "Episode $ep",
        stillPath: m?.stillPath,
        runtimeLabel: m?.runtimeLabel,
        source: file,
      );
      queued++;
    }
    _snack(
      context,
      queued == 0
          ? "Season $season already downloaded"
          : "Downloading $queued episode${queued == 1 ? '' : 's'}",
    );
  }

  // ---- Resolution helpers -------------------------------------------------

  Future<SeasonResult?> _resolveSeason(MediaCardData show, int season) async {
    final cached = _seasonCached(show.id, season);
    if (cached != null) return cached;
    final showResult = await _show(show);
    if (showResult == null) return null;
    SeasonRef? ref;
    for (final s in showResult.seasons) {
      if (s.number == season) {
        ref = s;
        break;
      }
    }
    if (ref == null) return null;
    final future = _scraper.resolveSeason(ref);
    _seasons['${_scraper.id}:${show.id}:$season'] = future;
    return future;
  }

  Future<VideoFile?> _chooseSource(
    BuildContext context,
    String title,
    List<VideoFile> sources,
  ) async {
    if (sources.length == 1) return sources.first;
    return pickSource(context, title, sources);
  }

  /// Run [task] behind a small non-dismissible "finding…" dialog.
  Future<T?> _resolving<T>(
    BuildContext context,
    String label,
    Future<T> Function() task,
  ) async {
    final nav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => _ResolvingDialog(label: label),
    );
    T? result;
    try {
      result = await task();
    } catch (_) {
      result = null;
    }
    if (nav.canPop()) nav.pop();
    return result;
  }

  void _snack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ResolvingDialog extends StatelessWidget {
  final String label;
  const _ResolvingDialog({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation(Color(0xFF0A84FF)),
              ),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
