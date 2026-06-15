import 'package:flutter/material.dart';
import 'package:libera/screens/torrent_downloads_screen.dart';
import 'package:libera/services/download_source_service.dart';
import 'package:libera/services/player_service.dart';
import 'package:libera/services/stremio/stremio_addons_service.dart';

const _accent = Color(0xFF0A84FF);

/// One-off player chooser. Returns the player the user tapped (without
/// changing the saved default), or null if dismissed. Used by the long-press
/// shortcut on the Play button to switch player for a single playback.
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
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: selected
                        ? Text(
                            "Default",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                            ),
                          )
                        : null,
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

/// App settings. Currently lets the user pick the default streaming player.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Settings",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          PlayerService.instance,
          DownloadSourceService.instance,
          StremioAddonsService.instance,
        ]),
        builder: (context, _) {
          final current = PlayerService.instance.current;
          final source = DownloadSourceService.instance.current;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 6),
                child: Text(
                  "PLAYER",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Default player",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: current.id,
                          dropdownColor: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: _accent,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          items: [
                            for (final player in kPlayers)
                              DropdownMenuItem(
                                value: player.id,
                                child: Text(player.name),
                              ),
                          ],
                          onChanged: (id) {
                            if (id != null) PlayerService.instance.select(id);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(
                  "Used for every movie and episode. Tip: long-press the Play "
                  "button to use a different player just once.",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 28, 20, 6),
                child: Text(
                  "DOWNLOAD SOURCE",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Download from",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: source.id,
                          dropdownColor: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: _accent,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          items: [
                            for (final s in kDownloadSources)
                              DropdownMenuItem(
                                value: s.id,
                                child: Text(s.name),
                              ),
                          ],
                          onChanged: (id) {
                            if (id != null) {
                              DownloadSourceService.instance.select(id);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(
                  "Where movies and episodes are downloaded from. Switch "
                  "sources if a title isn’t found on the current one.",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 28, 20, 6),
                child: Text(
                  "TORRENTS & STREMIO",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded, color: _accent),
                title: const Text("Torrent downloads",
                    style: TextStyle(color: Colors.white, fontSize: 16)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TorrentDownloadsScreen()),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 6),
                child: Text(
                  "Stremio addons",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final addon in StremioAddonsService.instance.addons)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.extension_rounded,
                      color: Colors.white54, size: 20),
                  title: Text(addon.name,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 14)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                    onPressed: () =>
                        StremioAddonsService.instance.removeAddon(addon.id),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.add, color: _accent),
                title: const Text("Add Stremio addon",
                    style: TextStyle(color: _accent, fontSize: 14)),
                onTap: () => _showAddAddonDialog(context),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Text(
                  "Addons (e.g. AIOStreams) provide torrent sources for the ⚡ "
                  "button on movies and episodes.",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
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
          focusedBorder:
              const UnderlineInputBorder(borderSide: BorderSide(color: _accent)),
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
