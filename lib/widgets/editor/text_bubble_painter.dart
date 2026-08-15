import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/text_layer_model.dart';

class TextBubbleDefinition {
  final String id;
  final String name;
  final String sampleText;
  final Color defaultTextColor;
  final Color? defaultStrokeColor;
  final double defaultStrokeWidth;
  final Color defaultBgColor;

  const TextBubbleDefinition({
    required this.id,
    required this.name,
    required this.sampleText,
    this.defaultTextColor = Colors.black,
    this.defaultStrokeColor,
    this.defaultStrokeWidth = 0.0,
    this.defaultBgColor = Colors.white,
  });
}

class TextBubbleRegistry {
  static const List<TextBubbleDefinition> bubbles = [
    TextBubbleDefinition(
      id: 'none',
      name: 'None',
      sampleText: 'None',
      defaultTextColor: Colors.white,
      defaultBgColor: Colors.transparent,
    ),
    TextBubbleDefinition(
      id: 'note_paper',
      name: 'Note Paper',
      sampleText: 'What a\nnice day',
      defaultTextColor: Colors.black87,
      defaultBgColor: Color(0xFFFDFBF7),
    ),
    TextBubbleDefinition(
      id: 'polka_dot',
      name: 'Polka Dots',
      sampleText: 'Don\'t worry\nbe happy',
      defaultTextColor: Colors.black,
      defaultBgColor: Colors.white,
    ),
    TextBubbleDefinition(
      id: 'speech_white',
      name: 'Comic Speech',
      sampleText: 'I love you\njust the way\nyou are',
      defaultTextColor: Colors.black,
      defaultBgColor: Colors.white,
    ),
    TextBubbleDefinition(
      id: 'cloud',
      name: 'Cloud Bubble',
      sampleText: 'Good\nMorning.',
      defaultTextColor: Colors.black,
      defaultBgColor: Colors.white,
    ),
    TextBubbleDefinition(
      id: 'radial_glow',
      name: 'Big News',
      sampleText: 'Big\nNews\n!!!',
      defaultTextColor: Colors.black,
      defaultBgColor: Colors.white,
    ),
    TextBubbleDefinition(
      id: 'polka_circle',
      name: 'Dot Circle',
      sampleText: 'Be the\nbest you\ncan be',
      defaultTextColor: Colors.black,
      defaultBgColor: Colors.white,
    ),
    TextBubbleDefinition(
      id: 'comic_burst',
      name: 'BAM Burst',
      sampleText: 'BAM!!!',
      defaultTextColor: Colors.black,
      defaultStrokeColor: Colors.black,
      defaultStrokeWidth: 1.0,
      defaultBgColor: Colors.white,
    ),
    TextBubbleDefinition(
      id: 'speech_dark',
      name: 'Dark Hero',
      sampleText: 'Old\nsuperheroes\ndon\'t fade\naway',
      defaultTextColor: Colors.white,
      defaultBgColor: Colors.black,
    ),
    TextBubbleDefinition(
      id: 'dark_mesh',
      name: 'Comic Noir',
      sampleText: 'With great\npower comes\ngreat\nresponsibility',
      defaultTextColor: Colors.white,
      defaultBgColor: Colors.black,
    ),
    TextBubbleDefinition(
      id: 'crystal_dark',
      name: 'Crystal Dark',
      sampleText: 'It\'s all\nin our\nheads',
      defaultTextColor: Colors.white,
      defaultBgColor: Color(0xFF111118),
    ),
    TextBubbleDefinition(
      id: 'torn_paper',
      name: 'Torn Paper',
      sampleText: 'Missing you',
      defaultTextColor: Color(0xFF5D5348),
      defaultBgColor: Color(0xFFE8E0D5),
    ),
    TextBubbleDefinition(
      id: 'kraft_paper',
      name: 'Kraft Scrap',
      sampleText: 'You\'re my\nsweetheart',
      defaultTextColor: Color(0xFF4A4036),
      defaultBgColor: Color(0xFFDCCBB5),
    ),
    TextBubbleDefinition(
      id: 'sale_tag',
      name: 'Sale Tag',
      sampleText: 'SALE\n20% OFF',
      defaultTextColor: Colors.black,
      defaultBgColor: Colors.white,
    ),
    TextBubbleDefinition(
      id: 'arrow_badge',
      name: 'Arrow Pill',
      sampleText: 'Sneakers ➔',
      defaultTextColor: Colors.white,
      defaultBgColor: Colors.black,
    ),
    TextBubbleDefinition(
      id: 'gold_bar',
      name: 'Sparkle Bar',
      sampleText: '♥ Select again ♥',
      defaultTextColor: Color(0xFF8A6200),
      defaultBgColor: Color(0xFFFFECC0),
    ),
    TextBubbleDefinition(
      id: 'capsule_clean',
      name: 'Pill Capsule',
      sampleText: 'Beautiful day',
      defaultTextColor: Color(0xFF333333),
      defaultBgColor: Color(0xFFF9F7F2),
    ),
    TextBubbleDefinition(
      id: 'two_tone_tag',
      name: 'Travel Plan',
      sampleText: 'Travel plan',
      defaultTextColor: Color(0xFF7A583A),
      defaultBgColor: Color(0xFFF4EBD9),
    ),
    TextBubbleDefinition(
      id: 'blue_card',
      name: 'Journey Card',
      sampleText: 'My journey',
      defaultTextColor: Color(0xFF0091EA),
      defaultBgColor: Colors.white,
    ),
    TextBubbleDefinition(
      id: 'ribbon_banner',
      name: 'Sunny Ribbon',
      sampleText: 'Sunny day',
      defaultTextColor: Colors.white,
      defaultBgColor: Color(0xFFFF7043),
    ),
  ];

