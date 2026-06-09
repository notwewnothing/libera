import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:libera/model/watch_provider.dart';
import 'package:libera/services/api_service.dart';

const _logoBase = "https://image.tmdb.org/t/p/w92";

/// Lazily resolves and renders the primary streaming provider logo for a title
/// (the small corner badge on artwork). Results are cached per id+type so a
/// title is only ever fetched once, and nothing is shown when no provider
/// exists for the region.
class ProviderBadge extends StatefulWidget {
  final int id;
  final bool isMovie;
  final double size;

  const ProviderBadge({
    super.key,
    required this.id,
    required this.isMovie,
    this.size = 22,
  });

  @override
  State<ProviderBadge> createState() => _ProviderBadgeState();
}

class _ProviderBadgeState extends State<ProviderBadge> {
  // Cache resolved providers and in-flight requests across the whole app.
  static final Map<String, StreamingProvider?> _cache = {};
  static final Map<String, Future<StreamingProvider?>> _inflight = {};

  StreamingProvider? _provider;
  bool _resolved = false;

  String get _key => "${widget.isMovie ? 'm' : 't'}${widget.id}";

  @override
  void initState() {
    super.initState();
    // Initialize synchronously from cache (no setState during build, which the
    // grid's widget recycling would otherwise trigger en masse).
    if (_cache.containsKey(_key)) {
      _provider = _cache[_key];
      _resolved = true;
    } else {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final provider = await (_inflight[_key] ??= _fetch());
    if (!mounted) return;
    setState(() {
      _provider = provider;
      _resolved = true;
    });
  }

  Future<StreamingProvider?> _fetch() async {
    final api = ApiServices();
    try {
      final data = widget.isMovie
          ? await api.fetchWatchProviders(widget.id)
          : await api.fetchTvWatchProviders(widget.id);
      final region = data?.results['US'] ??
          (data != null && data.results.isNotEmpty
              ? data.results.values.first
              : null);
      final provider = region == null || region.allProviders.isEmpty
          ? null
          : region.allProviders.first;
      _cache[_key] = provider;
      _inflight.remove(_key);
      return provider;
    } catch (_) {
      _cache[_key] = null;
      _inflight.remove(_key);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final logo = _provider?.logoPath;
    if (!_resolved || logo == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.size * 0.28),
      child: CachedNetworkImage(
        imageUrl: "$_logoBase$logo",
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        placeholder: (_, _) => const SizedBox.shrink(),
        errorWidget: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}
