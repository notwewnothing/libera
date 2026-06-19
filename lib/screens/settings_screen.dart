import 'package:flutter/material.dart';
import 'package:libera/screens/about_screen.dart';
import 'package:libera/services/app_settings.dart';
import 'package:libera/services/continue_watching_service.dart';
import 'package:libera/services/download_source_service.dart';
import 'package:libera/services/player_service.dart';
import 'package:libera/services/stremio/stremio_addons_service.dart';
import 'package:libera/services/torrent/torrent_stream_service.dart';
import 'package:libera/services/watched_service.dart';

const _accent = Color(0xFF0A84FF);

/// One-off player chooser. Returns the player the user tapped (without changing
/// the saved default), or null if dismissed. Used by the long-press shortcut on
/// the Play button to switch player for a single playback.
Future<MediaPlayer?> showPlayerPicker(BuildContext context) {
  final current = PlayerService.instance.current;
  return showModalBottomSheet<MediaPlayer>(
    context: context,
    backgroundColor: const Color(0xFF1A1A1A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Play with",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Choose a player just for this time",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: kPlayers.length,
                itemBuilder: (context, index) {
                  final player = kPlayers[index];
                  final selected = player.id == current.id;
                  return ListTile(
                    title: Text(
                      player.name,
                      style: TextStyle(
                        color: selected ? _accent : Colors.white,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check, color: _accent)
                        : null,
                    onTap: () => Navigator.pop(context, player),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Stremio-style, sectioned settings: Player, Streaming (torrents), Downloads
/// and Stremio addons — every option persisted and wired to real behaviour.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text("Settings",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          AppSettings.instance,
          PlayerService.instance,
          DownloadSourceService.instance,
          StremioAddonsService.instance,
        ]),
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // ── Player ──────────────────────────────────────────────────
              const _SectionHeader("Player"),
              _Card([
                _DropdownTile<String>(
                  title: "Default player",
                  value: PlayerService.instance.current.id,
                  items: [
                    for (final p in kPlayers) (p.id, p.name),
                  ],
                  onChanged: (id) => PlayerService.instance.select(id),
                ),
                _SwitchTile(
                  title: "Autoplay next episode",
                  value: s.autoplayNext,
                  onChanged: s.setAutoplayNext,
                ),
                _SwitchTile(
                  title: "Resume from last position",
                  value: s.resumePlayback,
                  onChanged: s.setResumePlayback,
                ),
                _SliderTile(
                  title: "Default playback speed",
                  value: s.defaultPlaybackSpeed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 6,
                  label: "${s.defaultPlaybackSpeed}x",
                  onChanged: s.setDefaultPlaybackSpeed,
                ),
                _SliderTile(
                  title: "Subtitle size",
                  value: s.subtitleScale,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: "${(s.subtitleScale * 100).round()}%",
                  onChanged: s.setSubtitleScale,
                ),
                _SwitchTile(
                  title: "Subtitle background box",
                  subtitle: "Off = stylised outlined text · On = dim box behind",
                  value: s.subtitleBackground,
                  onChanged: s.setSubtitleBackground,
                ),
                _DropdownTile<int>(
                  title: "Skip interval",
                  value: s.skipSeconds,
                  items: const [(10, "10 sec"), (15, "15 sec"), (30, "30 sec")],
                  onChanged: s.setSkipSeconds,
                ),
              ]),
              _Caption("Applies to the offline / torrent player. Tip: "
                  "long-press Play to pick a different player once."),

              // ── Interface ───────────────────────────────────────────────
              const _SectionHeader("Interface"),
              _Card([
                _SwitchTile(
                  title: "Autoplay trailer",
                  subtitle: "Play the trailer in the background on a title page",
                  value: s.autoplayTrailer,
                  onChanged: s.setAutoplayTrailer,
                ),
              ]),

              // ── Streaming (torrents) ────────────────────────────────────
              const _SectionHeader("Streaming"),
              _Card([
                _DropdownTile<bool>(
                  title: "Torrent cache",
                  value: s.torrentCacheToRam,
                  items: const [(true, "RAM (faster)"), (false, "Disk")],
                  onChanged: s.setTorrentCacheToRam,
                ),
                if (s.torrentCacheToRam)
                  _DropdownTile<int>(
                    title: "RAM cache size",
                    value: s.torrentRamCacheMb,
                    items: const [
                      (100, "100 MB"),
                      (200, "200 MB"),
                      (400, "400 MB"),
                      (800, "800 MB"),
                    ],
                    onChanged: s.setTorrentRamCacheMb,
                  ),
                _SliderTile(
                  title: "Max peer connections",
                  value: s.torrentMaxConnections.toDouble(),
                  min: 20,
                  max: 200,
                  divisions: 18,
                  label: "${s.torrentMaxConnections}",
                  onChanged: (v) {
                    s.setTorrentMaxConnections(v.round());
                    TorrentStreamService.instance.applyConnectionsLimit();
                  },
                ),
                _SliderTile(
                  title: "Startup buffer",
                  value: s.torrentStartBufferSeconds,
                  min: 1,
                  max: 20,
                  divisions: 19,
                  label: "${s.torrentStartBufferSeconds.round()}s",
                  onChanged: (v) => s.setTorrentStartBufferSeconds(v),
                ),
              ]),
              _Caption("How torrent streams are buffered. Lower the startup "
                  "buffer to start playing faster; raise it if slow swarms "
                  "stutter at the start."),

              // ── Downloads ───────────────────────────────────────────────
              const _SectionHeader("Downloads"),
              _Card([
                _DropdownTile<String>(
                  title: "Download source",
                  value: DownloadSourceService.instance.current.id,
                  items: [
                    for (final src in kDownloadSources) (src.id, src.name),
                  ],
                  onChanged: (id) => DownloadSourceService.instance.select(id),
                ),
                _SliderTile(
                  title: "Max concurrent downloads",
                  value: s.maxConcurrentDownloads.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: "${s.maxConcurrentDownloads}",
                  onChanged: (v) => s.setMaxConcurrentDownloads(v.round()),
                ),
                _SwitchTile(
                  title: "Background downloads",
                  subtitle: "Keep downloading when the app is in the background",
                  value: s.backgroundDownloads,
                  onChanged: s.setBackgroundDownloads,
                ),
              ]),
              _Caption("Torrent and file downloads both appear in the "
                  "Downloads tab."),

              // ── Stremio addons ──────────────────────────────────────────
              const _SectionHeader("Stremio addons"),
              _Card([
                for (final addon in StremioAddonsService.instance.addons)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.extension_rounded,
                        color: Colors.white54, size: 20),
                    title: Text(addon.name,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white38, size: 18),
                      onPressed: () =>
                          StremioAddonsService.instance.removeAddon(addon.id),
                    ),
                  ),
                _NavTile(
                  icon: Icons.add,
                  title: "Add Stremio addon",
                  accent: true,
                  onTap: () => _showAddAddonDialog(context),
                ),
              ]),
              _Caption("Addons (e.g. AIOStreams) provide torrent sources for "
                  "the Torrents option on movies and episodes."),

              // ── Data & About ────────────────────────────────────────────
              const _SectionHeader("Data & about"),
              _Card([
                _NavTile(
                  icon: Icons.history_rounded,
                  title: "Clear Continue Watching",
                  onTap: () => _confirmClear(
                    context,
                    "Clear Continue Watching?",
                    "Removes all in-progress items.",
                    () {
                      for (final e in ContinueWatchingService.instance.entries) {
                        ContinueWatchingService.instance
                            .remove(e.card.id, isMovie: e.card.isMovie);
                      }
                    },
                  ),
                ),
                _NavTile(
                  icon: Icons.delete_sweep_rounded,
                  title: "Clear watch history",
                  onTap: () => _confirmClear(
                    context,
                    "Clear watch history?",
                    "Marks everything as unwatched.",
                    WatchedService.instance.clearAll,
                  ),
                ),
                _NavTile(
                  icon: Icons.info_outline_rounded,
                  title: "About Libera",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable, polished settings widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 20, 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card(this.children);

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(
            height: 1, color: Colors.white.withValues(alpha: 0.06), indent: 16));
      }
      rows.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: rows),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  final String text;
  const _Caption(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
      );
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45), fontSize: 12)),
        value: value,
        activeThumbColor: _accent,
        onChanged: onChanged,
      );
}

