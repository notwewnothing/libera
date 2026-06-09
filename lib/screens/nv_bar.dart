import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:libera/screens/home.dart';
import 'package:libera/screens/search.dart';

const _accent = Color(0xFF0A84FF);

class AppNavbarScreen extends StatefulWidget {
  const AppNavbarScreen({super.key});

  @override
  State<AppNavbarScreen> createState() => _AppNavbarScreenState();
}

class _AppNavbarScreenState extends State<AppNavbarScreen> {
  int _index = 0;

  static const _tabs = [
    (icon: Iconsax.home5, label: "Home"),
    (icon: Iconsax.search_normal, label: "Search"),
    (icon: Iconsax.video_square, label: "Library"),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: const [HomeScreen(), SearchScreen(), _LibraryScreen()],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 66,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
              child: Row(
                children: List.generate(_tabs.length, (i) => _tab(i)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(int i) {
    final tab = _tabs[i];
    final selected = i == _index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _index = i),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                tab.icon,
                size: 24,
                color: selected
                    ? _accent
                    : Colors.white.withValues(alpha: 0.65),
              ),
              const SizedBox(height: 3),
              Text(
                tab.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? _accent
                      : Colors.white.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryScreen extends StatelessWidget {
  const _LibraryScreen();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                "Library",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Iconsax.video_square,
                      color: Colors.white24,
                      size: 56,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "Your library is empty",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Movies and shows you add will appear here.",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