  static TextBubbleDefinition? get(String? id) {
    if (id == null || id == 'none') return null;
    return bubbles.where((b) => b.id == id).firstOrNull;
  }
}

/// Custom painter for drawing decorative bubble shapes on Canvas (both preview, canvas, & export).
class BubbleShapePainter extends CustomPainter {
  final String styleId;
  final Color? customColor;
  final bool isPreview;

  BubbleShapePainter({
    required this.styleId,
    this.customColor,
    this.isPreview = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (styleId == 'none') return;
    paintBubbleOnCanvas(canvas, Rect.fromLTWH(0, 0, size.width, size.height), styleId, customColor: customColor);
  }

  @override
  bool shouldRepaint(covariant BubbleShapePainter oldDelegate) {
    return oldDelegate.styleId != styleId || oldDelegate.customColor != customColor;
  }

  /// Master static drawing function shared by Widget Painter and FFmpeg Image Generation!
  static void paintBubbleOnCanvas(Canvas canvas, Rect rect, String styleId, {Color? customColor}) {
    final w = rect.width;
    final h = rect.height;
    final x = rect.left;
    final y = rect.top;

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (styleId) {
      case 'note_paper':
        // White square note with slight curl on bottom-right
        fillPaint.color = customColor ?? const Color(0xFFFDFBF7);
        strokePaint.color = Colors.black.withOpacity(0.8);
        strokePaint.strokeWidth = 2.0;

        final path = Path();
        path.moveTo(x + 4, y + 4);
        path.lineTo(x + w - 4, y + 4);
        path.lineTo(x + w - 4, y + h - 16);
        path.quadraticBezierTo(x + w - 4, y + h - 4, x + w - 16, y + h - 4);
        path.lineTo(x + 12, y + h - 4);
        path.quadraticBezierTo(x + 4, y + h - 4, x + 4, y + h - 16);
        path.close();

        // Shadow
        canvas.drawShadow(path, Colors.black.withOpacity(0.3), 4.0, true);
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);

        // Fold line bottom right
        final foldPath = Path();
        foldPath.moveTo(x + w - 16, y + h - 4);
        foldPath.lineTo(x + w - 16, y + h - 16);
        foldPath.lineTo(x + w - 4, y + h - 16);
        strokePaint.strokeWidth = 1.5;
        canvas.drawPath(foldPath, strokePaint);
        break;

      case 'speech_white':
        // Classic comic speech bubble with tail
        fillPaint.color = customColor ?? Colors.white;
        strokePaint.color = Colors.black;
        strokePaint.strokeWidth = 2.5;

        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 4, y + 4, w - 8, h - 16),
          const Radius.circular(16),
        );
        final path = Path()..addRRect(rrect);

