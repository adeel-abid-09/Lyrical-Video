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
    _tabController = TabController(length: 6, vsync: this, initialIndex: widget.initialIndex);
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
      height: MediaQuery.of(context).size.height * 0.55,
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF18181C), // Darker background matching screenshot
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // TextField Area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C34),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            autofocus: true,
                            onChanged: (_) => _saveText(),
                            cursorColor: const Color(0xFF00E5FF),
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            decoration: const InputDecoration(
                              hintText: 'Enter text',
                              hintStyle: TextStyle(color: Colors.white38, fontSize: 16),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.open_in_full_rounded, color: Colors.white70, size: 20),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.subtitles_outlined, color: Colors.white70, size: 26),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Tab Bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: const Color(0xFF00E5FF),
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tabs: const [
              Tab(text: 'Templates'),
              Tab(text: 'Fonts'),
              Tab(text: 'Styles'),
              Tab(text: 'Effects'),
              Tab(text: 'Animations'),
              Tab(text: 'Bubbles'),
            ],
          ),
          
          // Tab Content
          Expanded(
            child: Container(
              color: const Color(0xFF111114), // Slightly darker for content area
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 1: Templates (Placeholder)
                  const Center(child: Text('Templates coming soon', style: TextStyle(color: Colors.white54))),
                  
                  // 2: Fonts
                  ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _fonts.length,
                    itemBuilder: (context, index) {
                      final font = _fonts[index];
                      final isSelected = _fontFamily == font;
                      return ListTile(
                        dense: true,
                        title: Text(font, style: TextStyle(color: isSelected ? const Color(0xFF00E5FF) : Colors.white, fontFamily: font, fontSize: 18)),
                        trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF00E5FF), size: 20) : null,
                        onTap: () {
                          setState(() => _fontFamily = font);
                          _saveText();
                        },
                      );
                    },
                  ),
                  
                  // 3: Styles
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Text Color', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildColorPalette(_selectedColor, (c) { setState(() => _selectedColor = c); _saveText(); }),
                        const SizedBox(height: 20),
                        
                        const Text('Stroke Color', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildColorPalette(_selectedStrokeColor, (c) { setState(() => _selectedStrokeColor = c); _saveText(); }),
                        const SizedBox(height: 20),
                        
                        const Text('Background Color', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildColorPalette(_selectedBackgroundColor, (c) { setState(() => _selectedBackgroundColor = c); _saveText(); }),
                        const SizedBox(height: 20),
                        
                        Row(
                          children: [
                            const Text('Size', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Slider(
                                value: _fontSize,
                                min: 10, max: 100,
                                activeColor: const Color(0xFF00E5FF),
                                inactiveColor: Colors.white24,
                                onChanged: (val) { setState(() => _fontSize = val); _saveText(); },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // 4: Effects
                  const Center(child: Text('Effects coming soon', style: TextStyle(color: Colors.white54))),
                  // 5: Animations
                  const Center(child: Text('Animations coming soon', style: TextStyle(color: Colors.white54))),
                  // 6: Bubbles
                  const Center(child: Text('Bubbles coming soon', style: TextStyle(color: Colors.white54))),
                ],
              ),
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
