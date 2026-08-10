import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../models/media_layer_model.dart';
import '../../services/groq_auto_lyrics_service.dart';
import '../../state/editor_state_notifier.dart';
import '../../theme/app_theme.dart';

enum ToolbarCategory { main, text, audio, video, stickers, ratio }

class HorizontalToolbarsWidget extends ConsumerStatefulWidget {
  final VoidCallback onOpenTextEditor;
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
  String? _lastSelectedLayerId;
  bool _isAutoLyricsLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // React to selection changes
    final project = ref.watch(editorProjectProvider);
    if (project.selectedLayerId != _lastSelectedLayerId) {
      _lastSelectedLayerId = project.selectedLayerId;
      if (_lastSelectedLayerId == null) {
        _activeCategory = ToolbarCategory.main;
      } else {
        // Find layer type
        if (project.textLayers.any((l) => l.id == _lastSelectedLayerId)) {
          _activeCategory = ToolbarCategory.text;
        } else {
          final media = project.mediaLayers.where((m) => m.id == _lastSelectedLayerId).firstOrNull;
          if (media != null) {
            if (media.type == MediaType.video) _activeCategory = ToolbarCategory.video;
            if (media.type == MediaType.audio) _activeCategory = ToolbarCategory.audio;
          }
        }
      }
    }
  }

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickVideo() async {
    final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      final media = MediaLayerModel(
        id: const Uuid().v4(),
        path: file.path,
        type: MediaType.video,
        mediaDuration: 15.0,
      );
      ref.read(editorProjectProvider.notifier).addMediaLayer(media);
    }
  }

  Future<void> _pickAudio() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final media = MediaLayerModel(
        id: const Uuid().v4(),
        path: path,
        type: MediaType.audio,
        mediaDuration: 15.0,
      );
      ref.read(editorProjectProvider.notifier).addMediaLayer(media);
    }
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
          SnackBar(content: Text('Generated ${lyrics.length} auto-lyric lines!')),
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
    return Container(
      height: 64,
      color: const Color(0xFF1E1E2C),
      child: Column(
        children: [
          if (_activeCategory != ToolbarCategory.main)
            Container(
              height: 20,
              color: const Color(0xFF14141E),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      ref.read(editorProjectProvider.notifier).selectLayer(null);
                      setState(() => _activeCategory = ToolbarCategory.main);
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.arrow_back_ios_new_rounded, size: 10, color: AppTheme.primaryAccent),
                        SizedBox(width: 4),
                        Text('Main Toolbar', style: TextStyle(color: AppTheme.primaryAccent, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
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
          _buildItem(Icons.text_fields_rounded, 'Text', () {
            setState(() => _activeCategory = ToolbarCategory.text);
          }),
          _buildItem(Icons.audiotrack_rounded, 'Audio', () {
            _pickAudio();
          }),
          _buildItem(Icons.video_library_rounded, 'Video', () {
            _pickVideo();
          }),
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
          _buildItem(Icons.add_circle_outline_rounded, 'Add Text', widget.onOpenTextEditor),
          _buildItem(Icons.style_rounded, 'Style & Fonts', widget.onOpenTextEditor),
          _buildItem(Icons.content_cut_rounded, 'Split', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId != null) {
              final text = project.textLayers.where((t) => t.id == project.selectedLayerId).firstOrNull;
              if (text != null) {
                final splitTime = project.currentPlayheadTime;
                if (splitTime > text.startTime && splitTime < text.endTime) {
                  ref.read(editorProjectProvider.notifier).updateTextLayer(
                    text.copyWith(endTime: splitTime),
                  );
                  ref.read(editorProjectProvider.notifier).addTextLayer(
                    text.text,
                    position: text.position,
                  );
                }
              }
            }
          }),
          _buildItem(Icons.delete_outline_rounded, 'Delete', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId != null) {
              ref.read(editorProjectProvider.notifier).deleteTextLayer(project.selectedLayerId!);
            }
          }),
        ];

      case ToolbarCategory.video:
        return [
          _buildItem(Icons.volume_up_rounded, 'Volume', () {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Volume control coming soon!')));
          }),
          _buildItem(Icons.speed_rounded, 'Speed', () {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Speed control coming soon!')));
          }),
          _buildItem(Icons.content_cut_rounded, 'Split', () {}),
          _buildItem(Icons.delete_outline_rounded, 'Delete', () {
            final project = ref.read(editorProjectProvider);
            if (project.selectedLayerId != null) {
              ref.read(editorProjectProvider.notifier).deleteMediaLayer(project.selectedLayerId!);
            }
          }),
        ];

      case ToolbarCategory.audio:
        return [
          _buildItem(Icons.audio_file_rounded, 'Import Audio', _pickAudio),
          _buildItem(Icons.library_music_rounded, 'Extract Audio', () {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Extract audio from video coming soon!')));
          }),
          _buildItem(Icons.volume_up_rounded, 'Volume', () {}),
          _buildItem(Icons.content_cut_rounded, 'Split', () {}),
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
