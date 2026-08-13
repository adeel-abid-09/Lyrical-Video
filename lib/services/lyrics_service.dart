import 'dart:convert';
import 'dart:io';

class LyricSegment {
  final String text;
  final Duration startTime;
  final Duration endTime;

  LyricSegment({
    required this.text,
    required this.startTime,
    required this.endTime,
  });
}

class LyricsService {
  static Future<List<Map<String, dynamic>>> _executeSearch(String query) async {
    final sanitizedQuery = Uri.encodeComponent(query.trim());
    if (sanitizedQuery.isEmpty) return [];

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final uri = Uri.parse('https://lrclib.net/api/search?q=$sanitizedQuery');
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'LyricalVideoMaker/1.0.0 (contact: support@lyricalvideomaker.com)');
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final List<dynamic> data = jsonDecode(body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (_) {
    } finally {
      client.close();
    }
    return [];
  }

  static Future<List<String>> _getSearchSuggestions(String query) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    try {
      final sanitizedQuery = Uri.encodeComponent(query.trim());
      final uri = Uri.parse('https://suggestqueries.google.com/complete/search?client=firefox&q=$sanitizedQuery');
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'Mozilla/5.0');
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final List<dynamic> data = jsonDecode(body);
        if (data.length > 1 && data[1] is List) {
          final List<dynamic> suggestions = data[1];
          return suggestions.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {
    } finally {
      client.close();
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> searchSongs(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];

    // 1. Try original search first
    List<Map<String, dynamic>> results = await _executeSearch(trimmedQuery);
    if (results.isNotEmpty) return results;

    // 2. Fallback: Query suggestion to correct typos (e.g. tery bina -> tere bina)
    // If the query is long, suggestqueries works better on a shorter phrase (first 4 words)
    final words = trimmedQuery.split(RegExp(r'\s+'));
    String suggestionQuery = trimmedQuery;
    if (words.length > 4) {
      suggestionQuery = words.take(4).join(' ');
    }

    final suggestions = await _getSearchSuggestions(suggestionQuery);
    for (final suggestion in suggestions) {
      // Clean query using suggestion
      String cleanedQuery = suggestion;
      if (words.length > 4) {
        // Re-append the rest of the words to keep search specific if possible
        cleanedQuery = '$suggestion ${words.skip(4).join(' ')}';
      }
      List<Map<String, dynamic>> suggestionResults = await _executeSearch(cleanedQuery);
      if (suggestionResults.isNotEmpty) return suggestionResults;
      
      // Try searching just the corrected suggestion itself as a relaxation
      suggestionResults = await _executeSearch(suggestion);
      if (suggestionResults.isNotEmpty) return suggestionResults;
    }

    // 3. Relaxation Fallback: Try searching just the first 3 words of the original query
    if (words.length > 3) {
      final subsetQuery = words.take(3).join(' ');
      final subsetResults = await _executeSearch(subsetQuery);
      if (subsetResults.isNotEmpty) return subsetResults;
    }

    return [];
  }

  static List<LyricSegment> parseLrc(String lrcString, Duration maxDuration) {
    final List<LyricSegment> segments = [];
    final lines = const LineSplitter().convert(lrcString);
    
    // Matches: [mm:ss.xx] or [mm:ss.xxx] followed by text
    final regex = RegExp(r'^\[(\d+):(\d+)(?:\.(\d+))?\](.*)$');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final match = regex.firstMatch(trimmed);
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        final msStr = match.group(3) ?? '0';
        
        int ms = 0;
        if (msStr.length == 2) {
          ms = int.parse(msStr) * 10;
        } else if (msStr.length == 3) {
          ms = int.parse(msStr);
        } else {
          ms = int.tryParse(msStr) ?? 0;
        }

        final startTime = Duration(minutes: min, seconds: sec, milliseconds: ms);
        final text = match.group(4)!.trim();

        // Filter out headers like [ar: Artist], [ti: Title], etc.
        if (text.isNotEmpty && !text.startsWith('[') && !text.endsWith(']')) {
          segments.add(LyricSegment(
            text: text,
            startTime: startTime,
            endTime: startTime + const Duration(seconds: 4),
          ));
        }
      }
    }

    // Sort to ensure chronological order before calculation
    segments.sort((a, b) => a.startTime.compareTo(b.startTime));

    // Post-process to adjust endTimes to startTimes of next lines
    for (int i = 0; i < segments.length; i++) {
      final current = segments[i];
      Duration end = maxDuration;
      if (i < segments.length - 1) {
        end = segments[i + 1].startTime;
      }
      
      // Limit line linger duration (max 8 seconds per subtitle block)
      final durationLimit = current.startTime + const Duration(seconds: 8);
      if (end > durationLimit) {
        end = durationLimit;
      }

      segments[i] = LyricSegment(
        text: current.text,
        startTime: current.startTime,
        endTime: end.clamp(Duration.zero, maxDuration),
      );
    }

    return segments;
  }
}

extension DurationClamp on Duration {
  Duration clamp(Duration min, Duration max) {
    if (this < min) return min;
    if (this > max) return max;
    return this;
  }
}
