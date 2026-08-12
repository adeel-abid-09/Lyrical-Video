import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../models/media_layer_model.dart';
import '../../services/groq_auto_lyrics_service.dart';
import '../../state/editor_state_notifier.dart';
import '../../theme/app_theme.dart';

enum ToolbarCategory { main, text, textStyle, audio, video, stickers, ratio }

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

  static const List<Color> _presetColors = [
    Colors.white,
    Color(0xFFFFD700), // Gold/Yellow
    Color(0xFFFF3B30), // Red
    Color(0xFF34C759), // Green
    Color(0xFF007AFF), // Blue
    Color(0xFFAF52DE), // Purple
    Color(0xFFFF9500), // Orange
    Color(0xFFFF2D55), // Pink
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

  Future<void> _runAutoLyrics() async {
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

  @override
  Widget build(BuildContext context) {
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
          // Fixed Left Back Arrow [ < ] matching CapCut design
          if (_activeCategory != ToolbarCategory.main)
            GestureDetector(
              onTap: () {
                if (_activeCategory == ToolbarCategory.textStyle) {
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

          // Horizontal Scrollable Action Items / Inline Sub-menus
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
    switch (_activeCategory) {
      case ToolbarCategory.main:
        return [
          _buildItem(Icons.text_fields_rounded, 'Add text', () {
            ref.read(editorProjectProvider.notifier).addTextLayer('Enter Text');
            setState(() => _activeCategory = ToolbarCategory.text);
          }),
          _buildItem(Icons.audiotrack_rounded, 'Audio', () => _pickAudio()),
          _buildItem(Icons.video_library_rounded, 'Video', () => _pickVideo()),
          _buildItem(Icons.layers_rounded, 'Layers', widget.onOpenLayersPanel),
          _buildItem(
            _isAutoLyricsLoading ? Icons.hourglass_top_rounded : Icons.auto_awesome_rounded,
            'Auto Lyrics',
            _runAutoLyrics,
            highlight: true,
          ),
          _buildItem(Icons.playlist_add_check_rounded, 'Manual Lyrics', widget.onOpenManualLyrics),
          _buildItem(Icons.aspect_ratio_rounded, 'Ratio', widget.onOpenRatioSelector),
        ];

      case ToolbarCategory.text:
        return [
          _buildItem(Icons.text_fields_rounded, 'Add text', () {
            ref.read(editorProjectProvider.notifier).addTextLayer('Enter Text');
          }),
          _buildItem(Icons.content_cut_rounded, 'Split', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId != null) {
              ref.read(editorProjectProvider.notifier).splitTextLayer(project.selectedLayerId!, project.currentPlayheadTime);
            }
          }),
          _buildItem(Icons.style_rounded, 'Style', () {
            setState(() => _activeCategory = ToolbarCategory.textStyle);
          }),
          _buildItem(Icons.edit_rounded, 'Edit', () => widget.onOpenTextEditor(initialIndex: 0)),
          _buildItem(Icons.font_download_rounded, 'Font', () => widget.onOpenTextEditor(initialIndex: 2)),
          _buildItem(Icons.animation_rounded, 'Animations', () {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Animations coming in next update!')));
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
          _buildItem(
            _isAutoLyricsLoading ? Icons.hourglass_top_rounded : Icons.auto_awesome_rounded,
            'Auto Lyrics',
            _runAutoLyrics,
            highlight: true,
          ),
        ];

      case ToolbarCategory.textStyle:
        final project = ref.watch(editorProjectProvider);
        final selectedText = project.textLayers.where((l) => l.id == project.selectedLayerId).firstOrNull;

        return [
          // Inline Horizontal Color Swatches
          ..._presetColors.map((color) {
            final isSelected = selectedText?.textColor == color;
            return GestureDetector(
              onTap: () {
                if (selectedText != null) {
                  ref.read(editorProjectProvider.notifier).updateTextLayer(selectedText.copyWith(textColor: color));
                }
              },
              child: Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryAccent : Colors.white54,
                    width: isSelected ? 2.5 : 1,
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
          _buildItem(Icons.edit_rounded, 'More Style', () => widget.onOpenTextEditor(initialIndex: 1)),
        ];

      case ToolbarCategory.video:
        return [
          _buildItem(Icons.change_circle_outlined, 'Change', () => _pickVideo(replace: true)),
          _buildItem(
            _isAutoLyricsLoading ? Icons.hourglass_top_rounded : Icons.auto_awesome_rounded,
            'Auto Lyrics',
            _runAutoLyrics,
            highlight: true,
          ),
          _buildItem(Icons.add_to_photos_rounded, 'Add Video', () => _pickVideo(replace: false)),
          _buildItem(Icons.picture_in_picture_rounded, 'Overlay', () => _pickVideo(isOverlay: true)),
          _buildItem(Icons.library_music_rounded, 'Extract Audio', _extractAudio),
          _buildItem(Icons.content_cut_rounded, 'Split', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId != null) {
              ref.read(editorProjectProvider.notifier).splitMediaLayer(project.selectedLayerId!, project.currentPlayheadTime);
            }
          }),
          _buildItem(Icons.arrow_back_ios_rounded, 'Trim Start', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId != null) {
              ref.read(editorProjectProvider.notifier).trimMediaLayerStart(project.selectedLayerId!, project.currentPlayheadTime);
            }
          }),
          _buildItem(Icons.arrow_forward_ios_rounded, 'Trim End', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId != null) {
              ref.read(editorProjectProvider.notifier).trimMediaLayerEnd(project.selectedLayerId!, project.currentPlayheadTime);
            }
          }),
          _buildItem(Icons.volume_up_rounded, 'Volume', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId == null) return;
            final layer = project.mediaLayers.firstWhere((l) => l.id == project.selectedLayerId);
            _showSliderBottomSheet(
              title: 'Volume',
              initialValue: layer.volume,
              min: 0.0,
              max: 2.0,
              onChanged: (val) => ref.read(editorProjectProvider.notifier).updateMediaLayerProperties(layer.id, volume: val),
            );
          }),
          _buildItem(Icons.speed_rounded, 'Speed', () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Speed control coming soon!')));
          }),
          _buildItem(Icons.filter_b_and_w_rounded, 'Filters', () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Filters coming soon!')));
          }),
          _buildItem(Icons.delete_outline_rounded, 'Delete', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId != null) {
              ref.read(editorProjectProvider.notifier).deleteMediaLayer(project.selectedLayerId!);
            }
          }),
        ];

      case ToolbarCategory.audio:
        return [
          _buildItem(Icons.change_circle_outlined, 'Replace', () => _pickAudio(replace: true)),
          _buildItem(
            _isAutoLyricsLoading ? Icons.hourglass_top_rounded : Icons.auto_awesome_rounded,
            'Auto Lyrics',
            _runAutoLyrics,
            highlight: true,
          ),
          _buildItem(Icons.audio_file_rounded, 'Add Audio', () => _pickAudio(replace: false)),
          _buildItem(Icons.content_cut_rounded, 'Split', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId != null) {
              ref.read(editorProjectProvider.notifier).splitMediaLayer(project.selectedLayerId!, project.currentPlayheadTime);
            }
          }),
          _buildItem(Icons.arrow_back_ios_rounded, 'Trim Start', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId != null) {
              ref.read(editorProjectProvider.notifier).trimMediaLayerStart(project.selectedLayerId!, project.currentPlayheadTime);
            }
          }),
          _buildItem(Icons.arrow_forward_ios_rounded, 'Trim End', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId != null) {
              ref.read(editorProjectProvider.notifier).trimMediaLayerEnd(project.selectedLayerId!, project.currentPlayheadTime);
            }
          }),
          _buildItem(Icons.volume_up_rounded, 'Volume', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId == null) return;
            final layer = project.mediaLayers.firstWhere((l) => l.id == project.selectedLayerId);
            _showSliderBottomSheet(
              title: 'Volume',
              initialValue: layer.volume,
              min: 0.0,
              max: 2.0,
              onChanged: (val) => ref.read(editorProjectProvider.notifier).updateMediaLayerProperties(layer.id, volume: val),
            );
          }),
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
