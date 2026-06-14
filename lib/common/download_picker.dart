import 'package:flutter/material.dart';
import 'package:libera/common/download_widgets.dart';
import 'package:libera/services/index_scraper.dart';

const _sheetBg = Color(0xFF1C1C1E);

String humanSize(int bytes) {
  if (bytes <= 0) return "—";
  const units = ["B", "KB", "MB", "GB", "TB"];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return "${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}";
}

Widget _grabber() => Container(
  margin: const EdgeInsets.symmetric(vertical: 10),
  width: 38,
  height: 4,
  decoration: BoxDecoration(
    color: Colors.white.withValues(alpha: 0.25),
    borderRadius: BorderRadius.circular(2),
  ),
);

Widget _header(String title, String subtitle) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
      ),
    ],
  ),
);

/// Ask the user which file to download when an episode/movie has 2+ sources.
/// Returns null if dismissed. (Caller should skip this when there's only one.)
Future<VideoFile?> pickSource(
  BuildContext context,
  String title,
  List<VideoFile> sources,
) {
  return showModalBottomSheet<VideoFile>(
    context: context,
    backgroundColor: _sheetBg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _grabber(),
            _header("Choose a source", title),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                itemCount: sources.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (_, i) {
                  final s = sources[i];
                  return _SourceTile(
                    quality: s.quality.label,
                    size: humanSize(s.sizeBytes),
                    detail: [
                      if (s.quality.audio != null) s.quality.audio!,
                      if (s.quality.group != null) s.quality.group!,
                    ].join(" · "),
                    best: i == 0,
                    onTap: () => Navigator.pop(ctx, s),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Ask the user which release "set" to grab for a whole-season download.
/// Returns null if dismissed.
Future<SeasonVariant?> pickSeasonVariant(
  BuildContext context,
  String showTitle,
  int season,
  List<SeasonVariant> variants,
) {
  return showModalBottomSheet<SeasonVariant>(
    context: context,
    backgroundColor: _sheetBg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _grabber(),
            _header("Choose quality", "$showTitle · Season $season"),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                itemCount: variants.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (_, i) {
                  final v = variants[i];
                  return _SourceTile(
                    quality: v.label,
                    size: humanSize(v.totalBytes),
                    detail: v.coverageLabel,
                    best: i == 0,
                    complete: v.isComplete,
                    onTap: () => Navigator.pop(ctx, v),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SourceTile extends StatelessWidget {
  final String quality;
  final String size;
  final String detail;
  final bool best;
  final bool complete;
  final VoidCallback onTap;

  const _SourceTile({
    required this.quality,
    required this.size,
    required this.detail,
    required this.onTap,
    this.best = false,
    this.complete = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          quality,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (best) ...[
                        const SizedBox(width: 8),
                        _Badge(complete ? "Best · Complete" : "Best"),
                      ],
                    ],
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              size,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_circle_down, color: downloadAccent, size: 24),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: downloadAccent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: downloadAccent,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
