// Returns a Flutter widget hosting the embed [url] in a web `<iframe>`.
//
// Resolves to the real DOM-backed implementation on web and a no-op stub
// everywhere else, so native builds never compile `dart:html`/`dart:ui_web`.
export 'web_embed_stub.dart' if (dart.library.html) 'web_embed_web.dart';
