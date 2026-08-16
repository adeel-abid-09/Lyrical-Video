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
  
  bool _isInLineSelectionStage = false;
  List<String> _parsedLines = [];
  final Set<int> _selectedLineIndices = {};

  void _proceedToLineSelection() {
    final text = _lyricsController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste or type lyrics first.')),
      );
      return;
    }

    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid lyric lines found.')),
      );
      return;
    }

    setState(() {
      _parsedLines = lines;
      _selectedLineIndices.clear();
      _selectedLineIndices.addAll(List.generate(lines.length, (i) => i));
      _isInLineSelectionStage = true;
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedLineIndices.length == _parsedLines.length) {
        _selectedLineIndices.clear();
      } else {
        _selectedLineIndices.clear();
        _selectedLineIndices.addAll(List.generate(_parsedLines.length, (i) => i));
      }
    });
  }

  void _queueLyrics() {
    final selectedLines = _selectedLineIndices
        .toList()
        ..sort();
    final result = selectedLines.map((idx) => _parsedLines[idx]).toList();

    if (result.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 line to queue.')),
      );
      return;
    }

    ref.read(editorProjectProvider.notifier).setQueuedLyrics(result);
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${result.length} lines queued! Tap "Paste Next Lyric" to place them.')),
    );
  }

  @override
  void dispose() {
    _lyricsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 520,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: _isInLineSelectionStage ? _buildLineSelectionView() : _buildInputView(),
    );
  }

  Widget _buildInputView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Manual Lyrics',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            label: const Text('Next: Select Lines', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: _proceedToLineSelection,
          ),
        ),
      ],
    );
  }

  Widget _buildLineSelectionView() {
    final isAllSelected = _selectedLineIndices.length == _parsedLines.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  onPressed: () => setState(() => _isInLineSelectionStage = false),
                ),
                const Text(
                  'Select Lines to Queue',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white60),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Select / Deselect All Controls
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF28283C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_selectedLineIndices.length} of ${_parsedLines.length} selected',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              InkWell(
                onTap: _toggleSelectAll,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        isAllSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                        color: isAllSelected ? Colors.orangeAccent : AppTheme.primaryAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAllSelected ? 'Deselect All' : 'Select All',
                        style: TextStyle(
                          color: isAllSelected ? Colors.orangeAccent : AppTheme.primaryAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Checkable Line List
        Expanded(
          child: ListView.builder(
            itemCount: _parsedLines.length,
            itemBuilder: (context, index) {
              final isChecked = _selectedLineIndices.contains(index);
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 2.5),
                decoration: BoxDecoration(
                  color: isChecked ? AppTheme.primaryAccent.withOpacity(0.12) : const Color(0xFF28283C),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isChecked ? AppTheme.primaryAccent.withOpacity(0.5) : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: CheckboxListTile(
                  value: isChecked,
                  activeColor: AppTheme.primaryAccent,
                  checkColor: Colors.white,
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  title: Text(
                    _parsedLines[index],
                    style: TextStyle(
                      color: isChecked ? Colors.white : Colors.white60,
                      fontSize: 13.5,
                      fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedLineIndices.add(index);
                      } else {
                        _selectedLineIndices.remove(index);
                      }
                    });
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Queue Action Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedLineIndices.isEmpty ? Colors.grey[800] : AppTheme.primaryAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.playlist_add_rounded, color: Colors.white),
            label: Text(
              'Queue ${_selectedLineIndices.length} Selected ${_selectedLineIndices.length == 1 ? "Line" : "Lines"}',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: _selectedLineIndices.isEmpty ? null : _queueLyrics,
          ),
        ),
      ],
    );
  }
}
