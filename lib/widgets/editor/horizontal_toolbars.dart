import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import 'in_app_audio_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/media_layer_model.dart';
import '../../models/text_layer_model.dart';
import '../../services/groq_auto_lyrics_service.dart';
import '../../state/auto_lyrics_notifier.dart';
import '../../state/editor_state_notifier.dart';
import '../../theme/app_theme.dart';
import 'online_lyrics_dialog.dart';
import 'text_bubble_painter.dart';
import 'text_animation_preview_tile.dart';
import 'text_template_preview_tile.dart';
import 'text_effect_preview_tile.dart';
import 'crop_media_dialog.dart';
import 'custom_hsv_color_picker.dart';

enum ToolbarCategory {
  main,
  text,
  textStyle,
  textPresets,
  textColor,
  textStroke,
  textGlow,
  textBackground,
  textSize,
  textRotate,
  textLineSpacing,
  textLetterSpacing,
  textOpacity,
  textFont,
  textTemplates,
  textEffects,
  textAnimations,
  textBubbles,
  textAlignment,
  audio,
  video,
  media,
  overlay,
  stickers,
  ratio,
}

class HorizontalToolbarsWidget extends ConsumerStatefulWidget {
  final void Function({int initialIndex}) onOpenTextEditor;
  final VoidCallback onOpenManualLyrics;
  final VoidCallback onOpenLayersPanel;
  final VoidCallback onOpenRatioSelector;

  const HorizontalToolbarsWidget({
    super.key,
    required this.onOpenTextEditor,
    required this.onOpenManualLyrics,
    required this.onOpenLayersPanel,
    required this.onOpenRatioSelector,
  });

  @override
  ConsumerState<HorizontalToolbarsWidget> createState() => _HorizontalToolbarsWidgetState();
}

class _HorizontalToolbarsWidgetState extends ConsumerState<HorizontalToolbarsWidget> {
  ToolbarCategory _activeCategory = ToolbarCategory.main;
  bool _isAutoLyricsLoading = false;
  final Map<ToolbarCategory, bool> _applyToAllStates = {};

  final ImagePicker _picker = ImagePicker();

  static const List<String> _fontOptions = [
    'Outfit',
    'Inter',
    'Roboto',
    'Rubik',
    'Bangers',
    'Solitreo',
    'Ephesis',
    'Rye',
    'Montserrat',
    'Bebas Neue',
    'Oswald',
    'Playfair Display',
    'Prompt',
    'Bowlby One',
    'PT Sans',
    'Chonburi',
    'Tangerine',
    'Caveat',
    'Permanent Marker',
    'Sacramento',
    'Great Vibes',
    'Cinzel Decorative',
    'Creepster',
    'Righteous',
    'Abril Fatface',
    'Comfortaa',
    'Satisfy',
    'Monoton',
    'Press Start 2P',
    'Alfa Slab One',
    'Courgette',
    'Pacifico',
    'Dancing Script',
    'Lobster',
    'Anton',
    'Poppins',
    'Nunito',
    'Merriweather',
    'Cinzel',
    'Amatic SC',
    'Kaushan Script',
    'Syne',
    'Fredoka',
  ];

  static const List<Color> _presetColors = [
    Colors.white,
    Color(0xFFFFD700), // Gold/Yellow
    Color(0xFFFF3B30), // Red
    Color(0xFF34C759), // Green
    Color(0xFF007AFF), // Blue
    Color(0xFFAF52DE), // Purple
    Color(0xFFFF9500), // Orange
    Color(0xFFFF2D55), // Pink
    Color(0xFF00E5FF), // Cyan
    Colors.black,
  ];

