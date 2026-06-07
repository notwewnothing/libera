import 'package:flutter/material.dart';
import 'package:libera/screens/nv_bar.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  @override
  void initState() {
    super.initState();
    // Schedule navigation immediately after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AppNavbarScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Returns an empty container since no visual asset is displayed
    return const Scaffold(body: SizedBox.shrink());
  }
}
