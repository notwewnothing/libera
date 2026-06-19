// Web-only: embeds the streaming player site in an <iframe> via a platform
// view. Compiled only on web (selected by the conditional export in
// web_embed.dart), so dart:html / dart:ui_web never reach native builds.
import 'dart:html';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

final Set<String> _registered = {};

Widget buildWebIframe(String url) {
  final viewType = 'libera-embed-${url.hashCode}';
  if (!_registered.contains(viewType)) {
    _registered.add(viewType);
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final iframe = IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'autoplay; fullscreen; encrypted-media; picture-in-picture'
        ..allowFullscreen = true;
      return iframe;
    });
  }
  return HtmlElementView(viewType: viewType);
}
