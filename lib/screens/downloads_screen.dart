import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:libera/common/download_widgets.dart';
import 'package:libera/services/downloads_service.dart';

Widget _circleBack(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.only(left: 8),
    child: GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade800.withValues(alpha: 0.6),
        ),
        child: const Icon(Icons.chevron_left, color: Colors.white),
      ),
    ),
  );
}

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: _circleBack(context),
        title: const Text(
          "Downloads",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: DownloadsService.instance,
          builder: (context, _) {
            final service = DownloadsService.instance;
            final groups = service.library;
            final hasActive = service.downloadingCount > 0;

            if (groups.isEmpty) return const _EmptyDownloads();

            return ListView(
              padding: const EdgeInsets.only(top: 6, bottom: 24),
              children: [
                if (hasActive)
                  _DownloadingTile(count: service.downloadingCount),
                for (final group in groups) _libraryRow(context, group),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _libraryRow(BuildContext context, DownloadGroup group) {
    if (group.isMovie) {
      final entry = group.entries.first;
      return DownloadRow(
        title: entry.title,
        subtitle: entry.isCompleted ? entry.subtitle : "Downloading…",
        thumbnailPath: entry.thumbnailPath,
        entry: entry,
        showProgressBar: true,
        onMore: () => _movieMenu(context, entry),
        onTap: () => _movieMenu(context, entry),
      );
    }
    final count = group.entries.length;
    return DownloadRow(
      title: group.media.title,
      subtitle: "$count ${count == 1 ? "episode" : "episodes"}",
      thumbnailPath: group.media.backdropPath ?? group.media.posterPath,
      fallbackIcon: Icons.tv,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DownloadShowScreen(showId: group.media.id),
        ),
      ),
    );
  }

  void _movieMenu(BuildContext context, DownloadEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text(
                "Remove Download",
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(context);
                DownloadsService.instance.remove(entry.key);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadingTile extends StatelessWidget {
  final int count;
  const _DownloadingTile({required this.count});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DownloadingScreen()),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Iconsax.arrow_down_1,
                color: downloadAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Downloading",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "$count in progress",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.4),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Iconsax.document_download,
            color: Colors.white24,
            size: 56,
          ),
          const SizedBox(height: 14),
          Text(
            "No downloads yet",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Downloaded titles will appear here.",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Per-show downloads with an Edit / multi-select / delete flow, mirroring the
/// Apple TV "Library" detail screen.
class DownloadShowScreen extends StatefulWidget {
  final int showId;
  const DownloadShowScreen({super.key, required this.showId});

  @override
  State<DownloadShowScreen> createState() => _DownloadShowScreenState();
}

class _DownloadShowScreenState extends State<DownloadShowScreen> {
  bool _editing = false;
  final Set<String> _selected = {};

  void _exitEdit() {
    setState(() {
      _editing = false;
      _selected.clear();
    });
  }

  void _toggle(String key) {
    setState(() {
      if (!_selected.add(key)) _selected.remove(key);
    });
  }

  void _selectAll(List<DownloadEntry> visible) {
    setState(() {
      final allSelected = visible.every((e) => _selected.contains(e.key));
      if (allSelected) {
        _selected.clear();
      } else {
        _selected.addAll(visible.map((e) => e.key));
      }
    });
  }

  void _confirmDelete(BuildContext context) {
    final count = _selected.length;
    if (count == 0) return;
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF2C2C2E),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Text(
                "These downloads will permanently be deleted from your device.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),
            InkWell(
              onTap: () {
                final keys = _selected.toList();
                Navigator.pop(context);
                DownloadsService.instance.removeAll(keys);
                _exitEdit();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  count == 1 ? "Delete 1 Download" : "Delete $count Downloads",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: DownloadsService.instance,
          builder: (context, _) {
            final service = DownloadsService.instance;
            final seasons = service.seasonsFor(widget.showId);

            // If everything is gone, pop back to the Downloads list.
            if (seasons.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.pop(context);
              });
              return const SizedBox.shrink();
            }

            final allVisible = [
              for (final s in seasons) ...service.episodesFor(widget.showId, s),
            ];
            // Drop any stale selections that no longer exist.
            _selected.retainWhere(
              (k) => allVisible.any((e) => e.key == k),
            );
            final show = allVisible.first.parent;
            final allSelected =
                allVisible.isNotEmpty &&
                allVisible.every((e) => _selected.contains(e.key));

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _header(context, show.title, allVisible, allSelected),
                ),
                for (final season in seasons) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                      child: Text(
                        "Season $season",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SliverList.separated(
                    itemCount: service.episodesFor(widget.showId, season).length,
                    separatorBuilder: (_, _) => Padding(
                      padding: const EdgeInsets.only(left: 134),
                      child: Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    itemBuilder: (context, index) {
                      final e =
                          service.episodesFor(widget.showId, season)[index];
                      return DownloadRow(
                        title: e.title,
                        subtitle: e.subtitle,
                        thumbnailPath: e.thumbnailPath,
                        fallbackIcon: Icons.tv,
                        entry: e,
                        selectionMode: _editing,
                        selected: _selected.contains(e.key),
                        onMore: _editing
                            ? null
                            : () => _episodeMenu(context, e),
                        onTap: _editing
                            ? () => _toggle(e.key)
                            : () => _episodeMenu(context, e),
                      );
                    },
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    String title,
    List<DownloadEntry> visible,
    bool allSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: [
              if (_editing)
                _PillButton(label: "Cancel", onTap: _exitEdit)
              else
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade800.withValues(alpha: 0.6),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.chevron_left, color: Colors.white),
                  ),
                ),
              const Spacer(),
              if (_editing) ...[
                _PillButton(
                  label: allSelected ? "Deselect All" : "Select All",
                  onTap: () => _selectAll(visible),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _selected.isEmpty
                      ? null
                      : () => _confirmDelete(context),
                  child: Text(
                    "Delete",
                    style: TextStyle(
                      color: _selected.isEmpty
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.redAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else
                _PillButton(
                  label: "Edit",
                  onTap: () => setState(() => _editing = true),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }

  void _episodeMenu(BuildContext context, DownloadEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text(
                "Remove Download",
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(context);
                DownloadsService.instance.remove(entry.key);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PillButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.grey.shade800.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class DownloadingScreen extends StatelessWidget {
  const DownloadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: _circleBack(context),
        title: const Text(
          "Downloading",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: DownloadsService.instance,
        builder: (context, _) {
          final items = DownloadsService.instance.downloading;
          if (items.isEmpty) return _empty();
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: items.length,
            separatorBuilder: (_, _) => Padding(
              padding: const EdgeInsets.only(left: 134),
              child: Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            itemBuilder: (context, index) {
              final e = items[index];
              final pct = (e.progress * 100).clamp(0, 100).toInt();
              return DownloadRow(
                title: e.isMovie ? e.title : "${e.parent.title} · ${e.title}",
                subtitle: "Downloading… $pct%",
                thumbnailPath: e.thumbnailPath,
                fallbackIcon: e.isMovie ? Icons.movie : Icons.tv,
                entry: e,
                showProgressBar: true,
                onMore: () => DownloadsService.instance.remove(e.key),
              );
            },
          );
        },
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.arrow_down_1, color: Colors.white24, size: 56),
          const SizedBox(height: 14),
          Text(
            "Nothing downloading",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Active downloads will show their progress here.",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
