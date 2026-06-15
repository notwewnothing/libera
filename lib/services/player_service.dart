import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A streaming source ("player"). URL templates use these tokens:
/// {id} TMDB id
/// {season} season number (tv only)
/// {episode} episode number (tv only)
/// {progress} optional resume marker, only honoured by players that

class MediaPlayer {
  final String id;
  final String name;
  final String movieTemplate;
  final String tvTemplate;

  const MediaPlayer({
    required this.id,
    required this.name,
    required this.movieTemplate,
    required this.tvTemplate,
  });

  String movieUrl(int tmdbId, {double startAt = 0}) =>
      _fill(movieTemplate, tmdbId: tmdbId, startAt: startAt);

  String episodeUrl(
    int tmdbId,
    int season,
    int episode, {
    double startAt = 0,
  }) => _fill(
    tvTemplate,
    tmdbId: tmdbId,
    season: season,
    episode: episode,
    startAt: startAt,
  );

  String _fill(
    String template, {
    required int tmdbId,
    int season = 1,
    int episode = 1,
    double startAt = 0,
  }) {
    final progress = startAt > 0 ? '&progress=${startAt.round()}' : '';
    return template
        .replaceAll('{id}', '$tmdbId')
        .replaceAll('{season}', '$season')
        .replaceAll('{episode}', '$episode')
        .replaceAll('{progress}', progress);
  }

  /// Registrableish domain (last two host labels) used to whitelist cuz vidfast riderects

  String get baseDomain {
    final host = Uri.parse(_fill(movieTemplate, tmdbId: 0)).host;
    final parts = host.split('.');
    return parts.length >= 2 ? parts.sublist(parts.length - 2).join('.') : host;
  }
}

/// vidking default
const List<MediaPlayer> kPlayers = [
  MediaPlayer(
    id: 'vidking',
    name: 'Vidking',
    movieTemplate:
        'https://www.vidking.net/embed/movie/{id}?color=e50914&autoPlay=true&nextEpisode=true&episodeSelector=true{progress}',
    tvTemplate:
        'https://www.vidking.net/embed/tv/{id}/{season}/{episode}?color=e50914&autoPlay=true&nextEpisode=true&episodeSelector=true{progress}',
  ),
  MediaPlayer(
    id: 'vidify',
    name: 'Vidify',
    movieTemplate:
        'https://player.vidify.top/embed/movie/{id}?autoplay=true&poster=true&chromecast=false&servericon=true&setting=true&pip=true&logourl=https%3A%2F%2Fi.ibb.co%2F67wTJd9R%2Fpngimg-com-netflix-PNG11.png&font=Roboto&fontcolor=6f63ff&fontsize=20&opacity=0.5&hidepip=true&primarycolor=e01b24&secondarycolor=1f2937&iconcolor=e01b24',
    tvTemplate:
        'https://player.vidify.top/embed/tv/{id}/{season}/{episode}?autoplay=true&poster=true&chromecast=false&servericon=true&setting=true&pip=true&logourl=https%3A%2F%2Fi.ibb.co%2F67wTJd9R%2Fpngimg-com-netflix-PNG11.png&font=Roboto&fontcolor=6f63ff&fontsize=20&opacity=0.5&hidepip=true&primarycolor=e01b24&secondarycolor=1f2937&iconcolor=e01b24',
  ),
  MediaPlayer(
    // very simple ad block
    id: 'videasy',
    name: 'Videasy',
    movieTemplate: 'https://player.videasy.to/movie/{id}?color=EF4444',
    tvTemplate:
        'https://player.videasy.to/tv/{id}/{season}/{episode}?color=EF4444&nextEpisode=true&episodeSelector=true&autoplayNextEpisode=true',
  ),
  MediaPlayer(
    id: 'vidfast',
    name: 'VidFast',
    movieTemplate: 'https://vidfast.pro/movie/{id}?autoplay=true',
    tvTemplate: 'https://vidfast.pro/tv/{id}/{season}/{episode}?autoplay=true',
  ),
  MediaPlayer(
    id: 'cinemaos',
    name: 'CinemaOS',
    movieTemplate: 'https://cinemaos.tech/movie/watch/{id}',
    tvTemplate:
        'https://cinemaos.tech/tv/watch/{id}?season={season}&episode={episode}',
  ),
  // ---- Added from the fmhy.net streaming/embed list (each probed live with a
  // known TMDB id; see testing/probe_players.sh). All four load directly on
  // their own registrable domain with no cross-domain top-level redirect, so
  // PlayerScreen's domain whitelist (baseDomain) doesn't block them.
  MediaPlayer(
    // Modern player; reflects the TMDB id and ships hls.js + jwplayer.
    id: 'vidlink',
    name: 'VidLink',
    movieTemplate:
        'https://vidlink.pro/movie/{id}?primaryColor=e50914&autoplay=true',
    tvTemplate:
        'https://vidlink.pro/tv/{id}/{season}/{episode}?primaryColor=e50914&autoplay=true&nextButton=true',
  ),
  MediaPlayer(
    // Classic multi-server. Resolved the correct movie *and* episode titles for
    // the probe ids, and its /embed/tv/{id}/{s}/{e} shape matches the
    // episode-change detector in player_screen so auto-advance tracking works.
    id: 'vidsrc',
    name: 'VidSrc',
    movieTemplate: 'https://vidsrcme.ru/embed/movie/{id}',
    tvTemplate: 'https://vidsrcme.ru/embed/tv/{id}/{season}/{episode}',
  ),
  MediaPlayer(
    // 2Embed multi-server; resolved the correct movie title for the probe id.
    id: '2embed',
    name: '2Embed',
    movieTemplate: 'https://www.2embed.skin/embed/{id}',
    tvTemplate: 'https://www.2embed.skin/embedtv/{id}&s={season}&e={episode}',
  ),
  MediaPlayer(
    id: '111movies',
    name: '111Movies',
    movieTemplate: 'https://111movies.net/movie/{id}',
    tvTemplate: 'https://111movies.net/tv/{id}/{season}/{episode}',
  ),
  // ---- From PlayTorrioV2's embed provider list (probed live, on-domain).
  MediaPlayer(
    id: 'vixsrc',
    name: 'VixSrc',
    movieTemplate: 'https://vixsrc.to/movie/{id}/',
    tvTemplate: 'https://vixsrc.to/tv/{id}/{season}/{episode}/',
  ),
  MediaPlayer(
    id: 'vidnest',
    name: 'VidNest',
    movieTemplate: 'https://vidnest.fun/movie/{id}',
    tvTemplate: 'https://vidnest.fun/tv/{id}/{season}/{episode}',
  ),
];

// local storage
class PlayerService extends ChangeNotifier {
  PlayerService._();
  static final PlayerService instance = PlayerService._();

  static const _prefsKey = 'selected_player';

  String _selectedId = kPlayers.first.id;
  bool _loaded = false;

  List<MediaPlayer> get players => kPlayers;

  MediaPlayer get current => kPlayers.firstWhere(
    (p) => p.id == _selectedId,
    orElse: () => kPlayers.first,
  );

  Future<void> init() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && kPlayers.any((p) => p.id == saved)) {
        _selectedId = saved;
      }
    } catch (e) {
      debugPrint('Failed to load selected player: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> select(String id) async {
    if (id == _selectedId || !kPlayers.any((p) => p.id == id)) return;
    _selectedId = id;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, id);
    } catch (e) {
      debugPrint('Failed to save selected player: $e');
    }
  }
}
