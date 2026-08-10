import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/editor_state_notifier.dart';
import '../../theme/app_theme.dart';

class TextEditingSheetWidget extends ConsumerStatefulWidget {
  final int initialIndex;
  const TextEditingSheetWidget({super.key, this.initialIndex = 0});

  @override
  ConsumerState<TextEditingSheetWidget> createState() => _TextEditingSheetWidgetState();
}

class _TextEditingSheetWidgetState extends ConsumerState<TextEditingSheetWidget> with SingleTickerProviderStateMixin {
  late TextEditingController _textController;
  late TabController _tabController;
  Color _selectedColor = Colors.white;
  Color _selectedStrokeColor = Colors.black;
  Color _selectedBackgroundColor = Colors.transparent;
  double _fontSize = 26.0;
  double _letterSpacing = 1.0;
  String _fontFamily = 'Outfit';
  
  final List<String> _fonts = ['Outfit', 'Inter', 'Roboto', 'Bebas Neue', 'Playfair Display'];

  final List<Color> _presetColors = [
    Colors.transparent,
    Colors.white,
    Colors.black,
    Colors.redAccent,
    Colors.yellowAccent,
    AppTheme.primaryAccent,
    AppTheme.secondaryAccent,
    Colors.cyanAccent,
    Colors.greenAccent,
    Colors.purpleAccent,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialIndex);
    final project = ref.read(editorProjectProvider);
    final selectedId = project.selectedLayerId;

    String initialText = '';
    if (selectedId != null) {
      final existing = project.textLayers.where((t) => t.id == selectedId).firstOrNull;
      if (existing != null) {
        initialText = existing.text;
        _selectedColor = existing.textColor;
        _selectedStrokeColor = existing.strokeColor ?? Colors.black;
        _selectedBackgroundColor = existing.backgroundColor ?? Colors.transparent;
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
    _tabController.dispose();
    super.dispose();
  }
  
  void _saveText() {
    final project = ref.read(editorProjectProvider);
    final notifier = ref.read(editorProjectProvider.notifier);
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
              strokeColor: _selectedStrokeColor == Colors.transparent ? null : _selectedStrokeColor,
              backgroundColor: _selectedBackgroundColor == Colors.transparent ? null : _selectedBackgroundColor,
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
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: EdgeInsets.only(
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 16)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    minimumSize: const Size(60, 32),
                  ),
                  onPressed: () {
                    _saveText();
                    Navigator.pop(context);
                  },
                  child: const Text('Done', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primaryAccent,
            labelColor: AppTheme.primaryAccent,
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: 'Keyboard'),
              Tab(text: 'Style'),
              Tab(text: 'Font'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Keyboard
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _textController,
                    autofocus: widget.initialIndex == 0,
                    maxLines: null,
                    textAlign: TextAlign.center,
                    onChanged: (_) => _saveText(),
                    style: TextStyle(color: _selectedColor, fontSize: _fontSize, fontFamily: _fontFamily),
                    decoration: InputDecoration(
                      hintText: 'Enter text here...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF28283C),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                
                // TAB 2: Style
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Text Color', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      _buildColorPalette(_selectedColor, (c) { setState(() => _selectedColor = c); _saveText(); }),
                      const SizedBox(height: 16),
                      const Text('Stroke Color', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      _buildColorPalette(_selectedStrokeColor, (c) { setState(() => _selectedStrokeColor = c); _saveText(); }),
                      const SizedBox(height: 16),
                      const Text('Background Color', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      _buildColorPalette(_selectedBackgroundColor, (c) { setState(() => _selectedBackgroundColor = c); _saveText(); }),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('Size', style: TextStyle(color: Colors.white70)),
                          Expanded(
                            child: Slider(
                              value: _fontSize,
                              min: 10, max: 80,
                              activeColor: AppTheme.primaryAccent,
                              onChanged: (val) { setState(() => _fontSize = val); _saveText(); },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // TAB 3: Font
                ListView.builder(
                  itemCount: _fonts.length,
                  itemBuilder: (context, index) {
                    final font = _fonts[index];
                    final isSelected = _fontFamily == font;
                    return ListTile(
                      title: Text(font, style: TextStyle(color: isSelected ? AppTheme.primaryAccent : Colors.white, fontFamily: font, fontSize: 18)),
                      trailing: isSelected ? const Icon(Icons.check, color: AppTheme.primaryAccent) : null,
                      onTap: () {
                        setState(() => _fontFamily = font);
                        _saveText();
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildColorPalette(Color selected, ValueChanged<Color> onSelect) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _presetColors.length,
        itemBuilder: (context, index) {
          final c = _presetColors[index];
          return GestureDetector(
            onTap: () => onSelect(c),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected == c ? Colors.white : Colors.white24,
                  width: selected == c ? 3 : 1,
                ),
              ),
              child: c == Colors.transparent ? const Icon(Icons.block, size: 16, color: Colors.white54) : null,
            ),
          );
        },
      ),
    );
  }
}
