import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../models/editor_project_model.dart';
import '../models/media_layer_model.dart';
import '../models/text_layer_model.dart';
import 'font_manager_service.dart';

class FFmpegExportService {
  static const MethodChannel _channel = MethodChannel('com.lyrical.lyricalvideo/gallery');

  static Future<String?> exportProject(
    EditorProjectModel project, {
    String resolution = '1080p',
    int fps = 30,
    String quality = 'High',
    Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        onProgress?.call(i / 10);
      }
      return 'Web Preview: Video render simulated ($resolution @ ${fps}FPS, $quality quality).';
    }

    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/lyrical_export_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final videoLayers = project.mediaLayers.where((m) => m.type == MediaType.video).toList();
    final audioLayers = project.mediaLayers.where((m) => m.type == MediaType.audio).toList();
    final stickerLayers = project.mediaLayers.where((m) => m.type == MediaType.sticker).toList();
    final textLayers = project.textLayers;

    int targetHeight = 1080;
    if (resolution == '720p') targetHeight = 720;
    if (resolution == '2K/4K') targetHeight = 2160;

    final ratioWidth = project.aspectRatio.resolution.width;
    final ratioHeight = project.aspectRatio.resolution.height;
    final width = ((targetHeight * (ratioWidth / ratioHeight)) / 2).round() * 2;
    final height = targetHeight;
    final durationStr = project.duration.toStringAsFixed(2);

    String bitrateParam = '-b:v 6M';
    if (quality == 'Lower') bitrateParam = '-b:v 3M';
    if (quality == 'Higher') bitrateParam = '-b:v 12M';

    List<String> inputArgs = [];
    int inputIndex = 0;

    int? videoIdx;
    if (videoLayers.isNotEmpty) {
      inputArgs.add('-i "${videoLayers.first.path}"');
      videoIdx = inputIndex++;
    } else {
      inputArgs.add('-f lavfi -i color=c=black:s=${width}x$height:r=$fps:d=$durationStr');
      videoIdx = inputIndex++;
    }

    int? audioIdx;
    if (audioLayers.isNotEmpty && !audioLayers.first.isMuted) {
      inputArgs.add('-i "${audioLayers.first.path}"');
      audioIdx = inputIndex++;
    } else if (videoLayers.isNotEmpty && !videoLayers.first.isMuted) {
      // Audio from video will be used by default if we don't map another audio
    }

    Map<int, int> stickerIndices = {};
    for (var sticker in stickerLayers) {
      inputArgs.add('-i "${sticker.path}"');
      stickerIndices[stickerIndices.length] = inputIndex++;
    }

    String filterGraph = '';
    String lastVideoLink = '[bg]';
    
    // 1. Scale background video
    if (videoLayers.isNotEmpty) {
      filterGraph += '[$videoIdx:v]scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2[bg];';
    } else {
      filterGraph += '[$videoIdx:v]null[bg];';
    }

    // 2. Add Stickers
    for (int i = 0; i < stickerLayers.length; i++) {
      final sticker = stickerLayers[i];
      final idx = stickerIndices[i];
      final nextLink = '[v_st$i]';
      // simple normalized positioning for sticker
      final dx = sticker.position.dx;
      final dy = sticker.position.dy;
      // sticker x = (W-w)*dx, y = (H-h)*dy
      final xExpr = '(W-w)*$dx';
      final yExpr = '(H-h)*$dy';
      
      final start = sticker.startTime.toStringAsFixed(2);
      final end = (sticker.startTime + sticker.mediaDuration).toStringAsFixed(2);
      
      filterGraph += '$lastVideoLink[$idx:v]overlay=x=\'$xExpr\':y=\'$yExpr\':enable=\'between(t,$start,$end)\'$nextLink;';
      lastVideoLink = nextLink;
    }

