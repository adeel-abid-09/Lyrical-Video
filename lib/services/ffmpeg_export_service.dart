import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/editor_project_model.dart';
import '../models/media_layer_model.dart';
import '../models/text_layer_model.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/editor/text_bubble_painter.dart';

class FFmpegExportService {
  static const MethodChannel _channel = MethodChannel('com.lyrical.lyricalvideo/gallery');

  static Future<bool> _hasAudioStream(String filePath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(filePath);
      final info = session.getMediaInformation();
      if (info == null) return true;
      final streams = info.getStreams();
      if (streams == null || streams.isEmpty) return true;
      for (final s in streams) {
        final type = (s.getType() ?? '').toLowerCase();
        final codec = (s.getCodec() ?? '').toLowerCase();
        if (type.contains('audio') || 
            codec.contains('aac') || 
            codec.contains('mp3') || 
            codec.contains('opus') || 
            codec.contains('vorbis') || 
            codec.contains('flac') || 
            codec.contains('pcm') || 
            codec.contains('ac3') || 
            codec.contains('wav') ||
            codec.contains('m4a')) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return true;
    }
  }

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

    final baseVideo = project.mediaLayers.where((m) => !m.isOverlay && m.type == MediaType.video).firstOrNull;
    final basePhoto = project.mediaLayers.where((m) => !m.isOverlay && m.type == MediaType.sticker).firstOrNull;
    final overlayLayers = project.mediaLayers.where((m) => m.isOverlay).toList();
    final audioLayers = project.mediaLayers.where((m) => m.type == MediaType.audio).toList();
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

    int? baseIdx;
    if (baseVideo != null) {
      inputArgs.add('-stream_loop -1 -i "${baseVideo.path}"');
      baseIdx = inputIndex++;
    } else if (basePhoto != null) {
      inputArgs.add('-loop 1 -t $durationStr -i "${basePhoto.path}"');
      baseIdx = inputIndex++;
    } else {
      inputArgs.add('-f lavfi -i color=c=black:s=${width}x$height:r=$fps:d=$durationStr');
      baseIdx = inputIndex++;
    }

    Map<int, int> audioIndices = {};
    for (int j = 0; j < audioLayers.length; j++) {
      final audio = audioLayers[j];
      if (!audio.isMuted) {
        inputArgs.add('-i "${audio.path}"');
        audioIndices[j] = inputIndex++;
      }
    }

    Map<int, int> overlayIndices = {};
    for (var overlay in overlayLayers) {
      if (overlay.type == MediaType.video) {
        inputArgs.add('-stream_loop -1 -i "${overlay.path}"');
      } else {
        inputArgs.add('-loop 1 -t $durationStr -i "${overlay.path}"');
      }
      overlayIndices[overlayIndices.length] = inputIndex++;
    }

    String filterGraph = '';
    String lastVideoLink = '[bg]';
    
    // 1. Scale background media & ensure yuv420p format
    final baseMedia = baseVideo ?? basePhoto;
    if (baseMedia != null) {
      String bgCropFilter = '';
      if (baseMedia.isCropped) {
        final cropW = (baseMedia.cropRight - baseMedia.cropLeft).clamp(0.01, 1.0);
        final cropH = (baseMedia.cropBottom - baseMedia.cropTop).clamp(0.01, 1.0);
        bgCropFilter = 'crop=w=trunc(iw*$cropW/2)*2:h=trunc(ih*$cropH/2)*2:x=trunc(iw*${baseMedia.cropLeft}):y=trunc(ih*${baseMedia.cropTop}),';
      }
      final String scaleFilter;
      if (baseMedia.fitMode == VideoFitMode.contain) {
        scaleFilter = 'scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2,';
      } else if (baseMedia.fitMode == VideoFitMode.fill || baseMedia.fitMode == VideoFitMode.stretch) {
        scaleFilter = 'scale=$width:$height,';
      } else {
        // VideoFitMode.cover (Default) - fills the canvas completely, center-cropping excess to match editor preview exactly
        scaleFilter = 'scale=$width:$height:force_original_aspect_ratio=increase,crop=$width:$height,';
      }
      filterGraph += '[$baseIdx:v]${bgCropFilter}${scaleFilter}format=yuv420p[bg];';
    } else {
      filterGraph += '[$baseIdx:v]format=yuv420p[bg];';
    }

