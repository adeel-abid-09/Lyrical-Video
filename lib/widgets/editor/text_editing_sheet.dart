import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/editor_state_notifier.dart';
import '../../theme/app_theme.dart';

class TextEditingSheetWidget extends ConsumerStatefulWidget {
  const TextEditingSheetWidget({super.key});

  @override
  ConsumerState<TextEditingSheetWidget> createState() => _TextEditingSheetWidgetState();
}

class _TextEditingSheetWidgetState extends ConsumerState<TextEditingSheetWidget> {
  late TextEditingController _textController;
  Color _selectedColor = Colors.white;
  double _fontSize = 26.0;
  double _letterSpacing = 1.0;
  String _fontFamily = 'Outfit';

  final List<Color> _presetColors = [
    Colors.white,
    Colors.yellowAccent,
    AppTheme.primaryAccent,
    AppTheme.secondaryAccent,
    Colors.cyanAccent,
    Colors.greenAccent,
    Colors.purpleAccent,
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    final project = ref.read(editorProjectProvider);
    final selectedId = project.selectedLayerId;

    String initialText = '';
    if (selectedId != null) {
      final existing = project.textLayers.where((t) => t.id == selectedId).firstOrNull;
      if (existing != null) {
        initialText = existing.text;
        _selectedColor = existing.textColor;
        _fontSize = existing.fontSize;
        _letterSpacing = existing.letterSpacing;
        _fontFamily = existing.fontFamily;
      }
    }
    _textController = TextEditingController(text: initialText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorProjectProvider);
    final notifier = ref.read(editorProjectProvider.notifier);

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Edit Text Layer',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {
                  final text = _textController.text.trim();
                  if (text.isNotEmpty) {
                    final selectedId = project.selectedLayerId;
                    if (selectedId != null) {
                      final existing = project.textLayers.where((t) => t.id == selectedId).firstOrNull;
                      if (existing != null) {
                        notifier.updateTextLayer(
                          existing.copyWith(
                            text: text,
                            textColor: _selectedColor,
                            fontSize: _fontSize,
                            letterSpacing: _letterSpacing,
                            fontFamily: _fontFamily,
                          ),
                        );
                      } else {
                        notifier.addTextLayer(text);
                      }
                    } else {
                      notifier.addTextLayer(text);
                    }
                  }
                  Navigator.pop(context);
                },
                child: const Text('Done', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Text Field
          TextField(
            controller: _textController,
            autofocus: true,
            style: TextStyle(color: _selectedColor, fontSize: 20),
            decoration: InputDecoration(
              hintText: 'Enter lyric or text here...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF28283C),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Color Palette Row
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _presetColors.length,
              itemBuilder: (context, index) {
                final c = _presetColors[index];
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedColor == c ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Font Size Slider
          Row(
            children: [
              const Text('Font Size', style: TextStyle(color: Colors.white70)),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 14.0,
                  max: 48.0,
                  activeColor: AppTheme.primaryAccent,
                  onChanged: (val) => setState(() => _fontSize = val),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
