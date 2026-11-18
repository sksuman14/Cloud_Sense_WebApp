import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_sense_webapp/src/widgets/device_image_view.dart';

/// Reusable widget for displaying photo attachments / evidence on complaints
/// with thumbnail previews and full-screen inspection dialogs.
class ComplaintAttachmentsWidget extends StatelessWidget {
  final List<String> attachments;
  final bool isDark;
  final bool isCompact;

  const ComplaintAttachmentsWidget({
    super.key,
    required this.attachments,
    required this.isDark,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    final cardBg = isDark ? const Color(0xFF132230) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? Colors.white12 : Colors.black12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: isCompact ? 13 : 15,
              color: const Color(0xFF0284C7),
            ),
            const SizedBox(width: 6),
            Text(
              'Attached Photos & Evidence (${attachments.length})',
              style: TextStyle(
                fontSize: isCompact ? 11 : 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: attachments.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildThumbnail(context, item, index, cardBg, borderColor);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildThumbnail(
    BuildContext context,
    String item,
    int index,
    Color cardBg,
    Color borderColor,
  ) {
    final double thumbSize = isCompact ? 68 : 82;
    final Uint8List? imageBytes = _tryDecodeBase64(item);
    final bool isNetworkUrl =
        item.startsWith('http://') || item.startsWith('https://');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openPreview(context, item, index, imageBytes),
        child: Container(
          width: thumbSize,
          height: thumbSize,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageBytes != null)
                Image.memory(
                  imageBytes,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildFallback(item),
                )
              else if (isNetworkUrl)
                DeviceImageView(
                  imageUrl: item,
                  width: thumbSize,
                  height: thumbSize,
                  fit: BoxFit.cover,
                )
              else
                _buildFallback(item),

              // Hover/Tap overlay icon
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.zoom_in_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallback(String item) {
    return Container(
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 22,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
          const SizedBox(height: 3),
          Text(
            item.split('/').last,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Uint8List? _tryDecodeBase64(String item) {
    try {
      if (item.startsWith('data:image')) {
        final commaIdx = item.indexOf(',');
        if (commaIdx != -1) {
          final b64 = item.substring(commaIdx + 1);
          return base64Decode(b64);
        }
      } else if (!item.startsWith('http') && item.length > 50) {
        // Raw base64 string
        return base64Decode(item);
      }
    } catch (_) {}
    return null;
  }

  void _openPreview(
    BuildContext context,
    String item,
    int index,
    Uint8List? imageBytes,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _PhotoPreviewDialog(
        item: item,
        index: index,
        imageBytes: imageBytes,
        isDark: isDark,
      ),
    );
  }
}

class _PhotoPreviewDialog extends StatefulWidget {
  final String item;
  final int index;
  final Uint8List? imageBytes;
  final bool isDark;

  const _PhotoPreviewDialog({
    required this.item,
    required this.index,
    required this.imageBytes,
    required this.isDark,
  });

  @override
  State<_PhotoPreviewDialog> createState() => _PhotoPreviewDialogState();
}

class _PhotoPreviewDialogState extends State<_PhotoPreviewDialog> {
  final TransformationController _transController = TransformationController();

  @override
  void dispose() {
    _transController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    final matrix = _transController.value.clone()..scale(1.25);
    setState(() => _transController.value = matrix);
  }

  void _zoomOut() {
    final matrix = _transController.value.clone()..scale(0.8);
    setState(() => _transController.value = matrix);
  }

  void _resetZoom() {
    setState(() => _transController.value = Matrix4.identity());
  }

  Future<void> _openExternal() async {
    if (widget.item.startsWith('http')) {
      final uri = Uri.parse(widget.item);
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = (size.width * 0.94).clamp(320.0, 1400.0);
    final dialogHeight = (size.height * 0.92).clamp(420.0, 950.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF0B131B) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.65),
              blurRadius: 32,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // Top Bar
            Row(
              children: [
                const Icon(
                  Icons.image_outlined,
                  color: Color(0xFF38BDF8),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Photo Attachment #${widget.index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Zoom Controls
                IconButton(
                  icon: const Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 20),
                  tooltip: 'Zoom In',
                  onPressed: _zoomIn,
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_out_rounded, color: Colors.white70, size: 20),
                  tooltip: 'Zoom Out',
                  onPressed: _zoomOut,
                ),
                IconButton(
                  icon: const Icon(Icons.restart_alt_rounded, color: Colors.white70, size: 20),
                  tooltip: 'Reset Zoom',
                  onPressed: _resetZoom,
                ),
                if (widget.item.startsWith('http')) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 19),
                    tooltip: 'Open in new tab',
                    onPressed: _openExternal,
                  ),
                ],
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 16),

            // Zoomable and Large Image Viewport
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black.withOpacity(0.4),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;

                      return InteractiveViewer(
                        transformationController: _transController,
                        panEnabled: true,
                        minScale: 0.5,
                        maxScale: 6.0,
                        child: SizedBox(
                          width: w,
                          height: h,
                          child: Center(
                            child: widget.imageBytes != null
                                ? Image.memory(
                                    widget.imageBytes!,
                                    width: w,
                                    height: h,
                                    fit: BoxFit.contain,
                                  )
                                : widget.item.startsWith('http')
                                    ? DeviceImageView(
                                        imageUrl: widget.item,
                                        width: w,
                                        height: h,
                                        fit: BoxFit.contain,
                                      )
                                    : const Icon(
                                        Icons.broken_image_rounded,
                                        size: 60,
                                        color: Colors.white54,
                                      ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.touch_app_outlined, size: 13, color: Colors.white54),
                SizedBox(width: 6),
                Text(
                  'Scroll / Pinch to zoom • Drag to pan • Use buttons above to zoom or reset',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