class _DropdownTile<T> extends StatelessWidget {
  final String title;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  const _DropdownTile({
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                dropdownColor: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                icon: const Icon(Icons.keyboard_arrow_down, color: _accent),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
                items: [
                  for (final (v, label) in items)
                    DropdownMenuItem(value: v, child: Text(label)),
                ],
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ],
        ),
      );
}

class _SliderTile extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;
  const _SliderTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
                Text(label,
                    style: const TextStyle(
                        color: _accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _accent,
                thumbColor: _accent,
                inactiveTrackColor: Colors.white24,
                overlayColor: _accent.withValues(alpha: 0.15),
                trackHeight: 3,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      );
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool accent;
  final VoidCallback onTap;
  const _NavTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: accent ? _accent : Colors.white70),
        title: Text(title,
            style: TextStyle(
                color: accent ? _accent : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        trailing: accent
            ? null
            : const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: onTap,
      );
}

/// Confirm-then-run a destructive "clear" action.
Future<void> _confirmClear(
  BuildContext context,
  String title,
  String message,
  VoidCallback onConfirm,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 17)),
      content: Text(message,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text("Clear", style: TextStyle(color: Color(0xFFE5484D))),
        ),
      ],
    ),
  );
  if (ok == true) {
    onConfirm();
    messenger.showSnackBar(SnackBar(
      content: const Text("Cleared"),
      backgroundColor: const Color(0xFF1A1A1A),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 1),
    ));
  }
}

/// Prompts for a Stremio addon manifest URL and installs it.
Future<void> _showAddAddonDialog(BuildContext context) async {
  final controller = TextEditingController();
  final url = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      title: const Text("Add Stremio addon",
          style: TextStyle(color: Colors.white, fontSize: 17)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "https://…/manifest.json",
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _accent)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text("Add", style: TextStyle(color: _accent)),
        ),
      ],
    ),
  );
  if (url == null || url.isEmpty || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final addon = await StremioAddonsService.instance.addAddon(url);
  messenger.showSnackBar(
    SnackBar(
      content: Text(addon != null
          ? "Added “${addon.name}”"
          : "Installed, but couldn’t read its manifest"),
      backgroundColor: const Color(0xFF1A1A1A),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
