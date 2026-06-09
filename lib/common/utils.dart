export 'secrets.dart' show apikey;

const baseUrl = "https://api.themoviedb.org/3/";
// Use a sized TMDB variant, not `original` (~2000px, multi-MB each): loading a
// grid/row of originals exhausts memory and ANRs/OOMs the app. w500 is plenty
// for posters and cards while cutting per-image memory ~16x.
const imageUrl = "https://image.tmdb.org/t/p/w500";
