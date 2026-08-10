import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/editor_state_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/editor/horizontal_toolbars.dart';
import '../widgets/editor/interactive_canvas.dart';
import '../widgets/editor/layers_panel.dart';
import '../widgets/editor/manual_lyrics_sheet.dart';
import '../widgets/editor/text_editing_sheet.dart';
import '../widgets/editor/timeline_widget.dart';
import 'aspect_ratio_screen.dart';
import 'export_screen.dart';
import 'main_navigation_screen.dart';
import '../services/project_storage_service.dart';

class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key});

  void _openTextEditor(BuildContext context, {int initialIndex = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TextEditingSheetWidget(initialIndex: initialIndex),
    );
  }

  void _openManualLyricsSync(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ManualLyricsSheetWidget(),
    );
  }

  void _openLayersPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const LayersPanelWidget(),
    );
  }

  void _openRatioSelector(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AspectRatioScreen()),
    );
  }

  Future<bool> _onWillPop(BuildContext context, WidgetRef ref) async {
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Save Draft?', style: TextStyle(color: Colors.white)),
        content: const Text('Do you want to save this project as a draft?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Discard', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save as Draft', style: TextStyle(color: AppTheme.primaryAccent)),
          ),
        ],
      ),
    );

    if (shouldSave == true) {
      await ProjectStorageService.saveProject(ref.read(editorProjectProvider));
      return true;
    } else if (shouldSave == false) {
      return true;
    }
    return false; // Cancel
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(editorProjectProvider);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop(context, ref);
        if (shouldPop && context.mounted) {
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
            );
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              final shouldPop = await _onWillPop(context, ref);
              if (shouldPop && context.mounted) {
                if (Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                  );
                }
              }
            },
          ),
        title: Text(project.title, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            color: ref.read(editorProjectProvider.notifier).canUndo ? Colors.white : Colors.white24,
            onPressed: () {
              ref.read(editorProjectProvider.notifier).undo();
            },
          ),
          IconButton(
            icon: const Icon(Icons.redo_rounded),
            color: ref.read(editorProjectProvider.notifier).canRedo ? Colors.white : Colors.white24,
            onPressed: () {
              ref.read(editorProjectProvider.notifier).redo();
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.file_upload_rounded, color: Colors.white, size: 18),
              label: const Text('Export', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExportScreen()),
                );
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Constrained Video Preview Viewport (Takes ~48% screen height so timeline & toolbars are clearly visible)
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: InteractiveCanvasWidget(
                  onOpenTextEditor: ({int initialIndex = 0}) => _openTextEditor(context, initialIndex: initialIndex),
                ),
              ),
            ),

            // 2. CapCut Style Timeline
            const SizedBox(
              height: 160,
              child: CapCutTimelineWidget(),
            ),

            // 3. Multi-Tier Horizontal Toolbar
            HorizontalToolbarsWidget(
              onOpenTextEditor: ({int initialIndex = 0}) => _openTextEditor(context, initialIndex: initialIndex),
              onOpenManualLyrics: () => _openManualLyricsSync(context),
              onOpenLayersPanel: () => _openLayersPanel(context),
              onOpenRatioSelector: () => _openRatioSelector(context),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
