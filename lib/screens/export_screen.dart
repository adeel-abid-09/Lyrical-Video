import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:keep_screen_on/keep_screen_on.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';

import '../models/media_layer_model.dart';
import '../services/ffmpeg_export_service.dart';
import '../state/editor_state_notifier.dart';
import '../theme/app_theme.dart';

class ExportScreen extends ConsumerStatefulWidget {
  final String resolution;
  final int fps;
  final String quality;

  const ExportScreen({
    super.key,
    this.resolution = '1080p',
    this.fps = 30,
    this.quality = 'High',
  });

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _isExporting = true;
  String? _exportedPath;
  String? _errorMessage;
  double _progress = 0.0;

  VideoPlayerController? _videoController;
  bool _isPlayingPreview = false;

  @override
  void initState() {
    super.initState();
    KeepScreenOn.turnOn();
    _startExport();
  }

  @override
  void dispose() {
    KeepScreenOn.turnOff();
    _videoController?.dispose();
    super.dispose();
  }

  Future<bool> _confirmCancelExport() async {
    if (!_isExporting) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 24),
            SizedBox(width: 8),
            Text('Cancel Export?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: const Text(
          'Export is currently in progress. Are you sure you want to quit?',
          style: TextStyle(color: Colors.white70, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continue Export', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        FFmpegKit.cancel();
      } catch (_) {}
      return true;
    }
    return false;
  }

  Future<void> _startExport() async {
    ref.read(editorProjectProvider.notifier).setPlaying(false);
    final project = ref.read(editorProjectProvider);

    try {
      final path = await FFmpegExportService.exportProject(
        project,
        resolution: widget.resolution,
        fps: widget.fps,
        quality: widget.quality,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      if (mounted) {
        setState(() {
          _isExporting = false;
          _progress = 1.0;
          _exportedPath = path;
        });

        // Initialize live video player preview inside the frame
        if (path != null) {
          _initializePreviewVideo(path);

          // Auto-trigger native share popup on export complete
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted && _exportedPath != null) {
              Share.shareXFiles([XFile(_exportedPath!)], text: 'Check out my new Lyrical Video!');
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _initializePreviewVideo(String path) async {
    try {
      if (kIsWeb || path.startsWith('blob:') || path.startsWith('http')) {
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(path),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      } else {
        _videoController = VideoPlayerController.file(
          File(path),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      }

      await _videoController!.initialize();
      _videoController!.setLooping(true);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Export preview video player init error: $e');
    }
  }

  void _togglePlayPause() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      setState(() {
        if (_videoController!.value.isPlaying) {
          _videoController!.pause();
          _isPlayingPreview = false;
        } else {
          _videoController!.play();
          _isPlayingPreview = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorProjectProvider);
    final firstMedia = project.mediaLayers.firstOrNull;
    final percentInt = (_progress * 100).toInt().clamp(0, 100);
    final ratio = project.aspectRatio.ratio > 0 ? project.aspectRatio.ratio : (9 / 16);

    double cardWidth;
    double cardHeight;
    if (ratio >= 1.0) {
      cardWidth = 320.0;
      cardHeight = (cardWidth / ratio).clamp(140.0, 360.0);
    } else {
      cardHeight = 360.0;
      cardWidth = (cardHeight * ratio).clamp(160.0, 320.0);
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _confirmCancelExport();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF111116),
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar with Close Button [ X ]
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                      onPressed: () async {
                        final shouldPop = await _confirmCancelExport();
                        if (shouldPop && context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    const Spacer(),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Header Titles
            if (_isExporting) ...[
              const Text(
                'Exporting without watermark',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please don\'t close Lyrical Video or lock your screen.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ] else if (_errorMessage != null) ...[
              const Text(
                'Export Failed',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SingleChildScrollView(
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
              ),
            ] else ...[
              const Text(
                'Ready to share!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Saved to your device gallery',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],

            const Spacer(),

            // Center Video Preview Card with Play Icon & Interactive Player
            Center(
              child: GestureDetector(
                onTap: _isExporting ? null : _togglePlayPause,
                child: CustomPaint(
                  painter: _isExporting ? _BorderProgressPainter(_progress, 16.0) : null,
                  child: Container(
                    width: cardWidth,
                    height: cardHeight,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C26),
                      borderRadius: BorderRadius.circular(16),
                      border: !_isExporting ? Border.all(color: Colors.white12, width: 1.5) : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Video Player or Thumbnail Background
                        if (_videoController != null && _videoController!.value.isInitialized)
                          Positioned.fill(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              clipBehavior: Clip.hardEdge,
                              child: SizedBox(
                                width: _videoController!.value.size.width,
                                height: _videoController!.value.size.height,
                                child: VideoPlayer(_videoController!),
                              ),
                            ),
                          )
                        else if (firstMedia != null)
                          Positioned.fill(
                            child: _buildThumbnailWidget(firstMedia),
                          )
                        else
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF1E1E2C), Color(0xFF2C2C3E)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),

                        // Mask Overlay
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(
                              _isExporting ? 0.45 : (_isPlayingPreview ? 0.0 : 0.25),
                            ),
                          ),
                        ),

                        // Percentage Overlay when exporting
                        if (_isExporting)
                          Text(
                            '$percentInt%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black87,
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          )
                        // Interactive Play Button when export complete
                        else if (_errorMessage == null)
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _isPlayingPreview ? 0.0 : 1.0,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white38, width: 1.5),
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

            const Spacer(),

            // Bottom Action Buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  if (!_isExporting && _exportedPath != null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.share_rounded, color: Colors.white),
                        label: const Text('Share Video', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Share.shareXFiles([XFile(_exportedPath!)], text: 'Check out my new Lyrical Video!');
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done', style: TextStyle(color: Colors.white70, fontSize: 15)),
                    ),
                  ] else if (!_isExporting && _errorMessage != null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          setState(() {
                            _isExporting = true;
                            _errorMessage = null;
                            _progress = 0.0;
                          });
                          _startExport();
                        },
                        child: const Text('Try Again', style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
  Widget _buildThumbnailWidget(MediaLayerModel media) {
    final path = media.path;
    if (kIsWeb || path.startsWith('blob:') || path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E1E2C)),
      );
    } else if (File(path).existsSync()) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E1E2C)),
      );
    }
    return Container(color: const Color(0xFF1E1E2C));
  }
}

class _BorderProgressPainter extends CustomPainter {
  final double progress;
  final double borderRadius;

  _BorderProgressPainter(this.progress, this.borderRadius);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = const Color(0xFF3E3E50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final progressPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.square;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // Draw distinct background border track
    canvas.drawRRect(rrect, bgPaint);

    if (progress <= 0) return;

    // Create clockwise perimeter path starting at top-left corner
    final path = Path()
      ..moveTo(borderRadius, 0)
      ..lineTo(size.width - borderRadius, 0)
      ..arcToPoint(Offset(size.width, borderRadius), radius: Radius.circular(borderRadius))
      ..lineTo(size.width, size.height - borderRadius)
      ..arcToPoint(Offset(size.width - borderRadius, size.height), radius: Radius.circular(borderRadius))
      ..lineTo(borderRadius, size.height)
      ..arcToPoint(Offset(0, size.height - borderRadius), radius: Radius.circular(borderRadius))
      ..lineTo(0, borderRadius)
      ..arcToPoint(Offset(borderRadius, 0), radius: Radius.circular(borderRadius))
      ..close();

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final extractPath = metric.extractPath(0.0, metric.length * progress.clamp(0.0, 1.0));
    canvas.drawPath(extractPath, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _BorderProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
