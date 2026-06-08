import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:libera/screens/home.dart';
import 'package:libera/screens/search.dart';

class AppNavbarScreen extends StatelessWidget {
  const AppNavbarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        bottomNavigationBar: Container(
          color: Colors.black,
          height: 70,
          child: TabBar(
            tabs: [
              Tab(icon: Icon(Iconsax.home5), text: "Home"),
              Tab(icon: Icon(Iconsax.search_normal), text: "Search"),
              Tab(icon: Icon(Iconsax.document_download5), text: "Downloads"),
            ],
            unselectedLabelColor: Colors.grey,
            labelColor: Colors.white,
            indicatorColor: Colors.transparent,
          ),
        ),
        body: TabBarView(children: [HomeScreen(), SearchScreen(), Scaffold()]),
      ),
    );
  }
}
