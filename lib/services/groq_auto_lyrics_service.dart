import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/text_layer_model.dart';

class AutoLyricItem {
  final String text;
  final double startTime;
  final double endTime;

  AutoLyricItem({
    required this.text,
    required this.startTime,
    required this.endTime,
  });
}

class GroqAutoLyricsService {
  static const String _apiUrl = 'https://api.groq.com/openai/v1/audio/transcriptions';
  
  static List<String> get _apiKeys {
    final keys = [
      dotenv.env['GROQ_API_KEY_1'] ?? '',
      dotenv.env['GROQ_API_KEY_2'] ?? '',
      dotenv.env['GROQ_API_KEY_3'] ?? '',
    ].where((k) => k.trim().isNotEmpty && !k.contains('YOUR_API_KEY')).toList();
    if (keys.isEmpty) {
      return [];
    }
    return keys;
  }
  static const String _storageKey = 'groq_api_key';
  
  static int _currentKeyIndex = 0;

  static Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_storageKey);
    if (savedKey != null && savedKey.trim().isNotEmpty && !savedKey.contains('YOUR_API_KEY')) {
      return savedKey.trim();
    }
    final keys = _apiKeys;
    return keys[_currentKeyIndex % keys.length];
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, key.trim());
  }

  /// Sends audio file to Groq API to transcribe and timestamp lyrics
  static Future<List<TextLayerModel>> generateLyricsFromAudio(
    String audioFilePath, {
    double totalDuration = 15.0,
  }) async {
    final apiKey = await getApiKey();
    final file = File(audioFilePath);
    
    if (!await file.exists()) {
      throw Exception('Audio file not found at path: $audioFilePath');
    }

    String finalUploadPath = audioFilePath;
    bool isTempFile = false;

    try {
      // Extract audio from video file to avoid Groq's 25MB limit and format issues
      final ext = audioFilePath.toLowerCase();
      if (ext.endsWith('.mp4') || ext.endsWith('.mov') || ext.endsWith('.mkv') || ext.endsWith('.webm') || ext.endsWith('.3gp') || ext.endsWith('.avi')) {
        try {
          final tempDir = await getTemporaryDirectory();
          final tempPath = '${tempDir.path}/extracted_audio_${const Uuid().v4()}.m4a';
          
          final session = await FFmpegKit.execute('-y -i "$audioFilePath" -vn -acodec aac -b:a 64k "$tempPath"');
          final returnCode = await session.getReturnCode();
          if (returnCode != null && returnCode.isValueSuccess() && await File(tempPath).exists()) {
            final fileLen = await File(tempPath).length();
            if (fileLen > 0) {
              finalUploadPath = tempPath;
              isTempFile = true;
            }
          }
        } catch (err) {
          debugPrint('Audio extraction fallback to original file: $err');
          finalUploadPath = audioFilePath;
        }
      }

      final uri = Uri.parse(_apiUrl);
      
      int maxRetries = _apiKeys.length;
      int attempts = 0;
      
      while (attempts < maxRetries) {
        try {
          final apiKey = await getApiKey();
          var request = http.MultipartRequest('POST', uri);
          request.headers.addAll({
            'Authorization': 'Bearer $apiKey',
          });
          request.fields['model'] = 'whisper-large-v3';
          request.fields['response_format'] = 'verbose_json';
          request.fields['timestamp_granularities[]'] = 'word';
          request.files.add(await http.MultipartFile.fromPath('file', finalUploadPath));

          final streamedResponse = await request.send();
          final response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final wordsArray = data['words'] as List<dynamic>? ?? [];
            final segments = data['segments'] as List<dynamic>? ?? [];
            final fullText = (data['text'] as String? ?? '').trim();

            final List<TextLayerModel> lyricLayers = [];
            final uuid = const Uuid();

            if (wordsArray.isNotEmpty) {
              List<dynamic> currentChunk = [];
              
              for (int i = 0; i < wordsArray.length; i++) {
                currentChunk.add(wordsArray[i]);
                
                if (currentChunk.length >= 4 || i == wordsArray.length - 1) {
                  final chunkStart = (currentChunk.first['start'] as num? ?? 0.0).toDouble();
                  final chunkEnd = (currentChunk.last['end'] as num? ?? chunkStart + 2.0).toDouble();
                  final originalText = currentChunk.map((w) => w['word'].toString().trim()).join(' ');
                  
                  if (originalText.isNotEmpty) {
                    lyricLayers.add(
                      TextLayerModel(
                        id: uuid.v4(),
                        text: originalText,
                        position: const Offset(0.5, 0.75),
                        fontSize: 26.0,
                        textColor: const Color(0xFFFFFFFF),
                        strokeColor: const Color(0xFF000000),
                        strokeWidth: 3.0,
                        startTime: chunkStart,
                        endTime: chunkEnd > totalDuration ? totalDuration : chunkEnd,
                        animation: TextAnimationType.fadeIn,
                        isAutoLyric: true,
                        zIndex: 10 + lyricLayers.length,
                      ),
                    );
                  }
                  currentChunk = [];
                }
              }
            } else if (segments.isNotEmpty) {
              for (int i = 0; i < segments.length; i++) {
                final seg = segments[i];
                final text = (seg['text'] as String? ?? '').trim();
                if (text.isEmpty) continue;

                final start = (seg['start'] as num? ?? 0.0).toDouble();
                final end = (seg['end'] as num? ?? (start + 3.0)).toDouble();
                final segDuration = (end > start) ? (end - start) : 3.0;

                double minEnd = start + 0.5;
                double maxEnd = totalDuration > minEnd ? totalDuration : minEnd;
                final segmentEnd = end.clamp(minEnd, maxEnd);

                final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
                List<String> chunks = [];
                for (int j = 0; j < words.length; j += 3) {
                  chunks.add(words.skip(j).take(3).join(' '));
                }

                if (chunks.isEmpty) continue;

                final chunkDuration = segDuration / chunks.length;
                for (int j = 0; j < chunks.length; j++) {
                  final chunkStart = start + (j * chunkDuration);
                  final chunkEnd = chunkStart + chunkDuration;

                  double minEndChunk = chunkStart + 0.5;
                  double maxEndChunk = totalDuration > minEndChunk ? totalDuration : minEndChunk;
                  final segmentEndChunk = chunkEnd.clamp(minEndChunk, maxEndChunk);

                  lyricLayers.add(
                    TextLayerModel(
                      id: uuid.v4(),
                      text: chunks[j],
                      position: const Offset(0.5, 0.75),
                      fontSize: 26.0,
                      textColor: const Color(0xFFFFFFFF),
                      strokeColor: const Color(0xFF000000),
                      strokeWidth: 3.0,
                      startTime: chunkStart,
                      endTime: segmentEndChunk > totalDuration ? totalDuration : segmentEndChunk,
                      animation: TextAnimationType.fadeIn,
                      isAutoLyric: true,
                      zIndex: 10 + lyricLayers.length,
                    ),
                  );
                }
              }
            } else if (fullText.isNotEmpty) {
              final lines = fullText
                  .split(RegExp(r'(?<=[.?!;\n,])\s+|\n+'))
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();

              if (lines.isNotEmpty) {
                final timePerLine = totalDuration / lines.length;
                for (int k = 0; k < lines.length; k++) {
                  final lStart = k * timePerLine;
                  final words = lines[k].split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
                  List<String> chunks = [];
                  for (int j = 0; j < words.length; j += 3) {
                    chunks.add(words.skip(j).take(3).join(' '));
                  }

                  if (chunks.isEmpty) continue;

                  final chunkDuration = timePerLine / chunks.length;
                  for (int j = 0; j < chunks.length; j++) {
                    final chunkStart = lStart + (j * chunkDuration);
                    final chunkEnd = chunkStart + chunkDuration;

                    double minEndChunk = chunkStart + 0.5;
                    double maxEndChunk = totalDuration > minEndChunk ? totalDuration : minEndChunk;
                    final segmentEndChunk = chunkEnd.clamp(minEndChunk, maxEndChunk);

                    lyricLayers.add(
                      TextLayerModel(
                        id: uuid.v4(),
                        text: chunks[j],
                        position: const Offset(0.5, 0.75),
                        fontSize: 26.0,
                        textColor: const Color(0xFFFFFFFF),
                        strokeColor: const Color(0xFF000000),
                        strokeWidth: 3.0,
                        startTime: chunkStart,
                        endTime: segmentEndChunk > totalDuration ? totalDuration : segmentEndChunk,
                        animation: TextAnimationType.fadeIn,
                        isAutoLyric: true,
                        zIndex: 10 + lyricLayers.length,
                      ),
                    );
                  }
                }
              }
            }

            if (lyricLayers.isNotEmpty) {
              return lyricLayers;
            }
            throw Exception('No spoken lyrics found in this video audio.');
          } else if (response.statusCode == 401 || response.statusCode == 429) {
            // API key expired or rate limited. Fallback to next key.
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(_storageKey);
            } catch (_) {}
            debugPrint('Groq API Key failed with status ${response.statusCode}. Trying next key...');
            _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
            attempts++;
            if (attempts >= maxRetries) {
              throw Exception('All Groq API Keys failed. Last error: ${response.statusCode} - ${response.body}');
            }
          } else {
            throw Exception('Groq API Error: ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          if (attempts >= maxRetries - 1) {
            rethrow;
          }
          attempts++;
          _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
        }
      }
      
      throw Exception('Max retries exceeded while trying to generate lyrics');
    } catch (e) {
      debugPrint('Groq Auto Lyrics Error: $e');
      throw Exception('Failed to generate lyrics from audio: $e');
    } finally {
      if (isTempFile) {
        try {
          File(finalUploadPath).deleteSync();
        } catch (_) {}
      }
    }
  }



  /// Fetches lyrics online using Groq LLaMA 3.3 70B
  static Future<List<String>> fetchLyricsOnline(String songName) async {
    final apiKey = await getApiKey();
    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a lyric fetching assistant. Provide the lyrics for the requested song in its original language (or Roman Urdu/Hindi if applicable). Output ONLY the raw lyrics, line by line. Do not include any intro, outro, title, or conversational text. Exclude empty lines.'
            },
            {
              'role': 'user',
              'content': songName,
            }
          ],
          'temperature': 0.3,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = (data['choices'][0]['message']['content'] as String? ?? '').trim();
        if (content.isNotEmpty) {
          return content
              .split('\n')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty && !s.toLowerCase().startsWith('[')) // Ignore [Chorus] etc.
              .toList();
        }
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch lyrics: $e');
    }
    return [];
  }
}
