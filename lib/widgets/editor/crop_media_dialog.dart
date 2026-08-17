import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../models/media_layer_model.dart';

class CropResult {
  final double cropLeft;
  final double cropTop;
  final double cropRight;
  final double cropBottom;

  const CropResult({
    required this.cropLeft,
    required this.cropTop,
    required this.cropRight,
    required this.cropBottom,
  });
}

class CropMediaDialog extends StatefulWidget {
  final MediaLayerModel layer;
  final double currentPlayheadTime;

  const CropMediaDialog({
    super.key,
    required this.layer,
    this.currentPlayheadTime = 0.0,
  });

  static Future<CropResult?> show(BuildContext context, MediaLayerModel layer, {double currentPlayheadTime = 0.0}) {
    return showGeneralDialog<CropResult>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.92),
      pageBuilder: (context, anim1, anim2) {
        return CropMediaDialog(layer: layer, currentPlayheadTime: currentPlayheadTime);
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }

  @override
  State<CropMediaDialog> createState() => _CropMediaDialogState();
}

class _CropMediaDialogState extends State<CropMediaDialog> {
  late double _cropLeft;
  late double _cropTop;
  late double _cropRight;
  late double _cropBottom;

  double? _selectedRatio; // null = Free
  String _activePresetName = 'Free';

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  Size _naturalSize = const Size(1920, 1080);

