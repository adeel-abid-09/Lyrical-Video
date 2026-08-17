import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uuid/uuid.dart';
import '../models/text_layer_model.dart';
import '../state/editor_state_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/editor/horizontal_toolbars.dart';
import '../widgets/editor/interactive_canvas.dart';
import '../widgets/editor/layers_panel.dart';
import '../widgets/editor/manual_lyrics_sheet.dart';
import '../widgets/editor/text_editing_sheet.dart';
import '../widgets/editor/timeline_widget.dart';
import 'aspect_ratio_screen.dart';
import 'export_settings_screen.dart';
import 'main_navigation_screen.dart';
import '../services/project_storage_service.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> with WidgetsBindingObserver {
  bool _isTextEditorOpen = false;
  int _textEditorInitialIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _persistSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _persistSession() async {
    final project = ref.read(editorProjectProvider);
    if (project.mediaLayers.isNotEmpty || project.textLayers.isNotEmpty) {
      await ProjectStorageService.saveProject(project);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('editor_restore_session_id', project.id);
    }
  }

  Future<void> _clearRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('editor_restore_session_id');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached || state == AppLifecycleState.hidden) {
      // Pause playback immediately so background uses 0 CPU/Audio resources
      ref.read(editorProjectProvider.notifier).setPlaying(false);
      _persistSession();
    }
  }

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

  final List<String> _sessionPlacedLyricLayerIds = [];

  Future<void> _handleCancelQueuedLyrics(BuildContext context) async {
    final notifier = ref.read(editorProjectProvider.notifier);
    if (_sessionPlacedLyricLayerIds.isEmpty) {
      notifier.clearQueuedLyrics();
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: Colors.orangeAccent, size: 24),
            SizedBox(width: 8),
            Text('Cancel Lyrics Queue?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'You have placed ${_sessionPlacedLyricLayerIds.length} lyric ${_sessionPlacedLyricLayerIds.length == 1 ? "line" : "lines"} on your timeline.\n\nDo you want to keep the placed lyrics or remove them?',
          style: const TextStyle(color: Colors.white70, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'continue'),
            child: const Text('Continue Placing', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'remove_all'),
            child: const Text('Remove Placed', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, 'keep_placed'),
            child: const Text('Keep Placed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (choice == 'keep_placed') {
      notifier.clearQueuedLyrics();
      _sessionPlacedLyricLayerIds.clear();
    } else if (choice == 'remove_all') {
      for (final id in _sessionPlacedLyricLayerIds) {
        notifier.deleteTextLayer(id);
      }
      notifier.clearQueuedLyrics();
      _sessionPlacedLyricLayerIds.clear();
    }
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
      await ref.read(editorProjectProvider.notifier).saveAsDraft();
      await _clearRestoreSession();
      return true;
    } else if (shouldSave == false) {
      await ref.read(editorProjectProvider.notifier).discardSession();
      await _clearRestoreSession();
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
        resizeToAvoidBottomInset: false,
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
                ref.read(editorProjectProvider.notifier).setPlaying(false);
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
          child: Stack(
            children: [
              // 1. Permanent Full-Height Editor Layout (Canvas + Timeline + Toolbar)
              Column(
                children: [
                  // Constrained Video Preview Viewport
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: InteractiveCanvasWidget(
                        onOpenTextEditor: ({int initialIndex = 0}) => _openTextEditor(initialIndex: initialIndex),
                      ),
                    ),
                  ),

                  // CapCut Style Timeline
                  const SizedBox(
                    height: 160,
                    child: CapCutTimelineWidget(),
                  ),

                  // Multi-Tier Horizontal Toolbar
                  HorizontalToolbarsWidget(
                    onOpenTextEditor: ({int initialIndex = 0}) => _openTextEditor(initialIndex: initialIndex),
                    onOpenManualLyrics: () => _openManualLyricsSync(context),
                    onOpenLayersPanel: () => _openLayersPanel(context),
                    onOpenRatioSelector: () => _openRatioSelector(context),
                  ),
                ],
              ),

              // 2. Floating Text Editor Overlay (Sits directly above keyboard without shrinking canvas)
              if (_isTextEditorOpen)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  child: Material(
                    elevation: 16,
                    color: Colors.transparent,
                    child: TextEditingSheetWidget(
                      initialIndex: _textEditorInitialIndex,
                      onDone: _closeTextEditor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ), // close SafeArea
      floatingActionButton: project.queuedLyrics.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B2A).withOpacity(0.95),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.4), width: 1.2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 16, offset: const Offset(0, 4)),
                  BoxShadow(color: Colors.cyanAccent.withOpacity(0.15), blurRadius: 12),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Paste Next Lyric Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.playlist_add_check_rounded, color: Colors.black, size: 20),
                    label: Text(
                      'Paste Lyric (${project.queuedLyrics.length} left)',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () {
                      final lineText = project.queuedLyrics.first;
                      final notifier = ref.read(editorProjectProvider.notifier);
                      notifier.popQueuedLyric();
                      
                      final startTime = project.currentPlayheadTime;
                      final newLayer = TextLayerModel(
                        id: const Uuid().v4(),
                        text: lineText,
                        startTime: startTime,
                        endTime: (startTime + 3.0).clamp(0.0, project.duration),
                        position: const Offset(0.5, 0.75),
                      );
                      _sessionPlacedLyricLayerIds.add(newLayer.id);
                      notifier.addTextLayers([newLayer]);
                    },
                  ),
                  const SizedBox(width: 8),
                  // 2. Cancel Queue Button
                  InkWell(
                    onTap: () => _handleCancelQueuedLyrics(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.redAccent.withOpacity(0.4), width: 1),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 18),
                    ),
                  ),
                ],
              ),
            ),
    ),
  );
}
}

