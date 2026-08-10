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

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _scrollToPlayhead(double playhead, double containerWidth) {
    if (!_horizontalScrollController.hasClients) return;
    if (_isUserScrolling) return; // Do not auto-scroll if user is panning

    final targetX = playhead * 44.0;
    final currentScroll = _horizontalScrollController.offset;
    final maxScroll = _horizontalScrollController.position.maxScrollExtent;

    if (targetX > currentScroll + containerWidth - 60 || targetX < currentScroll) {
      final desiredScroll = (targetX - containerWidth / 2).clamp(0.0, maxScroll);
      _horizontalScrollController.animateTo(
        desiredScroll,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
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

                  const Spacer(),

                  // Time Counter Right
                  Text(
                    '${_formatTime(playhead)} / ${_formatTime(duration)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),

            // Scrollable & Tappable Timeline Tracks
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final trackWidth = (totalSeconds * 44.0 + 60.0).clamp(constraints.maxWidth, double.infinity);

                  return NotificationListener<ScrollNotification>(
                    onNotification: (scrollNotification) {
                      if (scrollNotification is ScrollStartNotification) {
                        if (scrollNotification.dragDetails != null) {
                          _isUserScrolling = true;
                        }
                      } else if (scrollNotification is ScrollEndNotification) {
                        _isUserScrolling = false;
                      }
                      return false;
                    },
                    child: SingleChildScrollView(
                      controller: _horizontalScrollController,
                      scrollDirection: Axis.horizontal,
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
                                onPanStart: (details) {
                                  ref.read(editorProjectProvider.notifier).setScrubbing(true);
                                },
                                onPanUpdate: (details) {
                                  final project = ref.read(editorProjectProvider);
                                  if (!project.isScrubbing) {
                                    ref.read(editorProjectProvider.notifier).setScrubbing(true);
                                  }
                                  final newScroll = (_horizontalScrollController.offset - details.delta.dx).clamp(
                                    0.0,
                                    _horizontalScrollController.position.maxScrollExtent,
                                  );
                                  _horizontalScrollController.jumpTo(newScroll);
                                  
                                  final playheadX = newScroll + (MediaQuery.of(context).size.width * 0.5);
                                  final playheadTime = (playheadX / 44.0).clamp(0.0, duration);
                                  ref.read(editorProjectProvider.notifier).seekPlayhead(playheadTime);
                                },
                                onPanEnd: (details) {
                                  ref.read(editorProjectProvider.notifier).setScrubbing(false);
                                },
                                onPanCancel: () {
                                  ref.read(editorProjectProvider.notifier).setScrubbing(false);
                                },
                                onTapDown: (details) {
                                  // localPosition is relative to the track which has `trackWidth`
                                  final playheadTime = (details.localPosition.dx / 44.0).clamp(0.0, duration);
                                  notifier.seekPlayhead(playheadTime);
                                },
                                child: Container(
                                  color: const Color(0xFF14141E),
                                  child: Row(
                                    children: List.generate(totalSeconds + 1, (index) {
                                      return SizedBox(
                                        width: 44,
                                        child: Column(
                                          children: [
                                            Text(
                                              '${index.toString().padLeft(2, '0')}s',
                                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                                            ),
                                            Container(
                                              height: 4,
                                              width: 1,
                                              color: Colors.white24,
                                            ),
                                        ],
                                      ),
                                    );
                                  }),
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
                                        final left = media.startTime * 44;
                                        final w = media.mediaDuration * 44;
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
                                        final left = audio.startTime * 44;
                                        final w = audio.mediaDuration * 44;
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
                                        final left = text.startTime * 44;
                                        final w = (text.endTime - text.startTime) * 44;
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

                          // Red Scrub Playhead Line
                          Positioned(
                            left: playhead * 44,
                            top: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onHorizontalDragUpdate: (details) {
                                final newTime = (playhead + details.delta.dx / 44);
                                notifier.seekPlayhead(newTime);
                              },
                              child: Container(
                                width: 3,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
