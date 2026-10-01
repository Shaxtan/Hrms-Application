import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';

/// Fetches an image through authenticated Dio (sends JWT + X-Tenant-ID).
///
/// Responses are cached in-memory (keyed by URL) and concurrent requests for
/// the same URL are de-duplicated. Without this, every rebuild — e.g. a list
/// row scrolling back into view — refired a network GET per avatar, causing
/// visible flicker and hammering the backend.
class AuthImage extends StatefulWidget {
  final String url;
  final double? width, height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  const AuthImage(
      {super.key,
      required this.url,
      this.width,
      this.height,
      this.fit = BoxFit.cover,
      this.placeholder,
      this.errorWidget});

  /// Session-scoped byte cache. Bounded so a long session can't grow forever.
  static final Map<String, Uint8List> _cache = {};
  static final Map<String, Future<Uint8List?>> _inFlight = {};
  static const int _maxCacheEntries = 200;

  /// Drop everything (call on logout if needed).
  static void clearCache() {
    _cache.clear();
    _inFlight.clear();
  }

  /// Evict one URL (e.g. after uploading a new profile photo).
  static void evict(String url) {
    _cache.remove(url);
    _inFlight.remove(url);
  }

  static Future<Uint8List?> _load(String url) {
    final cached = _cache[url];
    if (cached != null) return Future.value(cached);
    // De-dupe: N widgets asking for the same URL share one request.
    return _inFlight.putIfAbsent(url, () async {
      try {
        final res = await ApiClient.instance
            .get(url, options: Options(responseType: ResponseType.bytes));
        final bytes = Uint8List.fromList(res.data as List<int>);
        if (_cache.length >= _maxCacheEntries) {
          _cache.remove(_cache.keys.first); // simple FIFO eviction
        }
        _cache[url] = bytes;
        return bytes;
      } catch (_) {
        return null;
      } finally {
        _inFlight.remove(url);
      }
    });
  }

  @override
  State<AuthImage> createState() => _AuthImageState();
}

class _AuthImageState extends State<AuthImage> {
  Uint8List? _bytes;
  bool _loading = true, _error = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(AuthImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _fetch();
  }

  Future<void> _fetch() async {
    // Cache hit: render synchronously, no spinner frame at all.
    final cached = AuthImage._cache[widget.url];
    if (cached != null) {
      _bytes = cached;
      _loading = false;
      _error = false;
      if (mounted) setState(() {});
      return;
    }
    setState(() {
      _loading = true;
      _error = false;
    });
    final bytes = await AuthImage._load(widget.url);
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _loading = false;
      _error = bytes == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
          width: widget.width,
          height: widget.height,
          child: widget.placeholder ??
              const Center(
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))));
    }
    if (_error || _bytes == null) {
      return SizedBox(
          width: widget.width,
          height: widget.height,
          child: widget.errorWidget ?? const SizedBox.shrink());
    }
    return Image.memory(_bytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => SizedBox(
            width: widget.width,
            height: widget.height,
            child: widget.errorWidget ?? const SizedBox.shrink()));
  }
}
