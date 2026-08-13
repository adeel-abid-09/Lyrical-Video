import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/editor_state_notifier.dart';
import '../../theme/app_theme.dart';

class TextEditingSheetWidget extends ConsumerStatefulWidget {
  final int initialIndex;
  final VoidCallback? onDone;
  const TextEditingSheetWidget({super.key, this.initialIndex = 0, this.onDone});

  @override
  ConsumerState<TextEditingSheetWidget> createState() => _TextEditingSheetWidgetState();
}

class _TextEditingSheetWidgetState extends ConsumerState<TextEditingSheetWidget> {
  late TextEditingController _textController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _focusNode.requestFocus();
    });

    final project = ref.read(editorProjectProvider);
    final selectedId = project.selectedLayerId;

    String initialText = '';
    if (selectedId != null) {
      final existing = project.textLayers.where((t) => t.id == selectedId).firstOrNull;
      if (existing != null) {
        initialText = existing.text;
      }
    }
    _textController = TextEditingController(text: initialText);
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
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
          notifier.updateTextLayer(existing.copyWith(text: text));
        } else {
          notifier.addTextLayer(text);
        }
      } else {
        notifier.addTextLayer(text);
      }
    }
  }

  void _updateLayerField({Color? bgColor, double? borderRadius}) {
    final project = ref.read(editorProjectProvider);
    final selectedId = project.selectedLayerId;
    if (selectedId != null) {
      final existing = project.textLayers.where((t) => t.id == selectedId).firstOrNull;
      if (existing != null) {
        ref.read(editorProjectProvider.notifier).updateTextLayer(
          existing.copyWith(
            backgroundColor: bgColor ?? existing.backgroundColor,
            boxBorderRadius: borderRadius ?? existing.boxBorderRadius,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: bottomInset + 12,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF18181C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'Enter Text',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.check_circle_rounded, color: AppTheme.primaryAccent, size: 28),
                onPressed: () {
                  _saveText();
                  widget.onDone?.call();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C34),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              autofocus: true,
              maxLines: 3,
              minLines: 1,
              onChanged: (_) => _saveText(),
              cursorColor: const Color(0xFF00E5FF),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'Type text here...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 16),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Bubble Styling Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const Text('Bubble Style:', style: TextStyle(color: Colors.white70, fontSize: 14)),
              _buildBubbleColorBtn(Colors.transparent, 'None'),
              _buildBubbleColorBtn(Colors.white, 'White'),
              _buildBubbleColorBtn(Colors.black87, 'Black'),
              _buildBubbleColorBtn(Colors.blueAccent, 'Blue'),
              Container(width: 1, height: 24, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 8)),
              IconButton(
                icon: const Icon(Icons.crop_square_rounded, color: Colors.white),
                onPressed: () => _updateLayerField(borderRadius: 0.0),
                tooltip: 'Square',
              ),
              IconButton(
                icon: const Icon(Icons.rounded_corner_rounded, color: Colors.white),
                onPressed: () => _updateLayerField(borderRadius: 24.0),
                tooltip: 'Rounded',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleColorBtn(Color color, String label) {
    return InkWell(
      onTap: () => _updateLayerField(bgColor: color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white38),
        ),
        alignment: Alignment.center,
        child: color == Colors.transparent ? const Icon(Icons.do_not_disturb, size: 16, color: Colors.white) : null,
      ),
    );
  }
}
