import 'dart:async';
import 'dart:io';
import 'dart:math';
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
import 'text_bubble_painter.dart';

class InteractiveCanvasWidget extends ConsumerStatefulWidget {
  final void Function({int initialIndex})? onOpenTextEditor;

  const InteractiveCanvasWidget({
    super.key,
    this.onOpenTextEditor,
  });

  @override
  ConsumerState<InteractiveCanvasWidget> createState() => _InteractiveCanvasWidgetState();
}

class _InteractiveCanvasWidgetState extends ConsumerState<InteractiveCanvasWidget> with WidgetsBindingObserver {
  final Map<String, VideoPlayerController> _videoControllers = {};
  final Map<String, AudioPlayer> _audioPlayers = {};
  Timer? _playbackTimer;
  final ImagePicker _picker = ImagePicker();

  // For text gesture tracking
  double _baseTextScale = 1.0;
  double _baseTextRotation = 0.0;
  Offset _baseTextPosition = Offset.zero;
  double _initialHandleDist = 1.0;
  double _initialHandleAngle = 0.0;
  double _initialFontSize = 20.0;
  double? _initialBoxWidth;
  double? _initialBoxHeight;
  double _initialRotation = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPlaybackTimer();
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 32), (timer) {
      final project = ref.read(editorProjectProvider);
      if (project.isPlaying && !project.isScrubbing) {
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached || state == AppLifecycleState.hidden) {
      _playbackTimer?.cancel();
      for (final ctrl in _videoControllers.values) {
        try {
          if (ctrl.value.isPlaying) {
            ctrl.pause();
          }
        } catch (_) {}
      }
      for (final p in _audioPlayers.values) {
        try {
          if (p.playing) {
            p.pause();
          }
        } catch (_) {}
      }
      ref.read(editorProjectProvider.notifier).setPlaying(false);
    } else if (state == AppLifecycleState.resumed) {
      _startPlaybackTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  double _lastSyncedPlayheadTime = 0.0;
  DateTime? _lastScrubSeekTime;

  void _syncMediaControllers(List<MediaLayerModel> videoLayers, List<MediaLayerModel> audioLayers, bool isPlaying, double currentPlayheadTime, bool isScrubbing) {
    // 1. Initialize any missing controllers for VIDEO
    for (final layer in videoLayers) {
      if (!_videoControllers.containsKey(layer.id)) {
        VideoPlayerController ctrl;
        if (kIsWeb || layer.path.startsWith('blob:') || layer.path.startsWith('http')) {
          ctrl = VideoPlayerController.networkUrl(
            Uri.parse(layer.path),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
        } else {
          ctrl = VideoPlayerController.file(
            File(layer.path),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
        }
        _videoControllers[layer.id] = ctrl;
        ctrl.initialize().then((_) {
          if (mounted) {
            final initLayerTime = (currentPlayheadTime - layer.startTime) + layer.trimStartTime;
            final clamped = initLayerTime.clamp(layer.trimStartTime, layer.trimStartTime + layer.mediaDuration);
            ctrl.seekTo(Duration(milliseconds: (clamped * 1000).toInt()));
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
        p.setFilePath(layer.path).then((_) {
          final initLayerTime = (currentPlayheadTime - layer.startTime) + layer.trimStartTime;
          final clamped = initLayerTime.clamp(layer.trimStartTime, layer.trimStartTime + layer.mediaDuration);
          p.seek(Duration(milliseconds: (clamped * 1000).toInt()));
        }).catchError((_) {});
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

    // 3. Determine if we need to explicitly seek all media controllers
    bool shouldSeek = false;
    if (!isPlaying) {
      // When paused, ANY change in playhead time must seek to show the exact frame
      if ((currentPlayheadTime - _lastSyncedPlayheadTime).abs() > 0.001) {
        shouldSeek = true;
      }
    } else if (isScrubbing) {
      // While actively scrubbing during playback, throttle seeking to 50ms so ExoPlayer doesn't get overloaded
      final now = DateTime.now();
      if (_lastScrubSeekTime == null || now.difference(_lastScrubSeekTime!).inMilliseconds >= 50) {
        shouldSeek = true;
        _lastScrubSeekTime = now;
      }
    } else {
      // While playing normally: only seek if playhead jumped (e.g. 5s skip button, or scrub release)
      final delta = currentPlayheadTime - _lastSyncedPlayheadTime;
      // Normal playback delta is ~0.032s. A jump is backwards (< 0) or forwards (> 0.12s)
      if (delta < -0.01 || delta > 0.12) {
        shouldSeek = true;
      }
    }

    _lastSyncedPlayheadTime = currentPlayheadTime;

    // 4. Sync states & perform seek for VIDEO
    for (final layer in videoLayers) {
      final ctrl = _videoControllers[layer.id];
      if (ctrl != null && ctrl.value.isInitialized) {
        final rawLayerTime = (currentPlayheadTime - layer.startTime) + layer.trimStartTime;
        final targetLayerTime = rawLayerTime.clamp(layer.trimStartTime, layer.trimStartTime + layer.mediaDuration);
        final shouldBePlayingThisLayer = isPlaying && !isScrubbing &&
                                         currentPlayheadTime >= layer.startTime && 
                                         currentPlayheadTime <= layer.startTime + layer.mediaDuration;

        final targetVolume = layer.isMuted ? 0.0 : layer.volume;
        if (ctrl.value.volume != targetVolume) {
          ctrl.setVolume(targetVolume);
        }

        if (ctrl.value.playbackSpeed != layer.playbackSpeed) {
          ctrl.setPlaybackSpeed(layer.playbackSpeed);
        }

        if (shouldSeek) {
          ctrl.seekTo(Duration(milliseconds: (targetLayerTime * 1000).toInt()));
        }

        if (shouldBePlayingThisLayer && !ctrl.value.isPlaying) {
          ctrl.play();
        } else if (!shouldBePlayingThisLayer && ctrl.value.isPlaying) {
          ctrl.pause();
        }
      }
    }
    
    // 5. Sync states & perform seek for AUDIO
    for (final layer in audioLayers) {
      final p = _audioPlayers[layer.id];
      if (p != null) {
        final rawLayerTime = (currentPlayheadTime - layer.startTime) + layer.trimStartTime;
        final targetLayerTime = rawLayerTime.clamp(layer.trimStartTime, layer.trimStartTime + layer.mediaDuration);
        final shouldBePlayingThisLayer = isPlaying && !isScrubbing &&
                                         currentPlayheadTime >= layer.startTime && 
                                         currentPlayheadTime <= layer.startTime + layer.mediaDuration;

        final targetVolume = layer.isMuted ? 0.0 : layer.volume;
        if (p.volume != targetVolume) {
          p.setVolume(targetVolume);
        }

        if (shouldSeek) {
          p.seek(Duration(milliseconds: (targetLayerTime * 1000).toInt()));
        }

        if (shouldBePlayingThisLayer && !p.playing) {
          p.play();
        } else if (!shouldBePlayingThisLayer && p.playing) {
          p.pause();
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

    _syncMediaControllers(videoLayers, audioLayers, project.isPlaying, project.currentPlayheadTime, project.isScrubbing);

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

          if (project.canvasWidth != canvasW || project.canvasHeight != canvasH) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                notifier.updateProjectCanvasSize(canvasW, canvasH);
              }
            });
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

                          final firstVisualLayer = project.mediaLayers.where((m) => m.type == MediaType.video || m.type == MediaType.sticker).firstOrNull;
                          final isBackground = firstVisualLayer?.id == layer.id;
                          if (isBackground) {
                            return Positioned.fill(
                              key: ValueKey(layer.id),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => notifier.selectLayer(layer.id),
                                child: Container(
                                  color: Colors.black,
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
                              child: Builder(
                                builder: (context) {
                                  final timeSinceStart = (project.currentPlayheadTime - textLayer.startTime).clamp(0.0, double.infinity);
                                  final animDur = textLayer.animationDuration.clamp(0.1, 10.0);
                                  final animProgress = (timeSinceStart / animDur).clamp(0.0, 1.0);

                                  double liveOpacity = textLayer.opacity.clamp(0.0, 1.0);
                                  double liveScale = textLayer.scaleX;
                                  double liveTranslateY = 0.0;
                                  double liveRotateAngle = textLayer.rotation;
                                  String liveText = textLayer.text;
                                  List<Shadow>? liveGlowShadows;

                                  switch (textLayer.animation) {
                                    case TextAnimationType.none:
                                      break;
                                    case TextAnimationType.fadeIn:
                                      liveOpacity *= Curves.easeIn.transform(animProgress);
                                      break;
                                    case TextAnimationType.popIn:
                                      final s = animProgress < 0.8
                                          ? (animProgress / 0.8) * 1.2
                                          : 1.2 - ((animProgress - 0.8) / 0.2) * 0.2;
                                      liveScale *= s.clamp(0.01, 1.3);
                                      break;
                                    case TextAnimationType.blurIn:
                                      final s = 0.7 + (Curves.easeOut.transform(animProgress) * 0.3);
                                      liveScale *= s;
                                      liveOpacity *= animProgress.clamp(0.05, 1.0);
                                      break;
                                    case TextAnimationType.slideUp:
                                      liveTranslateY = (1.0 - Curves.easeOutCubic.transform(animProgress)) * 30.0;
                                      liveOpacity *= animProgress;
                                      break;
                                    case TextAnimationType.slideDown:
                                      liveTranslateY = -(1.0 - Curves.easeOutCubic.transform(animProgress)) * 30.0;
                                      liveOpacity *= animProgress;
                                      break;
                                    case TextAnimationType.typewriter:
                                      final count = (textLayer.text.length * animProgress).clamp(1, textLayer.text.length).toInt();
                                      liveText = textLayer.text.substring(0, count);
                                      break;
                                    case TextAnimationType.bounce:
                                      final b = Curves.bounceOut.transform(animProgress);
                                      liveTranslateY = (1.0 - b) * -25.0;
                                      break;
                                    case TextAnimationType.glow:
                                      final radius = (sin(timeSinceStart * pi * 3).abs() * 8.0) + 2.0;
                                      liveGlowShadows = [
                                        Shadow(color: Colors.white, blurRadius: radius),
                                        Shadow(color: const Color(0xFF00E5FF), blurRadius: radius * 1.5),
                                      ];
                                      break;
                                    case TextAnimationType.stamp:
                                      final s = animProgress < 0.6
                                          ? 2.2 - (Curves.easeInQuad.transform(animProgress / 0.6) * 1.2)
                                          : 1.0;
                                      liveScale *= s;
                                      break;
                                    case TextAnimationType.zoomIn:
                                      liveScale *= Curves.easeOutBack.transform(animProgress).clamp(0.01, 1.2);
                                      break;
                                    case TextAnimationType.wave:
                                      liveRotateAngle += sin(animProgress * pi * 2) * 0.12;
                                      break;
                                  }

                                  return Transform.translate(
                                    offset: Offset(0, liveTranslateY),
                                    child: Transform.rotate(
                                      angle: liveRotateAngle,
                                      child: Transform.scale(
                                        scale: liveScale,
                                        child: Opacity(
                                          opacity: liveOpacity,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              // 1. Text Box Body (Interactive Position & Tap)
                                              GestureDetector(
                                                behavior: HitTestBehavior.opaque,
                                                onTap: () {
                                                  notifier.selectLayer(textLayer.id);
                                                },
                                                onDoubleTap: () {
                                                  notifier.selectLayer(textLayer.id);
                                                  widget.onOpenTextEditor?.call(initialIndex: 0);
                                                },
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
                                                child: Builder(
                                                  builder: (context) {
                                                    final hasBubble = textLayer.bubbleStyle != null && textLayer.bubbleStyle != 'none';

                                                    final textWidget = Padding(
                                                      padding: EdgeInsets.symmetric(
                                                        horizontal: hasBubble ? 24.0 : 16.0,
                                                        vertical: hasBubble ? 12.0 : 8.0,
                                                      ),
                                                      child: Text(
                                                        liveText,
                                                        textAlign: textLayer.textAlign,
                                                        softWrap: true,
                                                        style: () {
                                                          final baseStyle = TextStyle(
                                                            fontSize: textLayer.fontSize,
                                                            color: textLayer.textColor,
                                                            fontWeight: textLayer.fontWeight,
                                                            fontStyle: textLayer.fontStyle,
                                                            letterSpacing: textLayer.letterSpacing,
                                                            height: textLayer.lineSpacing,
                                                            shadows: liveGlowShadows ?? [
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
                                                    );

                                                    if (hasBubble) {
                                                      return CustomPaint(
                                                        painter: BubbleShapePainter(
                                                          styleId: textLayer.bubbleStyle!,
                                                          customColor: textLayer.backgroundColor,
                                                        ),
                                                        child: Container(
                                                          width: textLayer.boxWidth,
                                                          height: textLayer.boxHeight,
                                                          constraints: BoxConstraints(
                                                            minWidth: 40.0,
                                                            minHeight: 30.0,
                                                            maxWidth: (canvasW * 0.95).clamp(40.0, canvasW),
                                                          ),
                                                          child: textWidget,
                                                        ),
                                                      );
                                                    }

                                                    return Container(
                                                      decoration: BoxDecoration(
                                                        color: textLayer.backgroundColor,
                                                        borderRadius: BorderRadius.circular(textLayer.boxBorderRadius),
                                                        border: isSelected ? Border.all(color: Colors.white.withOpacity(0.85), width: 1.0) : null,
                                                      ),
                                                      width: textLayer.boxWidth,
                                                      height: textLayer.boxHeight,
                                                      alignment: Alignment.center,
                                                      constraints: BoxConstraints(
                                                        minWidth: 40.0,
                                                        minHeight: 30.0,
                                                        maxWidth: (canvasW * 0.95).clamp(40.0, canvasW),
                                                      ),
                                                      child: textLayer.boxHeight != null || textLayer.boxWidth != null
                                                          ? FittedBox(
                                                              fit: BoxFit.scaleDown,
                                                              alignment: Alignment.center,
                                                              child: textWidget,
                                                            )
                                                          : textWidget,
                                                    );
                                                  },
                                                ),
                                              ),

                                              // 2. Interactive Selection Handles (Original 4-Corner Resize + Edge Pills + Bottom Rotate)
                                              if (isSelected) ...[
                                                // --- 4 Corner Dots for Scaling & Resizing ---
                                                ...[
                                                  const Alignment(-1, -1), // Top-Left
                                                  const Alignment(1, -1),  // Top-Right
                                                  const Alignment(-1, 1),  // Bottom-Left
                                                  const Alignment(1, 1),   // Bottom-Right
                                                ].map((align) {
                                                  return Positioned(
                                                    left: align.x == -1 ? -12 : null,
                                                    right: align.x == 1 ? -12 : null,
                                                    top: align.y == -1 ? -12 : null,
                                                    bottom: align.y == 1 ? -12 : null,
                                                    child: GestureDetector(
                                                      behavior: HitTestBehavior.opaque,
                                                      onPanStart: (details) {
                                                        final canvasBox = context.findRenderObject() as RenderBox?;
                                                        final localTouch = canvasBox != null 
                                                            ? canvasBox.globalToLocal(details.globalPosition) 
                                                            : details.localPosition;
                                                        final textCenter = Offset(textLayer.position.dx * canvasW, textLayer.position.dy * canvasH);
                                                        _initialHandleDist = (localTouch - textCenter).distance;
                                                        if (_initialHandleDist < 10.0) _initialHandleDist = 10.0;
                                                        _initialFontSize = textLayer.fontSize;
                                                        _initialBoxWidth = textLayer.boxWidth;
                                                        _initialBoxHeight = textLayer.boxHeight;
                                                        notifier.pushHistory();
                                                      },
                                                      onPanUpdate: (details) {
                                                        final canvasBox = context.findRenderObject() as RenderBox?;
                                                        final localTouch = canvasBox != null 
                                                            ? canvasBox.globalToLocal(details.globalPosition) 
                                                            : details.localPosition;
                                                        final textCenter = Offset(textLayer.position.dx * canvasW, textLayer.position.dy * canvasH);
                                                        final currDist = (localTouch - textCenter).distance;
                                                        final scaleFactor = currDist / (_initialHandleDist > 0 ? _initialHandleDist : 1.0);

                                                        final newFontSize = (_initialFontSize * scaleFactor).clamp(10.0, 160.0);

                                                        double? newBoxWidth;
                                                        double? newBoxHeight;
                                                        if (_initialBoxWidth != null) {
                                                          newBoxWidth = (_initialBoxWidth! * scaleFactor).clamp(40.0, canvasW);
                                                        }
                                                        if (_initialBoxHeight != null) {
                                                          newBoxHeight = (_initialBoxHeight! * scaleFactor).clamp(30.0, canvasH);
                                                        }

                                                        notifier.updateTextLayer(
                                                          textLayer.copyWith(
                                                            fontSize: newFontSize,
                                                            boxWidth: newBoxWidth,
                                                            boxHeight: newBoxHeight,
                                                          ),
                                                          recordHistory: false,
                                                        );
                                                      },
                                                      child: Container(
                                                        width: 24,
                                                        height: 24,
                                                        alignment: Alignment.center,
                                                        child: Container(
                                                          width: 10,
                                                          height: 10,
                                                          decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            shape: BoxShape.circle,
                                                            border: Border.all(color: Colors.black54, width: 1),
                                                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
                                                          ),
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
                                                    left: align.x == -1 ? -12 : null,
                                                    right: align.x == 1 ? -12 : null,
                                                    top: 0,
                                                    bottom: 0,
                                                    child: Center(
                                                      child: GestureDetector(
                                                        behavior: HitTestBehavior.opaque,
                                                        onPanStart: (_) => notifier.pushHistory(),
                                                        onPanUpdate: (details) {
                                                          final currentWidth = textLayer.boxWidth ?? 120.0;
                                                          final delta = (align.x == 1 ? details.delta.dx : -details.delta.dx) * 2;
                                                          final newWidth = (currentWidth + delta).clamp(40.0, canvasW);
                                                          notifier.updateTextLayer(textLayer.copyWith(boxWidth: newWidth), recordHistory: false);
                                                        },
                                                        child: Container(
                                                          width: 24,
                                                          height: 32,
                                                          alignment: Alignment.center,
                                                          child: Container(
                                                            width: 8,
                                                            height: 20,
                                                            decoration: BoxDecoration(
                                                              color: Colors.white,
                                                              borderRadius: BorderRadius.circular(4),
                                                              border: Border.all(color: Colors.black45, width: 1),
                                                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }),

                                                // --- Top and Bottom Pill Handles for Height Adjust ---
                                                ...[
                                                  const Alignment(0, -1), // Top
                                                  const Alignment(0, 1),  // Bottom
                                                ].map((align) {
                                                  return Positioned(
                                                    top: align.y == -1 ? -12 : null,
                                                    bottom: align.y == 1 ? -12 : null,
                                                    left: 0,
                                                    right: 0,
                                                    child: Center(
                                                      child: GestureDetector(
                                                        behavior: HitTestBehavior.opaque,
                                                        onPanStart: (_) => notifier.pushHistory(),
                                                        onPanUpdate: (details) {
                                                          final currentHeight = textLayer.boxHeight ?? 50.0;
                                                          final delta = (align.y == 1 ? details.delta.dy : -details.delta.dy) * 2;
                                                          final newHeight = (currentHeight + delta).clamp(30.0, canvasH);
                                                          notifier.updateTextLayer(textLayer.copyWith(boxHeight: newHeight), recordHistory: false);
                                                        },
                                                        child: Container(
                                                          width: 32,
                                                          height: 24,
                                                          alignment: Alignment.center,
                                                          child: Container(
                                                            width: 20,
                                                            height: 8,
                                                            decoration: BoxDecoration(
                                                              color: Colors.white,
                                                              borderRadius: BorderRadius.circular(4),
                                                              border: Border.all(color: Colors.black45, width: 1),
                                                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }),

                                                // --- Live Degree Indicator Badge on Top ---
                                                Positioned(
                                                  top: -30,
                                                  left: 0,
                                                  right: 0,
                                                  child: Center(
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF14141E).withOpacity(0.92),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.8), width: 1),
                                                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
                                                      ),
                                                      child: Text(
                                                        '${(((textLayer.rotation * 180 / pi) % 360 + 360) % 360).round()}°',
                                                        style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                // --- Dedicated Bottom Rotate Handle ---
                                                Positioned(
                                                  bottom: -36,
                                                  left: 0,
                                                  right: 0,
                                                  child: Center(
                                                    child: GestureDetector(
                                                      behavior: HitTestBehavior.opaque,
                                                      onPanStart: (details) {
                                                        final canvasBox = context.findRenderObject() as RenderBox?;
                                                        final localTouch = canvasBox != null 
                                                            ? canvasBox.globalToLocal(details.globalPosition) 
                                                            : details.localPosition;
                                                        final textCenter = Offset(textLayer.position.dx * canvasW, textLayer.position.dy * canvasH);
                                                        _initialHandleAngle = atan2(localTouch.dy - textCenter.dy, localTouch.dx - textCenter.dx);
                                                        _initialRotation = textLayer.rotation;
                                                        notifier.pushHistory();
                                                      },
                                                      onPanUpdate: (details) {
                                                        final canvasBox = context.findRenderObject() as RenderBox?;
                                                        final localTouch = canvasBox != null 
                                                            ? canvasBox.globalToLocal(details.globalPosition) 
                                                            : details.localPosition;
                                                        final textCenter = Offset(textLayer.position.dx * canvasW, textLayer.position.dy * canvasH);
                                                        final currAngle = atan2(localTouch.dy - textCenter.dy, localTouch.dx - textCenter.dx);
                                                        final deltaAngle = currAngle - _initialHandleAngle;
                                                        final newRotation = _initialRotation + deltaAngle;
                                                        notifier.updateTextLayer(
                                                          textLayer.copyWith(rotation: newRotation),
                                                          recordHistory: false,
                                                        );
                                                      },
                                                      child: Container(
                                                        width: 36,
                                                        height: 36,
                                                        alignment: Alignment.center,
                                                        child: Container(
                                                          width: 22,
                                                          height: 22,
                                                          decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            shape: BoxShape.circle,
                                                            border: Border.all(color: Colors.black38, width: 1),
                                                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4, spreadRadius: 0.5)],
                                                          ),
                                                          child: const Icon(Icons.sync_rounded, size: 15, color: Colors.black87),
                                                        ),
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
                                  );
                                },
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
