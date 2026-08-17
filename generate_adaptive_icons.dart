import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final sourcePath = r'C:\Users\DELL\.gemini\antigravity-ide\brain\346e0bee-cc02-48ab-a74d-2528657cc688\app_icon_fullbleed_centered_1786960969875.jpg';
  final sourceBytes = File(sourcePath).readAsBytesSync();
  final sourceImage = img.decodeImage(sourceBytes)!;

  final int size = 1024;
  
  // 1. Create pure gradient background (1024x1024)
  // Sunset Orange (#FF512F) -> Magenta (#DD2476) -> Deep Rose (#B91D73)
  final bgImage = img.Image(width: size, height: size);
  final c1 = img.ColorRgb8(255, 81, 47);   // #FF512F
  final c2 = img.ColorRgb8(221, 36, 118);  // #DD2476
  final c3 = img.ColorRgb8(185, 29, 115);  // #B91D73
  
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      // 135-degree diagonal gradient
      double t = (x + y) / (2.0 * size);
      int r, g, b;
      if (t < 0.5) {
        double subT = t / 0.5;
        r = (c1.r + (c2.r - c1.r) * subT).round();
        g = (c1.g + (c2.g - c1.g) * subT).round();
        b = (c1.b + (c2.b - c1.b) * subT).round();
      } else {
        double subT = (t - 0.5) / 0.5;
        r = (c2.r + (c3.r - c2.r) * subT).round();
        g = (c2.g + (c3.g - c2.g) * subT).round();
        b = (c2.b + (c3.b - c2.b) * subT).round();
      }
      bgImage.setPixel(x, y, img.ColorRgb8(r, g, b));
    }
  }

  // 2. Create foreground image (1024x1024 transparent with centered source icon)
  final fgImage = img.Image(width: size, height: size, numChannels: 4);
  img.fill(fgImage, color: img.ColorRgba8(0, 0, 0, 0));

  // Scale the source icon to fill ~920px for optimal adaptive icon sizing with 16% inset
  final int targetFgSize = 920;
  final scaledSource = img.copyResize(sourceImage, width: targetFgSize, height: targetFgSize, interpolation: img.Interpolation.cubic);
  
  final legacyIcon = img.copyResize(sourceImage, width: size, height: size, interpolation: img.Interpolation.cubic);

  final int offsetX = (size - targetFgSize) ~/ 2;
  final int offsetY = (size - targetFgSize) ~/ 2;

  img.compositeImage(fgImage, scaledSource, dstX: offsetX, dstY: offsetY);

  final iconDir = Directory('assets/icon');
  if (!iconDir.existsSync()) {
    iconDir.createSync(recursive: true);
  }

  File('assets/icon/app_icon_bg.png').writeAsBytesSync(img.encodePng(bgImage));
  File('assets/icon/app_icon_fg.png').writeAsBytesSync(img.encodePng(fgImage));
  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(legacyIcon));

  print('Adaptive icons successfully generated in assets/icon/');
}
