import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';

/// Fetches an image through authenticated Dio (sends JWT + X-Tenant-ID).
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
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final res = await ApiClient.instance
          .get(widget.url, options: Options(responseType: ResponseType.bytes));
      if (mounted)
        setState(() {
          _bytes = Uint8List.fromList(res.data as List<int>);
          _loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _error = true;
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return SizedBox(
          width: widget.width,
          height: widget.height,
          child: widget.placeholder ??
              const Center(
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))));
    if (_error || _bytes == null)
      return SizedBox(
          width: widget.width,
          height: widget.height,
          child: widget.errorWidget ?? const SizedBox.shrink());
    return Image.memory(_bytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => SizedBox(
            width: widget.width,
            height: widget.height,
            child: widget.errorWidget ?? const SizedBox.shrink()));
  }
}
