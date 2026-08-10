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
import '../services/project_storage_service.dart';

class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key});

  void _openTextEditor(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TextEditingSheetWidget(),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(editorProjectProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () async {
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
              if (context.mounted) Navigator.pop(context);
            } else if (shouldSave == false) {
              if (context.mounted) Navigator.pop(context);
            }
          },
        ),
        title: Text(project.title),
        actions: [
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
                  onOpenTextEditor: () => _openTextEditor(context),
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
              onOpenTextEditor: () => _openTextEditor(context),
              onOpenManualLyrics: () => _openManualLyricsSync(context),
              onOpenLayersPanel: () => _openLayersPanel(context),
              onOpenRatioSelector: () => _openRatioSelector(context),
            ),
          ],
        ),
      ),
    );
  }
}
