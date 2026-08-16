import 'package:flutter/material.dart';
import '../../services/lyrics_service.dart';
import '../../theme/app_theme.dart';

class OnlineLyricsDialog extends StatefulWidget {
  const OnlineLyricsDialog({super.key});

  @override
  State<OnlineLyricsDialog> createState() => _OnlineLyricsDialogState();
}

class _OnlineLyricsDialogState extends State<OnlineLyricsDialog> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

  // Line selection stage
  bool _isInLineSelectionStage = false;
  String _selectedSongTitle = '';
  String _selectedSongArtist = '';
  List<String> _allLines = [];
  final Set<int> _selectedLineIndices = {};

  Future<void> _searchLyrics() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults.clear();
      _isInLineSelectionStage = false;
    });

    try {
      final results = await LyricsService.searchSongs(query);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to search lyrics: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _openSongLines(Map<String, dynamic> song) {
    final syncedLyrics = song['syncedLyrics'] as String?;
    final plainLyrics = song['plainLyrics'] as String?;

    List<String> lines = [];
    if (syncedLyrics != null && syncedLyrics.trim().isNotEmpty) {
      final segments = LyricsService.parseLrc(syncedLyrics, const Duration(minutes: 10));
      lines = segments.map((s) => s.text.trim()).where((t) => t.isNotEmpty).toList();
    } else if (plainLyrics != null && plainLyrics.trim().isNotEmpty) {
      lines = plainLyrics.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    }

    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No lyrics content available for this song.')),
      );
      return;
    }

    setState(() {
      _allLines = lines;
      _selectedSongTitle = song['name'] ?? 'Unknown Track';
      _selectedSongArtist = song['artistName'] ?? 'Unknown Artist';
      _selectedLineIndices.clear();
      // Select all by default
      _selectedLineIndices.addAll(List.generate(lines.length, (i) => i));
      _isInLineSelectionStage = true;
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedLineIndices.length == _allLines.length) {
        _selectedLineIndices.clear();
      } else {
        _selectedLineIndices.clear();
        _selectedLineIndices.addAll(List.generate(_allLines.length, (i) => i));
      }
    });
  }

  void _importSelectedLines() {
    final selectedLines = _selectedLineIndices
        .toList()
        ..sort();
    final result = selectedLines.map((idx) => _allLines[idx]).toList();

    if (result.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 lyric line to import.')),
      );
      return;
    }

    Navigator.pop(context, result);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF14141E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
          maxWidth: 420,
        ),
        padding: const EdgeInsets.all(20),
        child: _isInLineSelectionStage ? _buildLineSelectionView() : _buildSearchView(),
      ),
    );
  }

  Widget _buildSearchView() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Search Online Lyrics',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white60),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter song name (e.g. Chand baliyan)',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF222232),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search_rounded, color: AppTheme.primaryAccent),
              onPressed: _searchLyrics,
            ),
          ),
          onSubmitted: (_) => _searchLyrics(),
        ),
        const SizedBox(height: 14),
        if (_isSearching)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryAccent),
            ),
          )
        else if (_searchResults.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final song = _searchResults[index];
                final title = song['name'] ?? 'Unknown Track';
                final artist = song['artistName'] ?? 'Unknown Artist';
                final album = song['albumName'] ?? 'Unknown Album';
                final hasSynced = (song['syncedLyrics'] as String?)?.isNotEmpty ?? false;
                
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                    subtitle: Text('$artist • $album', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                    trailing: ElevatedButton(
                      onPressed: () => _openSongLines(song),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: Text(
                        hasSynced ? 'Select Lines' : 'Select Lines',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        else ...[
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.library_music_rounded, color: Colors.white24, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Search for a song to load lyrics.',
                    style: TextStyle(color: Colors.white38),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLineSelectionView() {
    final isAllSelected = _selectedLineIndices.length == _allLines.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Back Button
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              onPressed: () => setState(() => _isInLineSelectionStage = false),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedSongTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _selectedSongArtist,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Select / Deselect All Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF222232),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${_selectedLineIndices.length} of ${_allLines.length} selected',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: _toggleSelectAll,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAllSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                        color: isAllSelected ? Colors.orangeAccent : AppTheme.primaryAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAllSelected ? 'Deselect All' : 'Select All',
                        style: TextStyle(
                          color: isAllSelected ? Colors.orangeAccent : AppTheme.primaryAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
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

        // Line List
        Expanded(
          child: ListView.builder(
            itemCount: _allLines.length,
            itemBuilder: (context, index) {
              final isChecked = _selectedLineIndices.contains(index);
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 2.5),
                decoration: BoxDecoration(
                  color: isChecked ? AppTheme.primaryAccent.withOpacity(0.12) : const Color(0xFF1E1E2C),
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
                    _allLines[index],
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

        // Import Button
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedLineIndices.isEmpty ? Colors.grey[800] : AppTheme.primaryAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.playlist_add_check_rounded, color: Colors.white),
            label: Text(
              'Import ${_selectedLineIndices.length} Selected ${_selectedLineIndices.length == 1 ? "Line" : "Lines"}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            onPressed: _selectedLineIndices.isEmpty ? null : _importSelectedLines,
          ),
        ),
      ],
    );
  }
}