    // 2. Add Overlays (Videos and Images) with format=rgba and eof_action=pass
    for (int i = 0; i < overlayLayers.length; i++) {
      final overlay = overlayLayers[i];
      final idx = overlayIndices[i];
      final fmtLink = '[ov_fmt$i]';
      final nextLink = '[v_ov$i]';
      
      final dx = overlay.position.dx;
      final dy = overlay.position.dy;
      final xExpr = 'W*$dx-w/2';
      final yExpr = 'H*$dy-h/2';
      
      final start = overlay.startTime.toStringAsFixed(2);
      final end = (overlay.startTime + overlay.mediaDuration).toStringAsFixed(2);
      final scaleW = (((width * overlay.scaleX).round().clamp(10, width * 4)) / 2).round() * 2;
      
      String ovCropFilter = '';
      if (overlay.isCropped) {
        final cropW = (overlay.cropRight - overlay.cropLeft).clamp(0.01, 1.0);
        final cropH = (overlay.cropBottom - overlay.cropTop).clamp(0.01, 1.0);
        ovCropFilter = 'crop=w=trunc(iw*$cropW/2)*2:h=trunc(ih*$cropH/2)*2:x=trunc(iw*${overlay.cropLeft}):y=trunc(ih*${overlay.cropTop}),';
      }

      final scaleFilter = 'scale=$scaleW:-2';

      String rotateFilter = '';
      if (overlay.rotation != 0.0) {
        rotateFilter = 'rotate=${overlay.rotation}:ow=\'rotw(${overlay.rotation})\':oh=\'roth(${overlay.rotation})\':c=none,';
      }

      filterGraph += '[$idx:v]${ovCropFilter}${scaleFilter},${rotateFilter}format=rgba$fmtLink;$lastVideoLink$fmtLink'
          'overlay=x=\'$xExpr\':y=\'$yExpr\':enable=\'between(t,$start,$end)\':eof_action=pass$nextLink;';
      lastVideoLink = nextLink;
    }

    // 3. Add Text Track (Combined Concat Stream - EXACTLY 1 input stream for unlimited lyrics!)
    final concatFilePath = await _generateConcatTextTrack(
      textLayers,
      width,
      height,
      project.canvasWidth,
      project.canvasHeight,
      project.duration,
      tempDir,
    );

    if (concatFilePath != null) {
      inputArgs.add('-f concat -safe 0 -i "$concatFilePath"');
      final textInputIdx = inputIndex++;
      filterGraph += '[$textInputIdx:v]format=rgba[txt_all];$lastVideoLink[txt_all]overlay=0:0:eof_action=pass[v_txt];';
      lastVideoLink = '[v_txt]';
    }

    // Final audio mixing (Base Video Audio + Overlay Videos Audio + Audio Tracks)
    List<String> audioStreamLinks = [];

    if (baseVideo != null && !baseVideo.isMuted && baseVideo.type == MediaType.video && baseIdx != null) {
      final baseHasAudio = await _hasAudioStream(baseVideo.path);
      if (baseHasAudio) {
        final delayMs = (baseVideo.startTime * 1000).toInt();
        final trimStart = baseVideo.trimStartTime.toStringAsFixed(2);
        final trimEnd = (baseVideo.trimStartTime + baseVideo.mediaDuration).toStringAsFixed(2);
        final vol = baseVideo.volume.clamp(0.0, 2.0).toStringAsFixed(2);
        
        String aFilter = 'atrim=start=$trimStart:end=$trimEnd,asetpts=PTS-STARTPTS';
        if (delayMs > 0) {
          aFilter += ',adelay=$delayMs|$delayMs';
        }
        if (baseVideo.volume != 1.0) {
          aFilter += ',volume=$vol';
        }
        filterGraph += '[$baseIdx:a]$aFilter[a_base];';
        audioStreamLinks.add('[a_base]');
      }
    }

    for (int i = 0; i < overlayLayers.length; i++) {
      final overlay = overlayLayers[i];
      if (overlay.type == MediaType.video && !overlay.isMuted && overlayIndices.containsKey(i)) {
        final overlayHasAudio = await _hasAudioStream(overlay.path);
        if (overlayHasAudio) {
          final idx = overlayIndices[i]!;
          final delayMs = (overlay.startTime * 1000).toInt();
          final trimStart = overlay.trimStartTime.toStringAsFixed(2);
          final trimEnd = (overlay.trimStartTime + overlay.mediaDuration).toStringAsFixed(2);
          final vol = overlay.volume.clamp(0.0, 2.0).toStringAsFixed(2);

          String aFilter = 'atrim=start=$trimStart:end=$trimEnd,asetpts=PTS-STARTPTS';
          if (delayMs > 0) {
            aFilter += ',adelay=$delayMs|$delayMs';
          }
          if (overlay.volume != 1.0) {
            aFilter += ',volume=$vol';
          }
          filterGraph += '[$idx:a]$aFilter[a_ov$i];';
          audioStreamLinks.add('[a_ov$i]');
        }
      }
    }

