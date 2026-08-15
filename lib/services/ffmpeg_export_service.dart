import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/editor_project_model.dart';
import '../models/media_layer_model.dart';
import '../models/text_layer_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'font_manager_service.dart';
import '../widgets/editor/text_bubble_painter.dart';

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
      // sticker x = W*dx - w/2 (center anchored), y = H*dy - h/2
      final xExpr = 'W*$dx-w/2';
      final yExpr = 'H*$dy-h/2';
      
      final start = sticker.startTime.toStringAsFixed(2);
      final end = (sticker.startTime + sticker.mediaDuration).toStringAsFixed(2);
      
      filterGraph += '$lastVideoLink[$idx:v]overlay=x=\'$xExpr\':y=\'$yExpr\':enable=\'between(t,$start,$end)\'$nextLink;';
      lastVideoLink = nextLink;
    }

    // 3. Add Text Layers
    for (int i = 0; i < textLayers.length; i++) {
      final text = textLayers[i];
      final nextLink = '[v_txt$i]';
      
      final imagePath = await _generateTextImage(text, width, height, project.canvasWidth, project.canvasHeight);
      inputArgs.add('-i "$imagePath"');
      // inputArgs has 1 item per '-i' argument right now? Wait, no! 
      // Look at inputArgs collection above!
      // Let's count '-i' in inputArgs.
      final textInputIdx = inputArgs.where((arg) => arg.startsWith('-i')).length - 1;

      final start = text.startTime.toStringAsFixed(2);
      final end = text.endTime.toStringAsFixed(2);

      filterGraph += '$lastVideoLink[$textInputIdx:v]overlay=x=0:y=0:enable=\'between(t,$start,$end)\'$nextLink;';
      lastVideoLink = nextLink;
    }

    // Final mapping
    String mapArgs = '-map "$lastVideoLink"';
    bool hasVideoAudio = videoLayers.isNotEmpty && !videoLayers.first.isMuted;
    bool hasExtraAudio = audioIdx != null;

    if (hasVideoAudio && hasExtraAudio) {
      filterGraph += '[$videoIdx:a][$audioIdx:a]amix=inputs=2:duration=longest[aout];';
      mapArgs += ' -map "[aout]"';
    } else if (hasExtraAudio) {
      mapArgs += ' -map $audioIdx:a';
    } else if (hasVideoAudio) {
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

    // We need to use executeAsync with a statisticsCallback to get progress
    final completer = Completer<String?>();
    
    await FFmpegKit.executeAsync(
      cmd,
      (session) async {
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          try {
            await _channel.invokeMethod('saveVideoToGallery', {'filePath': outputPath});
          } catch (_) {}
          completer.complete(outputPath);
        } else {
          final logs = await session.getLogsAsString();
          final err = logs != null ? (logs.length > 1000 ? logs.substring(logs.length - 1000) : logs) : "Unknown error";
          completer.completeError(Exception('FFmpeg export failed:\n...\n$err'));
        }
      },
      (log) {}, // LogCallback
      (statistics) { // StatisticsCallback
        if (onProgress != null) {
          final int timeInMs = statistics.getTime();
          final double totalMs = project.duration * 1000;
          if (timeInMs > 0 && totalMs > 0) {
            double progress = timeInMs / totalMs;
            if (progress > 1.0) progress = 1.0;
            onProgress(progress);
          }
        }
      },
    );

    return completer.future;
  }

  static Future<String> _generateTextImage(TextLayerModel textLayer, int targetWidth, int targetHeight, double canvasWidth, double canvasHeight) async {
    // We use the exact canvas width the user had while editing for 1:1 mapping.
    final double logicalWidth = canvasWidth;
    
    final double scaleFactor = targetWidth / logicalWidth;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()));

    final centerX = textLayer.position.dx * targetWidth;
    final centerY = textLayer.position.dy * targetHeight;

    canvas.translate(centerX, centerY);
    canvas.rotate(textLayer.rotation);
    // Multiply textLayer.scaleX by our target scale factor!
    canvas.scale(textLayer.scaleX * scaleFactor, textLayer.scaleY * scaleFactor);

    if (textLayer.opacity < 1.0) {
      canvas.saveLayer(null, Paint()..color = Colors.black.withOpacity(textLayer.opacity.clamp(0.0, 1.0)));
    }

    final baseStyle = TextStyle(
      fontSize: textLayer.fontSize,
      color: textLayer.textColor,
      fontWeight: textLayer.fontWeight,
      fontStyle: textLayer.fontStyle,
      letterSpacing: textLayer.letterSpacing,
      shadows: [
         Shadow(color: textLayer.strokeColor ?? Colors.black.withOpacity(0.9), blurRadius: (textLayer.strokeColor != null ? textLayer.strokeWidth : 2.0) * 1.5),
         Shadow(color: textLayer.strokeColor ?? Colors.black.withOpacity(0.9), offset: const Offset(1, 1)),
         Shadow(color: textLayer.strokeColor ?? Colors.black.withOpacity(0.9), offset: const Offset(-1, -1)),
         Shadow(color: textLayer.strokeColor ?? Colors.black.withOpacity(0.9), offset: const Offset(1, -1)),
         Shadow(color: textLayer.strokeColor ?? Colors.black.withOpacity(0.9), offset: const Offset(-1, 1)),
      ],
    );

    TextStyle finalStyle = baseStyle;
    try {
      if (textLayer.fontFamily != null && textLayer.fontFamily!.isNotEmpty) {
        finalStyle = GoogleFonts.getFont(textLayer.fontFamily!, textStyle: baseStyle);
      } else {
        finalStyle = GoogleFonts.outfit(textStyle: baseStyle);
      }
    } catch (_) {
      finalStyle = GoogleFonts.outfit(textStyle: baseStyle);
    }

    final textSpan = TextSpan(
      text: textLayer.text,
      style: finalStyle,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: textLayer.textAlign,
      textDirection: TextDirection.ltr,
    );
    
    final hasBubble = textLayer.bubbleStyle != null && textLayer.bubbleStyle != 'none';
    final double padH = hasBubble ? 48.0 : 32.0;
    final double padV = hasBubble ? 24.0 : 16.0;

    final maxW = (textLayer.boxWidth != null) ? (textLayer.boxWidth! - padH) : ((logicalWidth * 0.90) - padH).clamp(40.0, logicalWidth);
    textPainter.layout(minWidth: 0, maxWidth: maxW);

    final double boxW = textLayer.boxWidth ?? (textPainter.width + padH).clamp(40.0, logicalWidth * 0.90);
    final double boxH = textLayer.boxHeight ?? (textPainter.height + padV).clamp(30.0, double.infinity);

    canvas.translate(-boxW / 2, -boxH / 2);

    if (hasBubble) {
      BubbleShapePainter.paintBubbleOnCanvas(
        canvas,
        Rect.fromLTWH(0, 0, boxW, boxH),
        textLayer.bubbleStyle!,
        customColor: textLayer.backgroundColor,
      );
    } else if (textLayer.backgroundColor != null && textLayer.backgroundColor!.alpha > 0) {
      final paint = Paint()..color = textLayer.backgroundColor!;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, boxW, boxH),
        Radius.circular(textLayer.boxBorderRadius),
      );
      canvas.drawRRect(rrect, paint);
    }

    final double textX = (boxW - textPainter.width) / 2;
    final double textY = (boxH - textPainter.height) / 2;
    textPainter.paint(canvas, Offset(textX, textY));

    if (textLayer.opacity < 1.0) {
      canvas.restore();
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(targetWidth, targetHeight);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/text_img_${textLayer.id}.png');
    await file.writeAsBytes(byteData!.buffer.asUint8List());

    return file.path.replaceAll('\\', '/');
  }
}
