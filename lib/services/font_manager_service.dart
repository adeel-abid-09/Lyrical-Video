import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class FontManagerService {
  /// Ensures the font is available as a local file (for FFmpeg) and returns its absolute path.
  /// If [fontFamily] is mapped to a bundled asset, it extracts it to the cache directory.
  static Future<String> getFontFilePath(String fontFamily) async {
    // Map Flutter font family names to our bundled asset paths
    String assetPath = '';
    
    if (fontFamily.toLowerCase().contains('outfit')) {
      assetPath = 'assets/fonts/Outfit-Bold.ttf'; // Using bold for lyrics usually looks better, or we can resolve weight
    } else {
      // Default fallback
      assetPath = 'assets/fonts/Roboto-Bold.ttf';
    }

    final tempDir = await getTemporaryDirectory();
    final fileName = assetPath.split('/').last;
    final localFile = File('${tempDir.path}/$fileName');

    if (await localFile.exists()) {
      return localFile.path;
    }

    try {
      final byteData = await rootBundle.load(assetPath);
      final buffer = byteData.buffer;
      await localFile.writeAsBytes(
        buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      );
      return localFile.path;
    } catch (e) {
      // If asset loading fails (e.g., asset not found), fallback to Android system font
      return '/system/fonts/Roboto-Regular.ttf';
    }
  }
}