    for (int j = 0; j < audioLayers.length; j++) {
      final audio = audioLayers[j];
      if (!audio.isMuted && audioIndices.containsKey(j)) {
        final idx = audioIndices[j]!;
        final delayMs = (audio.startTime * 1000).toInt();
        final trimStart = audio.trimStartTime.toStringAsFixed(2);
        final trimEnd = (audio.trimStartTime + audio.mediaDuration).toStringAsFixed(2);
        final vol = audio.volume.clamp(0.0, 2.0).toStringAsFixed(2);

        String aFilter = 'atrim=start=$trimStart:end=$trimEnd,asetpts=PTS-STARTPTS';
        if (delayMs > 0) {
          aFilter += ',adelay=$delayMs|$delayMs';
        }
        if (audio.volume != 1.0) {
          aFilter += ',volume=$vol';
        }
        filterGraph += '[$idx:a]$aFilter[a_aud$j];';
        audioStreamLinks.add('[a_aud$j]');
      }
    }

    String mapArgs = '-map "$lastVideoLink"';
    if (audioStreamLinks.length == 1) {
      mapArgs += ' -map "${audioStreamLinks.first}"';
    } else if (audioStreamLinks.length > 1) {
      final inputs = audioStreamLinks.join('');
      filterGraph += '${inputs}amix=inputs=${audioStreamLinks.length}:duration=longest:dropout_transition=0:normalize=0[aout];';
      mapArgs += ' -map "[aout]"';
    } else {
      inputArgs.add('-f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100');
      final silentIdx = inputIndex++;
      mapArgs += ' -map $silentIdx:a -shortest';
    }

    // Ensure filterGraph doesn't end with a semicolon
    if (filterGraph.endsWith(';')) {
      filterGraph = filterGraph.substring(0, filterGraph.length - 1);
    }

    String cmd = '-y ${inputArgs.join(' ')} -t $durationStr -r $fps';
    if (filterGraph.isNotEmpty) {
      cmd += ' -filter_complex "$filterGraph"';
    }
    cmd += ' $mapArgs -c:v libx264 -preset ultrafast -threads 0 $bitrateParam -pix_fmt yuv420p -c:a aac -b:a 192k "$outputPath"';

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

