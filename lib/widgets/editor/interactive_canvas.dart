import 'dart:async';
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
  final void Function({int initialIndex})? onOpenTextEditor;

  const InteractiveCanvasWidget({
    super.key,
    this.onOpenTextEditor,
  });

  @override
  ConsumerState<InteractiveCanvasWidget> createState() => _InteractiveCanvasWidgetState();
}

class _InteractiveCanvasWidgetState extends ConsumerState<InteractiveCanvasWidget> {
  final Map<String, VideoPlayerController> _videoControllers = {};
  Timer? _playbackTimer;
  final ImagePicker _picker = ImagePicker();

  // For text gesture tracking
  double _baseTextScale = 1.0;
  double _baseTextRotation = 0.0;
  Offset _baseTextPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    // A single timer ensures UI updates continuously for playback scrubbing
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      final project = ref.read(editorProjectProvider);
      if (project.isPlaying) {
        // Find the background (first) video to drive the master playhead if it's playing
        final mainVideo = project.mediaLayers.firstWhere(
          (m) => m.type == MediaType.video,
          orElse: () => MediaLayerModel(id: '', path: '', type: MediaType.video, mediaDuration: 0),
        );
        if (mainVideo.id.isNotEmpty && _videoControllers.containsKey(mainVideo.id)) {
          final ctrl = _videoControllers[mainVideo.id]!;
          if (ctrl.value.isInitialized && ctrl.value.isPlaying) {
            final pos = (ctrl.value.position.inMilliseconds / 1000.0) + mainVideo.startTime - mainVideo.trimStartTime;
            if (!project.isScrubbing) {
              ref.read(editorProjectProvider.notifier).seekPlayhead(pos);
            }
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
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

  void _syncVideoControllers(List<MediaLayerModel> videoLayers, bool isPlaying, double currentPlayheadTime) {
    // 1. Initialize any missing controllers
    for (final layer in videoLayers) {
      if (!_videoControllers.containsKey(layer.id)) {
        final ctrl = VideoPlayerController.file(File(layer.path));
        _videoControllers[layer.id] = ctrl;
        ctrl.initialize().then((_) {
          if (mounted) setState(() {});
        });
      }
    }

    // 2. Remove obsolete controllers
    final activeIds = videoLayers.map((l) => l.id).toSet();
    _videoControllers.keys.where((id) => !activeIds.contains(id)).toList().forEach((id) {
      _videoControllers[id]?.dispose();
      _videoControllers.remove(id);
    });

    // 3. Sync states (Play/Pause, Seek, Volume)
    for (final layer in videoLayers) {
      final ctrl = _videoControllers[layer.id];
      if (ctrl != null && ctrl.value.isInitialized) {
        
        // Calculate relative playback time for this specific layer based on project playhead
        final layerTime = (currentPlayheadTime - layer.startTime) + layer.trimStartTime;
        final shouldBePlayingThisLayer = isPlaying && 
                                         currentPlayheadTime >= layer.startTime && 
                                         currentPlayheadTime <= layer.startTime + layer.mediaDuration;

        // Sync Volume & Mute
        final targetVolume = layer.isMuted ? 0.0 : layer.volume;
        if (ctrl.value.volume != targetVolume) {
          ctrl.setVolume(targetVolume);
        }

        // Sync Speed
        if (ctrl.value.playbackSpeed != layer.playbackSpeed) {
          ctrl.setPlaybackSpeed(layer.playbackSpeed);
        }

        // Sync Play/Pause
        if (shouldBePlayingThisLayer && !ctrl.value.isPlaying) {
          ctrl.play();
        } else if (!shouldBePlayingThisLayer && ctrl.value.isPlaying) {
          ctrl.pause();
        }

        // Sync Seek (if diff > 0.5s or if scrubbing)
        final currentPos = ctrl.value.position.inMilliseconds / 1000.0;
        if ((currentPos - layerTime).abs() > 0.5 || !isPlaying) {
          // only seek if we are within bounds of this media, or if we need to reset it to trimStartTime
          if (layerTime >= layer.trimStartTime && layerTime <= layer.trimStartTime + layer.mediaDuration) {
             ctrl.seekTo(Duration(milliseconds: (layerTime * 1000).toInt()));
          } else {
             // Reset to beginning if it's outside its active window
             ctrl.seekTo(Duration(milliseconds: (layer.trimStartTime * 1000).toInt()));
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorProjectProvider);
    final notifier = ref.read(editorProjectProvider.notifier);

    final videoLayers = project.mediaLayers.where((m) => m.type == MediaType.video).toList();
    final imageLayers = project.mediaLayers.where((m) => m.type == MediaType.sticker).toList();

    _syncVideoControllers(videoLayers, project.isPlaying, project.currentPlayheadTime);

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
                  // 1. Background / Empty Picker State
                  if (videoLayers.isEmpty && imageLayers.isEmpty)
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

                  // 1.5 Media Layers (Images & Videos PIP)
                  ...project.mediaLayers.where((m) => m.isVisible).map((layer) {
                    final isSelected = project.selectedLayerId == layer.id;
                    final isVisibleAtTime = project.currentPlayheadTime >= layer.startTime &&
                        project.currentPlayheadTime <= layer.startTime + layer.mediaDuration;

                    if (!isVisibleAtTime) return const SizedBox.shrink();

                    Widget mediaWidget = const SizedBox.shrink();

                    if (layer.type == MediaType.video) {
                      final ctrl = _videoControllers[layer.id];
                      if (ctrl != null && ctrl.value.isInitialized) {
                        mediaWidget = SizedBox.expand(
                          child: FittedBox(
                            fit: layer.fitMode == VideoFitMode.cover ? BoxFit.cover : BoxFit.contain,
                            child: SizedBox(
                              width: ctrl.value.size.width,
                              height: ctrl.value.size.height,
                              child: VideoPlayer(ctrl),
                            ),
                          ),
                        );
                      }
                    } else if (layer.type == MediaType.sticker) {
                      if (File(layer.path).existsSync()) {
                        mediaWidget = SizedBox.expand(
                          child: Image.file(
                            File(layer.path),
                            fit: layer.fitMode == VideoFitMode.cover ? BoxFit.cover : BoxFit.contain,
                          ),
                        );
                      }
                    }

                    // For the first layer (background), make it full screen and non-draggable
                    final isBackground = project.mediaLayers.first.id == layer.id;
                    if (isBackground) {
                      return GestureDetector(
                        onTap: () => notifier.selectLayer(layer.id),
                        child: mediaWidget,
                      );
                    }

                    // For PIP/Overlay layers, make them draggable
                    return Positioned.fill(
                      key: ValueKey(layer.id),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final left = (layer.position.dx * constraints.maxWidth - (constraints.maxWidth * layer.scaleX) / 2);
                          final top = (layer.position.dy * constraints.maxHeight - (constraints.maxHeight * layer.scaleY) / 2);

                          return Stack(
                            children: [
                              Positioned(
                                left: left,
                                top: top,
                                width: constraints.maxWidth * layer.scaleX,
                                height: constraints.maxHeight * layer.scaleY,
                                child: GestureDetector(
                                  onTap: () => notifier.selectLayer(layer.id),
                                  onPanUpdate: (details) {
                                    final newDx = (left + details.delta.dx + (constraints.maxWidth * layer.scaleX) / 2) / constraints.maxWidth;
                                    final newDy = (top + details.delta.dy + (constraints.maxHeight * layer.scaleY) / 2) / constraints.maxHeight;
                                    notifier.updateMediaLayerProperties(
                                      layer.id,
                                      startTime: layer.startTime, // dummy update to trigger position (no update method exists for position so we'd normally just copy it, but since state lacks it, we will just use updateMediaLayer replacing it)
                                    );
                                    
                                    // Properly update position via updateMediaLayer
                                    notifier.updateMediaLayer(
                                      layer.copyWith(position: Offset(newDx, newDy))
                                    );
                                  },
                                  child: Container(
                                    decoration: isSelected
                                        ? BoxDecoration(border: Border.all(color: AppTheme.primaryAccent, width: 2))
                                        : null,
                                    child: mediaWidget,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  }),

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
                                  onScaleStart: (details) {
                                    notifier.selectLayer(textLayer.id);
                                    _baseTextScale = textLayer.scaleX;
                                    _baseTextRotation = textLayer.rotation;
                                    _baseTextPosition = textLayer.position;
                                  },
                                  onScaleUpdate: (details) {
                                    // Calculate new position
                                    final currentDx = _baseTextPosition.dx * constraints.maxWidth;
                                    final currentDy = _baseTextPosition.dy * constraints.maxHeight;
                                    
                                    final newDx = (currentDx + details.focalPointDelta.dx) / constraints.maxWidth;
                                    final newDy = (currentDy + details.focalPointDelta.dy) / constraints.maxHeight;
                                    
                                    _baseTextPosition = Offset(
                                      newDx.clamp(0.05, 0.95),
                                      newDy.clamp(0.05, 0.95),
                                    );

                                    // Calculate new scale and rotation
                                    final newScale = (_baseTextScale * details.scale).clamp(0.5, 5.0);
                                    final newRotation = _baseTextRotation + details.rotation;

                                    notifier.updateTextLayer(
                                      textLayer.copyWith(
                                        position: _baseTextPosition,
                                        scaleX: newScale,
                                        scaleY: newScale,
                                        rotation: newRotation,
                                      ),
                                    );
                                  },
                                  onScaleEnd: (details) {
                                    notifier.pushHistory(); // Save the final state to undo stack
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
                                                  onTap: () => widget.onOpenTextEditor?.call(),
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
