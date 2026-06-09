// Converts the various per-endpoint TMDB models into the shared [MediaCardData]
// the home/library cards consume. Each model lives in its own file with a
// class literally named `Result`, so the imports are prefixed to disambiguate.
import 'package:libera/common/media_widgets.dart';
import 'package:libera/common/genres.dart';
import 'package:libera/model/trending_all.dart';
import 'package:libera/model/popular.dart' as pop;
import 'package:libera/model/tendingshows.dart' as shows;
import 'package:libera/model/action.dart' as act;
import 'package:libera/model/comedy.dart' as com;
import 'package:libera/model/horror.dart' as hor;
import 'package:libera/model/drama.dart' as dra;

MediaCardData trendingToCard(TrendingItem t) => MediaCardData(
  id: t.id,
  title: t.displayTitle,
  posterPath: t.posterPath,
  backdropPath: t.backdropPath,
  genreLabel: primaryGenre(t.genreIds),
  typeLabel: t.isMovie ? "Movie" : "TV Show",
  isMovie: t.isMovie,
  overview: t.overview,
);

MediaCardData popularToCard(pop.Result r) => MediaCardData(
  id: r.id,
  title: r.title,
  posterPath: r.posterPath,
  backdropPath: r.backdropPath,
  genreLabel: primaryGenre(r.genreIds),
  typeLabel: "Movie",
  isMovie: true,
  overview: r.overview,
);

MediaCardData showToCard(shows.Result r) => MediaCardData(
  id: r.id,
  title: r.name,
  posterPath: r.posterPath,
  backdropPath: r.backdropPath,
  typeLabel: "TV Show",
  isMovie: false,
  overview: r.overview,
);

MediaCardData actionToCard(act.Result r, {String? genreLabel}) => MediaCardData(
  id: r.id,
  title: r.title,
  posterPath: r.posterPath,
  backdropPath: r.backdropPath,
  genreLabel: genreLabel,
  typeLabel: "Movie",
  isMovie: true,
  overview: r.overview,
);

MediaCardData comedyToCard(com.Result r, {String? genreLabel}) => MediaCardData(
  id: r.id,
  title: r.title,
  posterPath: r.posterPath,
  genreLabel: genreLabel,
  typeLabel: "Movie",
  isMovie: true,
  overview: r.overview,
);

MediaCardData horrorToCard(hor.Result r, {String? genreLabel}) => MediaCardData(
  id: r.id,
  title: r.title,
  posterPath: r.posterPath,
  genreLabel: genreLabel,
  typeLabel: "Movie",
  isMovie: true,
  overview: r.overview,
);

MediaCardData dramaToCard(dra.Result r, {String? genreLabel}) => MediaCardData(
  id: r.id,
  title: r.title,
  posterPath: r.posterPath,
  genreLabel: genreLabel,
  typeLabel: "Movie",
  isMovie: true,
  overview: r.overview,
);
