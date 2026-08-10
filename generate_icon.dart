import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  final int width = 512;
  final int height = 512;
  final image = img.Image(width: width, height: height);

  // Colors: Sunset Orange (#FF512F) to Magenta (#DD2476)
  final c1 = img.ColorRgb8(255, 81, 47); // Orange
  final c2 = img.ColorRgb8(221, 36, 118); // Magenta

  // Draw gradient background
  for (int y = 0; y < height; ++y) {
    for (int x = 0; x < width; ++x) {
      double t = (x + y) / (width + height); // Diagonal gradient
      int r = (c1.r + (c2.r - c1.r) * t).toInt();
      int g = (c1.g + (c2.g - c1.g) * t).toInt();
      int b = (c1.b + (c2.b - c1.b) * t).toInt();
      image.setPixel(x, y, img.ColorRgb8(r, g, b));
    }
  }

  // Draw dual ring arcs
  // We'll draw circles with thick outlines
  final white = img.ColorRgb8(255, 255, 255);
  final semiWhite = img.ColorRgba8(255, 255, 255, 100);
  
  img.drawCircle(image, x: width ~/ 2, y: height ~/ 2, radius: 200, color: semiWhite);
  img.drawCircle(image, x: width ~/ 2, y: height ~/ 2, radius: 195, color: semiWhite);
  img.drawCircle(image, x: width ~/ 2, y: height ~/ 2, radius: 190, color: semiWhite);

  img.drawCircle(image, x: width ~/ 2, y: height ~/ 2, radius: 160, color: semiWhite);
  img.drawCircle(image, x: width ~/ 2, y: height ~/ 2, radius: 155, color: semiWhite);

  // Draw 3D white play button (triangle)
  int cx = width ~/ 2 + 20;
  int cy = height ~/ 2;
  int rPlay = 90;
  
  // Vertices of equilateral triangle pointing right
  int x1 = cx - rPlay ~/ 2;
  int y1 = cy - rPlay;
  int x2 = cx - rPlay ~/ 2;
  int y2 = cy + rPlay;
  int x3 = cx + rPlay;
  int y3 = cy;

  // Simple filled triangle by drawing horizontal lines
  for (int y = cy - rPlay; y <= cy + rPlay; y++) {
    int dx;
    if (y < cy) {
      // Top half: x goes from left to the line connecting (x1, y1) and (x3, y3)
      // slope = (y3 - y1) / (x3 - x1) = rPlay / (1.5 * rPlay)
      // x = x1 + (y - y1) / slope
      dx = x1 + ((y - y1) * (x3 - x1) ~/ (y3 - y1));
    } else {
      // Bottom half: x goes from left to the line connecting (x2, y2) and (x3, y3)
      dx = x1 + ((y2 - y) * (x3 - x2) ~/ (y2 - y3));
    }
    img.drawLine(image, x1: x1, y1: y, x2: dx, y2: y, color: white);
  }

  // Draw subtle shadow for 3D effect
  int shadowOffset = 8;
  final shadow = img.ColorRgba8(0, 0, 0, 80);
  for (int y = cy - rPlay; y <= cy + rPlay; y++) {
    int dx;
    if (y < cy) {
      dx = x1 + ((y - y1) * (x3 - x1) ~/ (y3 - y1));
    } else {
      dx = x1 + ((y2 - y) * (x3 - x2) ~/ (y2 - y3));
    }
    img.drawLine(image, x1: x1 - shadowOffset, y1: y + shadowOffset, x2: x1, y2: y + shadowOffset, color: shadow);
    img.drawLine(image, x1: dx, y1: y + shadowOffset, x2: dx + shadowOffset, y2: y + shadowOffset, color: shadow);
  }

  final dir = Directory('assets/icon');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  final file = File('assets/icon/app_icon.png');
  file.writeAsBytesSync(img.encodePng(image));
  print('App icon generated successfully at assets/icon/app_icon.png');
}
