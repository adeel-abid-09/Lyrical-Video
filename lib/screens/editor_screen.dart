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
import 'export_settings_screen.dart';
import 'main_navigation_screen.dart';
import '../services/project_storage_service.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  bool _isTextEditorOpen = false;
  int _textEditorInitialIndex = 0;

  void _openTextEditor({int initialIndex = 0}) {
    setState(() {
      _textEditorInitialIndex = initialIndex;
      _isTextEditorOpen = true;
    });
  }

  void _closeTextEditor() {
    setState(() {
      _isTextEditorOpen = false;
    });
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

  Future<bool> _onWillPop() async {
    if (_isTextEditorOpen) {
      _closeTextEditor();
      return false; // Don't pop screen, just close editor
    }

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
  Widget build(BuildContext context) {
    final project = ref.watch(editorProjectProvider);

    // If editor is open but no text is selected (user tapped outside), close it.
    ref.listen(editorProjectProvider.select((p) => p.selectedLayerId), (prev, next) {
      if (_isTextEditorOpen && next == null) {
        _closeTextEditor();
      }
    });

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                  (route) => false,
                );
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
                  MaterialPageRoute(builder: (_) => const ExportSettingsScreen()),
                );
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ref.read(editorProjectProvider.notifier).selectLayer(null),
          child: Column(
          children: [
            // 1. Constrained Video Preview Viewport
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: InteractiveCanvasWidget(
                  onOpenTextEditor: ({int initialIndex = 0}) => _openTextEditor(initialIndex: initialIndex),
                ),
              ),
            ),

            if (_isTextEditorOpen)
              TextEditingSheetWidget(
                initialIndex: _textEditorInitialIndex,
                onDone: _closeTextEditor,
              )
            else ...[
              // 2. CapCut Style Timeline
              const SizedBox(
                height: 160,
                child: CapCutTimelineWidget(),
              ),

              // 3. Multi-Tier Horizontal Toolbar
              HorizontalToolbarsWidget(
                onOpenTextEditor: ({int initialIndex = 0}) => _openTextEditor(initialIndex: initialIndex),
                onOpenManualLyrics: () => _openManualLyricsSync(context),
                onOpenLayersPanel: () => _openLayersPanel(context),
                onOpenRatioSelector: () => _openRatioSelector(context),
              ),
            ]
          ],
        ),
        ),
      ), // close SafeArea
      floatingActionButton: project.queuedLyrics.isEmpty ? null : FloatingActionButton.extended(
        onPressed: () {
          final lineText = project.queuedLyrics.first;
          final notifier = ref.read(editorProjectProvider.notifier);
          notifier.popQueuedLyric();
          
          final startTime = project.currentPlayheadTime;
          notifier.addTextLayer(lineText, position: const Offset(0.5, 0.75));
        },
        backgroundColor: Colors.cyanAccent,
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.black),
        label: Text('Drop Lyric (${project.queuedLyrics.length})', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    ),
  );
}
}

