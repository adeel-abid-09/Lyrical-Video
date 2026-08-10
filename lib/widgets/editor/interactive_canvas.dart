import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../../models/media_layer_model.dart';
import '../../state/editor_state_notifier.dart';
import '../../theme/app_theme.dart';

class InteractiveCanvasWidget extends ConsumerStatefulWidget {
  final VoidCallback? onOpenTextEditor;

  const InteractiveCanvasWidget({
    super.key,
    this.onOpenTextEditor,
  });

  @override
  ConsumerState<InteractiveCanvasWidget> createState() => _InteractiveCanvasWidgetState();
}

class _InteractiveCanvasWidgetState extends ConsumerState<InteractiveCanvasWidget> {
  VideoPlayerController? _videoController;
  String? _activeVideoPath;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickMediaDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Media Source',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primaryAccent,
                  child: Icon(Icons.movie_rounded, color: Colors.white),
                ),
                title: const Text('Pick Video from Gallery', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
                  if (file != null) {
                    final controller = VideoPlayerController.file(File(file.path));
                    await controller.initialize();
                    final duration = controller.value.duration.inMilliseconds / 1000.0;
                    await controller.dispose();

                    final media = MediaLayerModel(
                      id: const Uuid().v4(),
                      path: file.path,
                      type: MediaType.video,
                      mediaDuration: duration > 0 ? duration : 15.0,
                    );
                    ref.read(editorProjectProvider.notifier).addMediaLayer(media);
                  }
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.purpleAccent,
                  child: Icon(Icons.image_rounded, color: Colors.white),
                ),
                title: const Text('Pick Image / Photo from Gallery', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
                  if (file != null) {
                    final media = MediaLayerModel(
                      id: const Uuid().v4(),
                      path: file.path,
                      type: MediaType.sticker, // Image layer
                      mediaDuration: 15.0,
                    );
                    ref.read(editorProjectProvider.notifier).addMediaLayer(media);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _syncVideoController(String videoPath, bool isPlaying, double currentPlayheadTime) {
    if (_activeVideoPath != videoPath) {
      _videoController?.dispose();
      _activeVideoPath = videoPath;
      _videoController = VideoPlayerController.file(File(videoPath))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            if (isPlaying) {
              _videoController?.play();
            }
          }
        });
      
      _videoController!.addListener(() {
        if (!mounted || _videoController == null) return;
        if (_videoController!.value.isPlaying) {
          final pos = _videoController!.value.position.inMilliseconds / 1000.0;
          ref.read(editorProjectProvider.notifier).seekPlayhead(pos);
        }
      });
      return;
    }

    if (_videoController != null && _videoController!.value.isInitialized) {
      if (isPlaying && !_videoController!.value.isPlaying) {
        _videoController?.play();
      } else if (!isPlaying && _videoController!.value.isPlaying) {
        _videoController?.pause();
      }

      final currentPos = _videoController!.value.position.inMilliseconds / 1000.0;
      if ((currentPos - currentPlayheadTime).abs() > 0.5) {
        _videoController?.seekTo(Duration(milliseconds: (currentPlayheadTime * 1000).toInt()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorProjectProvider);
    final notifier = ref.read(editorProjectProvider.notifier);

    final videoLayers = project.mediaLayers.where((m) => m.type == MediaType.video).toList();
    final imageLayers = project.mediaLayers.where((m) => m.type == MediaType.sticker).toList();

    if (videoLayers.isNotEmpty && videoLayers.first.isVisible) {
      _syncVideoController(videoLayers.first.path, project.isPlaying, project.currentPlayheadTime);
    }

    final targetRatio = project.aspectRatio.ratio;

    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 3.0,
      child: Center(
        child: AspectRatio(
          aspectRatio: targetRatio,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // 1. Background Video or Image Layer or Empty Picker State
                  if (_videoController != null && _videoController!.value.isInitialized)
                    SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _videoController!.value.size.width,
                          height: _videoController!.value.size.height,
                          child: VideoPlayer(_videoController!),
                        ),
                      ),
                    )
                  else if (imageLayers.isNotEmpty && File(imageLayers.first.path).existsSync())
                    SizedBox.expand(
                      child: Image.file(
                        File(imageLayers.first.path),
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1E1E2C), Color(0xFF232334)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white),
                          label: const Text('Pick Video or Image', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: _pickMediaDialog,
                        ),
                      ),
                    ),

                  // 2. Interactive Text Overlays
                  ...project.textLayers.where((t) => t.isVisible).map((textLayer) {
                    final isSelected = project.selectedLayerId == textLayer.id;
                    final isVisibleAtTime = project.currentPlayheadTime >= textLayer.startTime &&
                        project.currentPlayheadTime <= textLayer.endTime;

                    if (!isVisibleAtTime) return const SizedBox.shrink();

                    return Positioned.fill(
                      key: ValueKey(textLayer.id),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final left = (textLayer.position.dx * constraints.maxWidth - 60)
                              .clamp(0.0, constraints.maxWidth - 40);
                          final top = (textLayer.position.dy * constraints.maxHeight - 30)
                              .clamp(0.0, constraints.maxHeight - 30);

                          return Stack(
                            children: [
                              Positioned(
                                left: left,
                                top: top,
                                child: GestureDetector(
                                  onTap: () {
                                    notifier.selectLayer(textLayer.id);
                                  },
                                  onPanUpdate: (details) {
                                    final newDx = (left + details.delta.dx + 60) / constraints.maxWidth;
                                    final newDy = (top + details.delta.dy + 30) / constraints.maxHeight;

                                    notifier.updateTextLayer(
                                      textLayer.copyWith(
                                        position: Offset(
                                          newDx.clamp(0.05, 0.95),
                                          newDy.clamp(0.05, 0.95),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Transform.rotate(
                                    angle: textLayer.rotation,
                                    child: Transform.scale(
                                      scale: textLayer.scaleX,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          border: isSelected
                                              ? Border.all(color: AppTheme.primaryAccent, width: 2)
                                              : null,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Text(
                                              textLayer.text,
                                              textAlign: textLayer.textAlign,
                                              style: TextStyle(
                                                color: textLayer.textColor,
                                                fontSize: textLayer.fontSize,
                                                fontWeight: textLayer.fontWeight,
                                                letterSpacing: textLayer.letterSpacing,
                                                shadows: [
                                                  Shadow(
                                                    color: textLayer.strokeColor ?? Colors.black,
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                            ),

                                            if (isSelected) ...[
                                              // Delete Handle
                                              Positioned(
                                                right: -12,
                                                top: -12,
                                                child: GestureDetector(
                                                  onTap: () => notifier.deleteTextLayer(textLayer.id),
                                                  child: const CircleAvatar(
                                                    radius: 10,
                                                    backgroundColor: Colors.redAccent,
                                                    child: Icon(Icons.close, size: 12, color: Colors.white),
                                                  ),
                                                ),
                                              ),

                                              // Edit Handle
                                              Positioned(
                                                left: -12,
                                                top: -12,
                                                child: GestureDetector(
                                                  onTap: widget.onOpenTextEditor,
                                                  child: const CircleAvatar(
                                                    radius: 10,
                                                    backgroundColor: AppTheme.primaryAccent,
                                                    child: Icon(Icons.edit, size: 12, color: Colors.white),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