  final List<Map<String, dynamic>> _presets = [
    {'name': 'Free', 'ratio': null, 'icon': Icons.crop_free_rounded},
    {'name': '1:1', 'ratio': 1.0 / 1.0, 'icon': Icons.crop_square_rounded},
    {'name': '9:16', 'ratio': 9.0 / 16.0, 'icon': Icons.crop_portrait_rounded},
    {'name': '16:9', 'ratio': 16.0 / 9.0, 'icon': Icons.crop_landscape_rounded},
    {'name': '4:5', 'ratio': 4.0 / 5.0, 'icon': Icons.crop_5_4_rounded},
    {'name': '4:3', 'ratio': 4.0 / 3.0, 'icon': Icons.crop_3_2_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _cropLeft = widget.layer.cropLeft.clamp(0.0, 0.9);
    _cropTop = widget.layer.cropTop.clamp(0.0, 0.9);
    _cropRight = widget.layer.cropRight.clamp(_cropLeft + 0.05, 1.0);
    _cropBottom = widget.layer.cropBottom.clamp(_cropTop + 0.05, 1.0);

    _initMedia();
  }

  Future<void> _initMedia() async {
    final file = File(widget.layer.path);
    if (!file.existsSync()) return;

    if (widget.layer.type == MediaType.video) {
      try {
        _videoController = VideoPlayerController.file(file);
        await _videoController!.initialize();
        if (mounted) {
          final s = _videoController!.value.size;
          if (s.width > 0 && s.height > 0) {
            _naturalSize = s;
          }
          final rawLayerTime = (widget.currentPlayheadTime - widget.layer.startTime) + widget.layer.trimStartTime;
          final targetLayerTime = rawLayerTime.clamp(
            widget.layer.trimStartTime,
            widget.layer.trimStartTime + widget.layer.mediaDuration,
          );
          await _videoController!.seekTo(
            Duration(milliseconds: (targetLayerTime * 1000).toInt()),
          );
          setState(() {
            _isVideoInitialized = true;
          });
        }
      } catch (e) {
        debugPrint('CropMediaDialog: Video init error: $e');
      }
    } else {
      // Image / Sticker
      try {
        final decoded = await decodeImageFromList(await file.readAsBytes());
        if (mounted) {
          setState(() {
            _naturalSize = Size(decoded.width.toDouble(), decoded.height.toDouble());
          });
        }
      } catch (e) {
        debugPrint('CropMediaDialog: Image decode error: $e');
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _resetCrop() {
    setState(() {
      _cropLeft = 0.0;
      _cropTop = 0.0;
      _cropRight = 1.0;
      _cropBottom = 1.0;
      _selectedRatio = null;
      _activePresetName = 'Free';
    });
  }

  void _applyPreset(String name, double? targetRatio) {
    setState(() {
      _activePresetName = name;
      _selectedRatio = targetRatio;

      if (targetRatio == null) return;

      // Calculate new crop centered in natural coordinates
      final mediaAspect = _naturalSize.width / _naturalSize.height;
      double newCropWidthRatio;
      double newCropHeightRatio;

      if (targetRatio > mediaAspect) {
        // Wider than original media
        newCropWidthRatio = 1.0;
        newCropHeightRatio = (mediaAspect / targetRatio).clamp(0.05, 1.0);
      } else {
        // Taller than original media
        newCropHeightRatio = 1.0;
        newCropWidthRatio = (targetRatio / mediaAspect).clamp(0.05, 1.0);
      }

      _cropLeft = ((1.0 - newCropWidthRatio) / 2).clamp(0.0, 0.95);
      _cropRight = (_cropLeft + newCropWidthRatio).clamp(0.05, 1.0);
      _cropTop = ((1.0 - newCropHeightRatio) / 2).clamp(0.0, 0.95);
      _cropBottom = (_cropTop + newCropHeightRatio).clamp(0.05, 1.0);
    });
  }

  void _onConfirm() {
    Navigator.of(context).pop(
      CropResult(
        cropLeft: _cropLeft,
        cropTop: _cropTop,
        cropRight: _cropRight,
        cropBottom: _cropBottom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOverlay = widget.layer.isOverlay;
    final isVideo = widget.layer.type == MediaType.video;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1116),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(isOverlay, isVideo),

            // Center Media + Crop Overlay
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return _buildCropCanvas(constraints);
                  },
                ),
              ),
            ),

            // Bottom Presets Bar
            _buildBottomPresetBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isOverlay, bool isVideo) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161922),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          // Cancel (Cross)
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
            tooltip: 'Cancel',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),

          // Title & Badge
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Crop ${isOverlay ? "Overlay" : "Media"}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isVideo ? const Color(0xFF00E5FF) : const Color(0xFFFF4081)).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: (isVideo ? const Color(0xFF00E5FF) : const Color(0xFFFF4081)).withOpacity(0.5),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    isVideo ? 'VIDEO' : 'IMAGE',
                    style: TextStyle(
                      color: isVideo ? const Color(0xFF00E5FF) : const Color(0xFFFF4081),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Reset (Restore Full Frame)
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.amberAccent,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(40, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.amberAccent),
            label: const Text(
              'Reset',
              style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w600, fontSize: 12),
            ),
            onPressed: _resetCrop,
          ),
          const SizedBox(width: 8),

          // Apply (Tick)
          InkWell(
            onTap: _onConfirm,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, color: Colors.black87, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Apply',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropCanvas(BoxConstraints constraints) {
    final mediaAspect = _naturalSize.width / _naturalSize.height;
    final maxW = constraints.maxWidth;
    final maxH = constraints.maxHeight;

    double renderedW;
    double renderedH;

    if (maxW / maxH > mediaAspect) {
      // Height is constraining
      renderedH = maxH;
      renderedW = maxH * mediaAspect;
    } else {
      // Width is constraining
      renderedW = maxW;
      renderedH = maxW / mediaAspect;
    }

    return Center(
      child: Container(
        width: renderedW,
        height: renderedH,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 16,
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Raw Media Preview (Full Uncropped Frame)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildRawMedia(),
              ),
            ),

            // 2. Dimmed Mask & Draggable Handles
            Positioned.fill(
              child: _buildCropOverlay(renderedW, renderedH),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRawMedia() {
    final file = File(widget.layer.path);
    if (!file.existsSync()) {
      return const Center(
        child: Text('Media file not found', style: TextStyle(color: Colors.white54)),
      );
    }

    if (widget.layer.type == MediaType.video) {
      if (_isVideoInitialized && _videoController != null) {
        return FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: _naturalSize.width,
            height: _naturalSize.height,
            child: VideoPlayer(_videoController!),
          ),
        );
      }
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 2),
      );
    }

    // Image / Sticker
    return Image.file(file, fit: BoxFit.contain);
  }

  Widget _buildCropOverlay(double totalW, double totalH) {
    final cropPixelLeft = _cropLeft * totalW;
    final cropPixelTop = _cropTop * totalH;
    final cropPixelRight = _cropRight * totalW;
    final cropPixelBottom = _cropBottom * totalH;
    final cropPixelWidth = (cropPixelRight - cropPixelLeft).clamp(20.0, totalW);
    final cropPixelHeight = (cropPixelBottom - cropPixelTop).clamp(20.0, totalH);

    const handleSize = 28.0;

    return Stack(
      children: [
        // Custom Painter for Dimmed Outside + Grid Inside
        CustomPaint(
          size: Size(totalW, totalH),
          painter: _CropPainter(
            cropRect: Rect.fromLTRB(cropPixelLeft, cropPixelTop, cropPixelRight, cropPixelBottom),
          ),
        ),

        // Pan inside Crop Box to Move Entire Box
        Positioned(
          left: cropPixelLeft,
          top: cropPixelTop,
          width: cropPixelWidth,
          height: cropPixelHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanUpdate: (details) {
              final dxRatio = details.delta.dx / totalW;
              final dyRatio = details.delta.dy / totalH;
              final w = _cropRight - _cropLeft;
              final h = _cropBottom - _cropTop;

              setState(() {
                double newL = _cropLeft + dxRatio;
                double newT = _cropTop + dyRatio;

                if (newL < 0.0) newL = 0.0;
                if (newT < 0.0) newT = 0.0;
                if (newL + w > 1.0) newL = 1.0 - w;
                if (newT + h > 1.0) newT = 1.0 - h;

                _cropLeft = newL;
                _cropTop = newT;
                _cropRight = newL + w;
                _cropBottom = newT + h;
              });
            },
          ),
        ),

        // --- CORNER HANDLES ---
        // 1. Top-Left Handle
        Positioned(
          left: cropPixelLeft - handleSize / 2,
          top: cropPixelTop - handleSize / 2,
          child: _buildHandle(
            handleSize: handleSize,
            onPanUpdate: (d) => _onHandleDrag(
              deltaX: d.delta.dx / totalW,
              deltaY: d.delta.dy / totalH,
              isLeft: true,
              isTop: true,
            ),
            corner: _Corner.topLeft,
          ),
        ),

        // 2. Top-Right Handle
        Positioned(
          left: cropPixelRight - handleSize / 2,
          top: cropPixelTop - handleSize / 2,
          child: _buildHandle(
            handleSize: handleSize,
            onPanUpdate: (d) => _onHandleDrag(
              deltaX: d.delta.dx / totalW,
              deltaY: d.delta.dy / totalH,
              isRight: true,
              isTop: true,
            ),
            corner: _Corner.topRight,
          ),
        ),

        // 3. Bottom-Left Handle
        Positioned(
          left: cropPixelLeft - handleSize / 2,
          top: cropPixelBottom - handleSize / 2,
          child: _buildHandle(
            handleSize: handleSize,
            onPanUpdate: (d) => _onHandleDrag(
              deltaX: d.delta.dx / totalW,
              deltaY: d.delta.dy / totalH,
              isLeft: true,
              isBottom: true,
            ),
            corner: _Corner.bottomLeft,
          ),
        ),

        // 4. Bottom-Right Handle
        Positioned(
          left: cropPixelRight - handleSize / 2,
          top: cropPixelBottom - handleSize / 2,
          child: _buildHandle(
            handleSize: handleSize,
            onPanUpdate: (d) => _onHandleDrag(
              deltaX: d.delta.dx / totalW,
              deltaY: d.delta.dy / totalH,
              isRight: true,
              isBottom: true,
            ),
            corner: _Corner.bottomRight,
          ),
        ),

        // --- EDGE HANDLES ---
        // 5. Top Edge Handle
        Positioned(
          left: cropPixelLeft + cropPixelWidth / 2 - 20,
          top: cropPixelTop - 12,
          child: _buildEdgeHandle(
            width: 40,
            height: 24,
            isVertical: false,
            onPanUpdate: (d) => _onHandleDrag(
              deltaX: 0,
              deltaY: d.delta.dy / totalH,
              isTop: true,
            ),
          ),
        ),

        // 6. Bottom Edge Handle
        Positioned(
          left: cropPixelLeft + cropPixelWidth / 2 - 20,
          top: cropPixelBottom - 12,
          child: _buildEdgeHandle(
            width: 40,
            height: 24,
            isVertical: false,
            onPanUpdate: (d) => _onHandleDrag(
              deltaX: 0,
              deltaY: d.delta.dy / totalH,
              isBottom: true,
            ),
          ),
        ),

        // 7. Left Edge Handle
        Positioned(
          left: cropPixelLeft - 12,
          top: cropPixelTop + cropPixelHeight / 2 - 20,
          child: _buildEdgeHandle(
            width: 24,
            height: 40,
            isVertical: true,
            onPanUpdate: (d) => _onHandleDrag(
              deltaX: d.delta.dx / totalW,
              deltaY: 0,
              isLeft: true,
            ),
          ),
        ),

        // 8. Right Edge Handle
        Positioned(
          left: cropPixelRight - 12,
          top: cropPixelTop + cropPixelHeight / 2 - 20,
          child: _buildEdgeHandle(
            width: 24,
            height: 40,
            isVertical: true,
            onPanUpdate: (d) => _onHandleDrag(
              deltaX: d.delta.dx / totalW,
              deltaY: 0,
              isRight: true,
            ),
          ),
        ),
      ],
    );
  }

  void _onHandleDrag({
    required double deltaX,
    required double deltaY,
    bool isLeft = false,
    bool isRight = false,
    bool isTop = false,
    bool isBottom = false,
  }) {
    setState(() {
      double newLeft = _cropLeft;
      double newTop = _cropTop;
      double newRight = _cropRight;
      double newBottom = _cropBottom;

      const minW = 0.05;
      const minH = 0.05;

      if (isLeft) {
        newLeft = (newLeft + deltaX).clamp(0.0, newRight - minW);
      }
      if (isRight) {
        newRight = (newRight + deltaX).clamp(newLeft + minW, 1.0);
      }
      if (isTop) {
        newTop = (newTop + deltaY).clamp(0.0, newBottom - minH);
      }
      if (isBottom) {
        newBottom = (newBottom + deltaY).clamp(newTop + minH, 1.0);
      }

      // If locked aspect ratio, maintain it
      if (_selectedRatio != null) {
        final mediaAspect = _naturalSize.width / _naturalSize.height;
        final targetRatioInNorm = _selectedRatio! / mediaAspect;

        if (isRight || isLeft) {
          final curW = newRight - newLeft;
          final neededH = (curW / targetRatioInNorm).clamp(minH, 1.0);
          if (isTop) {
            newTop = (newBottom - neededH).clamp(0.0, newBottom - minH);
          } else {
            newBottom = (newTop + neededH).clamp(newTop + minH, 1.0);
          }
        } else if (isTop || isBottom) {
          final curH = newBottom - newTop;
          final neededW = (curH * targetRatioInNorm).clamp(minW, 1.0);
          if (isLeft) {
            newLeft = (newRight - neededW).clamp(0.0, newRight - minW);
          } else {
            newRight = (newLeft + neededW).clamp(newLeft + minW, 1.0);
          }
        }
      }

      _cropLeft = newLeft;
      _cropTop = newTop;
      _cropRight = newRight;
      _cropBottom = newBottom;
    });
  }

  Widget _buildHandle({
    required double handleSize,
    required GestureDragUpdateCallback onPanUpdate,
    required _Corner corner,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      child: Container(
        width: handleSize,
        height: handleSize,
        alignment: Alignment.center,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withOpacity(0.6),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEdgeHandle({
    required double width,
    required double height,
    required bool isVertical,
    required GestureDragUpdateCallback onPanUpdate,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        child: Container(
          width: isVertical ? 4 : 20,
          height: isVertical ? 20 : 4,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPresetBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161922),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _presets.map((preset) {
            final name = preset['name'] as String;
            final ratio = preset['ratio'] as double?;
            final icon = preset['icon'] as IconData;
            final isSelected = _activePresetName == name;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => _applyPreset(name, ratio),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00E5FF).withOpacity(0.15)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00E5FF)
                          : Colors.white.withOpacity(0.1),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

class _CropPainter extends CustomPainter {
  final Rect cropRect;

  _CropPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dimmed outside area
    final dimPaint = Paint()..color = Colors.black.withOpacity(0.65);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final path = Path()
      ..addRect(fullRect)
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, dimPaint);

    // 2. Crop border
    final borderPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRect(cropRect, borderPaint);

    // 3. Rule of thirds grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final thirdW = cropRect.width / 3;
    final thirdH = cropRect.height / 3;

    // Vertical grid lines
    canvas.drawLine(
      Offset(cropRect.left + thirdW, cropRect.top),
      Offset(cropRect.left + thirdW, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + thirdW * 2, cropRect.top),
      Offset(cropRect.left + thirdW * 2, cropRect.bottom),
      gridPaint,
    );

    // Horizontal grid lines
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdH),
      Offset(cropRect.right, cropRect.top + thirdH),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdH * 2),
      Offset(cropRect.right, cropRect.top + thirdH * 2),
      gridPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}
