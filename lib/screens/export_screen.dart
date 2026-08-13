import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:keep_screen_on/keep_screen_on.dart';

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

  Future<void> _startExport() async {
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
        _videoController = VideoPlayerController.networkUrl(Uri.parse(path));
      } else {
        _videoController = VideoPlayerController.file(File(path));
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

    return Scaffold(
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
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Header Titles
            if (_isExporting) ...[
              const Text(
                'Exporting...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Keep Lyrical Video open and don\'t lock your screen',
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
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
                    width: 210,
                    height: 360,
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
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final progressPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // Draw background border
    canvas.drawRRect(rrect, bgPaint);

    if (progress <= 0) return;

    // We can use a PathMetric to draw the progress
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final extractPath = metric.extractPath(0.0, metric.length * progress);
    canvas.drawPath(extractPath, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _BorderProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
