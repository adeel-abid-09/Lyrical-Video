import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/editor_project_model.dart';
import '../models/media_layer_model.dart';

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
      // On web preview mode, simulate export delay & return message
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        onProgress?.call(i / 10);
      }
      return 'Web Preview: Video render simulated ($resolution @ ${fps}FPS, $quality quality).';
    }

    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/lyrical_export_${DateTime.now().millisecondsSinceEpoch}.mp4';

    // Find main video or background track
    final videoLayers = project.mediaLayers.where((m) => m.type == MediaType.video).toList();
    final audioLayers = project.mediaLayers.where((m) => m.type == MediaType.audio).toList();

    int targetHeight = 1080;
    if (resolution == '720p') targetHeight = 720;
    if (resolution == '2K/4K') targetHeight = 2160;

    final ratioWidth = project.aspectRatio.resolution.width;
    final ratioHeight = project.aspectRatio.resolution.height;
    final calculatedWidth = ((targetHeight * (ratioWidth / ratioHeight)) / 2).round() * 2;

    final width = calculatedWidth;
    final height = targetHeight;
    final duration = project.duration.toStringAsFixed(2);

    String bitrateParam = '-b:v 6M';
    if (quality == 'Lower') bitrateParam = '-b:v 3M';
    if (quality == 'Higher') bitrateParam = '-b:v 12M';

    String cmd = '';

    if (videoLayers.isNotEmpty) {
      final inputVideo = videoLayers.first.path;
      if (audioLayers.isNotEmpty) {
        final inputAudio = audioLayers.first.path;
        cmd = '-y -i "$inputVideo" -i "$inputAudio" -t $duration -r $fps -vf "scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2" -c:v libx264 $bitrateParam -pix_fmt yuv420p -c:a aac -shortest "$outputPath"';
      } else {
        cmd = '-y -i "$inputVideo" -t $duration -r $fps -vf "scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2" -c:v libx264 $bitrateParam -pix_fmt yuv420p -c:a aac "$outputPath"';
      }
    } else if (audioLayers.isNotEmpty) {
      final inputAudio = audioLayers.first.path;
      cmd = '-y -f lavfi -i color=c=black:s=${width}x$height:r=$fps:d=$duration -i "$inputAudio" -c:v libx264 $bitrateParam -pix_fmt yuv420p -c:a aac -shortest "$outputPath"';
    } else {
      cmd = '-y -f lavfi -i color=c=black:s=${width}x$height:r=$fps:d=$duration -c:v libx264 $bitrateParam -pix_fmt yuv420p "$outputPath"';
    }

    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      try {
        await _channel.invokeMethod('saveVideoToGallery', {'filePath': outputPath});
      } catch (_) {}
      return outputPath;
    } else {
      final logs = await session.getLogsAsString();
      throw Exception('FFmpeg export failed: $logs');
    }
  }
}
