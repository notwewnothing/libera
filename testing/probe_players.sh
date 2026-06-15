#!/usr/bin/env bash
# Probe embed-player providers for a known movie (Fight Club, TMDB 550) and
# TV episode (Breaking Bad, TMDB 1396 S1E1). Classifies each endpoint as
# alive / cloudflare-gated / dead so we only ship players that actually respond.
set -u

UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
OUT=/tmp/player_probe
mkdir -p "$OUT"

# name | movie_url | tv_url   (TV = Breaking Bad 1396 S1E1)
read -r -d '' ROWS <<'EOF'
[BASE]vidking|https://www.vidking.net/embed/movie/550|https://www.vidking.net/embed/tv/1396/1/1
[BASE]vidify|https://player.vidify.top/embed/movie/550|https://player.vidify.top/embed/tv/1396/1/1
[BASE]videasy|https://player.videasy.to/movie/550|https://player.videasy.to/tv/1396/1/1
[BASE]vidfast|https://vidfast.pro/movie/550|https://vidfast.pro/tv/1396/1/1
[BASE]cinemaos|https://cinemaos.tech/movie/watch/550|https://cinemaos.tech/tv/watch/1396?season=1&episode=1
vidsrc.cc|https://vidsrc.cc/v2/embed/movie/550|https://vidsrc.cc/v2/embed/tv/1396/1/1
vidsrc.to|https://vidsrc.to/embed/movie/550|https://vidsrc.to/embed/tv/1396/1/1
vidsrc.xyz|https://vidsrc.xyz/embed/movie/550|https://vidsrc.xyz/embed/tv/1396/1/1
vidsrc.net|https://vidsrc.net/embed/movie/550|https://vidsrc.net/embed/tv/1396/1/1
vidsrc.me|https://vidsrc.me/embed/movie/550|https://vidsrc.me/embed/tv/1396/1/1
vidsrc.icu|https://vidsrc.icu/embed/movie/550|https://vidsrc.icu/embed/tv/1396/1/1
vidsrc.rip|https://vidsrc.rip/embed/movie/550|https://vidsrc.rip/embed/tv/1396/1/1
vidsrc.vip|https://vidsrc.vip/embed/movie/550|https://vidsrc.vip/embed/tv/1396/1/1
vidsrc.su|https://vidsrc.su/embed/movie/550|https://vidsrc.su/embed/tv/1396/1/1
vidsrc.pm|https://vidsrc.pm/embed/movie/550|https://vidsrc.pm/embed/tv/1396/1/1
vidlink.pro|https://vidlink.pro/movie/550|https://vidlink.pro/tv/1396/1/1
embed.su|https://embed.su/embed/movie/550|https://embed.su/embed/tv/1396/1/1
autoembed.cc|https://player.autoembed.cc/embed/movie/550|https://player.autoembed.cc/embed/tv/1396/1/1
2embed.cc|https://www.2embed.cc/embed/550|https://www.2embed.cc/embedtv/1396&s=1&e=1
2embed.skin|https://www.2embed.skin/embed/550|https://www.2embed.skin/embedtv/1396&s=1&e=1
moviesapi.club|https://moviesapi.club/movie/550|https://moviesapi.club/tv/1396-1-1
multiembed|https://multiembed.mov/?video_id=550&tmdb=1|https://multiembed.mov/?video_id=1396&tmdb=1&s=1&e=1
111movies|https://111movies.com/movie/550|https://111movies.com/tv/1396/1/1
vidjoy.pro|https://vidjoy.pro/embed/movie/550|https://vidjoy.pro/embed/tv/1396/1/1
vidbinge|https://vidbinge.dev/embed/movie/550|https://vidbinge.dev/embed/tv/1396/1/1
smashystream|https://embed.smashystream.com/playere.php?tmdb=550|https://embed.smashystream.com/playere.php?tmdb=1396&season=1&episode=1
nontongo|https://www.nontongo.win/embed/movie/550|https://www.nontongo.win/embed/tv/1396/1/1
moviee.tv|https://moviee.tv/embed/movie/550|https://moviee.tv/embed/tv/1396/1/1
warezcdn|https://embed.warezcdn.com/filme/550|https://embed.warezcdn.com/serie/1396/1/1
frembed|https://frembed.live/api/film.php?id=550|https://frembed.live/api/serie.php?id=1396&sa=1&epi=1
rivestream|https://rivestream.org/embed?type=movie&id=550|https://rivestream.org/embed?type=tv&id=1396&season=1&episode=1
spencerdevs|https://spencerdevs.xyz/movie/550|https://spencerdevs.xyz/tv/1396/1/1
EOF

printf "%-16s %-7s %-7s %-9s %-9s %s\n" "PROVIDER" "MOV" "TV" "MOV-KB" "TV-KB" "VERDICT / final-host"
printf '%.0s-' {1..110}; echo

fetch() { # url outfile -> echo "status|final_url"  (body in outfile.body)
  local code fin line
  : > "$2.body"; : > "$2.hdr"
  line=$(curl -sS -m 20 -A "$UA" -L --compressed \
    -D "$2.hdr" -o "$2.body" \
    -w '%{http_code} %{url_effective}' "$1" 2>/dev/null)
  code=${line%% *}; fin=${line#* }
  [[ -z "$code" || "$code" == "$line" && -z "$fin" ]] && { code=000; fin=ERR; }
  echo "${code:-000}|${fin:-ERR}"
}
size_kb() { local n; n=$(wc -c < "$1" 2>/dev/null); echo $(( ${n:-0} / 1024 )); }

classify() { # body hdr status -> verdict word
  local body="$1" hdr="$2" st="$3"
  if [[ "$st" == "000" ]]; then echo "DEAD(no-conn)"; return; fi
  if grep -qiE "just a moment|cf-browser-verification|challenge-platform|attention required|enable javascript and cookies" "$body" 2>/dev/null; then
    echo "CF-GATED"; return; fi
  if grep -qiE "domain( name)? is for sale|buy this domain|sedoparking|this domain has expired|namecheap parking|godaddy" "$body" 2>/dev/null; then
    echo "PARKED"; return; fi
  if [[ "$st" =~ ^(200|206)$ ]]; then
    if grep -qiE "<video|jwplayer|playerjs|hls\.|vidstack|new Plyr|player|m3u8|sources|<iframe|embed" "$body" 2>/dev/null; then
      echo "ALIVE(player)"; else echo "ALIVE($st)"; fi
    return; fi
  echo "HTTP-$st"
}

host_of() { sed -E 's#^https?://([^/]+).*#\1#' <<<"$1"; }

while IFS='|' read -r name murl turl; do
  [[ -z "$name" ]] && continue
  safe=$(tr -c 'A-Za-z0-9._-' '_' <<<"$name")
  IFS='|' read -r mst mfin < <(fetch "$murl" "$OUT/${safe}_m")
  IFS='|' read -r tst tfin < <(fetch "$turl" "$OUT/${safe}_t")
  mv=$(classify "$OUT/${safe}_m.body" "$OUT/${safe}_m.hdr" "$mst")
  tv=$(classify "$OUT/${safe}_t.body" "$OUT/${safe}_t.hdr" "$tst")
  printf "%-16s %-7s %-7s %-9s %-9s %-26s %s\n" \
    "$name" "$mst" "$tst" "$(size_kb "$OUT/${safe}_m.body")" "$(size_kb "$OUT/${safe}_t.body")" "$mv/$tv" "$(host_of "$mfin")"
done <<<"$ROWS"
