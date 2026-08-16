import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

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
  textFont,
  textTemplates,
  textEffects,
  textAnimations,
  textBubbles,
  audio,
  video,
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

  Future<void> _pickVideo({bool replace = false, bool isOverlay = false}) async {
    final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      final project = ref.read(editorProjectProvider);

      if (replace && project.selectedLayerId != null) {
        ref.read(editorProjectProvider.notifier).replaceMediaLayerPath(project.selectedLayerId!, file.path, 15.0);
        return;
      }

      final media = MediaLayerModel(
        id: const Uuid().v4(),
        path: file.path,
        type: MediaType.video,
        mediaDuration: 15.0,
        startTime: isOverlay ? project.currentPlayheadTime : (project.mediaLayers.isEmpty ? 0.0 : project.duration),
        scaleX: isOverlay ? 0.4 : 1.0,
        position: isOverlay ? const Offset(0.7, 0.7) : const Offset(0.5, 0.5),
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
            onAudioPicked: (path) {
              Navigator.pop(context); // Close the bottom sheet
              final project = ref.read(editorProjectProvider);

              if (replace && project.selectedLayerId != null) {
                ref.read(editorProjectProvider.notifier).replaceMediaLayerPath(project.selectedLayerId!, path, 15.0);
                return;
              }

              final media = MediaLayerModel(
                id: const Uuid().v4(),
                path: path,
                type: MediaType.audio,
                startTime: project.currentPlayheadTime,
                mediaDuration: 15.0,
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

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorProjectProvider);

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
              if (media.type == MediaType.video) setState(() => _activeCategory = ToolbarCategory.video);
              if (media.type == MediaType.audio) setState(() => _activeCategory = ToolbarCategory.audio);
            }
          }
        }
      }
    });

    return Container(
      height: 60,
      color: const Color(0xFF14141E),
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
                    _activeCategory == ToolbarCategory.textSize) {
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
                height: 60,
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
          _buildItem(Icons.video_library_rounded, 'Video', () {
            setState(() => _activeCategory = ToolbarCategory.video);
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
          _buildItem(Icons.auto_awesome_motion_rounded, 'Presets', () {
            setState(() => _activeCategory = ToolbarCategory.textPresets);
          }),
          _buildItem(Icons.palette_rounded, 'Text Color', () {
            setState(() => _activeCategory = ToolbarCategory.textColor);
          }),
          _buildItem(Icons.format_size_rounded, 'Size', () {
            final project = ref.read(editorProjectProvider);
            final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;
            if (selectedText != null) {
              _showSliderBottomSheet(
                title: 'Font Size',
                initialValue: selectedText.fontSize,
                min: 10.0,
                max: 150.0,
                unit: 'px',
                isInteger: true,
                onChanged: (val) {
                  ref.read(editorProjectProvider.notifier).updateTextLayer(selectedText.copyWith(fontSize: val));
                },
              );
            }
          }),
          _buildItem(Icons.rotate_right_rounded, 'Rotate', () {
            final project = ref.read(editorProjectProvider);
            final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;
            if (selectedText != null) {
              double currentDeg = (selectedText.rotation * 180 / pi) % 360;
              if (currentDeg > 180) currentDeg -= 360;
              if (currentDeg < -180) currentDeg += 360;

              _showSliderBottomSheet(
                title: 'Rotation',
                initialValue: currentDeg,
                min: -180.0,
                max: 180.0,
                unit: '°',
                isInteger: true,
                onChanged: (deg) {
                  ref.read(editorProjectProvider.notifier).updateTextLayer(
                    selectedText.copyWith(rotation: deg * pi / 180.0),
                  );
                },
              );
            }
          }),
          _buildItem(Icons.format_line_spacing_rounded, 'Line Spacing', () {
            final project = ref.read(editorProjectProvider);
            final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;
            if (selectedText != null) {
              _showSliderBottomSheet(
                title: 'Line Spacing',
                initialValue: selectedText.lineSpacing,
                min: 0.8,
                max: 3.0,
                unit: 'x',
                isInteger: false,
                onChanged: (val) {
                  ref.read(editorProjectProvider.notifier).updateTextLayer(selectedText.copyWith(lineSpacing: val));
                },
              );
            }
          }),
          _buildItem(Icons.space_bar_rounded, 'Letter Spacing', () {
            final project = ref.read(editorProjectProvider);
            final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;
            if (selectedText != null) {
              _showSliderBottomSheet(
                title: 'Letter Spacing',
                initialValue: selectedText.letterSpacing,
                min: -2.0,
                max: 20.0,
                unit: 'px',
                isInteger: false,
                onChanged: (val) {
                  ref.read(editorProjectProvider.notifier).updateTextLayer(selectedText.copyWith(letterSpacing: val));
                },
              );
            }
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
            final project = ref.read(editorProjectProvider);
            final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;
            if (selectedText != null) {
              _showSliderBottomSheet(
                title: 'Opacity',
                initialValue: selectedText.opacity,
                min: 0.0,
                max: 1.0,
                unit: '',
                isInteger: false,
                onChanged: (val) {
                  ref.read(editorProjectProvider.notifier).updateTextLayer(selectedText.copyWith(opacity: val));
                },
              );
            }
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
                ref.read(editorProjectProvider.notifier).updateTextLayer(
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
                    ref.read(editorProjectProvider.notifier).updateTextLayer(selectedText.copyWith(fontSize: val));
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
                    ref.read(editorProjectProvider.notifier).updateTextLayer(
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
                  ref.read(editorProjectProvider.notifier).updateTextLayer(selectedText.copyWith(textColor: color));
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
                    ref.read(editorProjectProvider.notifier).updateTextLayer(
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
                  ref.read(editorProjectProvider.notifier).updateTextLayer(
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
                    ref.read(editorProjectProvider.notifier).updateTextLayer(
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
                  ref.read(editorProjectProvider.notifier).updateTextLayer(
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
                    ref.read(editorProjectProvider.notifier).updateTextLayer(
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
                  ref.read(editorProjectProvider.notifier).updateTextLayer(
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
                ref.read(editorProjectProvider.notifier).updateTextLayer(selectedText.copyWith(fontFamily: font));
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
                  ref.read(editorProjectProvider.notifier).updateTextLayer(
                    selectedText.copyWith(
                      textColor: Colors.white,
                      fontFamily: 'Outfit',
                      clearStroke: true,
                      clearBackground: true,
                      animation: TextAnimationType.none,
                    ),
                  );
                } else {
                  ref.read(editorProjectProvider.notifier).updateTextLayer(
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
                  ref.read(editorProjectProvider.notifier).updateTextLayer(
                    selectedText.copyWith(
                      textColor: Colors.white,
                      clearStroke: true,
                      clearBackground: true,
                    ),
                  );
                } else {
                  ref.read(editorProjectProvider.notifier).updateTextLayer(
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

        final items = <Widget>[];

        // Prominent CapCut-style Duration / Speed controller
        if (selectedText != null && selectedText.animation != TextAnimationType.none) {
          items.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: InkWell(
                onTap: () {
                  _showSliderBottomSheet(
                    title: 'Animation Duration',
                    initialValue: selectedText.animationDuration,
                    min: 0.2,
                    max: 5.0,
                    unit: 's',
                    isInteger: false,
                    onChanged: (val) {
                      ref.read(editorProjectProvider.notifier).updateTextLayer(
                        selectedText.copyWith(animationDuration: val),
                      );
                    },
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryAccent, width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, color: AppTheme.primaryAccent, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${selectedText.animationDuration.toStringAsFixed(1)}s',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        items.addAll(
          TextAnimationRegistry.animations.map((def) {
            final isSelected = (selectedText?.animation == def.type);

            return TextAnimationPreviewTile(
              def: def,
              isSelected: isSelected,
              onTap: () {
                if (selectedText != null) {
                  ref.read(editorProjectProvider.notifier).updateTextLayer(
                    selectedText.copyWith(animation: def.type),
                  );
                }
              },
            );
          }),
        );

        return items;

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
                  ref.read(editorProjectProvider.notifier).updateTextLayer(
                    selectedText.copyWith(
                      clearBubble: true,
                      clearBackground: true,
                      clearBoxSize: true,
                      textColor: Colors.white,
                    ),
                  );
                } else {
                  ref.read(editorProjectProvider.notifier).updateTextLayer(
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

      case ToolbarCategory.video:
        return [
          _buildItem(Icons.add_to_photos_rounded, 'Add Video', () => _pickVideo(replace: false)),
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
          _buildItem(Icons.picture_in_picture_rounded, 'Overlay', () => _pickVideo(isOverlay: true)),
          _buildItem(Icons.library_music_rounded, 'Extract Audio', _extractAudio),
          _buildItem(
            Icons.volume_up_rounded,
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
          _buildItem(Icons.change_circle_outlined, 'Change', () => _pickVideo(replace: true)),
          _buildItem(Icons.delete_outline_rounded, 'Delete', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId != null) {
              ref.read(editorProjectProvider.notifier).deleteMediaLayer(project.selectedLayerId!);
            }
          }),
        ];

      case ToolbarCategory.audio:
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
            Icons.volume_up_rounded,
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
