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
    Function(double progress)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/lyrical_export_${DateTime.now().millisecondsSinceEpoch}.mp4';

    // Find main video or background track
    final videoLayers = project.mediaLayers.where((m) => m.type == MediaType.video).toList();
    final audioLayers = project.mediaLayers.where((m) => m.type == MediaType.audio).toList();

    final width = project.aspectRatio.resolution.width.toInt();
    final height = project.aspectRatio.resolution.height.toInt();
    final duration = project.duration.toStringAsFixed(2);

    String cmd = '';

    if (videoLayers.isNotEmpty) {
      final inputVideo = videoLayers.first.path;
      if (audioLayers.isNotEmpty) {
        final inputAudio = audioLayers.first.path;
        cmd = '-y -i "$inputVideo" -i "$inputAudio" -t $duration -vf "scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2" -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest "$outputPath"';
      } else {
        cmd = '-y -i "$inputVideo" -t $duration -vf "scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2" -c:v libx264 -pix_fmt yuv420p -c:a aac "$outputPath"';
      }
    } else if (audioLayers.isNotEmpty) {
      final inputAudio = audioLayers.first.path;
      cmd = '-y -f lavfi -i color=c=black:s=${width}x$height:r=30:d=$duration -i "$inputAudio" -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest "$outputPath"';
    } else {
      cmd = '-y -f lavfi -i color=c=black:s=${width}x$height:r=30:d=$duration -c:v libx264 -pix_fmt yuv420p "$outputPath"';
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
