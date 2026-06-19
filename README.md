# Libera

<img src="logo.png" width="120" alt="Libera logo"/>

A cross-platform Flutter app for browsing and watching movies and TV shows. Powered by the TMDB API, with multiple streaming backends and offline download support.

## Features

- **Browse & discover** — trending, popular, top-10, genre lists, and full-text search across movies and TV shows
- **Detailed info** — cast, trailers, watch providers, season/episode breakdowns
- **Streaming**
  - Embedded web players (configurable list of streaming sites via in-app WebView)
  - YouTube trailers
  - Native video player (media_kit) for direct links and torrents
  - Stremio addon support (AIOStreams) for additional stream sources
  - Torrent streaming via libtorrent_flutter
- **Downloads** — background file downloads from two sources: a scraper-backed index site (`a.111477.xyz`) and Vadapav; managed by a persistent foreground service on Android
- **Watchlist & history** — save titles, track watched episodes, resume where you left off
- **Settings** — choose active streaming player, download source, and other preferences

## Platforms

| Platform | Status |
|----------|--------|
| Android  | Supported |
| iOS / macOS | Supported |
| Web      | Supported |
| Windows  | Supported |
| Linux    | Supported |

## Tech stack

- **Flutter / Dart** — UI and app logic
- **TMDB API** — metadata (movies, TV shows, cast, trailers, providers)
- **media_kit** — native video playback
- **libtorrent_flutter** — torrent streaming and downloading
- **webview_flutter** — embedded web players
- **youtube_explode_dart / youtube_player_flutter** — YouTube playback
- **shared_preferences** — local persistence for settings, watchlist, history

## Getting started

1. Add your TMDB API key — see `lib/common/utils.dart` (or wherever `apikey` is defined).
2. Run `flutter pub get`.
3. Launch on your target platform:

```bash
flutter run                        # default device
flutter run -d android
flutter run -d chrome
flutter run -d windows
```

## Project layout

```
lib/
  main.dart               # app entry point, service initialisation
  model/                  # TMDB API response models
  screens/                # UI screens (home, detail, player, downloads, …)
  services/               # business logic
    api_service.dart          # TMDB API client
    download_manager.dart     # download orchestration
    download_source_service.dart  # active download source selection
    index_scraper.dart        # scraper for index-site download source
    vadapav_source.dart       # Vadapav download source
    stremio/                  # Stremio addon integration
    torrent/                  # libtorrent stream + download services
    player_service.dart       # active streaming player selection
    watchlist_service.dart
    watched_service.dart
    continue_watching_service.dart
  common/                 # shared utilities and platform helpers
```
