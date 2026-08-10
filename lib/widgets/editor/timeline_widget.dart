import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/media_layer_model.dart';
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
    final totalSeconds = (duration.ceil() + 5).toDouble();
    final playhead = project.currentPlayheadTime;

    if (!_isUserScrolling && _horizontalScrollController.hasClients) {
      final targetOffset = playhead * _timeScale;
      if ((_horizontalScrollController.offset - targetOffset).abs() > 1.0) {
        _horizontalScrollController.jumpTo(targetOffset);
      }
    }

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
            // Playback Controls Header Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              height: 36,
              color: const Color(0xFF1E1E2C),
              child: Row(
                children: [
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.undo_rounded, color: Colors.white70),
                    onPressed: notifier.canUndo ? () => notifier.undo() : null,
                  ),
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.redo_rounded, color: Colors.white70),
                    onPressed: notifier.canRedo ? () => notifier.redo() : null,
                  ),
                  const Spacer(),
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.replay_5_rounded, color: Colors.white70),
                    onPressed: () => notifier.seekPlayhead(playhead - 5.0),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    iconSize: 26,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      project.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                      color: AppTheme.primaryAccent,
                    ),
                    onPressed: () => notifier.togglePlayPause(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.forward_5_rounded, color: Colors.white70),
                    onPressed: () => notifier.seekPlayhead(playhead + 5.0),
                  ),
                ],
              ),
            ),

            // Scrollable Timeline Area
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const playheadOffset = 50.0;
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
                                ref.read(editorProjectProvider.notifier).setScrubbing(true);
                              } else if (scrollNotification is ScrollUpdateNotification && _isUserScrolling) {
                                final playheadTime = (_horizontalScrollController.offset / _timeScale).clamp(0.0, duration);
                                ref.read(editorProjectProvider.notifier).seekPlayhead(playheadTime);
                              } else if (scrollNotification is ScrollEndNotification) {
                                _isUserScrolling = false;
                                ref.read(editorProjectProvider.notifier).setScrubbing(false);
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
                                                      return Positioned(
                                                        left: media.startTime * _timeScale,
                                                        width: media.mediaDuration * _timeScale,
                                                        top: 0,
                                                        bottom: 0,
                                                        child: GestureDetector(
                                                          onTap: () => notifier.selectLayer(media.id),
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              color: isSelected ? AppTheme.primaryAccent : Colors.indigo.withOpacity(0.85),
                                                              borderRadius: BorderRadius.circular(6),
                                                              border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
                                                            ),
                                                            child: Center(
                                                              child: Text(
                                                                media.type == MediaType.video ? 'Video' : 'Photo',
                                                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                                                        child: GestureDetector(
                                                          onTap: () => notifier.selectLayer(audio.id),
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              color: isSelected ? AppTheme.primaryAccent : Colors.teal.shade700,
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            child: const Center(
                                                              child: Text('Audio Track', style: TextStyle(color: Colors.white, fontSize: 10)),
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
                                                Container(
                                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                                  height: 22,
                                                  child: Stack(
                                                    children: project.textLayers.map((text) {
                                                      final isSelected = project.selectedLayerId == text.id;
                                                      return Positioned(
                                                        left: text.startTime * _timeScale,
                                                        width: ((text.endTime - text.startTime) * _timeScale).clamp(24.0, double.infinity),
                                                        top: 0,
                                                        bottom: 0,
                                                        child: GestureDetector(
                                                          onTap: () => notifier.selectLayer(text.id),
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              color: isSelected ? AppTheme.primaryAccent : (text.isAutoLyric ? Colors.purple.shade700 : Colors.amber.shade800),
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            child: Padding(
                                                              padding: const EdgeInsets.symmetric(horizontal: 4),
                                                              child: Center(
                                                                child: Text(text.text, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10)),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
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
                                    Container(
                                      height: 26,
                                      margin: const EdgeInsets.symmetric(vertical: 2),
                                      child: const Icon(Icons.movie_rounded, color: Colors.white54, size: 14),
                                    ),
                                  ...audioLayers.map((audio) {
                                    return Container(
                                      height: 22,
                                      margin: const EdgeInsets.symmetric(vertical: 2),
                                      child: GestureDetector(
                                        onTap: () {
                                          notifier.updateMediaLayerProperties(audio.id, isMuted: !audio.isMuted);
                                        },
                                        child: Icon(
                                          audio.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                          color: audio.isMuted ? Colors.redAccent : AppTheme.primaryAccent,
                                          size: 16,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  if (project.textLayers.isNotEmpty)
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

                        // Floating Time Duration over Playhead
                        Positioned(
                          left: playheadOffset - 40,
                          top: 2,
                          child: IgnorePointer(
                            child: Container(
                              width: 80,
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryAccent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_formatTime(playhead)} / ${_formatTime(duration)}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
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
