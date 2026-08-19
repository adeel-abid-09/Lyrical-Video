import 'dart:async';
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

  String? _draggingTextId;
  double _dragTextInitialStart = 0.0;
  double _dragTextInitialEnd = 0.0;
  int _dragTextInitialTrack = 0;

  String? _draggingMediaId;
  double _dragMediaInitialStart = 0.0;

  Timer? _trimAutoScrollTimer;
  final GlobalKey _timelineViewportKey = GlobalKey();

  void _handleTrimDrag({
    required DragUpdateDetails details,
    required void Function(double deltaSeconds) onTrimDelta,
  }) {
    // 1. Instantaneous delta on current frame
    final delta = details.delta.dx / _timeScale;
    onTrimDelta(delta);

    // 2. Continuous auto-scroll when reaching viewport edges
    final box = _timelineViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !_horizontalScrollController.hasClients) return;

    final localX = box.globalToLocal(details.globalPosition).dx;
    final viewWidth = box.size.width;

    const edgeThreshold = 48.0;
    if (localX < edgeThreshold) {
      // Near Left Edge: auto-scroll left (backwards in time)
      final speedFactor = ((edgeThreshold - localX) / edgeThreshold).clamp(0.2, 1.8);
      _startTrimAutoScroll(direction: -1.0, speedFactor: speedFactor, onTrimDelta: onTrimDelta);
    } else if (localX > viewWidth - edgeThreshold) {
      // Near Right Edge: auto-scroll right (forward in time)
      final speedFactor = ((localX - (viewWidth - edgeThreshold)) / edgeThreshold).clamp(0.2, 1.8);
      _startTrimAutoScroll(direction: 1.0, speedFactor: speedFactor, onTrimDelta: onTrimDelta);
    } else {
      _stopTrimAutoScroll();
    }
  }

  void _startTrimAutoScroll({
    required double direction,
    required double speedFactor,
    required void Function(double deltaSeconds) onTrimDelta,
  }) {
    _trimAutoScrollTimer?.cancel();
    _trimAutoScrollTimer = Timer.periodic(const Duration(milliseconds: 32), (timer) {
      if (!_horizontalScrollController.hasClients) return;
      
      final double scrollStep = direction * (5.0 * speedFactor);
      final double newOffset = (_horizontalScrollController.offset + scrollStep).clamp(
        0.0,
        _horizontalScrollController.position.maxScrollExtent,
      );
      
      if ((newOffset - _horizontalScrollController.offset).abs() > 0.1) {
        _horizontalScrollController.jumpTo(newOffset);
        final deltaSeconds = scrollStep / _timeScale;
        onTrimDelta(deltaSeconds);
      }
    });
  }

  void _stopTrimAutoScroll() {
    _trimAutoScrollTimer?.cancel();
    _trimAutoScrollTimer = null;
  }

  @override
  void dispose() {
    _trimAutoScrollTimer?.cancel();
    _horizontalScrollController.dispose();
    _verticalTracksController.dispose();
    _verticalHeadersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorProjectProvider);
    final notifier = ref.read(editorProjectProvider.notifier);

    final duration = project.duration.isFinite && !project.duration.isNaN && project.duration > 0 ? project.duration : 15.0;
    final totalSeconds = duration; // Removed the arbitrary +5 seconds overscroll!
    final playhead = project.currentPlayheadTime.isFinite && !project.currentPlayheadTime.isNaN ? project.currentPlayheadTime : 0.0;

    ref.listen<double>(editorProjectProvider.select((p) => p.currentPlayheadTime), (prev, next) {
      if (!_isUserScrolling && _horizontalScrollController.hasClients) {
        final targetOffset = next * _timeScale;
        if ((_horizontalScrollController.offset - targetOffset).abs() > 0.5) {
          _horizontalScrollController.jumpTo(targetOffset.clamp(0.0, _horizontalScrollController.position.maxScrollExtent));
        }
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
                  Expanded(
                    child: Text(
                      '${_formatTime(playhead)} / ${_formatTime(duration)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),

                  // 2. Center: Play/Pause controls
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28),
                        icon: const Icon(Icons.replay_5_rounded, color: Colors.white70),
                        onPressed: () => notifier.seekPlayhead(playhead - 5.0),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        iconSize: 28,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32),
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
                        constraints: const BoxConstraints(minWidth: 28),
                        icon: const Icon(Icons.forward_5_rounded, color: Colors.white70),
                        onPressed: () => notifier.seekPlayhead(playhead + 5.0),
                      ),
                    ],
                  ),

                  // 3. Right: Balanced spacer
                  const Expanded(
                    child: SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            // Scrollable Timeline Area
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const playheadOffset = 100.0;
                  final trackWidth = (totalSeconds * _timeScale).clamp(0.0, double.infinity);

                  final overlayLayers = project.mediaLayers.where((m) => m.isOverlay).toList();
                  final mainMediaLayers = project.mediaLayers.where((m) => !m.isOverlay && (m.type == MediaType.video || m.type == MediaType.sticker)).toList();
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
                                notifier.setScrubbing(true);
                              } else if (scrollNotification is ScrollUpdateNotification && scrollNotification.dragDetails != null) {
                                _isUserScrolling = true;
                                final playheadTime = (_horizontalScrollController.offset / _timeScale).clamp(0.0, duration);
                                notifier.seekPlayhead(playheadTime);
                              } else if (scrollNotification is ScrollEndNotification) {
                                if (_horizontalScrollController.hasClients) {
                                  final playheadTime = (_horizontalScrollController.offset / _timeScale).clamp(0.0, duration);
                                  notifier.seekPlayhead(playheadTime);
                                }
                                notifier.setScrubbing(false);
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    _isUserScrolling = false;
                                  }
                                });
                              }
                            }
                            return false;
                          },
                          child: SingleChildScrollView(
                            key: _timelineViewportKey,
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
                                          if (scrollNotif.metrics.axis == Axis.vertical && _verticalHeadersController.hasClients && _verticalTracksController.hasClients) {
                                            final offset = _verticalTracksController.offset;
                                            WidgetsBinding.instance.addPostFrameCallback((_) {
                                              if (_verticalHeadersController.hasClients) {
                                                _verticalHeadersController.jumpTo(offset.clamp(0.0, _verticalHeadersController.position.maxScrollExtent));
                                              }
                                            });
                                          }
                                          return false;
                                        },
                                        child: SingleChildScrollView(
                                          controller: _verticalTracksController,
                                          scrollDirection: Axis.vertical,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // 1. Overlay Tracks (Dynamically shown only when overlays exist)
                                              if (overlayLayers.isNotEmpty)
                                                Container(
                                                   margin: const EdgeInsets.symmetric(vertical: 2),
                                                   height: 26,
                                                   child: Stack(
                                                     children: overlayLayers.map((media) {
                                                       final isSelected = project.selectedLayerId == media.id;
                                                       final isDragging = _draggingMediaId == media.id;
                                                       final double opacity = (project.isTrimMode && !isSelected) ? 0.3 : (isDragging ? 0.85 : 1.0);
                                                       final double mediaStart = media.startTime.isFinite && !media.startTime.isNaN ? media.startTime : 0.0;
                                                       final double mediaDurRaw = media.mediaDuration.isFinite && !media.mediaDuration.isNaN && media.mediaDuration > 0 ? media.mediaDuration : duration;
                                                       return Positioned(
                                                         left: mediaStart * _timeScale,
                                                         width: mediaDurRaw * _timeScale,
                                                         top: 0,
                                                         bottom: 0,
                                                         child: Opacity(
                                                           opacity: opacity,
                                                           child: Container(
                                                             decoration: BoxDecoration(
                                                               gradient: isSelected
                                                                   ? const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFFF4081)])
                                                                   : const LinearGradient(colors: [Color(0xFF673AB7), Color(0xFF512DA8)]),
                                                               borderRadius: BorderRadius.circular(6),
                                                               border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
                                                               boxShadow: isDragging
                                                                   ? [
                                                                       BoxShadow(
                                                                         color: const Color(0xFFFF4081).withOpacity(0.7),
                                                                         blurRadius: 8,
                                                                         spreadRadius: 1,
                                                                       )
                                                                     ]
                                                                   : null,
                                                             ),
                                                             child: Stack(
                                                               children: [
                                                                 // 1. Middle Body (Long-Press to MOVE clip, Tap to select)
                                                                 Positioned(
                                                                   left: isSelected ? 14.0 : 0.0,
                                                                   right: isSelected ? 14.0 : 0.0,
                                                                   top: 0,
                                                                   bottom: 0,
                                                                   child: GestureDetector(
                                                                     behavior: HitTestBehavior.opaque,
                                                                     onTap: () => notifier.selectLayer(media.id),
                                                                     onLongPressStart: (_) {
                                                                       notifier.pushHistory();
                                                                       setState(() {
                                                                         _draggingMediaId = media.id;
                                                                         _dragMediaInitialStart = media.startTime;
                                                                       });
                                                                     },
                                                                     onLongPressMoveUpdate: (details) {
                                                                       final deltaSeconds = details.localOffsetFromOrigin.dx / _timeScale;
                                                                       final maxAllowedStart = (project.duration - media.mediaDuration).clamp(0.0, double.infinity);
                                                                       final newStart = (_dragMediaInitialStart + deltaSeconds).clamp(0.0, maxAllowedStart);
                                                                       notifier.updateMediaLayer(
                                                                         media.copyWith(startTime: newStart),
                                                                         recordHistory: false,
                                                                       );
                                                                     },
                                                                     onLongPressEnd: (_) {
                                                                       setState(() {
                                                                         _draggingMediaId = null;
                                                                       });
                                                                     },
                                                                     child: Container(
                                                                       alignment: Alignment.center,
                                                                       color: Colors.transparent,
                                                                       child: Row(
                                                                         mainAxisAlignment: MainAxisAlignment.center,
                                                                         children: [
                                                                           Icon(
                                                                             media.type == MediaType.video ? Icons.videocam_rounded : Icons.photo_rounded,
                                                                             size: 12,
                                                                             color: Colors.white,
                                                                           ),
                                                                           const SizedBox(width: 4),
                                                                           Text(
                                                                             media.type == MediaType.video ? 'Overlay' : 'Overlay',
                                                                             style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                                           ),
                                                                         ],
                                                                       ),
                                                                     ),
                                                                   ),
                                                                 ),

                                                                 // 2. Left Trim Handle ONLY
                                                                 if (isSelected)
                                                                   Positioned(
                                                                     left: 0, top: 0, bottom: 0, width: 14,
                                                                     child: GestureDetector(
                                                                       behavior: HitTestBehavior.opaque,
                                                                       onHorizontalDragStart: (_) {
                                                                         _isUserScrolling = true;
                                                                         notifier.pushHistory();
                                                                       },
                                                                       onHorizontalDragUpdate: (details) {
                                                                         _handleTrimDrag(
                                                                           details: details,
                                                                           onTrimDelta: (delta) => notifier.trimMediaLayerStart(media.id, delta),
                                                                         );
                                                                       },
                                                                       onHorizontalDragEnd: (_) {
                                                                         _stopTrimAutoScroll();
                                                                         _isUserScrolling = false;
                                                                       },
                                                                       onHorizontalDragCancel: () {
                                                                         _stopTrimAutoScroll();
                                                                         _isUserScrolling = false;
                                                                       },
                                                                       child: Container(
                                                                         decoration: const BoxDecoration(
                                                                           color: Colors.white,
                                                                           borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
                                                                         ),
                                                                         child: const Center(child: Icon(Icons.drag_indicator_rounded, size: 10, color: Colors.black45)),
                                                                       ),
                                                                     ),
                                                                   ),

                                                                 // 3. Right Trim Handle ONLY
                                                                 if (isSelected)
                                                                   Positioned(
                                                                     right: 0, top: 0, bottom: 0, width: 14,
                                                                     child: GestureDetector(
                                                                       behavior: HitTestBehavior.opaque,
                                                                       onHorizontalDragStart: (_) {
                                                                         _isUserScrolling = true;
                                                                         notifier.pushHistory();
                                                                       },
                                                                       onHorizontalDragUpdate: (details) {
                                                                         _handleTrimDrag(
                                                                           details: details,
                                                                           onTrimDelta: (delta) => notifier.trimMediaLayerEnd(media.id, delta),
                                                                         );
                                                                       },
                                                                       onHorizontalDragEnd: (_) {
                                                                         _stopTrimAutoScroll();
                                                                         _isUserScrolling = false;
                                                                       },
                                                                       onHorizontalDragCancel: () {
                                                                         _stopTrimAutoScroll();
                                                                         _isUserScrolling = false;
                                                                       },
                                                                       child: Container(
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
                                                       );
                                                     }).toList(),
                                                   ),
                                                 ),

                                              // 2. Main Media Tracks (Video & Images)
                                              Container(
                                                margin: const EdgeInsets.symmetric(vertical: 2),
                                                height: 26,
                                                child: (mainMediaLayers.isNotEmpty) ? Stack(
                                                  children: mainMediaLayers.map((media) {
                                                    final isSelected = project.selectedLayerId == media.id;
                                                    final isDragging = _draggingMediaId == media.id;
                                                    final double opacity = (project.isTrimMode && !isSelected) ? 0.3 : (isDragging ? 0.85 : 1.0);
                                                    final double mediaStart = media.startTime.isFinite && !media.startTime.isNaN ? media.startTime : 0.0;
                                                    final double mediaDurRaw = media.mediaDuration.isFinite && !media.mediaDuration.isNaN && media.mediaDuration > 0 ? media.mediaDuration : duration;
                                                    return Positioned(
                                                      left: mediaStart * _timeScale,
                                                      width: mediaDurRaw * _timeScale,
                                                      top: 0,
                                                      bottom: 0,
                                                      child: Opacity(
                                                        opacity: opacity,
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                            color: isSelected ? const Color(0xFFFF512F) : const Color(0xFFEAB308),
                                                            borderRadius: BorderRadius.circular(6),
                                                            border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
                                                            boxShadow: isDragging
                                                                ? [
                                                                    BoxShadow(
                                                                      color: const Color(0xFFFF512F).withOpacity(0.7),
                                                                      blurRadius: 8,
                                                                      spreadRadius: 1,
                                                                    )
                                                                  ]
                                                                : null,
                                                          ),
                                                          child: Stack(
                                                            children: [
                                                              // 1. Middle Body (Long-Press to MOVE clip, Tap to select)
                                                              Positioned(
                                                                left: isSelected ? 14.0 : 0.0,
                                                                right: isSelected ? 14.0 : 0.0,
                                                                top: 0,
                                                                bottom: 0,
                                                                child: GestureDetector(
                                                                  behavior: HitTestBehavior.opaque,
                                                                  onTap: () => notifier.selectLayer(media.id),
                                                                  onLongPressStart: (_) {
                                                                    notifier.pushHistory();
                                                                    setState(() {
                                                                      _draggingMediaId = media.id;
                                                                      _dragMediaInitialStart = media.startTime;
                                                                    });
                                                                  },
                                                                  onLongPressMoveUpdate: (details) {
                                                                    final deltaSeconds = details.localOffsetFromOrigin.dx / _timeScale;
                                                                    final maxAllowedStart = (project.duration - media.mediaDuration).clamp(0.0, double.infinity);
                                                                    final newStart = (_dragMediaInitialStart + deltaSeconds).clamp(0.0, maxAllowedStart);
                                                                    notifier.updateMediaLayer(
                                                                      media.copyWith(startTime: newStart),
                                                                      recordHistory: false,
                                                                    );
                                                                  },
                                                                  onLongPressEnd: (_) {
                                                                    setState(() {
                                                                      _draggingMediaId = null;
                                                                    });
                                                                  },
                                                                  child: Container(
                                                                    alignment: Alignment.center,
                                                                    color: Colors.transparent,
                                                                    child: Text(
                                                                      media.type == MediaType.video ? 'Video' : 'Photo',
                                                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),

                                                              // 2. Left Trim Handle ONLY
                                                              if (isSelected)
                                                                Positioned(
                                                                  left: 0, top: 0, bottom: 0, width: 14,
                                                                  child: GestureDetector(
                                                                    behavior: HitTestBehavior.opaque,
                                                                    onHorizontalDragStart: (_) {
                                                                      _isUserScrolling = true;
                                                                      notifier.pushHistory();
                                                                    },
                                                                    onHorizontalDragUpdate: (details) {
                                                                      _handleTrimDrag(
                                                                        details: details,
                                                                        onTrimDelta: (delta) => notifier.trimMediaLayerStart(media.id, delta),
                                                                      );
                                                                    },
                                                                    onHorizontalDragEnd: (_) {
                                                                      _stopTrimAutoScroll();
                                                                      _isUserScrolling = false;
                                                                    },
                                                                    onHorizontalDragCancel: () {
                                                                      _stopTrimAutoScroll();
                                                                      _isUserScrolling = false;
                                                                    },
                                                                    child: Container(
                                                                      decoration: const BoxDecoration(
                                                                        color: Colors.white,
                                                                        borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
                                                                      ),
                                                                      child: const Center(child: Icon(Icons.drag_indicator_rounded, size: 10, color: Colors.black45)),
                                                                    ),
                                                                  ),
                                                                ),

                                                              // 3. Right Trim Handle ONLY
                                                              if (isSelected)
                                                                Positioned(
                                                                  right: 0, top: 0, bottom: 0, width: 14,
                                                                  child: GestureDetector(
                                                                    behavior: HitTestBehavior.opaque,
                                                                    onHorizontalDragStart: (_) {
                                                                      _isUserScrolling = true;
                                                                      notifier.pushHistory();
                                                                    },
                                                                    onHorizontalDragUpdate: (details) {
                                                                      _handleTrimDrag(
                                                                        details: details,
                                                                        onTrimDelta: (delta) => notifier.trimMediaLayerEnd(media.id, delta),
                                                                      );
                                                                    },
                                                                    onHorizontalDragEnd: (_) {
                                                                      _stopTrimAutoScroll();
                                                                      _isUserScrolling = false;
                                                                    },
                                                                    onHorizontalDragCancel: () {
                                                                      _stopTrimAutoScroll();
                                                                      _isUserScrolling = false;
                                                                    },
                                                                    child: Container(
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
                                                    );
                                                  }).toList(),
                                                ) : const SizedBox(),
                                              ),

                                              // Audio Tracks (One row per layer)
                                              ...audioLayers.map((audio) {
                                                final isSelected = project.selectedLayerId == audio.id;
                                                final isDragging = _draggingMediaId == audio.id;
                                                final double opacity = (project.isTrimMode && !isSelected) ? 0.3 : (isDragging ? 0.85 : 1.0);
                                                return Container(
                                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                                  height: 22,
                                                  child: Stack(
                                                    children: [
                                                      Positioned(
                                                        left: (audio.startTime.isFinite && !audio.startTime.isNaN ? audio.startTime : 0.0) * _timeScale,
                                                        width: (audio.mediaDuration.isFinite && !audio.mediaDuration.isNaN && audio.mediaDuration > 0 ? audio.mediaDuration : duration) * _timeScale,
                                                        top: 0,
                                                        bottom: 0,
                                                        child: Opacity(
                                                          opacity: opacity,
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              color: isSelected ? AppTheme.primaryAccent : Colors.teal.shade700,
                                                              borderRadius: BorderRadius.circular(6),
                                                              border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
                                                              boxShadow: isDragging
                                                                  ? [
                                                                      BoxShadow(
                                                                        color: AppTheme.primaryAccent.withOpacity(0.7),
                                                                        blurRadius: 8,
                                                                        spreadRadius: 1,
                                                                      )
                                                                    ]
                                                                  : null,
                                                            ),
                                                            child: Stack(
                                                              children: [
                                                                // 1. Middle Body (Long-Press to MOVE audio, Tap to select)
                                                                Positioned(
                                                                  left: isSelected ? 14.0 : 0.0,
                                                                  right: isSelected ? 14.0 : 0.0,
                                                                  top: 0,
                                                                  bottom: 0,
                                                                  child: GestureDetector(
                                                                    behavior: HitTestBehavior.opaque,
                                                                    onTap: () => notifier.selectLayer(audio.id),
                                                                    onLongPressStart: (_) {
                                                                      notifier.pushHistory();
                                                                      setState(() {
                                                                        _draggingMediaId = audio.id;
                                                                        _dragMediaInitialStart = audio.startTime;
                                                                      });
                                                                    },
                                                                    onLongPressMoveUpdate: (details) {
                                                                      final deltaSeconds = details.localOffsetFromOrigin.dx / _timeScale;
                                                                      final maxAllowedStart = (project.duration - audio.mediaDuration).clamp(0.0, double.infinity);
                                                                      final newStart = (_dragMediaInitialStart + deltaSeconds).clamp(0.0, maxAllowedStart);
                                                                      notifier.updateMediaLayer(
                                                                        audio.copyWith(startTime: newStart),
                                                                        recordHistory: false,
                                                                      );
                                                                    },
                                                                    onLongPressEnd: (_) {
                                                                      setState(() {
                                                                        _draggingMediaId = null;
                                                                      });
                                                                    },
                                                                    child: Container(
                                                                      alignment: Alignment.center,
                                                                      color: Colors.transparent,
                                                                      child: const Text('Audio Track', style: TextStyle(color: Colors.white, fontSize: 10)),
                                                                    ),
                                                                  ),
                                                                ),

                                                                // 2. Left Trim Handle ONLY
                                                                if (isSelected)
                                                                  Positioned(
                                                                    left: 0, top: 0, bottom: 0, width: 14,
                                                                    child: GestureDetector(
                                                                      behavior: HitTestBehavior.opaque,
                                                                      onHorizontalDragStart: (_) {
                                                                        _isUserScrolling = true;
                                                                        notifier.pushHistory();
                                                                      },
                                                                      onHorizontalDragUpdate: (details) {
                                                                        _handleTrimDrag(
                                                                          details: details,
                                                                          onTrimDelta: (delta) => notifier.trimMediaLayerStart(audio.id, delta),
                                                                        );
                                                                      },
                                                                      onHorizontalDragEnd: (_) {
                                                                        _stopTrimAutoScroll();
                                                                        _isUserScrolling = false;
                                                                      },
                                                                      onHorizontalDragCancel: () {
                                                                        _stopTrimAutoScroll();
                                                                        _isUserScrolling = false;
                                                                      },
                                                                      child: Container(
                                                                        decoration: const BoxDecoration(
                                                                          color: Colors.white,
                                                                          borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
                                                                        ),
                                                                        child: const Center(child: Icon(Icons.drag_indicator_rounded, size: 10, color: Colors.black45)),
                                                                      ),
                                                                    ),
                                                                  ),

                                                                // 3. Right Trim Handle ONLY
                                                                if (isSelected)
                                                                  Positioned(
                                                                    right: 0, top: 0, bottom: 0, width: 14,
                                                                    child: GestureDetector(
                                                                      behavior: HitTestBehavior.opaque,
                                                                      onHorizontalDragStart: (_) {
                                                                        _isUserScrolling = true;
                                                                        notifier.pushHistory();
                                                                      },
                                                                      onHorizontalDragUpdate: (details) {
                                                                        _handleTrimDrag(
                                                                          details: details,
                                                                          onTrimDelta: (delta) => notifier.trimMediaLayerEnd(audio.id, delta),
                                                                        );
                                                                      },
                                                                      onHorizontalDragEnd: (_) {
                                                                        _stopTrimAutoScroll();
                                                                        _isUserScrolling = false;
                                                                      },
                                                                      onHorizontalDragCancel: () {
                                                                        _stopTrimAutoScroll();
                                                                        _isUserScrolling = false;
                                                                      },
                                                                      child: Container(
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
                                  // Dynamic Overlay header
                                  if (overlayLayers.isNotEmpty)
                                    Container(
                                      height: 26,
                                      margin: const EdgeInsets.symmetric(vertical: 2),
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          if (overlayLayers.first.type == MediaType.video) {
                                            notifier.updateMediaLayerProperties(
                                              overlayLayers.first.id,
                                              isMuted: !overlayLayers.first.isMuted,
                                            );
                                          }
                                        },
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              overlayLayers.first.type == MediaType.sticker
                                                  ? Icons.layers_outlined
                                                  : (overlayLayers.first.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
                                              color: (overlayLayers.first.type == MediaType.video && overlayLayers.first.isMuted)
                                                  ? Colors.redAccent
                                                  : const Color(0xFF00E5FF),
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              overlayLayers.first.type == MediaType.sticker
                                                  ? 'Overlay\nPhoto'
                                                  : (overlayLayers.first.isMuted ? 'Muted' : 'Mute clip\naudio'),
                                              style: const TextStyle(color: Colors.white54, fontSize: 8, height: 1.1),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  // Main Media track header
                                  Container(
                                    height: 26,
                                    margin: const EdgeInsets.symmetric(vertical: 2),
                                    child: mainMediaLayers.isNotEmpty ? GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        if (mainMediaLayers.first.type == MediaType.video) {
                                          notifier.updateMediaLayerProperties(mainMediaLayers.first.id, isMuted: !mainMediaLayers.first.isMuted);
                                        }
                                      },
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            mainMediaLayers.first.type == MediaType.sticker
                                                ? Icons.image_rounded
                                                : (mainMediaLayers.first.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
                                            color: (mainMediaLayers.first.type == MediaType.video && mainMediaLayers.first.isMuted) ? Colors.redAccent : Colors.white54,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            mainMediaLayers.first.type == MediaType.sticker
                                                ? 'Main\nPhoto'
                                                : (mainMediaLayers.first.isMuted ? 'Muted' : 'Mute clip\naudio'),
                                            style: const TextStyle(color: Colors.white54, fontSize: 8, height: 1.1),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ) : const SizedBox(),
                                  ),
                                  ...audioLayers.map((audio) {
                                    return Container(
                                      height: 22,
                                      margin: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          // Mute/Unmute Button Only
                                          Expanded(
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () {
                                                notifier.updateMediaLayerProperties(audio.id, isMuted: !audio.isMuted);
                                              },
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    audio.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                                    color: audio.isMuted ? Colors.redAccent : Colors.white54,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 4),
                                                   Text(
                                                     audio.isMuted ? 'Muted' : 'Mute clip\naudio', 
                                                     style: const TextStyle(color: Colors.white54, fontSize: 8, height: 1.1),
                                                     textAlign: TextAlign.center,
                                                   ),
                                                 ],
                                               ),
                                             ),
                                           ),
                                         ],
                                       ),
                                     );
                                   }).toList(),
                                   if (project.textLayers.isNotEmpty)
                                     ...(() {
                                       final totalTracks = _computeActiveTextTracks(project);
                                       return List.generate(
                                         totalTracks,
                                         (i) => Container(
                                           height: 22,
                                           margin: const EdgeInsets.symmetric(vertical: 2),
                                           child: Row(
                                             mainAxisAlignment: MainAxisAlignment.center,
                                             children: [
                                               const Icon(Icons.text_fields_rounded, color: Colors.white54, size: 12),
                                               if (totalTracks > 1) ...[
                                                 const SizedBox(width: 2),
                                                 Text('T${i + 1}', style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
                                               ],
                                             ],
                                           ),
                                         ),
                                       );
                                     })(),
                                 ],
                               ),
                             ),
                           ),
                         ),

                        // PLAYHEAD LINE
                        Positioned(
                          left: playheadOffset - 1,
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

  int _computeActiveTextTracks(EditorProjectModel project) {
    if (project.textLayers.isEmpty) return 0;
    int maxZ = 0;
    for (final text in project.textLayers) {
      if (text.zIndex > maxZ) maxZ = text.zIndex;
    }
    if (_draggingTextId != null) {
      maxZ += 1;
    }
    return (maxZ + 1).clamp(1, 8);
  }

  List<Widget> _buildTextTracks(EditorProjectModel project, EditorProjectNotifier notifier) {
    final totalTracks = _computeActiveTextTracks(project);
    if (totalTracks == 0) return [];

    final List<List<TextLayerModel>> textRows = List.generate(totalTracks, (_) => []);
    for (final textLayer in project.textLayers) {
      final z = textLayer.zIndex.clamp(0, totalTracks - 1);
      textRows[z].add(textLayer);
    }
    for (int i = 0; i < textRows.length; i++) {
      textRows[i].sort((a, b) => a.startTime.compareTo(b.startTime));
    }

    return List.generate(totalTracks, (trackIndex) {
      final row = textRows[trackIndex];

      return Container(
        key: ValueKey('text_track_row_$trackIndex'),
        margin: const EdgeInsets.symmetric(vertical: 2),
        height: 22,
        child: Stack(
          children: row.map<Widget>((TextLayerModel text) {
            final isSelected = project.selectedLayerId == text.id;
            final isDragging = _draggingTextId == text.id;
            final width = ((text.endTime - text.startTime) * _timeScale).clamp(24.0, double.infinity);

            // Adjacent items on this exact track (stationary references)
            final index = row.indexOf(text);
            final minStart = index > 0 ? row[index - 1].endTime : 0.0;
            final maxEnd = index < row.length - 1 ? row[index + 1].startTime : project.duration;

            final double textStart = text.startTime.isFinite && !text.startTime.isNaN ? text.startTime : 0.0;
            final double textEnd = text.endTime.isFinite && !text.endTime.isNaN ? text.endTime : 3.0;
            final double textWidth = ((textEnd - textStart) * _timeScale).clamp(24.0, double.infinity);

            return Positioned(
              key: ValueKey('text_track_${trackIndex}_${text.id}'),
              left: textStart * _timeScale,
              width: textWidth.isFinite ? textWidth : 24.0,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () => notifier.selectLayer(text.id),
                child: Opacity(
                  opacity: isDragging ? 0.85 : ((!isSelected && project.isTrimMode) ? 0.3 : 1.0),
                  child: Container(
                    key: ValueKey('text_box_inner_${text.id}'),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFF512F) : const Color(0xFFEAB308),
                      borderRadius: BorderRadius.circular(6),
                      border: isSelected ? Border.all(color: Colors.white, width: 1.8) : null,
                      boxShadow: isDragging
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFF512F).withOpacity(0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: isSelected ? 14.0 : 0.0,
                          right: isSelected ? 14.0 : 0.0,
                          top: 0,
                          bottom: 0,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => notifier.selectLayer(text.id),
                            onLongPressStart: (_) {
                              notifier.pushHistory();
                              setState(() {
                                _draggingTextId = text.id;
                                _dragTextInitialStart = text.startTime;
                                _dragTextInitialEnd = text.endTime;
                                _dragTextInitialTrack = text.zIndex;
                              });
                            },
                            onLongPressMoveUpdate: (details) {
                              final deltaSeconds = details.localOffsetFromOrigin.dx / _timeScale;
                              final deltaRows = (details.localOffsetFromOrigin.dy / 26.0).round();

                              int targetTrack = (_dragTextInitialTrack + deltaRows).clamp(0, 7);

                              // Find other stationary items on targetTrack
                              final targetTrackOthers = project.textLayers
                                  .where((l) => l.id != text.id && l.zIndex == targetTrack)
                                  .toList()
                                ..sort((a, b) => a.startTime.compareTo(b.startTime));

                              final prev = targetTrackOthers.where((l) => l.endTime <= _dragTextInitialStart + 0.05).lastOrNull;
                              final next = targetTrackOthers.where((l) => l.startTime >= _dragTextInitialEnd - 0.05).firstOrNull;

                              final double trackMin = prev?.endTime ?? 0.0;
                              final double trackMax = next?.startTime ?? project.duration;

                              final duration = _dragTextInitialEnd - _dragTextInitialStart;
                              final maxAllowedStart = (trackMax - duration).clamp(trackMin, double.infinity);
                              final desiredStart = _dragTextInitialStart + deltaSeconds;

                              final clampedStart = desiredStart.clamp(trackMin, maxAllowedStart);
                              final clampedEnd = clampedStart + duration;

                              // ONLY update the moving text layer! None of the other layers are touched.
                              notifier.updateTextLayer(
                                text.copyWith(
                                  startTime: clampedStart,
                                  endTime: clampedEnd,
                                  zIndex: targetTrack,
                                ),
                                recordHistory: false,
                              );
                            },
                            onLongPressEnd: (_) {
                              setState(() {
                                _draggingTextId = null;
                              });
                            },
                            onLongPressCancel: () {
                              setState(() {
                                _draggingTextId = null;
                              });
                            },
                            child: Container(
                              alignment: Alignment.center,
                              color: Colors.transparent,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  text.text,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            left: 0, top: 0, bottom: 0, width: 14,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragStart: (_) {
                                _isUserScrolling = true;
                                notifier.pushHistory();
                              },
                              onHorizontalDragUpdate: (details) {
                                _handleTrimDrag(
                                  details: details,
                                  onTrimDelta: (delta) {
                                    final currentText = project.textLayers.firstWhere((t) => t.id == text.id, orElse: () => text);
                                    final newStart = (currentText.startTime + delta).clamp(minStart, currentText.endTime - 0.5);
                                    notifier.trimTextLayerStart(text.id, newStart);
                                  },
                                );
                              },
                              onHorizontalDragEnd: (_) {
                                _stopTrimAutoScroll();
                                _isUserScrolling = false;
                              },
                              onHorizontalDragCancel: () {
                                _stopTrimAutoScroll();
                                _isUserScrolling = false;
                              },
                              child: Container(
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
                            right: 0, top: 0, bottom: 0, width: 14,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragStart: (_) {
                                _isUserScrolling = true;
                                notifier.pushHistory();
                              },
                              onHorizontalDragUpdate: (details) {
                                _handleTrimDrag(
                                  details: details,
                                  onTrimDelta: (delta) {
                                    final currentText = project.textLayers.firstWhere((t) => t.id == text.id, orElse: () => text);
                                    final newEnd = (currentText.endTime + delta).clamp(currentText.startTime + 0.5, maxEnd);
                                    notifier.trimTextLayerEnd(text.id, newEnd);
                                  },
                                );
                              },
                              onHorizontalDragEnd: (_) {
                                _stopTrimAutoScroll();
                                _isUserScrolling = false;
                              },
                              onHorizontalDragCancel: () {
                                _stopTrimAutoScroll();
                                _isUserScrolling = false;
                              },
                              child: Container(
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
    });
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