  static Future<String?> _generateConcatTextTrack(
    List<TextLayerModel> textLayers,
    int targetWidth,
    int targetHeight,
    double canvasWidth,
    double canvasHeight,
    double totalDuration,
    Directory tempDir,
  ) async {
    if (textLayers.isEmpty) return null;

    final Set<double> timePointsSet = {0.0, totalDuration};
    for (final t in textLayers) {
      final start = t.startTime.clamp(0.0, totalDuration);
      final end = t.endTime.clamp(0.0, totalDuration);
      if (start >= end) continue;

      timePointsSet.add(double.parse(start.toStringAsFixed(3)));
      timePointsSet.add(double.parse(end.toStringAsFixed(3)));

      if (t.animation != TextAnimationType.none) {
        final animDur = t.animationDuration.clamp(0.1, 10.0);
        final animEnd = (start + animDur).clamp(start, end);
        timePointsSet.add(double.parse(animEnd.toStringAsFixed(3)));

        // Sample animation at 20fps intervals (0.05s) for smooth text animation
        const double step = 0.05;
        for (double s = start + step; s < animEnd; s += step) {
          timePointsSet.add(double.parse(s.toStringAsFixed(3)));
        }
      }
    }
    final timePoints = timePointsSet.toList()..sort();

    // Create a transparent empty PNG for gaps
    final emptyFile = File('${tempDir.path}/text_empty.png');
    if (!emptyFile.existsSync()) {
      final emptyRecorder = ui.PictureRecorder();
      final emptyCanvas = ui.Canvas(emptyRecorder);
      emptyCanvas.drawColor(const Color(0x00000000), ui.BlendMode.src);
      final emptyPic = emptyRecorder.endRecording();
      final emptyImg = await emptyPic.toImage(targetWidth, targetHeight);
      final emptyBytes = await emptyImg.toByteData(format: ui.ImageByteFormat.png);
      await emptyFile.writeAsBytes(emptyBytes!.buffer.asUint8List());
    }

    final StringBuffer concatBuffer = StringBuffer();
    String? lastWrittenImagePath;

    for (int i = 0; i < timePoints.length - 1; i++) {
      final tStart = timePoints[i];
      final tEnd = timePoints[i + 1];
      final dur = tEnd - tStart;
      if (dur < 0.001) continue;

      final active = textLayers.where((t) => t.startTime < tEnd && t.endTime > tStart).toList();

      if (active.isEmpty) {
        final path = emptyFile.path.replaceAll('\\', '/');
        concatBuffer.writeln("file '$path'");
        concatBuffer.writeln('duration ${dur.toStringAsFixed(3)}');
        lastWrittenImagePath = path;
      } else {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()));
        canvas.drawColor(const Color(0x00000000), ui.BlendMode.src);

        for (final text in active) {
          _drawTextLayerToCanvas(canvas, text, targetWidth, targetHeight, canvasWidth, canvasHeight, tStart);
        }

        final picture = recorder.endRecording();
        final image = await picture.toImage(targetWidth, targetHeight);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

        final frameFile = File('${tempDir.path}/text_seg_${i}_${tStart.toStringAsFixed(3)}.png');
        await frameFile.writeAsBytes(byteData!.buffer.asUint8List());

        final path = frameFile.path.replaceAll('\\', '/');
        concatBuffer.writeln("file '$path'");
        concatBuffer.writeln('duration ${dur.toStringAsFixed(3)}');
        lastWrittenImagePath = path;
      }
    }

    if (lastWrittenImagePath != null) {
      concatBuffer.writeln("file '$lastWrittenImagePath'");
    }

    final concatFile = File('${tempDir.path}/text_concat.txt');
    await concatFile.writeAsString(concatBuffer.toString());
    return concatFile.path.replaceAll('\\', '/');
  }

  static void _drawTextLayerToCanvas(
    ui.Canvas canvas,
    TextLayerModel textLayer,
    int targetWidth,
    int targetHeight,
    double canvasWidth,
    double canvasHeight,
    double currentTime,
  ) {
    final double logicalWidth = canvasWidth > 0 ? canvasWidth : 360.0;
    final double scaleFactor = targetWidth / logicalWidth;

    // Calculate animation state at currentTime
    final timeSinceStart = (currentTime - textLayer.startTime).clamp(0.0, double.infinity);
    final animDur = textLayer.animationDuration.clamp(0.1, 10.0);
    final animProgress = (timeSinceStart / animDur).clamp(0.0, 1.0);

    double liveOpacity = textLayer.opacity.clamp(0.0, 1.0);
    double liveScale = textLayer.scaleX;
    double liveTranslateY = 0.0;
    double liveRotateAngle = textLayer.rotation;
    String liveText = textLayer.text;
    List<Shadow>? liveGlowShadows;

    switch (textLayer.animation) {
      case TextAnimationType.none:
        break;
      case TextAnimationType.fadeIn:
        liveOpacity *= Curves.easeIn.transform(animProgress);
        break;
      case TextAnimationType.popIn:
        final s = animProgress < 0.8
            ? (animProgress / 0.8) * 1.2
            : 1.2 - ((animProgress - 0.8) / 0.2) * 0.2;
        liveScale *= s.clamp(0.01, 1.3);
        break;
      case TextAnimationType.blurIn:
        final s = 0.7 + (Curves.easeOut.transform(animProgress) * 0.3);
        liveScale *= s;
        liveOpacity *= animProgress.clamp(0.05, 1.0);
        break;
      case TextAnimationType.slideUp:
        liveTranslateY = (1.0 - Curves.easeOutCubic.transform(animProgress)) * 30.0;
        liveOpacity *= animProgress;
        break;
      case TextAnimationType.slideDown:
        liveTranslateY = -(1.0 - Curves.easeOutCubic.transform(animProgress)) * 30.0;
        liveOpacity *= animProgress;
        break;
      case TextAnimationType.typewriter:
        final count = (textLayer.text.length * animProgress).clamp(1, textLayer.text.length).toInt();
        liveText = textLayer.text.substring(0, count);
        break;
      case TextAnimationType.bounce:
        final b = Curves.bounceOut.transform(animProgress);
        liveTranslateY = (1.0 - b) * -25.0;
        break;
      case TextAnimationType.glow:
        final radius = (sin(timeSinceStart * pi * 3).abs() * 8.0) + 2.0;
        liveGlowShadows = [
          Shadow(color: Colors.white, blurRadius: radius),
          Shadow(color: const Color(0xFF00E5FF), blurRadius: radius * 1.5),
        ];
        break;
      case TextAnimationType.stamp:
        final s = animProgress < 0.6
            ? 2.2 - (Curves.easeInQuad.transform(animProgress / 0.6) * 1.2)
            : 1.0;
        liveScale *= s;
        break;
      case TextAnimationType.zoomIn:
        liveScale *= Curves.easeOutBack.transform(animProgress).clamp(0.01, 1.2);
        break;
      case TextAnimationType.wave:
        liveRotateAngle += sin(animProgress * pi * 2) * 0.12;
        break;
    }

    canvas.save();

    final centerX = textLayer.position.dx * targetWidth;
    final centerY = (textLayer.position.dy * targetHeight) + (liveTranslateY * scaleFactor);

    canvas.translate(centerX, centerY);
    canvas.rotate(liveRotateAngle);
    canvas.scale(liveScale * scaleFactor, textLayer.scaleY * scaleFactor);

    if (liveOpacity < 1.0) {
      canvas.saveLayer(null, Paint()..color = Colors.black.withOpacity(liveOpacity.clamp(0.0, 1.0)));
    }

    final shadowsList = liveGlowShadows ?? [
      Shadow(color: textLayer.strokeColor ?? Colors.black.withOpacity(0.9), blurRadius: (textLayer.strokeColor != null ? textLayer.strokeWidth : 2.0) * 1.5),
      Shadow(color: textLayer.strokeColor ?? Colors.black.withOpacity(0.9), offset: const Offset(1, 1)),
      Shadow(color: textLayer.strokeColor ?? Colors.black.withOpacity(0.9), offset: const Offset(-1, -1)),
      Shadow(color: textLayer.strokeColor ?? Colors.black.withOpacity(0.9), offset: const Offset(1, -1)),
      Shadow(color: textLayer.strokeColor ?? Colors.black.withOpacity(0.9), offset: const Offset(-1, 1)),
    ];

    final baseStyle = TextStyle(
      fontSize: textLayer.fontSize,
      color: textLayer.textColor,
      fontWeight: textLayer.fontWeight,
      fontStyle: textLayer.fontStyle,
      letterSpacing: textLayer.letterSpacing,
      height: textLayer.lineSpacing,
      shadows: shadowsList,
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
      text: liveText,
      style: finalStyle,
    );

    final bool isRtl = RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(liveText);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: textLayer.textAlign,
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
    );
    
    final hasBubble = textLayer.bubbleStyle != null && textLayer.bubbleStyle != 'none';
    final double padH = hasBubble ? 48.0 : 32.0;
    final double padV = hasBubble ? 24.0 : 16.0;

    final maxW = (textLayer.boxWidth != null) ? (textLayer.boxWidth! - padH) : ((logicalWidth * 0.95) - padH).clamp(40.0, logicalWidth);
    textPainter.layout(minWidth: 0, maxWidth: maxW);

    final double boxW = textLayer.boxWidth ?? (textPainter.width + padH).clamp(40.0, logicalWidth * 0.95);
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

    // Mathematical 1:1 match for FittedBox(fit: BoxFit.scaleDown) from editor
    final double availTextW = (boxW - padH).clamp(1.0, double.infinity);
    final double availTextH = (boxH - padV).clamp(1.0, double.infinity);
    double innerScale = 1.0;
    if (textLayer.boxWidth != null || textLayer.boxHeight != null) {
      if (textPainter.width > availTextW) {
        innerScale = (availTextW / textPainter.width).clamp(0.01, 1.0);
      }
      if (textPainter.height > availTextH) {
        final hScale = (availTextH / textPainter.height).clamp(0.01, 1.0);
        if (hScale < innerScale) innerScale = hScale;
      }
    }

    final double textX = (boxW - (textPainter.width * innerScale)) / 2;
    final double textY = (boxH - (textPainter.height * innerScale)) / 2;

    if (innerScale < 1.0) {
      canvas.save();
      canvas.translate(textX, textY);
      canvas.scale(innerScale, innerScale);
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    } else {
      textPainter.paint(canvas, Offset(textX, textY));
    }

    if (liveOpacity < 1.0) {
      canvas.restore();
    }

    canvas.restore();
  }
}
