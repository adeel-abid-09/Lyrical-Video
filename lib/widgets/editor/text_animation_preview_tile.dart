import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/text_layer_model.dart';

class AnimationDefinition {
  final TextAnimationType type;
  final String name;
  final String sampleText;

  const AnimationDefinition({
    required this.type,
    required this.name,
    this.sampleText = 'ABC123',
  });
}

class TextAnimationRegistry {
  static const List<AnimationDefinition> animations = [
    AnimationDefinition(type: TextAnimationType.none, name: 'None'),
    AnimationDefinition(type: TextAnimationType.fadeIn, name: 'Fade In'),
    AnimationDefinition(type: TextAnimationType.blurIn, name: 'Concentrate'),
    AnimationDefinition(type: TextAnimationType.popIn, name: 'Letter Pop-In'),
    AnimationDefinition(type: TextAnimationType.glow, name: 'Phantasm Glow'),
    AnimationDefinition(type: TextAnimationType.stamp, name: 'Shell Stamp'),
    AnimationDefinition(type: TextAnimationType.typewriter, name: 'Letter Reveal'),
    AnimationDefinition(type: TextAnimationType.slideUp, name: 'Slide Up'),
    AnimationDefinition(type: TextAnimationType.slideDown, name: 'Slide Down'),
    AnimationDefinition(type: TextAnimationType.bounce, name: 'Bounce In'),
    AnimationDefinition(type: TextAnimationType.zoomIn, name: 'Zoom In'),
    AnimationDefinition(type: TextAnimationType.wave, name: 'Wave Flip'),
  ];
}

/// CapCut-style Animated Preview Card for Horizontal Toolbars.
class TextAnimationPreviewTile extends StatefulWidget {
  final AnimationDefinition def;
  final bool isSelected;
  final VoidCallback onTap;

  const TextAnimationPreviewTile({
    super.key,
    required this.def,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<TextAnimationPreviewTile> createState() => _TextAnimationPreviewTileState();
}

class _TextAnimationPreviewTileState extends State<TextAnimationPreviewTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.def.type != TextAnimationType.none) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildAnimatedContent(double t) {
    final type = widget.def.type;
    // Animation phases: 0.0 - 0.70 is active animation, 0.70 - 1.0 is hold pause
    final animProgress = (t / 0.70).clamp(0.0, 1.0);

    switch (type) {
      case TextAnimationType.none:
        return const Center(
          child: Icon(Icons.do_not_disturb_alt_rounded, color: Colors.white54, size: 24),
        );

      case TextAnimationType.fadeIn:
        return Opacity(
          opacity: Curves.easeIn.transform(animProgress),
          child: const Text(
            'ABC123',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        );

      case TextAnimationType.blurIn:
        final blurVal = (1.0 - Curves.easeOut.transform(animProgress)) * 5.0;
        final scaleVal = 0.7 + (Curves.easeOut.transform(animProgress) * 0.3);
        return Transform.scale(
          scale: scaleVal,
          child: Opacity(
            opacity: animProgress.clamp(0.1, 1.0),
            child: Text(
              'ABC123',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                shadows: blurVal > 0.5
                    ? [
                        Shadow(color: Colors.white70, blurRadius: blurVal * 3),
                        Shadow(color: Colors.white, blurRadius: blurVal * 6),
                      ]
                    : null,
              ),
            ),
          ),
        );

      case TextAnimationType.popIn:
        final scale = animProgress < 0.8
            ? (animProgress / 0.8) * 1.25
            : 1.25 - ((animProgress - 0.8) / 0.2) * 0.25;
        return Transform.scale(
          scale: scale.clamp(0.01, 1.3),
          child: const Text(
            'ABC123',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        );

      case TextAnimationType.glow:
        final glowRadius = (sin(t * pi * 3).abs() * 10.0) + 2.0;
        return Text(
          'ABC123',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.white, blurRadius: glowRadius),
              Shadow(color: const Color(0xFF00E5FF), blurRadius: glowRadius * 1.5),
            ],
          ),
        );

      case TextAnimationType.stamp:
        // Shell stamp: drops fast from huge scale down to 1.0 with shake impact
        final stampScale = animProgress < 0.6
            ? 2.2 - (Curves.easeInQuad.transform(animProgress / 0.6) * 1.2)
            : 1.0;
        return Transform.scale(
          scale: stampScale,
          child: const Text(
            'ABC123',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        );

      case TextAnimationType.typewriter:
        final text = widget.def.sampleText;
        final count = (text.length * animProgress).clamp(1, text.length).toInt();
        final revealed = text.substring(0, count);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              revealed,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            if (animProgress < 0.95 && (t * 10).toInt() % 2 == 0)
              Container(width: 2, height: 14, color: const Color(0xFF00E5FF), margin: const EdgeInsets.only(left: 1)),
          ],
        );

      case TextAnimationType.slideUp:
        final dy = (1.0 - Curves.easeOutCubic.transform(animProgress)) * 24.0;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Opacity(
            opacity: animProgress,
            child: const Text(
              'ABC123',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        );

      case TextAnimationType.slideDown:
        final dy = -(1.0 - Curves.easeOutCubic.transform(animProgress)) * 24.0;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Opacity(
            opacity: animProgress,
            child: const Text(
              'ABC123',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        );

      case TextAnimationType.bounce:
        final bounceCurve = Curves.bounceOut.transform(animProgress);
        final dy = (1.0 - bounceCurve) * -22.0;
        return Transform.translate(
          offset: Offset(0, dy),
          child: const Text(
            'ABC123',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        );

      case TextAnimationType.zoomIn:
        final zoom = Curves.easeOutBack.transform(animProgress);
        return Transform.scale(
          scale: zoom.clamp(0.01, 1.2),
          child: const Text(
            'ABC123',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        );

      case TextAnimationType.wave:
        final angle = sin(animProgress * pi * 2) * 0.15;
        return Transform.rotate(
          angle: angle,
          child: const Text(
            'ABC123',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 78,
        height: 54,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF222230),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.isSelected ? const Color(0xFF00E5FF) : Colors.white12,
            width: widget.isSelected ? 2.0 : 1.0,
          ),
          boxShadow: widget.isSelected
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated preview viewport
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => _buildAnimatedContent(_controller.value),
                  ),
                ),
              ),
              // Name label
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(bottom: 3),
                alignment: Alignment.center,
                child: Text(
                  widget.def.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isSelected ? const Color(0xFF00E5FF) : Colors.white70,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
