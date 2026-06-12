import 'package:flutter/material.dart';
import 'package:libera/screens/intro.dart';
import 'package:libera/services/continue_watching_service.dart';
import 'package:libera/services/watched_service.dart';
import 'package:libera/services/watchlist_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    WatchlistService.instance.init(),
    WatchedService.instance.init(),
    ContinueWatchingService.instance.init(),
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: IntroScreen(),
      debugShowCheckedModeBanner: false,
      title: "Libera",
    );
  }
}
