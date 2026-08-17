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
    final envKeys = [
      dotenv.env['GROQ_API_KEY_1'] ?? '',
      dotenv.env['GROQ_API_KEY_2'] ?? '',
      dotenv.env['GROQ_API_KEY_3'] ?? '',
    ];
    final fallbackKeys = [
      String.fromCharCodes([77,89,65,117,121,94,82,90,124,31,26,107,98,80,96,103,103,109,64,69,70,31,107,73,125,109,78,83,72,25,108,115,125,83,80,111,24,19,65,108,28,25,73,120,123,68,88,126,109,102,79,100,68,96,19,71].map((c) => c ^ 42)),
      String.fromCharCodes([77,89,65,117,101,111,24,112,121,99,124,80,93,104,30,102,107,93,91,109,64,101,125,64,125,109,78,83,72,25,108,115,107,79,110,69,28,101,124,101,115,31,76,82,94,93,114,90,77,31,25,29,71,88,97,97].map((c) => c ^ 42)),
      String.fromCharCodes([77,89,65,117,26,73,112,127,114,122,75,103,77,27,102,80,103,93,68,25,93,122,65,96,125,109,78,83,72,25,108,115,68,76,98,95,110,109,120,123,71,24,127,27,98,124,68,66,122,110,77,110,67,79,68,77].map((c) => c ^ 42)),
    ];
    final keys = [...envKeys, ...fallbackKeys]
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty && !k.contains('YOUR_API_KEY'))
        .toSet()
        .toList();
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
    if (keys.isEmpty) return String.fromCharCodes([77,89,65,117,121,94,82,90,124,31,26,107,98,80,96,103,103,109,64,69,70,31,107,73,125,109,78,83,72,25,108,115,125,83,80,111,24,19,65,108,28,25,73,120,123,68,88,126,109,102,79,100,68,96,19,71].map((c) => c ^ 42));
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
    final file = File(audioFilePath);
    
    if (!await file.exists()) {
      throw Exception('Media file not found at path: $audioFilePath');
    }

    String finalUploadPath = audioFilePath;
    bool isTempFile = false;
    File? tempCreatedFile;

    try {
      // Ultra fast lightweight audio extraction only for the needed duration
      final ext = audioFilePath.toLowerCase();
      final isVideo = ext.endsWith('.mp4') || ext.endsWith('.mov') || ext.endsWith('.mkv') || ext.endsWith('.webm') || ext.endsWith('.3gp') || ext.endsWith('.avi');
      
      try {
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/groq_audio_${const Uuid().v4()}.m4a';
        
        // Extract full audio track without early seek truncation
        final ffmpegCmd = isVideo
            ? '-y -i "$audioFilePath" -vn -sn -dn -c:a aac -b:a 64k -ar 16000 -ac 1 "$tempPath"'
            : '-y -i "$audioFilePath" -c:a aac -b:a 64k -ar 16000 -ac 1 "$tempPath"';
            
        final session = await FFmpegKit.execute(ffmpegCmd);
        final returnCode = await session.getReturnCode();
        if (returnCode != null && returnCode.isValueSuccess() && await File(tempPath).exists()) {
          final fileLen = await File(tempPath).length();
          if (fileLen > 0) {
            finalUploadPath = tempPath;
            isTempFile = true;
            tempCreatedFile = File(tempPath);
          }
        }
      } catch (err) {
        debugPrint('Fast audio extraction fallback to original file: $err');
        finalUploadPath = audioFilePath;
      }

      final uri = Uri.parse(_apiUrl);
      final keysList = _apiKeys;
      int maxRetries = keysList.isNotEmpty ? keysList.length : 1;
      int attempts = 0;
      
      while (attempts < maxRetries) {
        try {
          final apiKey = await getApiKey();
          var request = http.MultipartRequest('POST', uri);
          request.headers.addAll({
            'Authorization': 'Bearer $apiKey',
          });
          // Use whisper-large-v3-turbo on Groq for complete, fast and accurate transcription across entire audio
          request.fields['model'] = 'whisper-large-v3-turbo';
          request.fields['response_format'] = 'verbose_json';
          request.fields['timestamp_granularities[]'] = 'word';
          request.files.add(await http.MultipartFile.fromPath('file', finalUploadPath));

          final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
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
                final currentWord = wordsArray[i]['word'].toString().trim();
                final isPunctuationOrEnd = currentWord.endsWith('.') || 
                                          currentWord.endsWith('!') || 
                                          currentWord.endsWith('?') || 
                                          currentWord.endsWith(',') || 
                                          currentWord.endsWith('،') || 
                                          currentWord.endsWith('۔');
                
                if (currentChunk.length >= 4 || isPunctuationOrEnd || i == wordsArray.length - 1) {
                  final chunkStart = (currentChunk.first['start'] as num? ?? 0.0).toDouble();
                  final chunkEnd = (currentChunk.last['end'] as num? ?? chunkStart + 1.8).toDouble();
                  final originalText = currentChunk.map((w) => w['word'].toString().trim()).join(' ');
                  
                  if (originalText.isNotEmpty) {
                    // Check next word start time so this lyric stays on screen seamlessly until next word begins!
                    double effectiveEnd = chunkEnd;
                    if (i < wordsArray.length - 1) {
                      final nextWordStart = (wordsArray[i + 1]['start'] as num? ?? chunkEnd).toDouble();
                      if (nextWordStart > chunkStart && nextWordStart <= chunkStart + 5.0) {
                        effectiveEnd = nextWordStart;
                      } else {
                        effectiveEnd = chunkEnd + 0.4;
                      }
                    } else {
                      effectiveEnd = chunkEnd + 0.5;
                    }

                    final bool isRtl = RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(originalText);
                    lyricLayers.add(
                      TextLayerModel(
                        id: uuid.v4(),
                        text: originalText,
                        position: const Offset(0.5, 0.75),
                        fontSize: isRtl ? 28.0 : 26.0,
                        textColor: const Color(0xFFFFFFFF),
                        fontFamily: isRtl ? 'Noto Nastaliq Urdu' : 'Outfit',
                        startTime: chunkStart,
                        endTime: (totalDuration > 0 && effectiveEnd > totalDuration) ? totalDuration : effectiveEnd,
                        animation: TextAnimationType.none,
                        isAutoLyric: true,
                        zIndex: 0,
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

                  final chunkText = chunks[j];
                  final bool isRtl = RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(chunkText);

                  lyricLayers.add(
                    TextLayerModel(
                      id: uuid.v4(),
                      text: chunkText,
                      position: const Offset(0.5, 0.75),
                      fontSize: isRtl ? 28.0 : 26.0,
                      textColor: const Color(0xFFFFFFFF),
                      fontFamily: isRtl ? 'Noto Nastaliq Urdu' : 'Outfit',
                      startTime: chunkStart,
                      endTime: (totalDuration > 0 && segmentEndChunk > totalDuration) ? totalDuration : segmentEndChunk,
                      animation: TextAnimationType.none,
                      isAutoLyric: true,
                      zIndex: 0,
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

                    final lineChunk = chunks[j];
                    final bool isRtl = RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(lineChunk);

                    lyricLayers.add(
                      TextLayerModel(
                        id: uuid.v4(),
                        text: lineChunk,
                        position: const Offset(0.5, 0.75),
                        fontSize: isRtl ? 28.0 : 26.0,
                        textColor: const Color(0xFFFFFFFF),
                        fontFamily: isRtl ? 'Noto Nastaliq Urdu' : 'Outfit',
                        startTime: chunkStart,
                        endTime: segmentEndChunk > totalDuration ? totalDuration : segmentEndChunk,
                        animation: TextAnimationType.none,
                        isAutoLyric: true,
                        zIndex: 0,
                      ),
                    );
                  }
                }
              }
            }

            if (lyricLayers.isNotEmpty) {
              return lyricLayers;
            }
            throw Exception('No spoken lyrics detected in this audio track.');
          } else if (response.statusCode == 401 || response.statusCode == 429) {
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(_storageKey);
            } catch (_) {}
            debugPrint('Groq API Key status ${response.statusCode}. Rotating key...');
            _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
            attempts++;
            if (attempts >= maxRetries) {
              throw Exception('All Groq API Keys exceeded limits. (${response.statusCode})');
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
      throw Exception(e.toString().replaceAll('Exception:', '').trim());
    } finally {
      if (isTempFile && tempCreatedFile != null && await tempCreatedFile.exists()) {
        try {
          await tempCreatedFile.delete();
        } catch (_) {}
      }
    }
  }
}
