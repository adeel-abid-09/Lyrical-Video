import 'package:flutter/material.dart';
import '../../services/lyrics_service.dart';

class OnlineLyricsDialog extends StatefulWidget {
  const OnlineLyricsDialog({super.key});

  @override
  State<OnlineLyricsDialog> createState() => _OnlineLyricsDialogState();
}

class _OnlineLyricsDialogState extends State<OnlineLyricsDialog> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

  Future<void> _searchLyrics() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults.clear();
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

  void _importSelectedSongLyrics(Map<String, dynamic> song) {
    final syncedLyrics = song['syncedLyrics'] as String?;
    final plainLyrics = song['plainLyrics'] as String?;

    if (syncedLyrics != null && syncedLyrics.trim().isNotEmpty) {
      // We parse the LRC to strip timestamps and get just the text
      final segments = LyricsService.parseLrc(syncedLyrics, const Duration(minutes: 10));
      if (segments.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to parse lyrics.')),
        );
        return;
      }
      final lines = segments.map((s) => s.text).toList();
      Navigator.pop(context, lines);
    } else if (plainLyrics != null && plainLyrics.trim().isNotEmpty) {
      final lines = plainLyrics.split('\n').where((l) => l.trim().isNotEmpty).toList();
      Navigator.pop(context, lines);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No lyrics content available for this song.')),
      );
    }
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Search Lyrics (LRCLIB)',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter song name (e.g. Chand baliyan)',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF28283C),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded, color: Colors.cyanAccent),
                  onPressed: _searchLyrics,
                ),
              ),
              onSubmitted: (_) => _searchLyrics(),
            ),
            const SizedBox(height: 16),
            if (_isSearching)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Colors.cyanAccent),
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
                    
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                      subtitle: Text('$artist • $album', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                      trailing: ElevatedButton(
                        onPressed: () => _importSelectedSongLyrics(song),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: Text(hasSynced ? 'Import (Synced)' : 'Import (Plain)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
              )
            else ...[
              const Expanded(
                child: Center(
                  child: Text(
                    'Search for a song to load lyrics.',
                    style: TextStyle(color: Colors.white38),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              )
            ]
          ],
        ),
      ),
    );
  }
}
