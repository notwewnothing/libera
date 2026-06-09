import 'package:http/http.dart';
import 'package:libera/common/utils.dart';
import 'package:libera/model/action.dart';
import 'package:libera/model/drama.dart';
import 'package:libera/model/horror.dart';
import 'package:libera/model/comedy.dart';
import 'package:libera/model/search_model.dart';
import 'package:libera/model/trending_all.dart';
import 'package:libera/model/movie_details.dart';
import 'package:libera/model/movie_video.dart';
import 'package:libera/model/watch_provider.dart';
import 'package:libera/model/credits.dart';
import 'package:libera/model/media_list.dart';
import 'package:libera/model/tv_details.dart';
import 'package:libera/model/popular.dart';
import 'package:libera/model/tendingshows.dart';

var key = "api_key=$apikey";

class ApiServices {
  // all trending (movies + tv shows)
  Future<TrendingAll?> fetchTrending() async {
    try {
      const endPoint = "trending/all/day?";
      final apiUrl = "$baseUrl$endPoint$key";
      final response = await get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        return trendingAllFromJson(response.body);
      } else {
        throw Exception("Failed to Load trending");
      }
    } catch (e) {
      throw Exception("Error while Fetching Trending : $e ");
    }
  }

  // trending
  Future<PopularMovies?> popularMovies() async {
    try {
      const endPoint = "trending/movie/week?";
      final apiUrl = "$baseUrl$endPoint$key";
      final response = await get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        return popularMoviesFromJson(response.body);
      } else {
        throw Exception("Failed to Load movies");
      }
    } catch (e) {
      throw Exception("Error while Fetching Movies : $e ");
    }
  }

  // trending shows
  Future<TrendingShows?> trendingshows() async {
    try {
      const endPoint = "trending/tv/week?";
      final apiUrl = "$baseUrl$endPoint$key";
      final response = await get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        return trendingShowsFromJson(response.body);
      } else {
        throw Exception("Failed to Load movies");
      }
    } catch (e) {
      throw Exception("Error while Fetching Movies : $e ");
    }
  }

  // action
  Future<ActionDiscover?> actionMovies() async {
    try {
      const endPoint = "discover/movie?sort_by=popularity.desc&with_genres=28&";
      final apiUrl = "$baseUrl$endPoint$key";
      final response = await get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        return actionDiscoverFromJson(response.body);
      } else {
        throw Exception("Failed to Load movies");
      }
    } catch (e) {
      throw Exception("Error while Fetching Movies : $e ");
    }
  }

  //comedy
  Future<ComedyDiscover?> comedyMovies() async {
    try {
      const endPoint = "discover/movie?sort_by=popularity.desc&with_genres=35&";
      final apiUrl = "$baseUrl$endPoint$key";
      final response = await get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        return comedyDiscoverFromJson(response.body);
      } else {
        throw Exception("Failed to Load movies");
      }
    } catch (e) {
      throw Exception("Error while Fetching Movies : $e ");
    }
  }

  //horror
  Future<HorrorDiscover?> horrorMovies() async {
    try {
      const endPoint = "discover/movie?sort_by=popularity.desc&with_genres=27&";
      final apiUrl = "$baseUrl$endPoint$key";
      final response = await get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        return horrorDiscoverFromJson(response.body);
      } else {
        throw Exception("Failed to Load movies");
      }
    } catch (e) {
      throw Exception("Error while Fetching Movies : $e ");
    }
  }

  // drama
  Future<DramaDiscover?> dramaMovies() async {
    try {
      const endPoint = "discover/movie?sort_by=popularity.desc&with_genres=18&";
      final apiUrl = "$baseUrl$endPoint$key";
      final response = await get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        return dramaDiscoverFromJson(response.body);
      } else {
        throw Exception("Failed to Load movies");
      }
    } catch (e) {
      throw Exception("Error while Fetching Movies : $e ");
    }
  }

  //movie details
  Future<MovieDetails?> movieDetails(int movieId) async {
    try {
      final endPoint = "movie/$movieId?";
      final apiUrl = "$baseUrl$endPoint$key";
      final response = await get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        return movieDetailsFromJson(response.body);
      } else {
        throw Exception("Failed to Load Movie Details");
      }
    } catch (e) {
      throw Exception("Error while Fetching Movie Details : $e ");
    }
  }

  // watch providers
  Future<WatchProviders?> fetchWatchProviders(int movieId) async {
    try {
      final endPoint = "movie/$movieId/watch/providers?";
      final apiUrl = "$baseUrl$endPoint$key";
      final response = await get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        return watchProvidersFromJson(response.body);
      } else {
        throw Exception("Failed to Load Watch Providers");
      }
    } catch (e) {
      throw Exception("Error while Fetching Watch Providers : $e ");
    }
  }

  // movie video details
  Future<MovieVideo?> fetchMovieVideo(int movieId) async {
    try {
      final endPoint = "movie/$movieId/videos?";
      final apiUrl = "$baseUrl$endPoint$key";
      final response = await get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        return movieVideoFromJson(response.body);
      } else {
        throw Exception("Failed to Load Movie Videos");
      }
    } catch (e) {
      throw Exception("Error while Fetching Movie Videos : $e ");
    }
  }

  // movie cast
  Future<Credits?> fetchMovieCredits(int movieId) async {
    try {
      final endPoint = "movie/$movieId/credits?";
      final apiUrl = "$baseUrl$endPoint$key";
      final response = await get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        return creditsFromJson(response.body);
      } else {
        throw Exception("Failed to Load Movie Credits");
      }
    } catch (e) {
      throw Exception("Error while Fetching Movie Credits : $e ");
    }
  }

  // similar movies
  Future<MediaList?> fetchSimilarMovies(int movieId) async {
    try {
      final endPoint = "movie/$movieId/similar?";
      final apiUrl = "$baseUrl$endPoint$key";
      final response = await get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        return mediaListFromJson(response.body);
      } else {
        throw Exception("Failed to Load Similar Movies");
      }
    } catch (e) {
      throw Exception("Error while Fetching Similar Movies : $e ");
    }
  }

  // tv show details
  Future<TvDetails?> tvDetails(int tvId) async {
    try {
      final endPoint = "tv/$tvId?";
      final apiUrl = "$baseUrl$endPoint$key";
      final response = await get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        return tvDetailsFromJson(response.body);
      } else {
        throw Exception("Failed to Load TV Details");
      }
    } catch (e) {
      throw Exception("Error while Fetching TV Details : $e ");
    }
  }

  // tv video details
  Future<MovieVideo?> fetchTvVideo(int tvId) async {
    try {
      final endPoint = "tv/$tvId/videos?";
      final apiUrl = "$baseUrl$endPoint$key";
      final response = await get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        return movieVideoFromJson(response.body);
      } else {
        throw Exception("Failed to Load TV Videos");
      }
    } catch (e) {
      throw Exception("Error while Fetching TV Videos : $e ");
    }
  }

  // tv watch providers
  Future<WatchProviders?> fetchTvWatchProviders(int tvId) async {
    try {
      final endPoint = "tv/$tvId/watch/providers?";
      final apiUrl = "$baseUrl$endPoint$key";
      final response = await get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        return watchProvidersFromJson(response.body);
      } else {
        throw Exception("Failed to Load TV Watch Providers");
      }
    } catch (e) {
      throw Exception("Error while Fetching TV Watch Providers : $e ");
    }
  }

  // tv cast
  Future<Credits?> fetchTvCredits(int tvId) async {
    try {
      final endPoint = "tv/$tvId/credits?";
      final apiUrl = "$baseUrl$endPoint$key";
      final response = await get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        return creditsFromJson(response.body);
      } else {
        throw Exception("Failed to Load TV Credits");
      }
    } catch (e) {
      throw Exception("Error while Fetching TV Credits : $e ");
    }
  }

  // similar tv shows
  Future<MediaList?> fetchSimilarTvShows(int tvId) async {
    try {
      final endPoint = "tv/$tvId/similar?";
      final apiUrl = "$baseUrl$endPoint$key";
      final response = await get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        return mediaListFromJson(response.body);
      } else {
        throw Exception("Failed to Load Similar TV Shows");
      }
    } catch (e) {
      throw Exception("Error while Fetching Similar TV Shows : $e ");
    }
  }

  // search

  Future<Search?> fetchSearch(String query) async {
    try {
      final endPoint = "search/multi?query=${Uri.encodeQueryComponent(query)}&";
      final apiUrl = "$baseUrl$endPoint$key";
      final response = await get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        return searchFromJson(response.body);
      } else {
        throw Exception("Failed to Search");
      }
    } catch (e) {
      throw Exception("Error while Searching : $e ");
    }
  }

  // discover movies for any genre id (shape matches the action discover model)
  Future<ActionDiscover?> discoverByGenre(int genreId) async {
    try {
      final endPoint =
          "discover/movie?sort_by=popularity.desc&with_genres=$genreId&";
      final apiUrl = "$baseUrl$endPoint$key";
      final response = await get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        return actionDiscoverFromJson(response.body);
      } else {
        throw Exception("Failed to Load genre");
      }
    } catch (e) {
      throw Exception("Error while Fetching genre : $e ");
    }
  }

  // multi search (movies + tv) — reuses the trending list shape
  Future<TrendingAll?> searchMulti(String query) async {
    try {
      final endPoint =
          "search/multi?query=${Uri.encodeQueryComponent(query)}&include_adult=false&";
      final apiUrl = "$baseUrl$endPoint$key";
      final response = await get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        return trendingAllFromJson(response.body);
      } else {
        throw Exception("Failed to Search");
      }
    } catch (e) {
      throw Exception("Error while Searching : $e ");
    }
  }
}
