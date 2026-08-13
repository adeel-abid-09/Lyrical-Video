import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/media_layer_model.dart';
import '../../models/editor_project_model.dart';
import '../../models/text_layer_model.dart';
import '../../state/editor_state_notifier.dart';
import '../../theme/app_theme.dart';

class CapCutTimelineWidget extends ConsumerStatefulWidget {
  const CapCutTimelineWidget({super.key});

  @override
  ConsumerState<CapCutTimelineWidget> createState() => _CapCutTimelineWidgetState();
}

class _CapCutTimelineWidgetState extends ConsumerState<CapCutTimelineWidget> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalTracksController = ScrollController();
  final ScrollController _verticalHeadersController = ScrollController();
  bool _isUserScrolling = false;
  
  double _timeScale = 44.0;
  double _baseScale = 44.0;

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalTracksController.dispose();
    _verticalHeadersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorProjectProvider);
    final notifier = ref.read(editorProjectProvider.notifier);

    final duration = project.duration;
    final totalSeconds = duration; // Removed the arbitrary +5 seconds overscroll!
    final playhead = project.currentPlayheadTime;

    ref.listen<double>(editorProjectProvider.select((p) => p.currentPlayheadTime), (prev, next) {
      if (project.isPlaying && !_isUserScrolling && _horizontalScrollController.hasClients) {
        final targetOffset = next * _timeScale;
        _horizontalScrollController.jumpTo(targetOffset);
      }
    });

    return Container(
      height: 160,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF181824),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Playback Controls & Time Display Header Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              height: 36,
              color: const Color(0xFF1E1E2C),
              child: Row(
                children: [
                  // 1. Left: Time Display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    constraints: const BoxConstraints(minWidth: 84),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_formatTime(playhead)} / ${_formatTime(duration)}',
                        style: const TextStyle(
                          color: Colors.white70, // Slightly dimmed to match screenshot
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // 2. Center: Play/Pause controls
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32),
                        icon: const Icon(Icons.replay_5_rounded, color: Colors.white70),
                        onPressed: () => notifier.seekPlayhead(playhead - 5.0),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        iconSize: 28,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36),
                        icon: Icon(
                          project.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => notifier.togglePlayPause(),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32),
                        icon: const Icon(Icons.forward_5_rounded, color: Colors.white70),
                        onPressed: () => notifier.seekPlayhead(playhead + 5.0),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // 3. Right: Spacer to keep play button centered
                  const SizedBox(width: 84),
                ],
              ),
            ),

            // Scrollable Timeline Area
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const playheadOffset = 100.0;
                  final trackWidth = (totalSeconds * _timeScale).clamp(0.0, double.infinity);

                  final videoLayers = project.mediaLayers.where((m) => m.type == MediaType.video || m.type == MediaType.sticker).toList();
                  final audioLayers = project.mediaLayers.where((m) => m.type == MediaType.audio).toList();

                  return GestureDetector(
                    onScaleStart: (details) => _baseScale = _timeScale,
                    onScaleUpdate: (details) {
                      if (details.pointerCount >= 2) {
                        setState(() => _timeScale = (_baseScale * details.scale).clamp(10.0, 200.0));
                      }
                    },
                    child: Stack(
                      children: [
                        // HORIZONTAL SCROLL FOR TRACKS
                        NotificationListener<ScrollNotification>(
                          onNotification: (scrollNotification) {
                            if (scrollNotification.metrics.axis == Axis.horizontal) {
                              if (scrollNotification is ScrollStartNotification && scrollNotification.dragDetails != null) {
                                _isUserScrolling = true;
                              } else if (scrollNotification is ScrollEndNotification) {
                                _isUserScrolling = false;
                              }

                              if (scrollNotification is ScrollUpdateNotification) {
                                if (!project.isPlaying || scrollNotification.dragDetails != null) {
                                  final playheadTime = (_horizontalScrollController.offset / _timeScale).clamp(0.0, duration);
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    notifier.seekPlayhead(playheadTime);
                                  });
                                }
                              }
                            }
                            return false;
                          },
                          child: SingleChildScrollView(
                            controller: _horizontalScrollController,
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Padding(
                              padding: EdgeInsets.only(left: playheadOffset, right: constraints.maxWidth - playheadOffset),
                              child: SizedBox(
                                width: trackWidth,
                                child: Stack(
                                  children: [
                                    // Ruler
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      height: 22,
                                      child: GestureDetector(
                                        onTapDown: (details) {
                                          final playheadTime = (details.localPosition.dx / _timeScale).clamp(0.0, duration);
                                          notifier.seekPlayhead(playheadTime);
                                        },
                                        child: CustomPaint(
                                          size: Size(trackWidth, 22),
                                          painter: _RulerPainter(duration: duration, scale: _timeScale),
                                        ),
                                      ),
                                    ),

                                    // Vertical Tracks
                                    Positioned.fill(
                                      top: 24,
                                      child: NotificationListener<ScrollNotification>(
                                        onNotification: (scrollNotif) {
                                          if (scrollNotif.metrics.axis == Axis.vertical && _verticalHeadersController.hasClients) {
                                            _verticalHeadersController.jumpTo(_verticalTracksController.offset);
                                          }
                                          return false;
                                        },
                                        child: SingleChildScrollView(
                                          controller: _verticalTracksController,
                                          scrollDirection: Axis.vertical,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Video Tracks
                                              if (videoLayers.isNotEmpty)
                                                Container(
                                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                                  height: 26,
                                                  child: Stack(
                                                    children: videoLayers.map((media) {
                                                      final isSelected = project.selectedLayerId == media.id;
                                                      final double opacity = (project.isTrimMode && !isSelected) ? 0.3 : 1.0;
                                                      return Positioned(
                                                        left: media.startTime * _timeScale,
                                                        width: (media.mediaDuration > 0 ? media.mediaDuration : duration) * _timeScale,
                                                        top: 0,
                                                        bottom: 0,
                                                        child: Opacity(
                                                          opacity: opacity,
                                                          child: GestureDetector(
                                                            onTap: () => notifier.selectLayer(media.id),
                                                            child: Container(
                                                              decoration: BoxDecoration(
                                                                color: isSelected ? const Color(0xFFFF512F) : const Color(0xFFEAB308),
                                                                borderRadius: BorderRadius.circular(6),
                                                                border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
                                                              ),
                                                              child: Stack(
                                                                children: [
                                                                  GestureDetector(
                                                                    behavior: HitTestBehavior.opaque,
                                                                    child: Container(
                                                                      alignment: Alignment.center,
                                                                      color: Colors.transparent,
                                                                      child: Text(
                                                                        media.type == MediaType.video ? 'Video' : 'Photo',
                                                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  if (isSelected)
                                                                    Positioned(
                                                                      left: 0, top: 0, bottom: 0,
                                                                      child: GestureDetector(
                                                                        behavior: HitTestBehavior.opaque,
                                                                        onHorizontalDragUpdate: (details) {
                                                                          final delta = details.delta.dx / _timeScale;
                                                                          notifier.trimMediaLayerStart(media.id, delta);
                                                                        },
                                                                        child: Container(
                                                                          width: 15,
                                                                          decoration: const BoxDecoration(
                                                                            color: Colors.white,
                                                                            borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
                                                                          ),
                                                                          child: const Center(child: Icon(Icons.drag_indicator_rounded, size: 10, color: Colors.black45)),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  if (isSelected)
                                                                    Positioned(
                                                                      right: 0, top: 0, bottom: 0,
                                                                      child: GestureDetector(
                                                                        behavior: HitTestBehavior.opaque,
                                                                        onHorizontalDragUpdate: (details) {
                                                                          final delta = details.delta.dx / _timeScale;
                                                                          notifier.trimMediaLayerEnd(media.id, delta);
                                                                        },
                                                                        child: Container(
                                                                          width: 15,
                                                                          decoration: const BoxDecoration(
                                                                            color: Colors.white,
                                                                            borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                                                                          ),
                                                                          child: const Center(child: Icon(Icons.drag_indicator_rounded, size: 10, color: Colors.black45)),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),

                                              // Audio Tracks (One row per layer)
                                              ...audioLayers.map((audio) {
                                                final isSelected = project.selectedLayerId == audio.id;
                                                final double opacity = (project.isTrimMode && !isSelected) ? 0.3 : 1.0;
                                                return Container(
                                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                                  height: 22,
                                                  child: Stack(
                                                    children: [
                                                      Positioned(
                                                        left: audio.startTime * _timeScale,
                                                        width: audio.mediaDuration * _timeScale,
                                                        top: 0,
                                                        bottom: 0,
                                                        child: Opacity(
                                                          opacity: opacity,
                                                          child: GestureDetector(
                                                            onTap: () => notifier.selectLayer(audio.id),
                                                            child: Container(
                                                              decoration: BoxDecoration(
                                                                color: isSelected ? AppTheme.primaryAccent : Colors.teal.shade700,
                                                                borderRadius: BorderRadius.circular(6),
                                                                border: (isSelected && project.isTrimMode) ? Border.all(color: Colors.white, width: 1.5) : null,
                                                              ),
                                                              child: Stack(
                                                                children: [
                                                                  GestureDetector(
                                                                    behavior: HitTestBehavior.opaque,
                                                                    child: Container(
                                                                      alignment: Alignment.center,
                                                                      color: Colors.transparent,
                                                                      child: const Text('Audio Track', style: TextStyle(color: Colors.white, fontSize: 10)),
                                                                    ),
                                                                  ),
                                                                  if (isSelected && project.isTrimMode)
                                                                    Positioned(
                                                                      left: 0, top: 0, bottom: 0,
                                                                      child: GestureDetector(
                                                                        behavior: HitTestBehavior.opaque,
                                                                        onHorizontalDragUpdate: (details) {
                                                                          final delta = details.delta.dx / _timeScale;
                                                                          notifier.trimMediaLayerStart(audio.id, delta);
                                                                        },
                                                                        child: Container(
                                                                          width: 15,
                                                                          decoration: const BoxDecoration(
                                                                            color: Colors.white,
                                                                            borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
                                                                          ),
                                                                          child: const Center(child: Icon(Icons.drag_indicator_rounded, size: 10, color: Colors.black45)),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  if (isSelected && project.isTrimMode)
                                                                    Positioned(
                                                                      right: 0, top: 0, bottom: 0,
                                                                      child: GestureDetector(
                                                                        behavior: HitTestBehavior.opaque,
                                                                        onHorizontalDragUpdate: (details) {
                                                                          final delta = details.delta.dx / _timeScale;
                                                                          notifier.trimMediaLayerEnd(audio.id, delta);
                                                                        },
                                                                        child: Container(
                                                                          width: 15,
                                                                          decoration: const BoxDecoration(
                                                                            color: Colors.white,
                                                                            borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                                                                          ),
                                                                          child: const Center(child: Icon(Icons.drag_indicator_rounded, size: 10, color: Colors.black45)),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),

                                              // Text Tracks
                                              if (project.textLayers.isNotEmpty)
                                                ..._buildTextTracks(project, notifier),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // LEFT FIXED HEADERS
                        Positioned(
                          left: 0,
                          top: 24,
                          bottom: 0,
                          width: playheadOffset,
                          child: Container(
                            color: const Color(0xFF181824).withOpacity(0.9), // slight transparency
                            child: SingleChildScrollView(
                              controller: _verticalHeadersController,
                              scrollDirection: Axis.vertical,
                              physics: const NeverScrollableScrollPhysics(), // Synced with tracks
                              child: Column(
                                children: [
                                  if (videoLayers.isNotEmpty)
                                    GestureDetector(
                                      onTap: () {
                                        notifier.updateMediaLayerProperties(videoLayers.first.id, isMuted: !videoLayers.first.isMuted);
                                      },
                                      child: Container(
                                        height: 26,
                                        margin: const EdgeInsets.symmetric(vertical: 2),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              videoLayers.first.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                              color: videoLayers.first.isMuted ? Colors.redAccent : Colors.white54,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              videoLayers.first.isMuted ? 'Muted' : 'Mute clip\naudio',
                                              style: const TextStyle(color: Colors.white54, fontSize: 8, height: 1.1),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ...audioLayers.map((audio) {
                                    return Container(
                                      height: 22,
                                      margin: const EdgeInsets.symmetric(vertical: 2),
                                      child: GestureDetector(
                                        onTap: () {
                                          notifier.updateMediaLayerProperties(audio.id, isMuted: !audio.isMuted);
                                        },
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              audio.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                              color: audio.isMuted ? Colors.redAccent : AppTheme.primaryAccent,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(audio.isMuted ? 'Muted' : 'Audio', style: const TextStyle(color: Colors.white54, fontSize: 9)),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  if (project.textLayers.isNotEmpty)
                                    // With the new layout logic we will have multiple text tracks, 
                                    // but we just render a simple placeholder for the texts section or nothing.
                                    // Actually, we don't need a row header for every text track.
                                    Container(
                                      height: 22,
                                      margin: const EdgeInsets.symmetric(vertical: 2),
                                      child: const Icon(Icons.text_fields_rounded, color: Colors.white54, size: 14),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // PLAYHEAD LINE (Fixed, no drag needed because user can drag the ruler instead)
                        Positioned(
                          left: playheadOffset - 1, // center the 2px width
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 2,
                            color: AppTheme.primaryAccent,
                          ),
                        ),
                        // PLAYHEAD CAP
                        Positioned(
                          left: playheadOffset - 10,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 20,
                            alignment: Alignment.center,
                            child: Container(
                              width: 3,
                              color: AppTheme.primaryAccent,
                              child: Column(
                                children: [
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primaryAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTextTracks(EditorProjectModel project, EditorProjectNotifier notifier) {
    // Sort texts by start time to ensure consistent row assignment
    final sortedTexts = List<TextLayerModel>.from(project.textLayers)..sort((a, b) => a.startTime.compareTo(b.startTime));
                                                  
    // Group text layers into non-overlapping rows
    final List<List<TextLayerModel>> textRows = [];
    for (final textLayer in sortedTexts) {
      bool placed = false;
      for (int i = 0; i < textRows.length; i++) {
        bool overlaps = false;
        for (final placedLayer in textRows[i]) {
          if (textLayer.startTime < placedLayer.endTime && textLayer.endTime > placedLayer.startTime) {
            overlaps = true;
            break;
          }
        }
        if (!overlaps) {
          textRows[i].add(textLayer);
          placed = true;
          break;
        }
      }
      if (!placed) {
        textRows.add([textLayer]);
      }
    }

    return textRows.map<Widget>((List<TextLayerModel> row) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        height: 22,
        child: Stack(
          children: row.map<Widget>((TextLayerModel text) {
            final isSelected = project.selectedLayerId == text.id;
            final width = ((text.endTime - text.startTime) * _timeScale).clamp(24.0, double.infinity);
                                                          
            // Calculate drag constraints based on adjacent items in the same row
            final index = row.indexOf(text);
            final minStart = index > 0 ? row[index - 1].endTime : 0.0;
            final maxEnd = index < row.length - 1 ? row[index + 1].startTime : project.duration;

            return Positioned(
              left: text.startTime * _timeScale,
              width: width,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () => notifier.selectLayer(text.id),
                child: Opacity(
                  opacity: (!isSelected && project.isTrimMode) ? 0.3 : 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFF512F) : const Color(0xFFEAB308),
                      borderRadius: BorderRadius.circular(6),
                      border: isSelected ? Border.all(color: Colors.white, width: 1.8) : null,
                    ),
                    child: Stack(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onLongPressStart: (_) {
                            notifier.pushHistory();
                          },
                          onLongPressMoveUpdate: (details) {
                            final delta = details.localOffsetFromOrigin.dx / _timeScale;
                            
                            double newStart = text.startTime + delta;
                            double newEnd = text.endTime + delta;
                            
                            if (newStart < minStart) {
                              newStart = minStart;
                            } else if (newEnd > maxEnd) {
                              newStart = maxEnd - (text.endTime - text.startTime);
                            }
                            
                            final effectiveDelta = newStart - text.startTime;
                            if (effectiveDelta != 0) {
                              notifier.moveTextLayer(text.id, effectiveDelta);
                            }
                          },
                          child: Container(
                            alignment: Alignment.center,
                            color: Colors.transparent,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(text.text, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10)),
                            ),
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            left: 0, top: 0, bottom: 0,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragUpdate: (details) {
                                final delta = details.delta.dx / _timeScale;
                                final newStart = (text.startTime + delta).clamp(minStart, text.endTime - 0.5);
                                notifier.trimTextLayerStart(text.id, newStart);
                              },
                              child: Container(
                                width: 15,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
                                ),
                                child: const Center(child: Icon(Icons.drag_indicator_rounded, size: 10, color: Colors.black45)),
                              ),
                            ),
                          ),
                        if (isSelected)
                          Positioned(
                            right: 0, top: 0, bottom: 0,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragUpdate: (details) {
                                final delta = details.delta.dx / _timeScale;
                                final newEnd = (text.endTime + delta).clamp(text.startTime + 0.5, maxEnd);
                                notifier.trimTextLayerEnd(text.id, newEnd);
                              },
                              child: Container(
                                width: 15,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                                ),
                                child: const Center(child: Icon(Icons.drag_indicator_rounded, size: 10, color: Colors.black45)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }).toList();
  }

  String _formatTime(double seconds) {
    final mins = (seconds / 60).floor().toString().padLeft(2, '0');
    final secs = (seconds % 60).floor().toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

class _RulerPainter extends CustomPainter {
  final double duration;
  final double scale;

  _RulerPainter({required this.duration, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final linePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0;

    final step = scale > 80.0 ? 0.5 : (scale > 150.0 ? 0.1 : 1.0);
    final totalSteps = (duration / step).ceil();

    for (int i = 0; i <= totalSteps; i++) {
      final time = i * step;
      final x = time * scale;
      if (x > size.width) break;

      // Draw text for integer seconds (or half seconds if zoomed in)
      if (time % 1 == 0 || scale > 80.0) {
        textPainter.text = TextSpan(
          text: time % 1 == 0 ? '${time.toInt().toString().padLeft(2, '0')}s' : '${time.toStringAsFixed(1)}s',
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, 0));
        canvas.drawLine(Offset(x, 14), Offset(x, 18), linePaint);
      } else {
        // Draw smaller ticks
        canvas.drawLine(Offset(x, 16), Offset(x, 18), linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RulerPainter oldDelegate) {
    return oldDelegate.duration != duration || oldDelegate.scale != scale;
  }
}
