// HTTP download engine. The real (dart:io + path_provider) implementation is
// used on native platforms; web — which has no filesystem — gets a no-op stub
// with the same public API and models, so downloads UI compiles but is hidden.
export 'downloads_service_stub.dart'
    if (dart.library.io) 'downloads_service_io.dart';
