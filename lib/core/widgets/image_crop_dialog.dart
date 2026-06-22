import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../theme/app_spacing.dart';

/// A dependency-free square image cropper. The user pans/zooms the image inside
/// a fixed square viewport (drag to align, pinch / +- to zoom) and the visible
/// square is rendered to PNG bytes via a RepaintBoundary capture.
///
/// Returns the cropped bytes, or null if cancelled. Works on web (CanvasKit)
/// and mobile without any native plugin.
class ImageCropDialog extends StatefulWidget {
  const ImageCropDialog({super.key, required this.bytes, this.outputSize = 512});
  final Uint8List bytes;

  /// Side length (px) of the produced square image.
  final double outputSize;

  /// Opens the cropper and resolves with cropped PNG bytes (or null).
  static Future<Uint8List?> show(BuildContext context, Uint8List bytes) {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImageCropDialog(bytes: bytes),
    );
  }

  @override
  State<ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<ImageCropDialog> {
  final _boundaryKey = GlobalKey();
  final _controller = TransformationController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm(double side) async {
    setState(() => _busy = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // Scale up so the captured square is ~outputSize px regardless of layout.
      final pixelRatio = (widget.outputSize / side).clamp(1.0, 4.0);
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;
      Navigator.of(context).pop(data?.buffer.asUint8List());
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const side = 300.0;
    // AlertDialog guarantees the action buttons are always laid out and visible
    // (they live in the actions slot, never inside the scrollable content), so
    // the "Save photo" button can never be clipped on a short/tall screen.
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.all(AppSpacing.x16),
      titlePadding: const EdgeInsets.fromLTRB(AppSpacing.x16, AppSpacing.x16, AppSpacing.x16, 0),
      contentPadding: const EdgeInsets.fromLTRB(AppSpacing.x16, AppSpacing.x12, AppSpacing.x16, 0),
      actionsPadding: const EdgeInsets.all(AppSpacing.x12),
      title: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Crop & align', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.x4),
        Text('Drag to reposition · pinch or use − / + to zoom',
            style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipOval(
          child: SizedBox(
            width: side,
            height: side,
            child: RepaintBoundary(
              key: _boundaryKey,
              child: ClipRect(
                child: InteractiveViewer(
                  transformationController: _controller,
                  clipBehavior: Clip.none,
                  minScale: 0.5,
                  maxScale: 5,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  child: Image.memory(widget.bytes, width: side, height: side, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(onPressed: () => _zoom(0.8), icon: const Icon(Icons.zoom_out)),
          IconButton(onPressed: () => _zoom(1.25), icon: const Icon(Icons.zoom_in)),
          IconButton(onPressed: () => _controller.value = Matrix4.identity(), icon: const Icon(Icons.restart_alt)),
        ]),
      ]),
      // Full-width, equal-prominence actions — Save can't be missed or clipped.
      actions: [
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: AppSpacing.x12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _confirm(side),
              icon: _busy
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 18),
              label: const Text('Save photo'),
            ),
          ),
        ]),
      ],
    );
  }

  void _zoom(double factor) {
    _controller.value = _controller.value.clone()..scaleByDouble(factor, factor, factor, 1);
  }
}
