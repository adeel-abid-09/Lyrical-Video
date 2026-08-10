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
  bool _isUserScrolling = false;
  
  double _timeScale = 44.0;
  double _baseScale = 44.0;

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _scrollToPlayhead(double playhead, double containerWidth) {
    if (!_horizontalScrollController.hasClients) return;
    if (_isUserScrolling) return;

    final targetScroll = playhead * _timeScale;
    final maxScroll = _horizontalScrollController.position.maxScrollExtent;
    _horizontalScrollController.jumpTo(targetScroll.clamp(0.0, maxScroll));
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorProjectProvider);
    final notifier = ref.read(editorProjectProvider.notifier);

    final duration = project.duration;
    final playhead = project.currentPlayheadTime;
    final totalSeconds = duration.ceil();

    if (project.isPlaying) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToPlayhead(playhead, MediaQuery.of(context).size.width);
      });
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
            // Playback Controls Header Row (Centered Play/Pause with -5s and +5s buttons)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              height: 36,
              color: const Color(0xFF1E1E2C),
              child: Row(
                children: [
                  // Undo / Redo Left
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

                  // Rewind 5s (-5s)
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.replay_5_rounded, color: Colors.white70),
                    onPressed: () {
                      notifier.seekPlayhead(playhead - 5.0);
                    },
                  ),
                  const SizedBox(width: 8),

                  // Center Play/Pause Button
                  IconButton(
                    iconSize: 26,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      project.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                      color: AppTheme.primaryAccent,
                    ),
                    onPressed: () {
                      notifier.togglePlayPause();
                    },
                  ),
                  const SizedBox(width: 8),

                  // Forward 5s (+5s)
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.forward_5_rounded, color: Colors.white70),
                    onPressed: () {
                      notifier.seekPlayhead(playhead + 5.0);
                    },
                  ),

                ],
              ),
            ),

            // Scrollable & Tappable Timeline Tracks
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final halfWidth = constraints.maxWidth / 2;
                  final trackWidth = (totalSeconds * _timeScale).clamp(0.0, double.infinity);

                  return GestureDetector(
                    onScaleStart: (details) {
                      _baseScale = _timeScale;
                    },
                    onScaleUpdate: (details) {
                      if (details.pointerCount >= 2) {
                        setState(() {
                          _timeScale = (_baseScale * details.scale).clamp(10.0, 200.0);
                        });
                      }
                    },
                    child: Stack(
                      children: [
                        NotificationListener<ScrollNotification>(
                        onNotification: (scrollNotification) {
                          if (scrollNotification is ScrollStartNotification) {
                            if (scrollNotification.dragDetails != null) {
                              _isUserScrolling = true;
                              ref.read(editorProjectProvider.notifier).setScrubbing(true);
                            }
                          } else if (scrollNotification is ScrollUpdateNotification) {
                            if (_isUserScrolling) {
                              final playheadTime = (_horizontalScrollController.offset / _timeScale).clamp(0.0, duration);
                              ref.read(editorProjectProvider.notifier).seekPlayhead(playheadTime);
                            }
                          } else if (scrollNotification is ScrollEndNotification) {
                            _isUserScrolling = false;
                            ref.read(editorProjectProvider.notifier).setScrubbing(false);
                          }
                          return false;
                        },
                        child: SingleChildScrollView(
                          controller: _horizontalScrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: halfWidth),
                            child: SizedBox(
                              width: trackWidth,
                              child: Stack(
                                children: [
                                  // Tappable Seconds Ruler
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
                                      child: Container(
                                        color: const Color(0xFF14141E),
                                        child: CustomPaint(
                                          size: Size(trackWidth, 22),
                                          painter: _RulerPainter(
                                            duration: duration,
                                            scale: _timeScale,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Vertical Scrollable Tracks Container
                                  Positioned.fill(
                                    top: 24,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.vertical,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Video / Image Media Tracks Row
                                          Container(
                                            margin: const EdgeInsets.symmetric(vertical: 2),
                                            height: 26,
                                            child: Stack(
                                              children: project.mediaLayers
                                                  .where((m) => m.type == MediaType.video || m.type == MediaType.sticker)
                                                  .map((media) {
                                                final left = media.startTime * _timeScale;
                                                final w = media.mediaDuration * _timeScale;
                                                final isSelected = project.selectedLayerId == media.id;
                                                return Positioned(
                                                  left: left,
                                                  width: w,
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
                                                          media.type == MediaType.video ? 'Video Track' : 'Photo Track',
                                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),

                                          // Audio Tracks Row
                                          Container(
                                            margin: const EdgeInsets.symmetric(vertical: 2),
                                            height: 22,
                                            child: Stack(
                                              children: project.mediaLayers
                                                  .where((m) => m.type == MediaType.audio)
                                                  .map((audio) {
                                                final left = audio.startTime * _timeScale;
                                                final w = audio.mediaDuration * _timeScale;
                                                final isSelected = project.selectedLayerId == audio.id;
                                                return Positioned(
                                                  left: left,
                                                  width: w,
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
                                                        child: Text(
                                                          'Audio Track',
                                                          style: TextStyle(color: Colors.white, fontSize: 10),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),

                                          // Text & Auto Lyrics Tracks Row
                                          Container(
                                            margin: const EdgeInsets.symmetric(vertical: 2),
                                            height: 22,
                                            child: Stack(
                                              children: project.textLayers.map((text) {
                                                final left = text.startTime * _timeScale;
                                                final w = (text.endTime - text.startTime) * _timeScale;
                                                final isSelected = project.selectedLayerId == text.id;
                                                return Positioned(
                                                  left: left,
                                                  width: w.clamp(24.0, double.infinity),
                                                  top: 0,
                                                  bottom: 0,
                                                  child: GestureDetector(
                                                    onTap: () => notifier.selectLayer(text.id),
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: isSelected
                                                            ? AppTheme.primaryAccent
                                                            : (text.isAutoLyric ? Colors.purple.shade700 : Colors.amber.shade800),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                                        child: Center(
                                                          child: Text(
                                                            text.text,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(color: Colors.white, fontSize: 10),
                                                          ),
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
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Fixed Center Playhead Line (Draggable)
                      Positioned(
                        left: halfWidth - 10, // give a bit of padding for easier grabbing
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragUpdate: (details) {
                            // Moving playhead right means scrolling timeline left
                            final maxScroll = _horizontalScrollController.position.maxScrollExtent;
                            final newOffset = (_horizontalScrollController.offset + details.delta.dx).clamp(0.0, maxScroll);
                            _horizontalScrollController.jumpTo(newOffset);
                          },
                          child: Container(
                            width: 20,
                            alignment: Alignment.center,
                            child: Container(
                              width: 3,
                              color: Colors.redAccent,
                              child: Column(
                                children: [
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Floating Time Duration over Playhead
                      Positioned(
                        left: halfWidth - 40,
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
