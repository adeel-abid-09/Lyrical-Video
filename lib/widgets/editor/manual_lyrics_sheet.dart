import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/editor_state_notifier.dart';
import '../../theme/app_theme.dart';

class ManualLyricsSheetWidget extends ConsumerStatefulWidget {
  const ManualLyricsSheetWidget({super.key});

  @override
  ConsumerState<ManualLyricsSheetWidget> createState() => _ManualLyricsSheetWidgetState();
}

class _ManualLyricsSheetWidgetState extends ConsumerState<ManualLyricsSheetWidget> {
  final TextEditingController _lyricsController = TextEditingController();
  List<String> _lines = [];

  void _parseLines() {
    final text = _lyricsController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();
      });
    }
  }

  void _addSingleLineToTimeline(String lineText) {
    final project = ref.read(editorProjectProvider);
    final notifier = ref.read(editorProjectProvider.notifier);
    final startTime = project.currentPlayheadTime;
    final endTime = (startTime + 3.5).clamp(0.0, project.duration);

    notifier.addTextLayer(lineText, position: const Offset(0.5, 0.75));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added lyric line at ${startTime.toStringAsFixed(1)}s!')),
    );
  }

  @override
  void dispose() {
    _lyricsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorProjectProvider);

    return Container(
      height: 480,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Manual Lyrics Import & Sync',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_lines.isEmpty) ...[
            const Text(
              'Paste or type song lyrics (one line per row):',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _lyricsController,
                maxLines: null,
                expands: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Paste song lyrics here...\nLine 1\nLine 2\nLine 3',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF28283C),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
                icon: const Icon(Icons.playlist_add_rounded, color: Colors.white),
                label: const Text('Parse Lyrics Lines', style: TextStyle(color: Colors.white, fontSize: 16)),
                onPressed: _parseLines,
              ),
            ),
          ] else ...[
            Text(
              'Current Playhead: ${project.currentPlayheadTime.toStringAsFixed(1)}s',
              style: const TextStyle(color: AppTheme.primaryAccent, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _lines.length,
                itemBuilder: (context, index) {
                  final line = _lines[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF28283C),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      title: Text(line, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_alarm_rounded, color: AppTheme.primaryAccent),
                        onPressed: () => _addSingleLineToTimeline(line),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _lines = []),
              child: const Text('Edit Lyrics List', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ],
      ),
    );
  }
}