        // Add tail at bottom-left
        final tail = Path();
        tail.moveTo(x + 20, y + h - 16);
        tail.lineTo(x + 10, y + h - 2);
        tail.lineTo(x + 36, y + h - 16);
        tail.close();

        final combined = Path.combine(PathOperation.union, path, tail);
        canvas.drawPath(combined, fillPaint);
        canvas.drawPath(combined, strokePaint);
        break;

      case 'speech_dark':
        // Black sleek comic bubble with tail
        fillPaint.color = customColor ?? Colors.black;
        strokePaint.color = Colors.white24;
        strokePaint.strokeWidth = 1.0;

        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 4, y + 4, w - 8, h - 16),
          const Radius.circular(18),
        );
        final path = Path()..addRRect(rrect);

        final tail = Path();
        tail.moveTo(x + 24, y + h - 16);
        tail.lineTo(x + 14, y + h - 2);
        tail.lineTo(x + 40, y + h - 16);
        tail.close();

        final combined = Path.combine(PathOperation.union, path, tail);
        canvas.drawShadow(combined, Colors.black.withOpacity(0.5), 6.0, true);
        canvas.drawPath(combined, fillPaint);
        canvas.drawPath(combined, strokePaint);
        break;

      case 'comic_burst':
        // BAM! Explosion burst with sharp spikes
        fillPaint.color = customColor ?? Colors.white;
        strokePaint.color = Colors.black;
        strokePaint.strokeWidth = 2.5;

        final path = Path();
        const numPoints = 14;
        final cx = x + w / 2;
        final cy = y + h / 2;
        final rx = (w - 8) / 2;
        final ry = (h - 8) / 2;

        for (int i = 0; i < numPoints * 2; i++) {
          final angle = (i * math.pi) / numPoints;
          final isSpike = i % 2 == 0;
          final rFactorX = isSpike ? 1.0 : 0.65;
          final rFactorY = isSpike ? 1.0 : 0.65;
          final px = cx + math.cos(angle) * (rx * rFactorX);
          final py = cy + math.sin(angle) * (ry * rFactorY);
          if (i == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        path.close();

        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;

      case 'cloud':
        // Scalloped cloud bubble
        fillPaint.color = customColor ?? Colors.white;
        strokePaint.color = Colors.black;
        strokePaint.strokeWidth = 2.5;

        final path = Path();
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 8, y + 8, w - 16, h - 16),
          const Radius.circular(20),
        );
        path.addRRect(rrect);

        // Draw cloud scalloped lobes
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);

        // Little circles around for cloud feel
        final dotPaint = Paint()
          ..color = customColor ?? Colors.white
          ..style = PaintingStyle.fill;
        final dotStroke = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        canvas.drawCircle(Offset(x + 12, y + h - 6), 4, dotPaint);
        canvas.drawCircle(Offset(x + 12, y + h - 6), 4, dotStroke);
        canvas.drawCircle(Offset(x + 6, y + h - 2), 2.5, dotPaint);
        canvas.drawCircle(Offset(x + 6, y + h - 2), 2.5, dotStroke);
        break;

      case 'polka_dot':
      case 'polka_circle':
        // Rounded oval speech with polka dots along border
        fillPaint.color = customColor ?? Colors.white;
        strokePaint.color = Colors.black;
        strokePaint.strokeWidth = 2.0;

        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 8, y + 6, w - 16, h - 18),
          const Radius.circular(22),
        );
        final path = Path()..addRRect(rrect);
        final tail = Path()
          ..moveTo(x + w / 2 - 8, y + h - 18)
          ..lineTo(x + w / 2, y + h - 4)
          ..lineTo(x + w / 2 + 8, y + h - 18)
          ..close();

        final combined = Path.combine(PathOperation.union, path, tail);
        canvas.drawPath(combined, fillPaint);
        canvas.drawPath(combined, strokePaint);

        // Draw decorative black polka dots around inside margin
        final dotP = Paint()..color = Colors.black87;
        const dotRadius = 1.8;
        for (double dx = x + 16; dx < x + w - 16; dx += 12) {
          canvas.drawCircle(Offset(dx, y + 12), dotRadius, dotP);
          canvas.drawCircle(Offset(dx, y + h - 24), dotRadius, dotP);
        }
        break;

      case 'radial_glow':
        // White ellipse with radiating black speed lines
        final linePaint = Paint()
          ..color = Colors.black87
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

        final cx = x + w / 2;
        final cy = y + h / 2;
        const numLines = 28;
        for (int i = 0; i < numLines; i++) {
          final angle = (i * 2 * math.pi) / numLines;
          final p1x = cx + math.cos(angle) * (w / 2 - 12);
          final p1y = cy + math.sin(angle) * (h / 2 - 8);
          final p2x = cx + math.cos(angle) * (w / 2 - 2);
          final p2y = cy + math.sin(angle) * (h / 2 - 2);
          canvas.drawLine(Offset(p1x, p1y), Offset(p2x, p2y), linePaint);
        }

        fillPaint.color = customColor ?? Colors.white;
        strokePaint.color = Colors.black;
        strokePaint.strokeWidth = 2.0;

        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 10, y + 8, w - 20, h - 16),
          const Radius.circular(16),
        );
        canvas.drawRRect(rrect, fillPaint);
        canvas.drawRRect(rrect, strokePaint);
        break;

      case 'dark_mesh':
        // Noir comic speech with dotted background shading
        fillPaint.color = customColor ?? Colors.black;
        strokePaint.color = Colors.white70;
        strokePaint.strokeWidth = 1.5;

        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 4, y + 4, w - 8, h - 16),
          const Radius.circular(18),
        );
        final path = Path()..addRRect(rrect);
        final tail = Path()
          ..moveTo(x + w - 24, y + h - 16)
          ..lineTo(x + w - 12, y + h - 2)
          ..lineTo(x + w - 38, y + h - 16)
          ..close();

        final combined = Path.combine(PathOperation.union, path, tail);
        canvas.drawPath(combined, fillPaint);
        canvas.drawPath(combined, strokePaint);

        // Dot pattern
        final dotP = Paint()..color = Colors.white24;
        for (double px = x + 12; px < x + w - 12; px += 8) {
          for (double py = y + 10; py < y + h - 22; py += 8) {
            canvas.drawCircle(Offset(px, py), 1.0, dotP);
          }
        }
        break;

      case 'crystal_dark':
        // Faceted crystal polygon
        fillPaint.color = customColor ?? const Color(0xFF161622);
        strokePaint.color = const Color(0xFF00E5FF).withOpacity(0.6);
        strokePaint.strokeWidth = 1.5;

        final path = Path();
        const cornerCut = 12.0;
        path.moveTo(x + cornerCut, y + 4);
        path.lineTo(x + w - cornerCut, y + 4);
        path.lineTo(x + w - 4, y + cornerCut);
        path.lineTo(x + w - 4, y + h - cornerCut);
        path.lineTo(x + w - cornerCut, y + h - 4);
        path.lineTo(x + cornerCut, y + h - 4);
        path.lineTo(x + 4, y + h - cornerCut);
        path.lineTo(x + 4, y + cornerCut);
        path.close();

        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;

      case 'torn_paper':
      case 'kraft_paper':
        // Realistic torn paper strip with jagged edges
        fillPaint.color = customColor ?? (styleId == 'kraft_paper' ? const Color(0xFFDCCBB5) : const Color(0xFFE8E0D5));
        strokePaint.color = (styleId == 'kraft_paper' ? const Color(0xFF9E846A) : const Color(0xFFB0A494));
        strokePaint.strokeWidth = 1.0;

        final path = Path();
        path.moveTo(x + 4, y + 6);
        // Jagged top edge
        const step = 8.0;
        for (double dx = x + 4; dx <= x + w - 4; dx += step) {
          final offset = ((dx ~/ step) % 2 == 0) ? -2.5 : 2.5;
          path.lineTo(dx, y + 6 + offset);
        }
        path.lineTo(x + w - 4, y + h - 6);
        // Jagged bottom edge
        for (double dx = x + w - 4; dx >= x + 4; dx -= step) {
          final offset = ((dx ~/ step) % 2 == 0) ? 2.5 : -2.5;
          path.lineTo(dx, y + h - 6 + offset);
        }
        path.close();

        canvas.drawShadow(path, Colors.black.withOpacity(0.3), 4.0, true);
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;

      case 'sale_tag':
        // Coupon / Shopping price tag with barcode & SALE notch
        fillPaint.color = customColor ?? Colors.white;
        strokePaint.color = Colors.black87;
        strokePaint.strokeWidth = 1.5;

        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 4, y + 4, w - 8, h - 8),
          const Radius.circular(8),
        );
        canvas.drawRRect(rrect, fillPaint);
        canvas.drawRRect(rrect, strokePaint);

        // Yellow SALE badge tab on top-left
        final badgePaint = Paint()..color = const Color(0xFFFFD600);
        final badgePath = Path()
          ..moveTo(x + 4, y + 4)
          ..lineTo(x + 36, y + 4)
          ..lineTo(x + 28, y + 18)
          ..lineTo(x + 4, y + 18)
          ..close();
        canvas.drawPath(badgePath, badgePaint);

        // Mini barcode lines on right
        final barP = Paint()
          ..color = Colors.black45
          ..strokeWidth = 1.5;
        for (double bx = x + w - 18; bx <= x + w - 8; bx += 3) {
          canvas.drawLine(Offset(bx, y + 10), Offset(bx, y + h - 10), barP);
        }
        break;

      case 'arrow_badge':
        // Black pill with curved arrow
        fillPaint.color = customColor ?? Colors.black;
        strokePaint.color = Colors.white38;
        strokePaint.strokeWidth = 1.5;

        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 4, y + 6, w - 18, h - 12),
          const Radius.circular(16),
        );
        canvas.drawRRect(rrect, fillPaint);
        canvas.drawRRect(rrect, strokePaint);

        // Arrow loop on right
        final arrowPaint = Paint()
          ..color = customColor ?? Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        final arrowPath = Path();
        arrowPath.moveTo(x + w - 18, y + h / 2);
        arrowPath.quadraticBezierTo(x + w - 4, y + h / 2 - 8, x + w - 4, y + h / 2 - 12);
        canvas.drawPath(arrowPath, arrowPaint);

        // Arrow head
        final headPaint = Paint()..color = customColor ?? Colors.white;
        final head = Path()
          ..moveTo(x + w - 8, y + h / 2 - 10)
          ..lineTo(x + w - 4, y + h / 2 - 16)
          ..lineTo(x + w, y + h / 2 - 10)
          ..close();
        canvas.drawPath(head, headPaint);
        break;

      case 'gold_bar':
        // Sparkling yellow/gold bar with hearts
        fillPaint.color = customColor ?? const Color(0xFFFFECC0);
        strokePaint.color = const Color(0xFFFFB300);
        strokePaint.strokeWidth = 2.0;

        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 4, y + 6, w - 8, h - 12),
          const Radius.circular(14),
        );
        canvas.drawRRect(rrect, fillPaint);
        canvas.drawRRect(rrect, strokePaint);

        // Heart on left and right
        final heartP = Paint()..color = const Color(0xFFFF8F00);
        canvas.drawCircle(Offset(x + 14, y + h / 2), 3, heartP);
        canvas.drawCircle(Offset(x + w - 14, y + h / 2), 3, heartP);
        break;

      case 'capsule_clean':
        fillPaint.color = customColor ?? const Color(0xFFF9F7F2);
        strokePaint.color = Colors.black54;
        strokePaint.strokeWidth = 1.5;

        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 4, y + 6, w - 8, h - 12),
          const Radius.circular(20),
        );
        canvas.drawRRect(rrect, fillPaint);
        canvas.drawRRect(rrect, strokePaint);
        break;

      case 'two_tone_tag':
        fillPaint.color = customColor ?? const Color(0xFFF4EBD9);
        strokePaint.color = const Color(0xFF8D6E63);
        strokePaint.strokeWidth = 1.5;

        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 4, y + 4, w - 8, h - 14),
          const Radius.circular(8),
        );
        canvas.drawRRect(rrect, fillPaint);
        canvas.drawRRect(rrect, strokePaint);

        // Bottom sub-badge
        final subP = Paint()..color = const Color(0xFF8D6E63);
        final subRRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + w / 2 - 20, y + h - 14, 40, 10),
          const Radius.circular(5),
        );
        canvas.drawRRect(subRRect, subP);
        break;

      case 'blue_card':
        fillPaint.color = customColor ?? Colors.white;
        strokePaint.color = const Color(0xFF00B0FF);
        strokePaint.strokeWidth = 2.0;

        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 4, y + 4, w - 8, h - 8),
          const Radius.circular(8),
        );
        canvas.drawRRect(rrect, fillPaint);
        canvas.drawRRect(rrect, strokePaint);
        break;

      case 'ribbon_banner':
        // Curved orange banner with fishtail ends
        fillPaint.color = customColor ?? const Color(0xFFFF7043);
        strokePaint.color = const Color(0xFFD84315);
        strokePaint.strokeWidth = 1.5;

        final path = Path();
        path.moveTo(x + 16, y + 6);
        path.lineTo(x + w - 16, y + 6);
        path.lineTo(x + w - 4, y + 14);
        path.lineTo(x + w - 16, y + h - 6);
        path.lineTo(x + 16, y + h - 6);
        path.lineTo(x + 4, y + h / 2);
        path.close();

        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;

      default:
        // Default rounded box if unknown
        fillPaint.color = customColor ?? Colors.white;
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 4, y + 4, w - 8, h - 8),
          const Radius.circular(12),
        );
        canvas.drawRRect(rrect, fillPaint);
        break;
    }
  }
}

/// Mini visual preview tile for the horizontal toolbar picker!
class TextBubblePreviewTile extends StatelessWidget {
  final TextBubbleDefinition def;
  final bool isSelected;
  final VoidCallback onTap;

  const TextBubblePreviewTile({
    super.key,
    required this.def,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 78,
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF232330),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF00E5FF) : Colors.white12,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.35),
                    blurRadius: 6,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (def.id == 'none')
                const Center(
                  child: Icon(Icons.do_not_disturb_alt_rounded, color: Colors.white54, size: 24),
                )
              else ...[
                // The actual mini bubble drawing
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: CustomPaint(
                      painter: BubbleShapePainter(
                        styleId: def.id,
                        isPreview: true,
                      ),
                    ),
                  ),
                ),
                // Mini sample text inside the preview
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 4.0),
                  child: Text(
                    def.sampleText,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: def.defaultTextColor,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      height: 1.05,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
