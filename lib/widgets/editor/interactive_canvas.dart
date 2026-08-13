import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/media_layer_model.dart';
import '../../models/aspect_ratio_model.dart';
import '../../models/text_layer_model.dart';
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
  final Map<String, AudioPlayer> _audioPlayers = {};
  Timer? _playbackTimer;
  DateTime? _seekIgnoreTimerUntil;
  final ImagePicker _picker = ImagePicker();

  // For text gesture tracking
  double _baseTextScale = 1.0;
  double _baseTextRotation = 0.0;
  Offset _baseTextPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    // Continuous timer for scrubber & playhead sync (120ms lightweight update for 60 FPS video smoothness)
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 32), (timer) {
      final project = ref.read(editorProjectProvider);
      if (project.isPlaying && !project.isScrubbing) {
        if (_seekIgnoreTimerUntil != null && DateTime.now().isBefore(_seekIgnoreTimerUntil!)) {
          return;
        }

        final newTime = project.currentPlayheadTime + 0.032;
        final notifier = ref.read(editorProjectProvider.notifier);
        
        if (newTime >= project.duration) {
          notifier.setPlaying(false);
          notifier.seekPlayhead(0.0);
        } else {
          notifier.seekPlayhead(newTime);
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
    for (final player in _audioPlayers.values) {
      player.dispose();
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
                    double duration = 15.0;
                    try {
                      VideoPlayerController controller;
                      if (kIsWeb || file.path.startsWith('blob:') || file.path.startsWith('http')) {
                        controller = VideoPlayerController.networkUrl(Uri.parse(file.path));
                      } else {
                        controller = VideoPlayerController.file(File(file.path));
                      }
                      await controller.initialize();
                      if (controller.value.duration.inMilliseconds > 0) {
                        duration = controller.value.duration.inMilliseconds / 1000.0;
                      }
                      await controller.dispose();
                    } catch (_) {}

                    final media = MediaLayerModel(
                      id: const Uuid().v4(),
                      path: file.path,
                      type: MediaType.video,
                      mediaDuration: duration,
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
                      type: MediaType.sticker,
                      mediaDuration: 5.0,
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

  void _syncMediaControllers(List<MediaLayerModel> videoLayers, List<MediaLayerModel> audioLayers, bool isPlaying, double currentPlayheadTime) {
    // 1. Initialize any missing controllers for VIDEO
    for (final layer in videoLayers) {
      if (!_videoControllers.containsKey(layer.id)) {
        VideoPlayerController ctrl;
        if (kIsWeb || layer.path.startsWith('blob:') || layer.path.startsWith('http')) {
          ctrl = VideoPlayerController.networkUrl(Uri.parse(layer.path));
        } else {
          ctrl = VideoPlayerController.file(File(layer.path));
        }
        _videoControllers[layer.id] = ctrl;
        ctrl.initialize().then((_) {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {});
            });
          }
        }).catchError((_) {});
      }
    }
    
    // 1.5 Initialize any missing controllers for AUDIO
    for (final layer in audioLayers) {
      if (!_audioPlayers.containsKey(layer.id)) {
        final p = AudioPlayer();
        p.setFilePath(layer.path).catchError((_) {});
        _audioPlayers[layer.id] = p;
      }
    }

    // 2. Remove obsolete controllers
    final activeVideoIds = videoLayers.map((l) => l.id).toSet();
    _videoControllers.keys.where((id) => !activeVideoIds.contains(id)).toList().forEach((id) {
      _videoControllers[id]?.dispose();
      _videoControllers.remove(id);
    });
    
    final activeAudioIds = audioLayers.map((l) => l.id).toSet();
    _audioPlayers.keys.where((id) => !activeAudioIds.contains(id)).toList().forEach((id) {
      _audioPlayers[id]?.dispose();
      _audioPlayers.remove(id);
    });

    // 3. Sync states for VIDEO
    for (final layer in videoLayers) {
      final ctrl = _videoControllers[layer.id];
      if (ctrl != null && ctrl.value.isInitialized) {
        final layerTime = (currentPlayheadTime - layer.startTime) + layer.trimStartTime;
        final shouldBePlayingThisLayer = isPlaying && 
                                         currentPlayheadTime >= layer.startTime && 
                                         currentPlayheadTime <= layer.startTime + layer.mediaDuration;

        final targetVolume = layer.isMuted ? 0.0 : layer.volume;
        if (ctrl.value.volume != targetVolume) {
          ctrl.setVolume(targetVolume);
        }

        if (ctrl.value.playbackSpeed != layer.playbackSpeed) {
          ctrl.setPlaybackSpeed(layer.playbackSpeed);
        }

        if (shouldBePlayingThisLayer && !ctrl.value.isPlaying) {
          ctrl.play();
        } else if (!shouldBePlayingThisLayer && ctrl.value.isPlaying) {
          ctrl.pause();
        }

        final currentPos = ctrl.value.position.inMilliseconds / 1000.0;
        if (!isPlaying) {
          if ((currentPos - layerTime).abs() > 0.1) {
            if (_seekIgnoreTimerUntil == null || DateTime.now().isAfter(_seekIgnoreTimerUntil!)) {
              _seekIgnoreTimerUntil = DateTime.now().add(const Duration(milliseconds: 350));
              if (layerTime >= layer.trimStartTime && layerTime <= layer.trimStartTime + layer.mediaDuration) {
                 ctrl.seekTo(Duration(milliseconds: (layerTime * 1000).toInt()));
              } else {
                 ctrl.seekTo(Duration(milliseconds: (layer.trimStartTime * 1000).toInt()));
              }
            }
          }
        }
      }
    }
    
    // 4. Sync states for AUDIO
    for (final layer in audioLayers) {
      final p = _audioPlayers[layer.id];
      if (p != null) {
        final layerTime = (currentPlayheadTime - layer.startTime) + layer.trimStartTime;
        final shouldBePlayingThisLayer = isPlaying && 
                                         currentPlayheadTime >= layer.startTime && 
                                         currentPlayheadTime <= layer.startTime + layer.mediaDuration;

        final targetVolume = layer.isMuted ? 0.0 : layer.volume;
        if (p.volume != targetVolume) {
          p.setVolume(targetVolume);
        }

        if (shouldBePlayingThisLayer && !p.playing) {
          p.play();
        } else if (!shouldBePlayingThisLayer && p.playing) {
          p.pause();
        }

        final currentPos = p.position.inMilliseconds / 1000.0;
        if (!isPlaying) {
          if ((currentPos - layerTime).abs() > 0.1) {
            if (_seekIgnoreTimerUntil == null || DateTime.now().isAfter(_seekIgnoreTimerUntil!)) {
              _seekIgnoreTimerUntil = DateTime.now().add(const Duration(milliseconds: 350));
              if (layerTime >= layer.trimStartTime && layerTime <= layer.trimStartTime + layer.mediaDuration) {
                 p.seek(Duration(milliseconds: (layerTime * 1000).toInt()));
              } else {
                 p.seek(Duration(milliseconds: (layer.trimStartTime * 1000).toInt()));
              }
            }
          }
        }
      }
    }
  }

  Widget _buildStickerWidget(String path, VideoFitMode fitMode) {
    final fit = fitMode == VideoFitMode.contain ? BoxFit.contain : BoxFit.cover;
    if (kIsWeb || path.startsWith('blob:') || path.startsWith('http')) {
      return Image.network(
        path,
        fit: fit,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54)),
      );
    } else {
      return Image.file(
        File(path),
        fit: fit,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorProjectProvider);
    final notifier = ref.read(editorProjectProvider.notifier);

    final videoLayers = project.mediaLayers.where((m) => m.type == MediaType.video).toList();
    final audioLayers = project.mediaLayers.where((m) => m.type == MediaType.audio).toList();
    final imageLayers = project.mediaLayers.where((m) => m.type == MediaType.sticker).toList();

    _syncMediaControllers(videoLayers, audioLayers, project.isPlaying, project.currentPlayheadTime);

    final targetRatio = project.aspectRatio.ratio;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => notifier.selectLayer(null),
      child: LayoutBuilder(
        builder: (context, outerConstraints) {
          final maxW = outerConstraints.maxWidth;
          final maxH = outerConstraints.maxHeight;

          if (maxW <= 0 || maxH <= 0) return const SizedBox.shrink();

          double canvasW;
          double canvasH;

          final containerRatio = maxW / maxH;
          if (targetRatio > containerRatio) {
            canvasW = maxW;
            canvasH = maxW / targetRatio;
          } else {
            canvasH = maxH;
            canvasW = maxH * targetRatio;
          }

          return Center(
            child: SizedBox(
              width: canvasW,
              height: canvasH,
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
                      clipBehavior: Clip.none,
                      children: [
                        // 1. Empty Picker Button
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

                        // 2. Media Layers (Video & Images)
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
                                  fit: layer.fitMode == VideoFitMode.contain ? BoxFit.contain : BoxFit.cover,
                                  child: SizedBox(
                                    width: ctrl.value.size.width,
                                    height: ctrl.value.size.height,
                                    child: VideoPlayer(ctrl),
                                  ),
                                ),
                              );
                            }
                          } else if (layer.type == MediaType.sticker) {
                            mediaWidget = SizedBox.expand(
                              child: _buildStickerWidget(layer.path, layer.fitMode),
                            );
                          }

                          final isBackground = project.mediaLayers.first.id == layer.id;
                          if (isBackground) {
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => notifier.selectLayer(layer.id),
                              child: IgnorePointer(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    // Removed border from interactive canvas
                                  ),
                                  child: mediaWidget,
                                ),
                              ),
                            );
                          }

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
                                      child: GestureDetector(
                                        onTap: () => notifier.selectLayer(layer.id),
                                        onScaleStart: (_) => notifier.pushHistory(),
                                        onScaleUpdate: (details) {
                                          final newScale = (layer.scaleX * details.scale).clamp(0.2, 5.0);
                                          notifier.updateMediaLayer(layer.copyWith(scaleX: newScale, scaleY: newScale), recordHistory: false);
                                        },
                                        child: Transform.rotate(
                                          angle: layer.rotation,
                                          child: SizedBox(
                                            width: constraints.maxWidth * layer.scaleX,
                                            height: constraints.maxHeight * layer.scaleY,
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                mediaWidget,
                                                if (project.selectedLayerId == layer.id) ...[
                                                  Positioned(
                                                    left: -14,
                                                    top: -14,
                                                    child: GestureDetector(
                                                      behavior: HitTestBehavior.opaque,
                                                      onTap: () => notifier.deleteMediaLayer(layer.id),
                                                      child: const CircleAvatar(radius: 12, backgroundColor: Colors.redAccent, child: Icon(Icons.close, size: 14, color: Colors.white)),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    right: -14,
                                                    bottom: -14,
                                                    child: GestureDetector(
                                                      behavior: HitTestBehavior.opaque,
                                                      onPanStart: (_) => notifier.pushHistory(),
                                                      onPanUpdate: (details) {
                                                        final newScale = (layer.scaleX + (details.delta.dx + details.delta.dy) * 0.005).clamp(0.2, 5.0);
                                                        notifier.updateMediaLayer(layer.copyWith(scaleX: newScale, scaleY: newScale), recordHistory: false);
                                                      },
                                                      child: const CircleAvatar(radius: 12, backgroundColor: AppTheme.primaryAccent, child: Icon(Icons.open_with, size: 14, color: Colors.white)),
                                                    ),
                                                  ),
                                                ]
                                              ],
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

                        // 3. Interactive Centered Text Overlays
                        ...project.textLayers.where((t) => t.isVisible).map((textLayer) {
                          final isSelected = project.selectedLayerId == textLayer.id;
                          final isVisibleAtTime = project.currentPlayheadTime >= textLayer.startTime &&
                              project.currentPlayheadTime <= textLayer.endTime;

                          if (!isVisibleAtTime) return const SizedBox.shrink();

                          final centerX = textLayer.position.dx * canvasW;
                          final centerY = textLayer.position.dy * canvasH;

                          return Positioned(
                            key: ValueKey(textLayer.id),
                            left: centerX,
                            top: centerY,
                            child: FractionalTranslation(
                              translation: const Offset(-0.5, -0.5),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  notifier.selectLayer(textLayer.id);
                                },
                                onDoubleTap: () {
                                  notifier.selectLayer(textLayer.id);
                                  widget.onOpenTextEditor?.call(initialIndex: 0);
                                },
                                // Removed long press because onScaleUpdate handles 1-finger panning perfectly
                                onPanStart: (details) {
                                  notifier.pushHistory();
                                  notifier.selectLayer(textLayer.id);
                                  _baseTextPosition = textLayer.position;
                                },
                                onPanUpdate: (details) {
                                  final currentDx = _baseTextPosition.dx * canvasW;
                                  final currentDy = _baseTextPosition.dy * canvasH;

                                  final newDx = ((currentDx + details.delta.dx) / canvasW).clamp(0.05, 0.95);
                                  final newDy = ((currentDy + details.delta.dy) / canvasH).clamp(0.05, 0.95);

                                  _baseTextPosition = Offset(newDx, newDy);

                                  notifier.updateTextLayer(
                                    textLayer.copyWith(
                                      position: _baseTextPosition,
                                    ),
                                    recordHistory: false,
                                  );
                                },
                                child: Transform.rotate(
                                  angle: textLayer.rotation,
                                  child: Transform.scale(
                                    scale: textLayer.scaleX,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        // Text Box Border & Content Container
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: textLayer.backgroundColor,
                                            borderRadius: BorderRadius.circular(textLayer.boxBorderRadius),
                                            border: isSelected ? Border.all(color: Colors.white.withOpacity(0.8), width: 1.0) : null,
                                          ),
                                          width: textLayer.boxWidth,
                                          height: textLayer.boxHeight,
                                          constraints: BoxConstraints(
                                            minWidth: 120.0,
                                            minHeight: 48.0,
                                            maxWidth: (canvasW * 0.95).clamp(120.0, canvasW),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            textLayer.text,
                                            textAlign: textLayer.textAlign,
                                            softWrap: true,
                                            style: () {
                                              final baseStyle = TextStyle(
                                                fontSize: textLayer.fontSize,
                                                color: textLayer.textColor,
                                                fontWeight: textLayer.fontWeight,
                                                fontStyle: textLayer.fontStyle,
                                                letterSpacing: textLayer.letterSpacing,
                                                shadows: [
                                                  Shadow(
                                                    color: textLayer.strokeColor ?? Colors.black.withOpacity(0.9),
                                                    blurRadius: (textLayer.strokeColor != null ? textLayer.strokeWidth : 2.0) * 1.5,
                                                  ),
                                                  Shadow(
                                                    color: textLayer.strokeColor ?? Colors.black.withOpacity(0.9),
                                                    offset: const Offset(1, 1),
                                                  ),
                                                  Shadow(
                                                    color: textLayer.strokeColor ?? Colors.black.withOpacity(0.9),
                                                    offset: const Offset(-1, -1),
                                                  ),
                                                ],
                                              );
                                              try {
                                                if (textLayer.fontFamily != null && textLayer.fontFamily!.isNotEmpty) {
                                                  return GoogleFonts.getFont(textLayer.fontFamily!, textStyle: baseStyle);
                                                }
                                              } catch (_) {}
                                              return GoogleFonts.outfit(textStyle: baseStyle);
                                            }(),
                                          ),
                                        ),

                                        // Handles when Selected
                                        if (isSelected) ...[
                                          // --- 4 Corner Dots for Scaling ---
                                          ...[
                                            const Alignment(-1, -1), // Top-Left
                                            const Alignment(1, -1),  // Top-Right
                                            const Alignment(-1, 1),  // Bottom-Left
                                            const Alignment(1, 1),   // Bottom-Right
                                          ].map((align) {
                                            return Positioned(
                                              left: align.x == -1 ? -6 : null,
                                              right: align.x == 1 ? -6 : null,
                                              top: align.y == -1 ? -6 : null,
                                              bottom: align.y == 1 ? -6 : null,
                                              child: GestureDetector(
                                                behavior: HitTestBehavior.opaque,
                                                onPanStart: (_) => notifier.pushHistory(),
                                                onPanUpdate: (details) {
                                                  // Simple scaling based on diagonal drag distance
                                                  final direction = align.x * align.y; // positive for TR/BL, negative for TL/BR
                                                  double delta = 0;
                                                  if (align.x == 1 && align.y == 1) { // BR
                                                    delta = (details.delta.dx + details.delta.dy) * 0.005;
                                                  } else if (align.x == -1 && align.y == -1) { // TL
                                                    delta = -(details.delta.dx + details.delta.dy) * 0.005;
                                                  } else if (align.x == 1 && align.y == -1) { // TR
                                                    delta = (details.delta.dx - details.delta.dy) * 0.005;
                                                  } else if (align.x == -1 && align.y == 1) { // BL
                                                    delta = (-details.delta.dx + details.delta.dy) * 0.005;
                                                  }
                                                  
                                                  final newScale = (textLayer.scaleX + delta).clamp(0.2, 5.0);
                                                  final newFontSize = (textLayer.fontSize + delta * 20).clamp(12.0, 150.0);
                                                  notifier.updateTextLayer(textLayer.copyWith(scaleX: newScale, fontSize: newFontSize), recordHistory: false);
                                                },
                                                child: Container(
                                                  width: 12, height: 12,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: Colors.black26, width: 1),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),

                                          // --- Left and Right Pill Handles for Width Adjust ---
                                          ...[
                                            const Alignment(-1, 0), // Left
                                            const Alignment(1, 0),  // Right
                                          ].map((align) {
                                            return Positioned(
                                              left: align.x == -1 ? -6 : null,
                                              right: align.x == 1 ? -6 : null,
                                              top: 0, bottom: 0,
                                              child: Center(
                                                child: GestureDetector(
                                                  behavior: HitTestBehavior.opaque,
                                                  onPanStart: (_) => notifier.pushHistory(),
                                                  onPanUpdate: (details) {
                                                    final delta = align.x == 1 ? details.delta.dx : -details.delta.dx;
                                                    final newWidth = ((textLayer.boxWidth ?? 120.0) + delta * 2).clamp(60.0, canvasW);
                                                    notifier.updateTextLayer(textLayer.copyWith(boxWidth: newWidth), recordHistory: false);
                                                  },
                                                  child: Container(
                                                    width: 12, height: 24,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: Colors.black26, width: 1),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),

                                          // --- Bottom Rotate Handle ---
                                          Positioned(
                                            bottom: -32,
                                            left: 0, right: 0,
                                            child: Center(
                                              child: GestureDetector(
                                                behavior: HitTestBehavior.opaque,
                                                onPanStart: (_) => notifier.pushHistory(),
                                                onPanUpdate: (details) {
                                                  // Rotating
                                                  final rotDelta = details.delta.dx * 0.01;
                                                  final newRotation = textLayer.rotation + rotDelta;
                                                  notifier.updateTextLayer(textLayer.copyWith(rotation: newRotation), recordHistory: false);
                                                },
                                                child: Container(
                                                  width: 24, height: 24,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: Colors.black26, width: 1),
                                                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                                  ),
                                                  child: const Icon(Icons.sync_rounded, size: 16, color: Colors.black87),
                                                ),
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
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
  }
}
