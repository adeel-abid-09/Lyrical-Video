import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
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
  static const String defaultApiKey = 'YOUR_GROQ_API_KEY_HERE';
  static const String _storageKey = 'groq_api_key';

  static Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storageKey) ?? defaultApiKey;
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
      // If the file is a video, extract the audio first to avoid Groq's 25MB limit and format issues
      if (audioFilePath.toLowerCase().endsWith('.mp4') || 
          audioFilePath.toLowerCase().endsWith('.mov') || 
          audioFilePath.toLowerCase().endsWith('.mkv')) {
        
        final tempDir = await getTemporaryDirectory();
        finalUploadPath = '${tempDir.path}/extracted_audio_${const Uuid().v4()}.m4a';
        
        final session = await FFmpegKit.execute('-y -i "$audioFilePath" -vn -acodec aac -b:a 64k "$finalUploadPath"');
        final returnCode = await session.getReturnCode();
        if (returnCode == null || !returnCode.isValueSuccess()) {
          throw Exception('Failed to extract audio from video for transcription.');
        }
        isTempFile = true;
      }

      final uri = Uri.parse('https://api.groq.com/openai/v1/audio/translations');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..fields['model'] = 'whisper-large-v3' // Used large-v3 for best translation support
        ..fields['response_format'] = 'verbose_json'
        ..files.add(await http.MultipartFile.fromPath('file', finalUploadPath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final segments = data['segments'] as List<dynamic>? ?? [];

        final List<TextLayerModel> lyricLayers = [];
        final uuid = const Uuid();

        if (segments.isNotEmpty) {
          for (int i = 0; i < segments.length; i++) {
            final seg = segments[i];
            final text = (seg['text'] as String? ?? '').trim();
            if (text.isEmpty) continue;

            final start = (seg['start'] as num? ?? 0.0).toDouble();
            final end = (seg['end'] as num? ?? (start + 3.0)).toDouble();

            lyricLayers.add(
              TextLayerModel(
                id: uuid.v4(),
                text: text,
                position: const Offset(0.5, 0.75), // Bottom lyric area
                fontSize: 26.0,
                textColor: const Color(0xFFFFFFFF),
                strokeColor: const Color(0xFF000000),
                strokeWidth: 3.0,
                startTime: start,
                endTime: end > totalDuration ? totalDuration : end,
                animation: TextAnimationType.fadeIn,
                isAutoLyric: true,
                zIndex: 10 + i,
              ),
            );
          }
        }

        if (lyricLayers.isNotEmpty) {
          return lyricLayers;
        }
      }
      throw Exception('Groq API Error: ${response.statusCode} - ${response.body}');
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
}
