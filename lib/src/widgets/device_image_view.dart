import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:ui_web' as ui_web;

/// A CORS-safe image view for Flutter Web that renders cross-origin images
/// (like S3 pre-signed URLs) using native HTML <img> tags, bypassing XMLHttpRequest CORS restrictions.
class DeviceImageView extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const DeviceImageView({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.onTap,
  }) : super(key: key);

  @override
  State<DeviceImageView> createState() => _DeviceImageViewState();
}

class _DeviceImageViewState extends State<DeviceImageView> {
  late String _viewType;
  static int _counter = 0;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _registerView();
  }

  @override
  void didUpdateWidget(DeviceImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _isLoading = true;
      _hasError = false;
      _registerView();
    }
  }

  void _registerView() {
    if (kIsWeb) {
      _counter++;
      _viewType = 's3-img-$_counter-${DateTime.now().microsecondsSinceEpoch}';
      final objectFit = widget.fit == BoxFit.contain ? 'contain' : 'cover';

      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) {
          final img = html.ImageElement()
            ..src = widget.imageUrl
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.objectFit = objectFit
            ..style.objectPosition = 'center'
            ..style.backgroundColor = 'transparent'
            ..style.border = 'none'
            ..style.display = 'block'
            ..style.pointerEvents = 'none'; // Pass clicks to Flutter InkWell

          img.onLoad.listen((_) {
            if (mounted) setState(() => _isLoading = false);
          });
          img.onError.listen((_) {
            if (mounted) setState(() => _hasError = true);
          });

          return img;
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width ?? double.infinity;
    final h = widget.height ?? 180.0;

    Widget content;

    if (kIsWeb) {
      if (_hasError) {
        content = Container(
          width: w,
          height: h,
          color: Colors.black12,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, color: Colors.white54, size: 28),
                SizedBox(height: 6),
                Text('Image failed to load', style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
        );
      } else {
        content = Stack(
          children: [
            SizedBox(
              width: w,
              height: h,
              child: HtmlElementView(viewType: _viewType),
            ),
            if (_isLoading)
              Container(
                width: w,
                height: h,
                color: Colors.black26,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyan),
                  ),
                ),
              ),
          ],
        );
      }
    } else {
      content = Image.network(
        widget.imageUrl,
        width: w,
        height: h,
        fit: widget.fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: w,
            height: h,
            color: Colors.black12,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyan),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          width: w,
          height: h,
          color: Colors.black12,
          child: const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 28),
          ),
        ),
      );
    }

    if (widget.borderRadius != null) {
      content = ClipRRect(borderRadius: widget.borderRadius!, child: content);
    }

    if (widget.onTap != null) {
      content = InkWell(
        onTap: widget.onTap,
        borderRadius: widget.borderRadius,
        child: content,
      );
    }

    return content;
  }
}
