import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:libera/common/utils.dart';
import 'package:libera/model/action.dart';
import 'package:libera/model/comedy.dart';
import 'package:libera/model/drama.dart';
import 'package:libera/model/horror.dart';
import 'package:libera/model/trending_all.dart';
import 'package:libera/model/popular.dart';
import 'package:libera/model/tendingshows.dart';
import 'package:libera/screens/Moviedetailed.dart';
import 'package:libera/screens/Tvshowdetailed.dart';
import 'package:libera/services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiServices apiServices = ApiServices();
  late Future<TrendingAll?> trendingData;
  late Future<PopularMovies?> popularMovies;
  late Future<TrendingShows?> trendingShows;
  late Future<ActionDiscover?> actionMovies;
  late Future<ComedyDiscover?> comedyMovies;
  late Future<HorrorDiscover?> horrorMovies;
  late Future<DramaDiscover?> dramaMovies;
  @override
  void initState() {
    trendingData = apiServices.fetchTrending();
    popularMovies = apiServices.popularMovies();
    trendingShows = apiServices.trendingshows();
    actionMovies = apiServices.actionMovies();
    comedyMovies = apiServices.comedyMovies();
    horrorMovies = apiServices.horrorMovies();
    dramaMovies = apiServices.dramaMovies();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 50),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  Text(
                    "DIH 🥀",
                    style: GoogleFonts.dangrek(
                      textStyle: const TextStyle(
                        color: Color.fromARGB(255, 255, 50, 50),
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.search, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.settings, color: Colors.white),
                  ),
                ],
              ),
            ),
            // Main Box
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 530,
                    width: double.maxFinite,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade800),
                    ),
                    child: FutureBuilder<TrendingAll?>(
                      future: trendingData,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(
                            child: Text("Error: ${snapshot.error}"),
                          );
                        } else if (snapshot.data == null) {
                          return Center(child: Text("No Data"));
                        } else if (snapshot.hasData) {
                          final items = snapshot.data!.results;
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: PageView.builder(
                              itemCount: items.length,
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => item.isMovie
                                            ? MovieDetailedScreen(
                                                movieid: item.id,
                                              )
                                            : TvShowDetailedScreen(
                                                tvid: item.id,
                                              ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    height: 530,
                                    width: 388,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: Colors.white,
                                      image: DecorationImage(
                                        fit: BoxFit.cover,
                                        image: CachedNetworkImageProvider(
                                          "$imageUrl${item.posterPath}",
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        } else {
                          return Center(child: Text("Problem Fetching Data"));
                        }
                      },
                    ),
                  ),
                  Positioned(
                    bottom: -40,
                    left: 17,

                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 50,
                            width: 150,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.play_arrow,
                                  color: Colors.black,
                                  size: 30,
                                ),
                                Text(
                                  "Play",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 15),
                          Container(
                            height: 50,
                            width: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade800,
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, color: Colors.white, size: 30),
                                Text(
                                  "My List",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),
            moviesTypes(future: popularMovies, movieType: "Trending Movies"),
            moviesTypes(
              future: trendingShows,
              movieType: "Trending Shows",
              isTvShow: true,
            ),
            moviesTypes(future: actionMovies, movieType: "Action"),
            moviesTypes(future: comedyMovies, movieType: "Comedy"),
            moviesTypes(future: horrorMovies, movieType: "Horror"),
            moviesTypes(future: dramaMovies, movieType: "Drama"),
          ],
        ),
      ),
    );
  }

  Padding moviesTypes({
    required Future future,
    required String movieType,
    bool isTvShow = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: 10, top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            movieType,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          SizedBox(
            height: 180,
            width: double.maxFinite,
            child: FutureBuilder(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                } else if (snapshot.data == null) {
                  return Center(child: Text("No Data"));
                } else if (snapshot.hasData) {
                  final popularMovies = snapshot.data!.results;
                  return ListView.builder(
                    itemCount: popularMovies.length,
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final movie = popularMovies[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => isTvShow
                                    ? TvShowDetailedScreen(tvid: movie.id)
                                    : MovieDetailedScreen(movieid: movie.id),
                              ),
                            );
                          },
                          child: Container(
                            width: 130,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              image: DecorationImage(
                                fit: BoxFit.cover,
                                image: CachedNetworkImageProvider(
                                  "$imageUrl${movie.posterPath}",
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                } else {
                  return Center(child: Text("Problem Fetching Data"));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
