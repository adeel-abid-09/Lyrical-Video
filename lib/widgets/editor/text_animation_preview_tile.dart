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
  final VoidCallback? onAdjustTap;

  const TextAnimationPreviewTile({
    super.key,
    required this.def,
    required this.isSelected,
    required this.onTap,
    this.onAdjustTap,
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
        return Transform.scale(
          scale: 0.7 + (Curves.easeOut.transform(animProgress) * 0.3),
          child: Opacity(
            opacity: animProgress.clamp(0.1, 1.0),
            child: Text(
              'ABC123',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.white.withOpacity((1.0 - animProgress).clamp(0.0, 1.0)),
                    blurRadius: blurVal,
                  ),
                ],
              ),
            ),
          ),
        );

      case TextAnimationType.popIn:
        final scaleVal = animProgress < 0.6
            ? (animProgress / 0.6) * 1.25
            : 1.25 - ((animProgress - 0.6) / 0.4) * 0.25;
        return Transform.scale(
          scale: scaleVal.clamp(0.0, 1.3),
          child: const Text(
            'ABC123',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        );

      case TextAnimationType.glow:
        final glowAlpha = (sin(animProgress * pi * 2) * 0.5 + 0.5).clamp(0.2, 1.0);
        return Text(
          'ABC123',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: const Color(0xFFFF9800).withOpacity(glowAlpha), blurRadius: 10),
              Shadow(color: const Color(0xFFFF5722).withOpacity(glowAlpha * 0.8), blurRadius: 20),
            ],
          ),
        );

      case TextAnimationType.stamp:
        final scaleVal = animProgress < 0.5 ? 2.2 - (animProgress / 0.5) * 1.2 : 1.0;
        final op = animProgress < 0.2 ? (animProgress / 0.2) : 1.0;
        return Transform.scale(
          scale: scaleVal.clamp(1.0, 2.2),
          child: Opacity(
            opacity: op.clamp(0.0, 1.0),
            child: const Text(
              'ABC123',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        );

      case TextAnimationType.typewriter:
        const fullText = 'ABC123';
        final charCount = (animProgress * (fullText.length + 1)).floor().clamp(0, fullText.length);
        final visibleText = fullText.substring(0, charCount);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              visibleText,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            if (animProgress < 0.95 && animProgress > 0.1)
              Container(width: 2, height: 14, color: const Color(0xFFFF9800)),
          ],
        );

      case TextAnimationType.slideUp:
        final offset = (1.0 - Curves.easeOutCubic.transform(animProgress)) * 25.0;
        final op = animProgress.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, offset),
          child: Opacity(
            opacity: op,
            child: const Text(
              'ABC123',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        );

      case TextAnimationType.slideDown:
        final offset = -(1.0 - Curves.easeOutCubic.transform(animProgress)) * 25.0;
        final op = animProgress.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, offset),
          child: Opacity(
            opacity: op,
            child: const Text(
              'ABC123',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        );

      case TextAnimationType.bounce:
        final bounceT = (animProgress * pi * 3).clamp(0.0, pi * 3);
        final bounceOffset = -sin(bounceT).abs() * 12.0 * (1.0 - animProgress);
        return Transform.translate(
          offset: Offset(0, bounceOffset),
          child: const Text(
            'ABC123',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        );

      case TextAnimationType.zoomIn:
        final scaleVal = Curves.easeOutBack.transform(animProgress);
        return Transform.scale(
          scale: scaleVal.clamp(0.0, 1.0),
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
    const activeColor = Color(0xFFFF9800); // CapCut warm accent orange
    final isNone = widget.def.type == TextAnimationType.none;
    final showAdjustBadge = widget.isSelected && !isNone;

    return GestureDetector(
      onTap: () {
        if (widget.isSelected && !isNone && widget.onAdjustTap != null) {
          widget.onAdjustTap!();
        } else {
          widget.onTap();
        }
      },
      child: Container(
        width: 78,
        height: 54,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: widget.isSelected ? const Color(0xFF282025) : const Color(0xFF222230),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.isSelected ? activeColor : Colors.white12,
            width: widget.isSelected ? 2.0 : 1.0,
          ),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Stack(
          children: [
            ClipRRect(
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
                        color: widget.isSelected ? activeColor : Colors.white70,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // CapCut-style Adjust / Tune Sliders Icon Badge
            if (showAdjustBadge)
              Positioned(
                top: 3,
                right: 3,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    color: activeColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Colors.white,
                    size: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