    // 3. Add Text Layers
    for (int i = 0; i < textLayers.length; i++) {
      final text = textLayers[i];
      final nextLink = '[v_txt$i]';
      
      // Write text to a temporary file to avoid FFmpeg escaping hell
      final tempDir = await getTemporaryDirectory();
      final textFile = File('${tempDir.path}/text_layer_$i.txt');
      // Rough text wrapping to match Flutter UI wrapping behavior
      final actualFontSize = text.fontSize * text.scaleX;
      final maxLogicalWidth = text.boxWidth ?? (360.0 * 0.95); // approximate logical width
      final charsPerLine = (maxLogicalWidth / (actualFontSize * 0.55)).floor();
      
      String wrappedText = text.text;
      if (charsPerLine > 5 && !wrappedText.contains('\n') && wrappedText.length > charsPerLine) {
        final words = wrappedText.split(' ');
        String currentLine = '';
        wrappedText = '';
        for (final word in words) {
          if (currentLine.isEmpty) {
            currentLine = word;
          } else if ((currentLine.length + 1 + word.length) <= charsPerLine) {
            currentLine += ' $word';
          } else {
            wrappedText += (wrappedText.isEmpty ? '' : '\n') + currentLine;
            currentLine = word;
          }
        }
        if (currentLine.isNotEmpty) {
          wrappedText += (wrappedText.isEmpty ? '' : '\n') + currentLine;
        }
      }

      await textFile.writeAsString(wrappedText);
      final safeTextFilePath = textFile.path.replaceAll('\\', '/');

      final fontPath = await FontManagerService.getFontFilePath(text.fontFamily);
      // FFmpeg requires absolute path with forward slashes usually, escaping backslashes just in case on windows?
      // PathProvider gives C:\... on windows, /data/... on android. FFmpeg handles absolute paths well.
      final safeFontPath = fontPath.replaceAll('\\', '/');

      final hexColor = text.textColor.value.toRadixString(16).padLeft(8, '0').substring(2); // ARGB to RGB
      final strokeHex = text.strokeColor?.value.toRadixString(16).padLeft(8, '0').substring(2) ?? '000000';
      
      // Calculate font size relative to target height
      // Flutter font size 24 is roughly 24 pixels on a logical screen. We'll scale it.
      // Standard logical screen height is around 800.
      final scaleFactor = targetHeight / 800.0;
      final fontSize = (text.fontSize * text.scaleX * scaleFactor).round();
      final strokeWidth = (text.strokeWidth * text.scaleX * (scaleFactor / 2)).round(); // FFmpeg borderw is thicker visually

      final dx = text.position.dx;
      final dy = text.position.dy;
      final xExpr = '(w-text_w)*$dx';
      final yExpr = '(h-text_h)*$dy';
      
      final start = text.startTime.toStringAsFixed(2);
      final end = text.endTime.toStringAsFixed(2);

      filterGraph += '$lastVideoLink'
          'drawtext=fontfile=\'$safeFontPath\':textfile=\'$safeTextFilePath\':'
          'fontcolor=0x$hexColor:fontsize=$fontSize:borderw=$strokeWidth:bordercolor=0x$strokeHex:'
          'x=\'$xExpr\':y=\'$yExpr\':enable=\'between(t,$start,$end)\'$nextLink;';
      
      lastVideoLink = nextLink;
    }

    // Final mapping
    String mapArgs = '-map "$lastVideoLink"';
    if (audioIdx != null) {
      mapArgs += ' -map $audioIdx:a';
    } else if (videoLayers.isNotEmpty && !videoLayers.first.isMuted) {
      mapArgs += ' -map $videoIdx:a?'; // Use original video audio if available
    }

    // Ensure filterGraph doesn't end with a semicolon
    if (filterGraph.endsWith(';')) {
      filterGraph = filterGraph.substring(0, filterGraph.length - 1);
    }

    String cmd = '-y ${inputArgs.join(' ')} -t $durationStr -r $fps';
    if (filterGraph.isNotEmpty) {
      cmd += ' -filter_complex "$filterGraph"';
    }
    cmd += ' $mapArgs -c:v libx264 $bitrateParam -pix_fmt yuv420p -c:a aac -shortest "$outputPath"';

    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      try {
        await _channel.invokeMethod('saveVideoToGallery', {'filePath': outputPath});
      } catch (_) {}
      return outputPath;
    } else {
      final logs = await session.getLogsAsString();
      final err = logs != null ? (logs.length > 1000 ? logs.substring(logs.length - 1000) : logs) : "Unknown error";
      throw Exception('FFmpeg export failed:\n...\n$err');
    }
  }
}
