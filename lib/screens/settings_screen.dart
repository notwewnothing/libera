import 'package:flutter/material.dart';
import 'package:libera/services/player_service.dart';

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
        listenable: PlayerService.instance,
        builder: (context, _) {
          final current = PlayerService.instance.current;
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
            ],
          );
        },
      ),
    );
  }
}
