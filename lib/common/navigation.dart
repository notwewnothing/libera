import 'package:flutter/material.dart';
import 'package:libera/screens/Moviedetailed.dart';
import 'package:libera/screens/Tvshowdetailed.dart';

/// Pushes the appropriate detail screen for a media item.
void openDetail(BuildContext context, {required int id, required bool isMovie}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => isMovie
          ? MovieDetailedScreen(movieid: id)
          : TvShowDetailedScreen(tvid: id),
    ),
  );
}
