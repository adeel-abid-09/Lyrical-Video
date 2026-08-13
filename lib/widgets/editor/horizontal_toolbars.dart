import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/media_layer_model.dart';
import '../../models/text_layer_model.dart';
import '../../services/groq_auto_lyrics_service.dart';
import '../../state/editor_state_notifier.dart';
import '../../theme/app_theme.dart';
import 'online_lyrics_dialog.dart';

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
    'Bebas Neue',
    'Playfair Display',
    'Montserrat',
    'Pacifico',
    'Dancing Script',
    'Lobster',
    'Anton',
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

  Future<void> _pickAudio({bool replace = false}) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
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
    }
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
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14141E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        double currentValue = initialValue;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppTheme.primaryAccent,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: AppTheme.primaryAccent,
                      trackHeight: 4.0,
                    ),
                    child: Slider(
                      value: currentValue,
                      min: min,
                      max: max,
                      onChanged: (val) {
                        setSheetState(() => currentValue = val);
                        onChanged(val);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
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
    final audioLayers = project.mediaLayers.where((m) => m.type == MediaType.audio || m.type == MediaType.video);

    if (audioLayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please import a Video or Audio track first!')),
      );
      return;
    }

    setState(() {
      _isAutoLyricsLoading = true;
    });

    try {
      final lyrics = await GroqAutoLyricsService.generateLyricsFromAudio(
        audioLayers.first.path,
        totalDuration: project.duration,
      );

      ref.read(editorProjectProvider.notifier).addTextLayers(lyrics);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generated ${lyrics.length} English auto-lyric lines!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auto lyrics error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAutoLyricsLoading = false;
        });
      }
    }
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
                leading: const Icon(Icons.mic_rounded, color: Colors.cyanAccent),
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
            child: _activeCategory == ToolbarCategory.main
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _buildActiveToolbarItems(),
                  )
                : SingleChildScrollView(
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
          _buildItem(Icons.video_library_rounded, 'Video', () {
            setState(() => _activeCategory = ToolbarCategory.video);
          }),
          _buildItem(Icons.layers_rounded, 'Layers', widget.onOpenLayersPanel),
          _buildItem(Icons.aspect_ratio_rounded, 'Ratio', widget.onOpenRatioSelector),
        ];

      case ToolbarCategory.text:
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;
        return [
          if (selectedText == null) ...[
            _buildItem(Icons.add_rounded, 'Add text', () {
              ref.read(editorProjectProvider.notifier).addTextLayer('Enter Text');
              widget.onOpenTextEditor(initialIndex: 0);
            }),
            _buildItem(Icons.playlist_add_check_rounded, 'Manual Lyrics', widget.onOpenManualLyrics),
            _buildItem(
              _isAutoLyricsLoading ? Icons.hourglass_top_rounded : Icons.auto_awesome_rounded,
              'Auto Lyrics',
              _runAutoLyrics,
              highlight: true,
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
            _buildItem(Icons.settings_overscan_rounded, 'Trim', () {
              ref.read(editorProjectProvider.notifier).setTrimMode(true);
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
          _buildItem(Icons.border_color_rounded, 'Stroke', () {
            setState(() => _activeCategory = ToolbarCategory.textStroke);
          }),
          _buildItem(Icons.wb_sunny_rounded, 'Glow', () {
            setState(() => _activeCategory = ToolbarCategory.textGlow);
          }),
          _buildItem(Icons.crop_free_rounded, 'Background', () {
            setState(() => _activeCategory = ToolbarCategory.textBackground);
          }),
          _buildItem(Icons.format_size_rounded, 'Size', () {
            final project = ref.read(editorProjectProvider);
            final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;
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
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bg == Colors.transparent ? const Color(0xFF242434) : bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                'Aa',
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  shadows: stroke != Colors.transparent
                      ? [
                          Shadow(color: stroke, blurRadius: 2),
                        ]
                      : null,
                ),
              ),
            ),
          );
        }).toList();

      case ToolbarCategory.textColor:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;

        return _presetColors.map((color) {
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
        }).toList();

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

        return colors.map((color) {
          final isSelected = selectedText?.strokeColor == color;
          return GestureDetector(
            onTap: () {
              if (selectedText != null) {
                ref.read(editorProjectProvider.notifier).updateTextLayer(
                  selectedText.copyWith(strokeColor: color == Colors.transparent ? null : color),
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
        }).toList();

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

        return colors.map((color) {
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
        }).toList();

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

        return colors.map((color) {
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
        }).toList();

      case ToolbarCategory.textFont:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;

        return _fontOptions.map((font) {
          final isSelected = selectedText?.fontFamily == font;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              selected: isSelected,
              label: () {
                final baseStyle = TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 12);
                try {
                  return Text(font, style: GoogleFonts.getFont(font, textStyle: baseStyle));
                } catch (_) {
                  return Text(font, style: baseStyle);
                }
              }(),
              selectedColor: const Color(0xFF00E5FF),
              backgroundColor: const Color(0xFF28283C),
              onSelected: (_) {
                if (selectedText != null) {
                  ref.read(editorProjectProvider.notifier).updateTextLayer(selectedText.copyWith(fontFamily: font));
                }
              },
            ),
          );
        }).toList();

      case ToolbarCategory.textTemplates:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;

        final templates = [
          {'name': 'Glow Neon', 'color': Colors.cyanAccent, 'stroke': Colors.pinkAccent, 'font': 'Bebas Neue', 'bg': Colors.transparent},
          {'name': 'Vlog Yellow', 'color': Colors.black, 'stroke': Colors.transparent, 'font': 'Outfit', 'bg': Colors.yellowAccent},
          {'name': 'Typewriter', 'color': Colors.white, 'stroke': Colors.black, 'font': 'Roboto', 'bg': Colors.transparent},
          {'name': 'Classic Gold', 'color': const Color(0xFFFFD700), 'stroke': Colors.deepOrange, 'font': 'Playfair Display', 'bg': Colors.transparent},
          {'name': 'Retro Red', 'color': Colors.redAccent, 'stroke': Colors.black, 'font': 'Anton', 'bg': Colors.black87},
          {'name': 'Minimalist', 'color': Colors.white, 'stroke': Colors.black, 'font': 'Inter', 'bg': Colors.transparent},
          {'name': 'Pastel Pill', 'color': Colors.deepPurple, 'stroke': Colors.transparent, 'font': 'Pacifico', 'bg': Colors.pinkAccent},
        ];

        return templates.map((tpl) {
          final name = tpl['name'] as String;
          final color = tpl['color'] as Color;
          final stroke = tpl['stroke'] as Color;
          final font = tpl['font'] as String;
          final bg = tpl['bg'] as Color;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ActionChip(
              backgroundColor: const Color(0xFF242434),
              label: () {
                final baseStyle = const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12);
                try {
                  return Text(name, style: GoogleFonts.getFont(font, textStyle: baseStyle));
                } catch (_) {
                  return Text(name, style: baseStyle);
                }
              }(),
              onPressed: () {
                if (selectedText != null) {
                  ref.read(editorProjectProvider.notifier).updateTextLayer(
                    selectedText.copyWith(
                      textColor: color,
                      strokeColor: stroke == Colors.transparent ? null : stroke,
                      fontFamily: font,
                      backgroundColor: bg == Colors.transparent ? null : bg,
                    ),
                  );
                }
              },
            ),
          );
        }).toList();

      case ToolbarCategory.textEffects:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;

        final effects = [
          {'name': 'Neon Cyan', 'color': Colors.cyanAccent, 'stroke': Colors.blueAccent},
          {'name': 'Golden Sun', 'color': const Color(0xFFFFD700), 'stroke': Colors.deepOrangeAccent},
          {'name': 'Cyber Pink', 'color': Colors.pinkAccent, 'stroke': Colors.cyanAccent},
          {'name': 'Fire Red', 'color': Colors.redAccent, 'stroke': Colors.yellowAccent},
          {'name': 'Emerald', 'color': Colors.greenAccent, 'stroke': Colors.black},
          {'name': 'Purple Haze', 'color': Colors.purpleAccent, 'stroke': Colors.white},
          {'name': 'Heavy Black', 'color': Colors.white, 'stroke': Colors.black},
        ];

        return effects.map((eff) {
          final name = eff['name'] as String;
          final color = eff['color'] as Color;
          final stroke = eff['stroke'] as Color;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ActionChip(
              backgroundColor: const Color(0xFF242434),
              label: Text(
                name,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onPressed: () {
                if (selectedText != null) {
                  ref.read(editorProjectProvider.notifier).updateTextLayer(
                    selectedText.copyWith(
                      textColor: color,
                      strokeColor: stroke,
                      strokeWidth: 3.0,
                    ),
                  );
                }
              },
            ),
          );
        }).toList();

      case ToolbarCategory.textAnimations:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;

        final anims = [
          {'label': 'None', 'type': TextAnimationType.none},
          {'label': 'Fade In', 'type': TextAnimationType.fadeIn},
          {'label': 'Pop In', 'type': TextAnimationType.popIn},
          {'label': 'Slide Up', 'type': TextAnimationType.slideUp},
          {'label': 'Typewriter', 'type': TextAnimationType.typewriter},
          {'label': 'Bounce', 'type': TextAnimationType.bounce},
          {'label': 'Glow Pulse', 'type': TextAnimationType.glow},
        ];

        return anims.map((anim) {
          final label = anim['label'] as String;
          final type = anim['type'] as TextAnimationType;
          final isSelected = selectedText?.animation == type;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              selected: isSelected,
              selectedColor: const Color(0xFF00E5FF),
              backgroundColor: const Color(0xFF242434),
              label: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 12)),
              onSelected: (_) {
                if (selectedText != null) {
                  ref.read(editorProjectProvider.notifier).updateTextLayer(
                    selectedText.copyWith(animation: type),
                  );
                }
              },
            ),
          );
        }).toList();

      case ToolbarCategory.textBubbles:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;

        final bubbles = [
          {'name': 'None', 'bg': Colors.transparent, 'fg': Colors.white},
          {'name': 'Dark Pill', 'bg': Colors.black87, 'fg': Colors.white},
          {'name': 'Yellow Badge', 'bg': Colors.yellowAccent, 'fg': Colors.black},
          {'name': 'White Card', 'bg': Colors.white, 'fg': Colors.black},
          {'name': 'Cyan Glass', 'bg': Colors.cyanAccent.withOpacity(0.3), 'fg': Colors.white},
          {'name': 'Red Banner', 'bg': Colors.redAccent, 'fg': Colors.white},
          {'name': 'Purple Bubble', 'bg': Colors.purpleAccent, 'fg': Colors.white},
        ];

        return bubbles.map((bub) {
          final name = bub['name'] as String;
          final bg = bub['bg'] as Color;
          final fg = bub['fg'] as Color;
          final isSelected = selectedText?.backgroundColor == bg;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              selected: isSelected,
              selectedColor: const Color(0xFF00E5FF),
              backgroundColor: const Color(0xFF242434),
              label: Text(name, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 12)),
              onSelected: (_) {
                if (selectedText != null) {
                  ref.read(editorProjectProvider.notifier).updateTextLayer(
                    selectedText.copyWith(
                      backgroundColor: bg == Colors.transparent ? null : bg,
                      textColor: fg,
                    ),
                  );
                }
              },
            ),
          );
        }).toList();

      case ToolbarCategory.video:
        return [
          _buildItem(Icons.delete_outline_rounded, 'Delete', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId != null) {
              ref.read(editorProjectProvider.notifier).deleteMediaLayer(project.selectedLayerId!);
            }
          }),
          _buildItem(Icons.settings_overscan_rounded, 'Trim', () {
            ref.read(editorProjectProvider.notifier).setTrimMode(true);
          }),
          _buildItem(Icons.add_to_photos_rounded, 'Add Video', () => _pickVideo(replace: false)),
          _buildItem(
            _isAutoLyricsLoading ? Icons.hourglass_top_rounded : Icons.auto_awesome_rounded,
            'Auto Lyrics',
            _runAutoLyrics,
          ),
          _buildItem(Icons.picture_in_picture_rounded, 'Overlay', () => _pickVideo(isOverlay: true)),
          _buildItem(Icons.library_music_rounded, 'Extract Audio', _extractAudio),
          _buildItem(Icons.change_circle_outlined, 'Change', () => _pickVideo(replace: true)),
          _buildItem(Icons.content_cut_rounded, 'Split', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId != null) {
              ref.read(editorProjectProvider.notifier).splitMediaLayer(project.selectedLayerId!, project.currentPlayheadTime);
            }
          }),
          _buildItem(
            (() {
              final project = ref.read(editorProjectProvider);
              final layer = project.mediaLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;
              return layer?.isMuted == true ? Icons.volume_off_rounded : Icons.volume_up_rounded;
            })(),
            (() {
              final project = ref.read(editorProjectProvider);
              final layer = project.mediaLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;
              return layer?.isMuted == true ? 'Unmute' : 'Mute';
            })(),
            () {
              final project = ref.read(editorProjectProvider);
              if (project.selectedLayerId == null) return;
              final layer = project.mediaLayers.firstWhere((l) => l.id == project.selectedLayerId);
              ref.read(editorProjectProvider.notifier).updateMediaLayerProperties(
                layer.id,
                isMuted: !layer.isMuted,
              );
            },
          ),
        ];

      case ToolbarCategory.audio:
        return [
          _buildItem(Icons.delete_outline_rounded, 'Delete', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId != null) {
              ref.read(editorProjectProvider.notifier).deleteMediaLayer(project.selectedLayerId!);
            }
          }),
          _buildItem(Icons.settings_overscan_rounded, 'Trim', () {
            ref.read(editorProjectProvider.notifier).setTrimMode(true);
          }),
          _buildItem(Icons.audio_file_rounded, 'Add Audio', () => _pickAudio(replace: false)),
          _buildItem(
            _isAutoLyricsLoading ? Icons.hourglass_top_rounded : Icons.auto_awesome_rounded,
            'Auto Lyrics',
            _runAutoLyrics,
          ),
          _buildItem(Icons.change_circle_outlined, 'Replace', () => _pickAudio(replace: true)),
          _buildItem(Icons.content_cut_rounded, 'Split', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId != null) {
              ref.read(editorProjectProvider.notifier).splitMediaLayer(project.selectedLayerId!, project.currentPlayheadTime);
            }
          }),
          _buildItem(
            (() {
              final project = ref.read(editorProjectProvider);
              final layer = project.mediaLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;
              return layer?.isMuted == true ? Icons.volume_off_rounded : Icons.volume_up_rounded;
            })(),
            (() {
              final project = ref.read(editorProjectProvider);
              final layer = project.mediaLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;
              return layer?.isMuted == true ? 'Unmute' : 'Mute';
            })(),
            () {
              final project = ref.read(editorProjectProvider);
              if (project.selectedLayerId == null) return;
              final layer = project.mediaLayers.firstWhere((l) => l.id == project.selectedLayerId);
              ref.read(editorProjectProvider.notifier).updateMediaLayerProperties(
                layer.id,
                isMuted: !layer.isMuted,
              );
            },
          ),
        ];

      default:
        return [];
    }
  }

  Widget _buildItem(IconData icon, String label, VoidCallback onTap, {bool highlight = false}) {
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
                color: highlight ? AppTheme.primaryAccent : Colors.white,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: highlight ? AppTheme.primaryAccent : Colors.white70,
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