  void _showMediaPickerSheet({bool replace = false, bool isOverlay = false}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181826),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final title = replace ? 'Replace Media' : (isOverlay ? 'Add Overlay' : 'Add Media');
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickVideo(replace: replace, isOverlay: isOverlay);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1BFFFF).withOpacity(0.2),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Column(
                            children: const [
                              Icon(Icons.videocam_rounded, color: Colors.white, size: 30),
                              SizedBox(height: 8),
                              Text(
                                'Video',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickImage(replace: replace, isOverlay: isOverlay);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD4145A), Color(0xFFFBB03B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFBB03B).withOpacity(0.2),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Column(
                            children: const [
                              Icon(Icons.photo_library_rounded, color: Colors.white, size: 30),
                              SizedBox(height: 8),
                              Text(
                                'Image',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickVideo({bool replace = false, bool isOverlay = false}) async {
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

      final project = ref.read(editorProjectProvider);

      if (replace && project.selectedLayerId != null) {
        ref.read(editorProjectProvider.notifier).replaceMediaLayerPath(
          project.selectedLayerId!, 
          file.path, 
          duration,
          newType: MediaType.video,
        );
        return;
      }

      final media = MediaLayerModel(
        id: const Uuid().v4(),
        path: file.path,
        type: MediaType.video,
        mediaDuration: duration,
        originalDuration: duration,
        startTime: isOverlay ? project.currentPlayheadTime : (project.mediaLayers.where((m) => !m.isOverlay && (m.type == MediaType.video || m.type == MediaType.sticker)).isEmpty ? 0.0 : project.duration),
        scaleX: isOverlay ? 0.4 : 1.0,
        scaleY: isOverlay ? 0.4 : 1.0,
        position: isOverlay ? const Offset(0.5, 0.5) : const Offset(0.5, 0.5),
        isOverlay: isOverlay,
      );
      ref.read(editorProjectProvider.notifier).addMediaLayer(media);
    }
  }

  Future<void> _pickImage({bool replace = false, bool isOverlay = false}) async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      final project = ref.read(editorProjectProvider);

      if (replace && project.selectedLayerId != null) {
        ref.read(editorProjectProvider.notifier).replaceMediaLayerPath(
          project.selectedLayerId!, 
          file.path, 
          5.0,
          newType: MediaType.sticker,
        );
        return;
      }

      final media = MediaLayerModel(
        id: const Uuid().v4(),
        path: file.path,
        type: MediaType.sticker,
        mediaDuration: 5.0,
        originalDuration: 5.0,
        startTime: isOverlay ? project.currentPlayheadTime : (project.mediaLayers.where((m) => !m.isOverlay && (m.type == MediaType.video || m.type == MediaType.sticker)).isEmpty ? 0.0 : project.duration),
        scaleX: isOverlay ? 0.4 : 1.0,
        scaleY: isOverlay ? 0.4 : 1.0,
        position: isOverlay ? const Offset(0.5, 0.5) : const Offset(0.5, 0.5),
        isOverlay: isOverlay,
      );
      ref.read(editorProjectProvider.notifier).addMediaLayer(media);
    }
  }

  void _pickAudio({bool replace = false}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.7,
          child: InAppAudioPicker(
            onAudioPicked: (path, duration) {
              Navigator.pop(context); // Close the bottom sheet
              final project = ref.read(editorProjectProvider);

              final effectiveDuration = duration > 0 ? duration : 15.0;

              if (replace && project.selectedLayerId != null) {
                ref.read(editorProjectProvider.notifier).replaceMediaLayerPath(project.selectedLayerId!, path, effectiveDuration);
                return;
              }

              final media = MediaLayerModel(
                id: const Uuid().v4(),
                path: path,
                type: MediaType.audio,
                startTime: project.currentPlayheadTime,
                mediaDuration: effectiveDuration,
                originalDuration: effectiveDuration,
              );
              ref.read(editorProjectProvider.notifier).addMediaLayer(media);
            },
          ),
        );
      },
    );
  }

  Future<void> _extractAudio() async {
    final project = ref.read(editorProjectProvider);
    if (project.selectedLayerId == null) return;

    final layer = project.mediaLayers.firstWhere((l) => l.id == project.selectedLayerId);
    if (layer.type != MediaType.video) return;

    ref.read(editorProjectProvider.notifier).extractAudio(layer.id, layer.path, layer.mediaDuration);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Audio extracted and added as a separate track!')),
    );
  }

  void _showSliderBottomSheet({
    required String title,
    required double initialValue,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    String unit = '',
    bool isInteger = true,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14141E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        double currentValue = initialValue;
        final textController = TextEditingController(
          text: isInteger ? currentValue.toInt().toString() : currentValue.toStringAsFixed(1),
        );

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 20.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.check_circle_rounded, color: AppTheme.primaryAccent, size: 26),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Direct Input & Stepper Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white70, size: 28),
                        onPressed: () {
                          final step = isInteger ? 1.0 : 0.1;
                          final newVal = (currentValue - step).clamp(min, max);
                          setSheetState(() {
                            currentValue = newVal;
                            textController.text = isInteger ? newVal.toInt().toString() : newVal.toStringAsFixed(1);
                          });
                          onChanged(newVal);
                        },
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 90,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF222232),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.cyanAccent.withOpacity(0.6), width: 1.2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: TextField(
                                controller: textController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (val) {
                                  if (val.trim() == '-' || val.trim().isEmpty) return;
                                  final parsed = double.tryParse(val);
                                  if (parsed != null) {
                                    final clamped = parsed.clamp(min, max);
                                    setSheetState(() {
                                      currentValue = clamped;
                                    });
                                    onChanged(clamped);
                                  }
                                },
                              ),
                            ),
                            if (unit.isNotEmpty) ...[
                              const SizedBox(width: 2),
                              Text(unit, style: const TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white70, size: 28),
                        onPressed: () {
                          final step = isInteger ? 1.0 : 0.1;
                          final newVal = (currentValue + step).clamp(min, max);
                          setSheetState(() {
                            currentValue = newVal;
                            textController.text = isInteger ? newVal.toInt().toString() : newVal.toStringAsFixed(1);
                          });
                          onChanged(newVal);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Slider
                  SliderTheme(
                    data: const SliderThemeData(
                      activeTrackColor: AppTheme.primaryAccent,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: AppTheme.primaryAccent,
                      trackHeight: 4.0,
                    ),
                    child: Slider(
                      value: currentValue.clamp(min, max),
                      min: min,
                      max: max,
                      onChanged: (val) {
                        setSheetState(() {
                          currentValue = val;
                          textController.text = isInteger ? val.toInt().toString() : val.toStringAsFixed(1);
                        });
                        onChanged(val);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCropDialog() async {
    final project = ref.read(editorProjectProvider);
    if (project.selectedLayerId == null) return;
    final layer = project.mediaLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;
    if (layer == null) return;

    final result = await CropMediaDialog.show(
      context,
      layer,
      currentPlayheadTime: project.currentPlayheadTime,
    );
    if (result != null) {
      ref.read(editorProjectProvider.notifier).updateMediaLayerCrop(
        layer.id,
        cropLeft: result.cropLeft,
        cropTop: result.cropTop,
        cropRight: result.cropRight,
        cropBottom: result.cropBottom,
      );
    }
  }

  Future<void> _executeAutoLyricsGenerate() async {
    final project = ref.read(editorProjectProvider);
    final audioVideoLayers = project.mediaLayers.where((m) => m.type == MediaType.audio || m.type == MediaType.video).toList();
    
    MediaLayerModel? targetLayer;
    if (project.selectedLayerId != null) {
      try {
        targetLayer = audioVideoLayers.firstWhere((m) => m.id == project.selectedLayerId);
      } catch (_) {}
    }

    if (targetLayer == null) {
      if (audioVideoLayers.length == 1) {
        targetLayer = audioVideoLayers.first;
      } else if (audioVideoLayers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please import a Video or Audio track first!')),
        );
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please tap to select a specific track for Auto Lyrics!')),
        );
        return;
      }
    }

    ref.read(autoLyricsProvider.notifier).startGeneration(targetLayer);
    _showAutoLyricsProgressModal(targetLayer);
  }

  void _showAutoLyricsProgressModal(MediaLayerModel targetLayer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return Consumer(
          builder: (context, ref, _) {
            final autoState = ref.watch(autoLyricsProvider);

            if (autoState.status == AutoLyricsStatus.success) {
              Future.delayed(const Duration(milliseconds: 1400), () {
                if (context.mounted && Navigator.canPop(context)) {
                  Navigator.pop(context);
                  ref.read(autoLyricsProvider.notifier).reset();
                }
              });
            }

            return Center(
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B28),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: autoState.status == AutoLyricsStatus.success
                          ? Colors.greenAccent.withOpacity(0.6)
                          : autoState.status == AutoLyricsStatus.error
                              ? Colors.redAccent.withOpacity(0.6)
                              : const Color(0xFFFF9800).withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (autoState.status == AutoLyricsStatus.success
                                ? Colors.greenAccent
                                : autoState.status == AutoLyricsStatus.error
                                    ? Colors.redAccent
                                    : const Color(0xFFFF9800))
                            .withOpacity(0.25),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Status Icon / Animation
                      if (autoState.status == AutoLyricsStatus.generating || autoState.status == AutoLyricsStatus.idle) ...[
                        Container(
                          width: 64,
                          height: 64,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFF9800).withOpacity(0.12),
                          ),
                          child: const CircularProgressIndicator(
                            strokeWidth: 3.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF9800)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Generating AI Lyrics...',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'AI is transcribing speech from your video audio...',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ] else if (autoState.status == AutoLyricsStatus.success) ...[
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.greenAccent.withOpacity(0.15),
                          ),
                          child: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 48),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          '✨ Lyrics Generated!',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Added ${autoState.generatedCount} synchronized lyric lines to your timeline.',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ] else if (autoState.status == AutoLyricsStatus.error) ...[
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.redAccent.withOpacity(0.15),
                          ),
                          child: Icon(
                            autoState.isNetworkError ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                            color: Colors.redAccent,
                            size: 44,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          autoState.isNetworkError ? 'Network Connection Error' : 'Generation Failed',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          autoState.errorMessage,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  ref.read(autoLyricsProvider.notifier).reset();
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Cancel', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => ref.read(autoLyricsProvider.notifier).startGeneration(targetLayer),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF9800),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _runAutoLyrics() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14141E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Lyrics',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFF9800)),
                title: const Text('Auto Generate (Speech-to-Text)', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Uses AI to extract lyrics from video/audio', style: TextStyle(color: Colors.white54)),
                onTap: () {
                  Navigator.pop(context);
                  _executeAutoLyricsGenerate();
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_download_rounded, color: Colors.cyanAccent),
                title: const Text('Import Lyrics Online', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Search for a song and download lyrics', style: TextStyle(color: Colors.white54)),
                onTap: () async {
                  Navigator.pop(context);
                  final selectedLines = await showDialog<List<String>>(
                    context: context,
                    builder: (ctx) => const OnlineLyricsDialog(),
                  );
                  if (selectedLines != null && selectedLines.isNotEmpty) {
                    ref.read(editorProjectProvider.notifier).setQueuedLyrics(selectedLines);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${selectedLines.length} lines queued! Tap the \"Drop Next Lyric\" button to place them.')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isStyleSubtool(ToolbarCategory cat) {
    return cat == ToolbarCategory.textStyle ||
           cat == ToolbarCategory.textColor ||
           cat == ToolbarCategory.textStroke ||
           cat == ToolbarCategory.textGlow ||
           cat == ToolbarCategory.textBackground ||
           cat == ToolbarCategory.textSize ||
           cat == ToolbarCategory.textFont ||
           cat == ToolbarCategory.textEffects ||
           cat == ToolbarCategory.textAnimations ||
           cat == ToolbarCategory.textBubbles ||
           cat == ToolbarCategory.textPresets ||
           cat == ToolbarCategory.textAlignment ||
           cat == ToolbarCategory.textRotate ||
           cat == ToolbarCategory.textLineSpacing ||
           cat == ToolbarCategory.textLetterSpacing ||
           cat == ToolbarCategory.textOpacity ||
           cat == ToolbarCategory.textTemplates;
  }

  void _triggerApplyToAllStyle() {
    final project = ref.read(editorProjectProvider);
    final selectedId = project.selectedLayerId;
    if (selectedId == null) return;
    final selectedText = project.textLayers.where((l) => l.id == selectedId).firstOrNull;
    if (selectedText == null) return;

    final notifier = ref.read(editorProjectProvider.notifier);

    switch (_activeCategory) {
      case ToolbarCategory.textColor:
        notifier.updateAllTextLayersStyle(
          textColor: selectedText.textColor,
        );
        break;
      case ToolbarCategory.textFont:
        notifier.updateAllTextLayersStyle(
          fontFamily: selectedText.fontFamily,
        );
        break;
      case ToolbarCategory.textPresets:
        notifier.updateAllTextLayersStyle(
          textColor: selectedText.textColor,
          strokeColor: selectedText.strokeColor,
          strokeWidth: selectedText.strokeWidth,
          backgroundColor: selectedText.backgroundColor,
          clearStroke: selectedText.strokeColor == null,
          clearBackground: selectedText.backgroundColor == null,
        );
        break;
      case ToolbarCategory.textStroke:
        notifier.updateAllTextLayersStyle(
          strokeColor: selectedText.strokeColor,
          strokeWidth: selectedText.strokeWidth,
          clearStroke: selectedText.strokeColor == null,
        );
        break;
      case ToolbarCategory.textGlow:
        notifier.updateAllTextLayersStyle(
          strokeColor: selectedText.strokeColor,
          strokeWidth: selectedText.strokeWidth,
          clearStroke: selectedText.strokeColor == null,
        );
        break;
      case ToolbarCategory.textBackground:
        notifier.updateAllTextLayersStyle(
          backgroundColor: selectedText.backgroundColor,
          textColor: selectedText.textColor,
          clearBackground: selectedText.backgroundColor == null,
        );
        break;
      case ToolbarCategory.textAnimations:
        notifier.updateAllTextLayersStyle(
          animation: selectedText.animation,
          animationDuration: selectedText.animationDuration,
        );
        break;
      case ToolbarCategory.textBubbles:
        notifier.updateAllTextLayersStyle(
          bubbleStyle: selectedText.bubbleStyle,
          textColor: selectedText.textColor,
          backgroundColor: selectedText.backgroundColor,
          clearBubble: selectedText.bubbleStyle == null || selectedText.bubbleStyle == 'none',
        );
        break;
      case ToolbarCategory.textStyle:
        notifier.updateAllTextLayersStyle(
          fontWeight: selectedText.fontWeight,
          fontStyle: selectedText.fontStyle,
          textAlign: selectedText.textAlign,
          letterSpacing: selectedText.letterSpacing,
          lineSpacing: selectedText.lineSpacing,
          opacity: selectedText.opacity,
        );
        break;
      case ToolbarCategory.textAlignment:
        notifier.updateAllTextLayersStyle(
          textAlign: selectedText.textAlign,
          position: selectedText.position,
        );
        break;
      case ToolbarCategory.textSize:
        notifier.updateAllTextLayersStyle(
          fontSize: selectedText.fontSize,
        );
        break;
      case ToolbarCategory.textRotate:
        notifier.updateAllTextLayersStyle(
          rotation: selectedText.rotation,
        );
        break;
      case ToolbarCategory.textLineSpacing:
        notifier.updateAllTextLayersStyle(
          lineSpacing: selectedText.lineSpacing,
        );
        break;
      case ToolbarCategory.textLetterSpacing:
        notifier.updateAllTextLayersStyle(
          letterSpacing: selectedText.letterSpacing,
        );
        break;
      case ToolbarCategory.textOpacity:
        notifier.updateAllTextLayersStyle(
          opacity: selectedText.opacity,
        );
        break;
      case ToolbarCategory.textTemplates:
        if (selectedText.animation == TextAnimationType.none && (selectedText.strokeColor == null || selectedText.strokeColor == Colors.transparent)) {
          notifier.updateAllTextLayersStyle(
            textColor: Colors.white,
            fontFamily: 'Outfit',
            clearStroke: true,
            clearBackground: true,
            animation: TextAnimationType.none,
          );
        } else {
          notifier.updateAllTextLayersStyle(
            textColor: selectedText.textColor,
            strokeColor: selectedText.strokeColor,
            strokeWidth: selectedText.strokeWidth,
            clearStroke: selectedText.strokeColor == null,
            backgroundColor: selectedText.backgroundColor,
            clearBackground: selectedText.backgroundColor == null,
            fontFamily: selectedText.fontFamily,
            animation: selectedText.animation,
          );
        }
        break;
      case ToolbarCategory.textEffects:
        if (selectedText.strokeColor == null || selectedText.strokeColor == Colors.transparent) {
          notifier.updateAllTextLayersStyle(
            textColor: Colors.white,
            clearStroke: true,
            clearBackground: true,
          );
        } else {
          notifier.updateAllTextLayersStyle(
            textColor: selectedText.textColor,
            strokeColor: selectedText.strokeColor,
            strokeWidth: selectedText.strokeWidth,
            clearStroke: selectedText.strokeColor == null,
            backgroundColor: selectedText.backgroundColor,
            clearBackground: selectedText.backgroundColor == null,
          );
        }
        break;
      default:
        break;
    }
  }

  void _updateTextLayerStyle(TextLayerModel updated) {
    if (_applyToAllStates[_activeCategory] == true) {
      setState(() {
        _applyToAllStates[_activeCategory] = false;
      });
      if (_activeCategory == ToolbarCategory.textAlignment) {
        ref.read(editorProjectProvider.notifier).syncPositionToAll = false;
      }
    }
    ref.read(editorProjectProvider.notifier).updateTextLayer(updated);
  }

  Widget _buildApplyToAllSection() {
    final isApplied = _applyToAllStates[_activeCategory] ?? false;
    return InkWell(
      onTap: () {
        final nextState = !isApplied;
        setState(() {
          _applyToAllStates[_activeCategory] = nextState;
        });
        if (_activeCategory == ToolbarCategory.textAlignment) {
          ref.read(editorProjectProvider.notifier).syncPositionToAll = nextState;
        }
        if (nextState) {
          _triggerApplyToAllStyle();
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              isApplied ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              size: 13,
              color: isApplied ? const Color(0xFF00E5FF) : Colors.white60,
            ),
            const SizedBox(width: 4),
            const Text(
              'Apply to All',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNumericInputDialog({
    required String title,
    required double currentValue,
    required double min,
    required double max,
    required Function(double) onSubmitted,
  }) {
    final controller = TextEditingController(text: currentValue.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''));
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter value between $min and $max',
              hintStyle: const TextStyle(color: Colors.white30),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryAccent)),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                final double? parsedVal = double.tryParse(controller.text);
                if (parsedVal != null) {
                  final clamped = parsedVal.clamp(min, max);
                  onSubmitted(clamped);
                }
                Navigator.pop(context);
              },
              child: const Text('OK', style: TextStyle(color: AppTheme.primaryAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorProjectProvider);

    // If syncPositionToAll was disabled programmatically (e.g. by manual dragging), uncheck the alignment checkbox
    final notifierSync = ref.watch(editorProjectProvider.select((_) => ref.read(editorProjectProvider.notifier).syncPositionToAll));
    if (_applyToAllStates[ToolbarCategory.textAlignment] == true && !notifierSync) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _applyToAllStates[ToolbarCategory.textAlignment] = false;
          });
        }
      });
    }

    ref.listen(editorProjectProvider, (previous, next) {
      if (previous?.selectedLayerId != next.selectedLayerId) {
        if (next.selectedLayerId == null) {
          setState(() => _activeCategory = ToolbarCategory.main);
        } else {
          if (next.textLayers.any((l) => l.id == next.selectedLayerId)) {
            setState(() => _activeCategory = ToolbarCategory.text);
          } else {
            final media = next.mediaLayers.where((m) => m.id == next.selectedLayerId).firstOrNull;
            if (media != null) {
              if (media.isOverlay) {
                setState(() => _activeCategory = ToolbarCategory.overlay);
              } else if (media.type == MediaType.audio) {
                setState(() => _activeCategory = ToolbarCategory.audio);
              } else {
                setState(() => _activeCategory = ToolbarCategory.media);
              }
            }
          }
        }
      }
    });

    final isStyle = _isStyleSubtool(_activeCategory);
    return Container(
      height: isStyle ? 75 : 60,
      color: const Color(0xFF14141E),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isStyle)
            Container(
              height: 20,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 12, top: 4),
              child: _buildApplyToAllSection(),
            ),
          Expanded(
            child: Row(
              children: [
                // Multi-Tier Back Button [ < ]
                if (_activeCategory != ToolbarCategory.main)
                  GestureDetector(
                    onTap: () {
                      if (_activeCategory == ToolbarCategory.textPresets ||
                          _activeCategory == ToolbarCategory.textColor ||
                          _activeCategory == ToolbarCategory.textStroke ||
                          _activeCategory == ToolbarCategory.textGlow ||
                          _activeCategory == ToolbarCategory.textBackground ||
                          _activeCategory == ToolbarCategory.textSize ||
                          _activeCategory == ToolbarCategory.textAlignment) {
                        setState(() => _activeCategory = ToolbarCategory.textStyle);
                      } else if (_activeCategory == ToolbarCategory.textStyle ||
                          _activeCategory == ToolbarCategory.textFont ||
                          _activeCategory == ToolbarCategory.textTemplates ||
                          _activeCategory == ToolbarCategory.textEffects ||
                          _activeCategory == ToolbarCategory.textAnimations ||
                          _activeCategory == ToolbarCategory.textBubbles) {
                        setState(() => _activeCategory = ToolbarCategory.text);
                      } else {
                        ref.read(editorProjectProvider.notifier).selectLayer(null);
                        setState(() => _activeCategory = ToolbarCategory.main);
                      }
                    },
                    child: Container(
                      width: 48,
                      height: double.infinity,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF222232),
                        border: Border(right: BorderSide(color: Colors.white10, width: 1)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                    ),
                  ),

                // Action Items / Sub-menus
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: _buildActiveToolbarItems(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActiveToolbarItems() {
    final project = ref.read(editorProjectProvider);
    
    if (project.isTrimMode) {
      return [
        _buildItem(Icons.check_circle_rounded, 'Done', () {
          ref.read(editorProjectProvider.notifier).setTrimMode(false);
        }, highlight: true),
      ];
    }

    switch (_activeCategory) {
      case ToolbarCategory.main:
        return [
          _buildItem(Icons.text_fields_rounded, 'Text', () {
            setState(() => _activeCategory = ToolbarCategory.text);
          }),
          _buildItem(Icons.audiotrack_rounded, 'Audio', () {
            setState(() => _activeCategory = ToolbarCategory.audio);
          }),
          _buildItem(
            _isAutoLyricsLoading ? Icons.hourglass_top_rounded : Icons.auto_awesome_rounded,
            'Auto Lyrics',
            _runAutoLyrics,
            highlight: _isAutoLyricsLoading,
            activeColor: const Color(0xFFFF9800),
          ),
          _buildItem(Icons.perm_media_rounded, 'Media', () {
            final mainMedia = project.mediaLayers.where((m) => !m.isOverlay && (m.type == MediaType.video || m.type == MediaType.sticker)).firstOrNull;
            if (mainMedia != null) {
              ref.read(editorProjectProvider.notifier).selectLayer(mainMedia.id);
            } else {
              _showMediaPickerSheet(replace: false, isOverlay: false);
            }
          }),
          _buildItem(Icons.layers_outlined, 'Overlay', () {
            final overlayMedia = project.mediaLayers.where((m) => m.isOverlay).firstOrNull;
            if (overlayMedia != null && project.selectedLayerId == null) {
              ref.read(editorProjectProvider.notifier).selectLayer(overlayMedia.id);
            } else {
              _showMediaPickerSheet(replace: false, isOverlay: true);
            }
          }),
          _buildItem(Icons.layers_rounded, 'Layers', widget.onOpenLayersPanel),
          _buildItem(Icons.aspect_ratio_rounded, 'Ratio', widget.onOpenRatioSelector),
        ];

      case ToolbarCategory.text:
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;
        return [
          _buildItem(Icons.add_rounded, 'Add text', () {
            ref.read(editorProjectProvider.notifier).addTextLayer('Enter Text');
            widget.onOpenTextEditor(initialIndex: 0);
          }),
          if (selectedText == null) ...[
            _buildItem(Icons.playlist_add_check_rounded, 'Manual Lyrics', widget.onOpenManualLyrics),
            _buildItem(
              _isAutoLyricsLoading ? Icons.hourglass_top_rounded : Icons.auto_awesome_rounded,
              'Auto Lyrics',
              _runAutoLyrics,
              highlight: _isAutoLyricsLoading,
              activeColor: const Color(0xFFFF9800),
            ),
          ],
          if (selectedText != null) ...[
            _buildItem(Icons.edit_rounded, 'Edit', () => widget.onOpenTextEditor(initialIndex: 0)),
            _buildItem(Icons.style_rounded, 'Style', () {
              setState(() => _activeCategory = ToolbarCategory.textStyle);
            }),
            _buildItem(Icons.font_download_rounded, 'Font', () {
              setState(() => _activeCategory = ToolbarCategory.textFont);
            }),
            _buildItem(Icons.dashboard_customize_rounded, 'Templates', () {
              setState(() => _activeCategory = ToolbarCategory.textTemplates);
            }),
            _buildItem(Icons.auto_fix_high_rounded, 'Effects', () {
              setState(() => _activeCategory = ToolbarCategory.textEffects);
            }),
            _buildItem(Icons.animation_rounded, 'Animations', () {
              setState(() => _activeCategory = ToolbarCategory.textAnimations);
            }),
            _buildItem(Icons.chat_bubble_outline_rounded, 'Bubbles', () {
              setState(() => _activeCategory = ToolbarCategory.textBubbles);
            }),
            _buildItem(Icons.content_cut_rounded, 'Split', () {
              final project = ref.read(editorProjectProvider);
              if (project.selectedLayerId != null) {
                ref.read(editorProjectProvider.notifier).splitTextLayer(project.selectedLayerId!, project.currentPlayheadTime);
              }
            }),
            _buildItem(Icons.delete_outline_rounded, 'Delete', () {
              final project = ref.read(editorProjectProvider);
              if (project.selectedLayerId != null) {
                ref.read(editorProjectProvider.notifier).deleteTextLayer(project.selectedLayerId!);
              }
            }),
            _buildItem(Icons.copy_rounded, 'Duplicate', () {
              final project = ref.read(editorProjectProvider);
              if (project.selectedLayerId != null) {
                final layerIndex = project.textLayers.indexWhere((l) => l.id == project.selectedLayerId);
                if (layerIndex != -1) {
                  final textLayer = project.textLayers[layerIndex];
                  final duplicate = textLayer.copyWith(
                    id: const Uuid().v4(),
                    position: Offset(textLayer.position.dx + 0.04, textLayer.position.dy + 0.04),
                  );
                  ref.read(editorProjectProvider.notifier).addTextLayers([duplicate]);
                }
              }
            }),
          ],
        ];
      case ToolbarCategory.textStyle:
        return [
          _buildItem(Icons.format_align_center_rounded, 'Alignment', () {
            setState(() => _activeCategory = ToolbarCategory.textAlignment);
          }),
          _buildItem(Icons.auto_awesome_motion_rounded, 'Presets', () {
            setState(() => _activeCategory = ToolbarCategory.textPresets);
          }),
          _buildItem(Icons.palette_rounded, 'Text Color', () {
            setState(() => _activeCategory = ToolbarCategory.textColor);
          }),
          _buildItem(Icons.format_size_rounded, 'Size', () {
            setState(() => _activeCategory = ToolbarCategory.textSize);
          }),
          _buildItem(Icons.rotate_right_rounded, 'Rotate', () {
            setState(() => _activeCategory = ToolbarCategory.textRotate);
          }),
          _buildItem(Icons.format_line_spacing_rounded, 'Line Spacing', () {
            setState(() => _activeCategory = ToolbarCategory.textLineSpacing);
          }),
          _buildItem(Icons.space_bar_rounded, 'Letter Spacing', () {
            setState(() => _activeCategory = ToolbarCategory.textLetterSpacing);
          }),
          _buildItem(Icons.border_color_rounded, 'Stroke', () {
            setState(() => _activeCategory = ToolbarCategory.textStroke);
          }),
          _buildItem(Icons.wb_sunny_rounded, 'Glow', () {
            setState(() => _activeCategory = ToolbarCategory.textGlow);
          }),
          _buildItem(Icons.crop_free_rounded, 'Background', () {
            setState(() => _activeCategory = ToolbarCategory.textBackground);
          }),
          _buildItem(Icons.opacity_rounded, 'Opacity', () {
            setState(() => _activeCategory = ToolbarCategory.textOpacity);
          }),
        ];

      case ToolbarCategory.textPresets:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;

        final presets = [
          {'label': 'White / Black', 'fg': Colors.white, 'stroke': Colors.black, 'bg': Colors.transparent},
          {'label': 'Yellow / Black', 'fg': Colors.yellowAccent, 'stroke': Colors.black, 'bg': Colors.transparent},
          {'label': 'Red / White', 'fg': Colors.redAccent, 'stroke': Colors.white, 'bg': Colors.transparent},
          {'label': 'Cyan / Blue', 'fg': Colors.cyanAccent, 'stroke': Colors.blueAccent, 'bg': Colors.transparent},
          {'label': 'Gold / Orange', 'fg': const Color(0xFFFFD700), 'stroke': Colors.deepOrange, 'bg': Colors.transparent},
          {'label': 'Hot Pink', 'fg': Colors.pinkAccent, 'stroke': Colors.white, 'bg': Colors.transparent},
          {'label': 'Yellow Badge', 'fg': Colors.black, 'stroke': Colors.transparent, 'bg': Colors.yellowAccent},
        ];

        return presets.map((p) {
          final label = p['label'] as String;
          final fg = p['fg'] as Color;
          final stroke = p['stroke'] as Color;
          final bg = p['bg'] as Color;

          return GestureDetector(
            onTap: () {
              if (selectedText != null) {
                _updateTextLayerStyle(
                  selectedText.copyWith(
                    textColor: fg,
                    strokeColor: stroke == Colors.transparent ? null : stroke,
                    backgroundColor: bg == Colors.transparent ? null : bg,
                  ),
                );
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: bg == Colors.transparent ? const Color(0xFF1A1A24) : bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    shadows: stroke != Colors.transparent
                        ? [Shadow(color: stroke, blurRadius: 4)]
                        : null,
                  ),
                ),
              ),
            ),
          );
        }).toList();

      case ToolbarCategory.textColor:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;

        return [
          // 1. Font Size Control
          GestureDetector(
            onTap: () {
              if (selectedText != null) {
                _showSliderBottomSheet(
                  title: 'Font Size',
                  initialValue: selectedText.fontSize,
                  min: 12.0,
                  max: 80.0,
                  onChanged: (val) {
                    _updateTextLayerStyle(selectedText.copyWith(fontSize: val));
                  },
                );
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF222232),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.6), width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.format_size_rounded, size: 14, color: Colors.cyanAccent),
                  const SizedBox(width: 4),
                  Text(
                    '${selectedText?.fontSize.toInt() ?? 20}px',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // 2. Custom HSV 2D Color Spectrum Palette Picker Button
          GestureDetector(
            onTap: () {
              if (selectedText != null) {
                CustomHsvColorPickerSheet.show(
                  context,
                  initialColor: selectedText.textColor,
                  onColorChanged: (newColor) {
                    _updateTextLayerStyle(
                      selectedText.copyWith(textColor: newColor),
                    );
                  },
                );
              }
            },
            child: Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Colors.red,
                    Colors.yellow,
                    Colors.green,
                    Colors.cyan,
                    Colors.blue,
                    Colors.purple,
                    Colors.red,
                  ],
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 4),
                ],
              ),
              child: const Center(
                child: Icon(Icons.colorize_rounded, size: 15, color: Colors.white),
              ),
            ),
          ),

          // 3. Preset Quick Colors
          ..._presetColors.map((color) {
            final isSelected = selectedText?.textColor == color;
            return GestureDetector(
              onTap: () {
                if (selectedText != null) {
                  _updateTextLayerStyle(selectedText.copyWith(textColor: color));
                }
              },
              child: Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF00E5FF) : Colors.white54,
                    width: isSelected ? 2.5 : 1,
                  ),
                ),
              ),
            );
          }),
        ];

      case ToolbarCategory.textStroke:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;

        final colors = [
          Colors.transparent,
          Colors.black,
          Colors.white,
          Colors.cyanAccent,
          Colors.redAccent,
          Colors.yellowAccent,
          Colors.purpleAccent
        ];

        return [
          GestureDetector(
            onTap: () {
              if (selectedText != null) {
                CustomHsvColorPickerSheet.show(
                  context,
                  initialColor: selectedText.strokeColor ?? Colors.black,
                  onColorChanged: (newColor) {
                    _updateTextLayerStyle(
                      selectedText.copyWith(strokeColor: newColor, strokeWidth: selectedText.strokeWidth > 0 ? selectedText.strokeWidth : 2.0),
                    );
                  },
                );
              }
            },
            child: Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Colors.red,
                    Colors.yellow,
                    Colors.green,
                    Colors.cyan,
                    Colors.blue,
                    Colors.purple,
                    Colors.red,
                  ],
                ),
                border: Border.all(color: Colors.white, width: 1.8),
              ),
              child: const Center(
                child: Icon(Icons.colorize_rounded, size: 14, color: Colors.white),
              ),
            ),
          ),
          ...colors.map((color) {
            final isSelected = selectedText?.strokeColor == color;
            return GestureDetector(
              onTap: () {
                if (selectedText != null) {
                  _updateTextLayerStyle(
                    selectedText.copyWith(
                      strokeColor: color == Colors.transparent ? null : color,
                      strokeWidth: color == Colors.transparent ? 0.0 : (selectedText.strokeWidth > 0 ? selectedText.strokeWidth : 2.0),
                    ),
                  );
                }
              },
              child: Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: color == Colors.transparent ? Colors.grey[800] : color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF00E5FF) : Colors.white54,
                    width: isSelected ? 2.5 : 1,
                  ),
                ),
                child: color == Colors.transparent
                    ? const Icon(Icons.close_rounded, size: 16, color: Colors.white54)
                    : null,
              ),
            );
          }),
        ];

      case ToolbarCategory.textGlow:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;

        final colors = [
          Colors.transparent,
          Colors.cyanAccent,
          const Color(0xFFFFD700),
          Colors.pinkAccent,
          Colors.redAccent,
          Colors.greenAccent,
          Colors.purpleAccent,
          Colors.white,
        ];

        return [
          GestureDetector(
            onTap: () {
              if (selectedText != null) {
                CustomHsvColorPickerSheet.show(
                  context,
                  initialColor: selectedText.strokeColor ?? Colors.cyanAccent,
                  onColorChanged: (newColor) {
                    _updateTextLayerStyle(
                      selectedText.copyWith(strokeColor: newColor, strokeWidth: 4.0),
                    );
                  },
                );
              }
            },
            child: Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Colors.red,
                    Colors.yellow,
                    Colors.green,
                    Colors.cyan,
                    Colors.blue,
                    Colors.purple,
                    Colors.red,
                  ],
                ),
                border: Border.all(color: Colors.white, width: 1.8),
              ),
              child: const Center(
                child: Icon(Icons.colorize_rounded, size: 14, color: Colors.white),
              ),
            ),
          ),
          ...colors.map((color) {
            final isSelected = selectedText?.strokeColor == color;
            return GestureDetector(
              onTap: () {
                if (selectedText != null) {
                  _updateTextLayerStyle(
                    selectedText.copyWith(
                      strokeColor: color == Colors.transparent ? null : color,
                      strokeWidth: color == Colors.transparent ? 0.0 : 4.0,
                    ),
                  );
                }
              },
              child: Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: color == Colors.transparent ? Colors.grey[800] : color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF00E5FF) : Colors.white54,
                    width: isSelected ? 2.5 : 1,
                  ),
                ),
                child: color == Colors.transparent
                    ? const Icon(Icons.close_rounded, size: 16, color: Colors.white54)
                    : null,
              ),
            );
          }),
        ];

      case ToolbarCategory.textBackground:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;

        final colors = [
          Colors.transparent,
          Colors.black87,
          Colors.yellowAccent,
          Colors.white,
          Colors.cyanAccent,
          Colors.redAccent,
          Colors.purpleAccent,
        ];

        return [
          GestureDetector(
            onTap: () {
              if (selectedText != null) {
                CustomHsvColorPickerSheet.show(
                  context,
                  initialColor: selectedText.backgroundColor ?? Colors.black87,
                  onColorChanged: (newColor) {
                    _updateTextLayerStyle(
                      selectedText.copyWith(
                        backgroundColor: newColor,
                        textColor: (newColor.computeLuminance() > 0.5) ? Colors.black : Colors.white,
                      ),
                    );
                  },
                );
              }
            },
            child: Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Colors.red,
                    Colors.yellow,
                    Colors.green,
                    Colors.cyan,
                    Colors.blue,
                    Colors.purple,
                    Colors.red,
                  ],
                ),
                border: Border.all(color: Colors.white, width: 1.8),
              ),
              child: const Center(
                child: Icon(Icons.colorize_rounded, size: 14, color: Colors.white),
              ),
            ),
          ),
          ...colors.map((color) {
            final isSelected = selectedText?.backgroundColor == color;
            return GestureDetector(
              onTap: () {
                if (selectedText != null) {
                  _updateTextLayerStyle(
                    selectedText.copyWith(
                      backgroundColor: color == Colors.transparent ? null : color,
                      textColor: (color == Colors.yellowAccent || color == Colors.white) ? Colors.black : Colors.white,
                    ),
                  );
                }
              },
              child: Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: color == Colors.transparent ? Colors.grey[800] : color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF00E5FF) : Colors.white54,
                    width: isSelected ? 2.5 : 1,
                  ),
                ),
                child: color == Colors.transparent
                    ? const Icon(Icons.close_rounded, size: 16, color: Colors.white54)
                    : null,
              ),
            );
          }),
        ];

      case ToolbarCategory.textFont:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;

        return _fontOptions.map((font) {
          final isSelected = selectedText?.fontFamily == font;
          return GestureDetector(
            onTap: () {
              if (selectedText != null) {
                _updateTextLayerStyle(selectedText.copyWith(fontFamily: font));
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF202030) : const Color(0xFF1A1A24),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFF00E5FF) : Colors.white12,
                  width: isSelected ? 1.5 : 1.0,
                ),
                boxShadow: isSelected
                    ? [const BoxShadow(color: Color(0x3300E5FF), blurRadius: 8, spreadRadius: 1)]
                    : [],
              ),
              child: Center(
                child: () {
                  final baseStyle = TextStyle(color: isSelected ? const Color(0xFF00E5FF) : Colors.white, fontSize: 14);
                  try {
                    return Text(font, style: GoogleFonts.getFont(font, textStyle: baseStyle));
                  } catch (_) {
                    return Text(font, style: baseStyle);
                  }
                }(),
              ),
            ),
          );
        }).toList();

      case ToolbarCategory.textTemplates:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;

        return TextTemplateRegistry.templates.map((def) {
          final isSelected = def.id == 'none'
              ? (selectedText?.animation == TextAnimationType.none && (selectedText?.strokeColor == null || selectedText?.strokeColor == Colors.transparent))
              : (selectedText?.fontFamily == def.fontFamily && selectedText?.animation == def.animation);

          return TextTemplatePreviewTile(
            def: def,
            isSelected: isSelected,
            onTap: () {
              if (selectedText != null) {
                if (def.id == 'none') {
                  _updateTextLayerStyle(
                    selectedText.copyWith(
                      textColor: Colors.white,
                      fontFamily: 'Outfit',
                      clearStroke: true,
                      clearBackground: true,
                      animation: TextAnimationType.none,
                    ),
                  );
                } else {
                  _updateTextLayerStyle(
                    selectedText.copyWith(
                      textColor: def.textColor,
                      strokeColor: def.strokeColor,
                      strokeWidth: def.strokeWidth,
                      clearStroke: def.strokeColor == null,
                      backgroundColor: def.backgroundColor,
                      clearBackground: def.backgroundColor == null,
                      fontFamily: def.fontFamily,
                      animation: def.animation,
                    ),
                  );
                }
              }
            },
          );
        }).toList();

      case ToolbarCategory.textEffects:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;

        return TextEffectRegistry.effects.map((def) {
          final isSelected = def.id == 'none'
              ? (selectedText?.strokeColor == null || selectedText?.strokeColor == Colors.transparent)
              : (selectedText?.strokeColor == def.strokeColor && selectedText?.textColor == def.textColor);

          return TextEffectPreviewTile(
            def: def,
            isSelected: isSelected,
            onTap: () {
              if (selectedText != null) {
                if (def.id == 'none') {
                  _updateTextLayerStyle(
                    selectedText.copyWith(
                      textColor: Colors.white,
                      clearStroke: true,
                      clearBackground: true,
                    ),
                  );
                } else {
                  _updateTextLayerStyle(
                    selectedText.copyWith(
                      textColor: def.textColor,
                      strokeColor: def.strokeColor,
                      strokeWidth: def.strokeWidth,
                      clearStroke: def.strokeColor == null,
                      backgroundColor: def.backgroundColor,
                      clearBackground: def.backgroundColor == null,
                    ),
                  );
                }
              }
            },
          );
        }).toList();

      case ToolbarCategory.textAnimations:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;

        return TextAnimationRegistry.animations.map((def) {
          final isSelected = (selectedText?.animation == def.type);

          return TextAnimationPreviewTile(
            def: def,
            isSelected: isSelected,
            onTap: () {
              if (selectedText != null) {
                _updateTextLayerStyle(
                  selectedText.copyWith(animation: def.type),
                );
              }
            },
            onAdjustTap: () {
              if (selectedText != null) {
                _showSliderBottomSheet(
                  title: '${def.name} Duration',
                  initialValue: selectedText.animationDuration,
                  min: 0.2,
                  max: 5.0,
                  unit: 's',
                  isInteger: false,
                  onChanged: (val) {
                    _updateTextLayerStyle(
                      selectedText.copyWith(animationDuration: val),
                    );
                  },
                );
              }
            },
          );
        }).toList();

      case ToolbarCategory.textBubbles:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;

        return TextBubbleRegistry.bubbles.map((def) {
          final isSelected = (selectedText?.bubbleStyle == def.id) || 
                             (def.id == 'none' && (selectedText?.bubbleStyle == null || selectedText?.bubbleStyle == 'none'));

          return TextBubblePreviewTile(
            def: def,
            isSelected: isSelected,
            onTap: () {
              if (selectedText != null) {
                if (def.id == 'none') {
                  _updateTextLayerStyle(
                    selectedText.copyWith(
                      clearBubble: true,
                      clearBackground: true,
                      clearBoxSize: true,
                      textColor: Colors.white,
                    ),
                  );
                } else {
                  _updateTextLayerStyle(
                    selectedText.copyWith(
                      bubbleStyle: def.id,
                      clearBoxSize: true,
                      clearStroke: true,
                      textColor: def.defaultTextColor,
                      backgroundColor: def.defaultBgColor,
                    ),
                  );
                }
              }
            },
          );
        }).toList();

      case ToolbarCategory.textAlignment:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;

        return [
          _buildItem(
            Icons.format_align_left_rounded,
            'Text L',
            () {
              if (selectedText != null) {
                _updateTextLayerStyle(selectedText.copyWith(textAlign: TextAlign.left));
              }
            },
            highlight: selectedText?.textAlign == TextAlign.left,
          ),
          _buildItem(
            Icons.format_align_center_rounded,
            'Text C',
            () {
              if (selectedText != null) {
                _updateTextLayerStyle(selectedText.copyWith(textAlign: TextAlign.center));
              }
            },
            highlight: selectedText?.textAlign == TextAlign.center,
          ),
          _buildItem(
            Icons.format_align_right_rounded,
            'Text R',
            () {
              if (selectedText != null) {
                _updateTextLayerStyle(selectedText.copyWith(textAlign: TextAlign.right));
              }
            },
            highlight: selectedText?.textAlign == TextAlign.right,
          ),
          _buildItem(
            Icons.align_horizontal_left_rounded,
            'Pos L',
            () {
              if (selectedText != null) {
                _updateTextLayerStyle(selectedText.copyWith(position: Offset(0.15, selectedText.position.dy)));
              }
            },
          ),
          _buildItem(
            Icons.align_horizontal_center_rounded,
            'Pos C',
            () {
              if (selectedText != null) {
                _updateTextLayerStyle(selectedText.copyWith(position: Offset(0.5, selectedText.position.dy)));
              }
            },
          ),
          _buildItem(
            Icons.align_horizontal_right_rounded,
            'Pos R',
            () {
              if (selectedText != null) {
                _updateTextLayerStyle(selectedText.copyWith(position: Offset(0.85, selectedText.position.dy)));
              }
            },
          ),
          _buildItem(
            Icons.align_vertical_top_rounded,
            'Pos Top',
            () {
              if (selectedText != null) {
                _updateTextLayerStyle(selectedText.copyWith(position: Offset(selectedText.position.dx, 0.15)));
              }
            },
          ),
          _buildItem(
            Icons.align_vertical_center_rounded,
            'Pos Mid',
            () {
              if (selectedText != null) {
                _updateTextLayerStyle(selectedText.copyWith(position: Offset(selectedText.position.dx, 0.5)));
              }
            },
          ),
          _buildItem(
            Icons.align_vertical_bottom_rounded,
            'Pos Bot',
            () {
              if (selectedText != null) {
                _updateTextLayerStyle(selectedText.copyWith(position: Offset(selectedText.position.dx, 0.8)));
              }
            },
          ),
          _buildItem(
            Icons.open_with_rounded,
            'Manual Drag',
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Drag text freely on screen to set manual position.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ];

      case ToolbarCategory.textSize:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;
        if (selectedText == null) return [];
        return [
          const SizedBox(width: 8),
          const Icon(Icons.format_size_rounded, size: 16, color: Colors.white54),
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(
                activeTrackColor: AppTheme.primaryAccent,
                inactiveTrackColor: Colors.white24,
                thumbColor: AppTheme.primaryAccent,
                trackHeight: 3.0,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
              ),
              child: Slider(
                value: selectedText.fontSize.clamp(10.0, 150.0),
                min: 10.0,
                max: 150.0,
                onChanged: (val) {
                  _updateTextLayerStyle(selectedText.copyWith(fontSize: val));
                },
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              _showNumericInputDialog(
                title: 'Set Text Size (px)',
                currentValue: selectedText.fontSize,
                min: 10.0,
                max: 150.0,
                onSubmitted: (val) {
                  _updateTextLayerStyle(selectedText.copyWith(fontSize: val));
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${selectedText.fontSize.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} px',
                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ];

      case ToolbarCategory.textRotate:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;
        if (selectedText == null) return [];
        double currentDeg = (selectedText.rotation * 180 / pi) % 360;
        if (currentDeg > 180) currentDeg -= 360;
        if (currentDeg < -180) currentDeg += 360;
        return [
          const SizedBox(width: 8),
          const Icon(Icons.rotate_right_rounded, size: 16, color: Colors.white54),
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(
                activeTrackColor: AppTheme.primaryAccent,
                inactiveTrackColor: Colors.white24,
                thumbColor: AppTheme.primaryAccent,
                trackHeight: 3.0,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
              ),
              child: Slider(
                value: currentDeg.clamp(-180.0, 180.0),
                min: -180.0,
                max: 180.0,
                onChanged: (val) {
                  _updateTextLayerStyle(selectedText.copyWith(rotation: val * pi / 180.0));
                },
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              _showNumericInputDialog(
                title: 'Set Rotation (degrees)',
                currentValue: currentDeg,
                min: -180.0,
                max: 180.0,
                onSubmitted: (val) {
                  _updateTextLayerStyle(selectedText.copyWith(rotation: val * pi / 180.0));
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${currentDeg.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}°',
                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ];

      case ToolbarCategory.textLineSpacing:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;
        if (selectedText == null) return [];
        return [
          const SizedBox(width: 8),
          const Icon(Icons.format_line_spacing_rounded, size: 16, color: Colors.white54),
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(
                activeTrackColor: AppTheme.primaryAccent,
                inactiveTrackColor: Colors.white24,
                thumbColor: AppTheme.primaryAccent,
                trackHeight: 3.0,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
              ),
              child: Slider(
                value: selectedText.lineSpacing.clamp(0.8, 3.0),
                min: 0.8,
                max: 3.0,
                onChanged: (val) {
                  _updateTextLayerStyle(selectedText.copyWith(lineSpacing: val));
                },
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              _showNumericInputDialog(
                title: 'Set Line Spacing',
                currentValue: selectedText.lineSpacing,
                min: 0.8,
                max: 3.0,
                onSubmitted: (val) {
                  _updateTextLayerStyle(selectedText.copyWith(lineSpacing: val));
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${selectedText.lineSpacing.toStringAsFixed(1)}x',
                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ];

      case ToolbarCategory.textLetterSpacing:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;
        if (selectedText == null) return [];
        return [
          const SizedBox(width: 8),
          const Icon(Icons.space_bar_rounded, size: 16, color: Colors.white54),
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(
                activeTrackColor: AppTheme.primaryAccent,
                inactiveTrackColor: Colors.white24,
                thumbColor: AppTheme.primaryAccent,
                trackHeight: 3.0,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
              ),
              child: Slider(
                value: selectedText.letterSpacing.clamp(-2.0, 20.0),
                min: -2.0,
                max: 20.0,
                onChanged: (val) {
                  _updateTextLayerStyle(selectedText.copyWith(letterSpacing: val));
                },
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              _showNumericInputDialog(
                title: 'Set Letter Spacing (px)',
                currentValue: selectedText.letterSpacing,
                min: -2.0,
                max: 20.0,
                onSubmitted: (val) {
                  _updateTextLayerStyle(selectedText.copyWith(letterSpacing: val));
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${selectedText.letterSpacing.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}px',
                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ];

      case ToolbarCategory.textOpacity:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;
        if (selectedText == null) return [];
        return [
          const SizedBox(width: 8),
          const Icon(Icons.opacity_rounded, size: 16, color: Colors.white54),
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(
                activeTrackColor: AppTheme.primaryAccent,
                inactiveTrackColor: Colors.white24,
                thumbColor: AppTheme.primaryAccent,
                trackHeight: 3.0,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
              ),
              child: Slider(
                value: selectedText.opacity.clamp(0.0, 1.0),
                min: 0.0,
                max: 1.0,
                onChanged: (val) {
                  _updateTextLayerStyle(selectedText.copyWith(opacity: val));
                },
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              _showNumericInputDialog(
                title: 'Set Opacity (%)',
                currentValue: selectedText.opacity * 100,
                min: 0.0,
                max: 100.0,
                onSubmitted: (val) {
                  _updateTextLayerStyle(selectedText.copyWith(opacity: val / 100.0));
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${(selectedText.opacity * 100).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}%',
                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ];

      case ToolbarCategory.media:
      case ToolbarCategory.video:
        final selectedLayer = project.mediaLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;
        final isVideo = selectedLayer?.type == MediaType.video;

        return [
          _buildItem(Icons.add_to_photos_rounded, 'Add Media', () => _showMediaPickerSheet(replace: false, isOverlay: false)),
          _buildItem(Icons.crop_rounded, 'Crop', _openCropDialog),
          _buildItem(Icons.settings_overscan_rounded, 'Trim', () {
            ref.read(editorProjectProvider.notifier).setTrimMode(true);
          }),
          if (isVideo)
            _buildItem(
              _isAutoLyricsLoading ? Icons.hourglass_top_rounded : Icons.auto_awesome_rounded,
              'Auto Lyrics',
              _runAutoLyrics,
              highlight: _isAutoLyricsLoading,
              activeColor: const Color(0xFFFF9800),
            ),
          _buildItem(Icons.content_cut_rounded, 'Split', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId != null) {
              ref.read(editorProjectProvider.notifier).splitMediaLayer(project.selectedLayerId!, project.currentPlayheadTime);
            }
          }),
          _buildItem(Icons.layers_outlined, 'Overlay', () => _showMediaPickerSheet(isOverlay: true, replace: false)),
          if (isVideo)
            _buildItem(Icons.library_music_rounded, 'Extract Audio', _extractAudio),
          if (isVideo)
            _buildItem(
              selectedLayer?.isMuted == true ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              selectedLayer?.isMuted == true ? 'Unmute' : 'Mute',
              () {
                if (selectedLayer != null) {
                  ref.read(editorProjectProvider.notifier).toggleMuteMediaLayer(selectedLayer.id);
                }
              },
              highlight: selectedLayer?.isMuted == true,
              activeColor: Colors.redAccent,
            ),
          if (isVideo)
            _buildItem(
              Icons.tune_rounded,
              'Volume',
              () {
                final project = ref.read(editorProjectProvider);
                if (project.selectedLayerId == null) return;
                final layer = project.mediaLayers.firstWhere((l) => l.id == project.selectedLayerId);
                
                _showSliderBottomSheet(
                  title: 'Volume',
                  initialValue: layer.volume,
                  min: 0.0,
                  max: 1.0,
                  unit: '%',
                  isInteger: false,
                  onChanged: (val) {
                    ref.read(editorProjectProvider.notifier).updateMediaLayerProperties(
                      layer.id, 
                      volume: val,
                      isMuted: val == 0.0,
                    );
                  },
                );
              },
            ),
          _buildItem(Icons.change_circle_outlined, 'Replace', () => _showMediaPickerSheet(replace: true, isOverlay: false)),
          _buildItem(Icons.delete_outline_rounded, 'Delete', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId != null) {
              ref.read(editorProjectProvider.notifier).deleteMediaLayer(project.selectedLayerId!);
            }
          }),
        ];

      case ToolbarCategory.overlay:
        final selectedLayer = project.mediaLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;
        final isVideo = selectedLayer?.type == MediaType.video;

        return [
          _buildItem(Icons.add_to_photos_rounded, 'Add Overlay', () => _showMediaPickerSheet(replace: false, isOverlay: true)),
          _buildItem(Icons.crop_rounded, 'Crop', _openCropDialog),
          if (selectedLayer?.isCropped == true)
            _buildItem(Icons.crop_free_rounded, 'Reset Crop', () {
              if (selectedLayer != null) {
                ref.read(editorProjectProvider.notifier).resetMediaLayerCrop(selectedLayer.id);
              }
            }),
          _buildItem(Icons.settings_overscan_rounded, 'Trim', () {
            ref.read(editorProjectProvider.notifier).setTrimMode(true);
          }),
          _buildItem(Icons.content_cut_rounded, 'Split', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId != null) {
              ref.read(editorProjectProvider.notifier).splitMediaLayer(project.selectedLayerId!, project.currentPlayheadTime);
            }
          }),
          if (isVideo)
            _buildItem(Icons.library_music_rounded, 'Extract Audio', _extractAudio),
          if (isVideo)
            _buildItem(
              selectedLayer?.isMuted == true ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              selectedLayer?.isMuted == true ? 'Unmute' : 'Mute',
              () {
                if (selectedLayer != null) {
                  ref.read(editorProjectProvider.notifier).toggleMuteMediaLayer(selectedLayer.id);
                }
              },
              highlight: selectedLayer?.isMuted == true,
              activeColor: Colors.redAccent,
            ),
          if (isVideo)
            _buildItem(
              Icons.tune_rounded,
              'Volume',
              () {
                final project = ref.read(editorProjectProvider);
                if (project.selectedLayerId == null) return;
                final layer = project.mediaLayers.firstWhere((l) => l.id == project.selectedLayerId);
                
                _showSliderBottomSheet(
                  title: 'Volume',
                  initialValue: layer.volume,
                  min: 0.0,
                  max: 1.0,
                  unit: '%',
                  isInteger: false,
                  onChanged: (val) {
                    ref.read(editorProjectProvider.notifier).updateMediaLayerProperties(
                      layer.id, 
                      volume: val,
                      isMuted: val == 0.0,
                    );
                  },
                );
              },
            ),
          _buildItem(Icons.change_circle_outlined, 'Replace', () => _showMediaPickerSheet(replace: true, isOverlay: true)),
          _buildItem(Icons.delete_outline_rounded, 'Delete', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId != null) {
              ref.read(editorProjectProvider.notifier).deleteMediaLayer(project.selectedLayerId!);
            }
          }),
        ];

      case ToolbarCategory.audio:
        final selectedLayer = project.mediaLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;

        return [
          _buildItem(Icons.audio_file_rounded, 'Add Audio', () => _pickAudio(replace: false)),
          _buildItem(Icons.settings_overscan_rounded, 'Trim', () {
            ref.read(editorProjectProvider.notifier).setTrimMode(true);
          }),
          _buildItem(
            _isAutoLyricsLoading ? Icons.hourglass_top_rounded : Icons.auto_awesome_rounded,
            'Auto Lyrics',
            _runAutoLyrics,
            highlight: _isAutoLyricsLoading,
            activeColor: const Color(0xFFFF9800),
          ),
          _buildItem(Icons.content_cut_rounded, 'Split', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId != null) {
              ref.read(editorProjectProvider.notifier).splitMediaLayer(project.selectedLayerId!, project.currentPlayheadTime);
            }
          }),
          _buildItem(
            selectedLayer?.isMuted == true ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            selectedLayer?.isMuted == true ? 'Unmute' : 'Mute',
            () {
              if (selectedLayer != null) {
                ref.read(editorProjectProvider.notifier).toggleMuteMediaLayer(selectedLayer.id);
              }
            },
            highlight: selectedLayer?.isMuted == true,
            activeColor: Colors.redAccent,
          ),
          _buildItem(
            Icons.tune_rounded,
            'Volume',
            () {
              final project = ref.read(editorProjectProvider);
              if (project.selectedLayerId == null) return;
              final layer = project.mediaLayers.firstWhere((l) => l.id == project.selectedLayerId);
              
              _showSliderBottomSheet(
                title: 'Volume',
                initialValue: layer.volume,
                min: 0.0,
                max: 1.0,
                unit: '%',
                isInteger: false,
                onChanged: (val) {
                  ref.read(editorProjectProvider.notifier).updateMediaLayerProperties(
                    layer.id, 
                    volume: val,
                    isMuted: val == 0.0,
                  );
                },
              );
            },
          ),
          _buildItem(Icons.change_circle_outlined, 'Replace', () => _pickAudio(replace: true)),
          _buildItem(Icons.delete_outline_rounded, 'Delete', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId != null) {
              ref.read(editorProjectProvider.notifier).deleteMediaLayer(project.selectedLayerId!);
            }
          }),
        ];

      default:
        return [];
    }
  }

  Widget _buildItem(IconData icon, String label, VoidCallback onTap, {bool highlight = false, Color? activeColor}) {
    final col = activeColor ?? AppTheme.primaryAccent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: highlight ? col : Colors.white,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: highlight ? col : Colors.white70,
                  fontSize: 10,
                  fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
