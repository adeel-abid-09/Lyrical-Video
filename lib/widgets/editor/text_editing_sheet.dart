import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/editor_state_notifier.dart';
import '../../theme/app_theme.dart';
import 'text_bubble_painter.dart';

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

  void _updateLayerBubble(TextBubbleDefinition def) {
    final project = ref.read(editorProjectProvider);
    final selectedId = project.selectedLayerId;
    if (selectedId != null) {
      final existing = project.textLayers.where((t) => t.id == selectedId).firstOrNull;
      if (existing != null) {
        if (def.id == 'none') {
          ref.read(editorProjectProvider.notifier).updateTextLayer(
            existing.copyWith(
              clearBubble: true,
              clearBackground: true,
              clearBoxSize: true,
              textColor: Colors.white,
            ),
          );
        } else {
          ref.read(editorProjectProvider.notifier).updateTextLayer(
            existing.copyWith(
              bubbleStyle: def.id,
              clearBoxSize: true,
              clearStroke: true,
              textColor: def.defaultTextColor,
              backgroundColor: def.defaultBgColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final project = ref.watch(editorProjectProvider);
    final selectedId = project.selectedLayerId;
    final selectedText = project.textLayers.where((t) => t.id == selectedId).firstOrNull;

    return Container(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12,
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
          const SizedBox(height: 12),
          // Quick Bubble Styles (Horizontal Scrollable)
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: TextBubbleRegistry.bubbles.map((def) {
                final isSelected = (selectedText?.bubbleStyle == def.id) ||
                    (def.id == 'none' && (selectedText?.bubbleStyle == null || selectedText?.bubbleStyle == 'none'));
                return TextBubblePreviewTile(
                  def: def,
                  isSelected: isSelected,
                  onTap: () => _updateLayerBubble(def),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
