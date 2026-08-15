import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/text_layer_model.dart';

class TextTemplateDefinition {
  final String id;
  final String name;
  final Color textColor;
  final Color? strokeColor;
  final double strokeWidth;
  final Color? backgroundColor;
  final String fontFamily;
  final TextAnimationType animation;
  final String sampleText;

  const TextTemplateDefinition({
    required this.id,
    required this.name,
    required this.textColor,
    this.strokeColor,
    this.strokeWidth = 2.0,
    this.backgroundColor,
    required this.fontFamily,
    required this.animation,
    this.sampleText = 'Aa1',
  });
}

class TextTemplateRegistry {
  static const List<TextTemplateDefinition> templates = [
    TextTemplateDefinition(
      id: 'none',
      name: 'None',
      textColor: Colors.white,
      fontFamily: 'Outfit',
      animation: TextAnimationType.none,
      sampleText: 'None',
    ),
    TextTemplateDefinition(
      id: 'cyber_glow',
      name: 'Cyber Glow',
      textColor: Color(0xFF00FFFF),
      strokeColor: Color(0xFFFF007F),
      strokeWidth: 2.5,
      fontFamily: 'Bebas Neue',
      animation: TextAnimationType.glow,
      sampleText: 'CYBER',
    ),
    TextTemplateDefinition(
      id: 'typewriter',
      name: 'Typewriter',
      textColor: Colors.white,
      strokeColor: Colors.black,
      strokeWidth: 1.5,
      fontFamily: 'Roboto',
      animation: TextAnimationType.typewriter,
      sampleText: 'TYPE',
    ),
    TextTemplateDefinition(
      id: 'royal_gold',
      name: 'Royal Gold',
      textColor: Color(0xFFFFD700),
      strokeColor: Color(0xFFD35400),
      strokeWidth: 2.0,
      fontFamily: 'Playfair Display',
      animation: TextAnimationType.blurIn,
      sampleText: 'GOLD',
    ),
    TextTemplateDefinition(
      id: 'vlog_punch',
      name: 'Vlog Yellow',
      textColor: Colors.black,
      backgroundColor: Color(0xFFFFEB3B),
      fontFamily: 'Outfit',
      animation: TextAnimationType.popIn,
      sampleText: 'VLOG',
    ),
    TextTemplateDefinition(
      id: 'stamp_action',
      name: 'Red Stamp',
      textColor: Color(0xFFFF1744),
      strokeColor: Colors.black,
      strokeWidth: 2.5,
      fontFamily: 'Anton',
      animation: TextAnimationType.stamp,
      sampleText: 'STAMP',
    ),
    TextTemplateDefinition(
      id: 'dreamy_violet',
      name: 'Dreamy Wave',
      textColor: Color(0xFFE1BEE7),
      strokeColor: Color(0xFF8E24AA),
      strokeWidth: 2.0,
      fontFamily: 'Pacifico',
      animation: TextAnimationType.wave,
      sampleText: 'Dream',
    ),
    TextTemplateDefinition(
      id: 'cinema_sub',
      name: 'Cinema Fade',
      textColor: Colors.white,
      strokeColor: Color(0xCC000000),
      strokeWidth: 1.5,
      fontFamily: 'Cinzel',
      animation: TextAnimationType.fadeIn,
      sampleText: 'CINEMA',
    ),
    TextTemplateDefinition(
      id: 'retro_slide',
      name: 'Retro Sunset',
      textColor: Color(0xFFFF6E40),
      strokeColor: Color(0xFF1A237E),
      strokeWidth: 2.0,
      fontFamily: 'Montserrat',
      animation: TextAnimationType.slideUp,
      sampleText: 'RETRO',
    ),
    TextTemplateDefinition(
      id: 'matrix_tech',
      name: 'Matrix Code',
      textColor: Color(0xFF00E676),
      strokeColor: Color(0xFF004D40),
      strokeWidth: 2.0,
      fontFamily: 'Orbitron',
      animation: TextAnimationType.typewriter,
      sampleText: 'MATRIX',
    ),
    TextTemplateDefinition(
      id: 'bubble_pop',
      name: 'Bubble Pop',
      textColor: Color(0xFFFF4081),
      strokeColor: Color(0xFF00E5FF),
      strokeWidth: 2.0,
      fontFamily: 'Pacifico',
      animation: TextAnimationType.bounce,
      sampleText: 'POP',
    ),
    TextTemplateDefinition(
      id: 'headline_black',
      name: 'Headline',
      textColor: Colors.white,
      backgroundColor: Color(0xFF111111),
      fontFamily: 'Bebas Neue',
      animation: TextAnimationType.slideDown,
      sampleText: 'NEWS',
    ),
    TextTemplateDefinition(
      id: 'urban_glitch',
      name: 'Urban Glitch',
      textColor: Color(0xFF00E5FF),
      strokeColor: Color(0xFFD500F9),
      strokeWidth: 2.5,
      fontFamily: 'Anton',
      animation: TextAnimationType.popIn,
      sampleText: 'URBAN',
    ),
    TextTemplateDefinition(
      id: 'cozy_romance',
      name: 'Cozy Romance',
      textColor: Color(0xFFFFCDD2),
      strokeColor: Color(0xFF880E4F),
      strokeWidth: 1.5,
      fontFamily: 'Playfair Display',
      animation: TextAnimationType.fadeIn,
      sampleText: 'Love',
    ),
    TextTemplateDefinition(
      id: 'speed_lime',
      name: 'Speed Wave',
      textColor: Color(0xFFEEFF41),
      strokeColor: Colors.black,
      strokeWidth: 2.5,
      fontFamily: 'Montserrat',
      animation: TextAnimationType.wave,
      sampleText: 'SPEED',
    ),
    TextTemplateDefinition(
      id: 'diamond_zoom',
      name: 'Diamond Zoom',
      textColor: Colors.white,
      strokeColor: Color(0xFF00B0FF),
      strokeWidth: 2.0,
      fontFamily: 'Outfit',
      animation: TextAnimationType.zoomIn,
      sampleText: 'SHINE',
    ),
  ];
}

/// CapCut-style Animated Preview Card for Text Templates in Horizontal Toolbars.
class TextTemplatePreviewTile extends StatefulWidget {
  final TextTemplateDefinition def;
  final bool isSelected;
  final VoidCallback onTap;

  const TextTemplatePreviewTile({
    super.key,
    required this.def,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<TextTemplatePreviewTile> createState() => _TextTemplatePreviewTileState();
}

class _TextTemplatePreviewTileState extends State<TextTemplatePreviewTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.def.animation != TextAnimationType.none) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildLiveAnimatedText(double t) {
    final def = widget.def;
    final animProgress = (t / 0.70).clamp(0.0, 1.0);

    if (def.id == 'none') {
      return const Center(
        child: Icon(Icons.do_not_disturb_alt_rounded, color: Colors.white54, size: 22),
      );
    }

    String currentText = def.sampleText;
    double currentOpacity = 1.0;
    double currentScale = 1.0;
    double currentDy = 0.0;
    double currentRotate = 0.0;
    List<Shadow>? dynamicShadows;

    if (def.strokeColor != null) {
      dynamicShadows = [
        Shadow(color: def.strokeColor!, blurRadius: def.strokeWidth * 1.5),
        Shadow(color: def.strokeColor!, offset: const Offset(0.8, 0.8)),
        Shadow(color: def.strokeColor!, offset: const Offset(-0.8, -0.8)),
      ];
    }

    switch (def.animation) {
      case TextAnimationType.none:
        break;

      case TextAnimationType.fadeIn:
        currentOpacity = Curves.easeIn.transform(animProgress);
        break;

      case TextAnimationType.blurIn:
        final b = (1.0 - Curves.easeOut.transform(animProgress)) * 4.0;
        currentScale = 0.7 + (Curves.easeOut.transform(animProgress) * 0.3);
        currentOpacity = animProgress.clamp(0.1, 1.0);
        if (b > 0.3) {
          dynamicShadows = [
            Shadow(color: def.textColor.withOpacity(0.8), blurRadius: b * 3),
            Shadow(color: def.strokeColor ?? Colors.white, blurRadius: b * 6),
          ];
        }
        break;

      case TextAnimationType.popIn:
        currentScale = animProgress < 0.8
            ? (animProgress / 0.8) * 1.25
            : 1.25 - ((animProgress - 0.8) / 0.2) * 0.25;
        break;

      case TextAnimationType.glow:
        final glowR = (sin(t * pi * 3).abs() * 8.0) + 1.5;
        dynamicShadows = [
          Shadow(color: def.textColor, blurRadius: glowR),
          Shadow(color: def.strokeColor ?? Colors.white, blurRadius: glowR * 1.5),
        ];
        break;

      case TextAnimationType.stamp:
        currentScale = animProgress < 0.6
            ? 2.2 - (Curves.easeInQuad.transform(animProgress / 0.6) * 1.2)
            : 1.0;
        break;

      case TextAnimationType.typewriter:
        final count = (def.sampleText.length * animProgress).clamp(1, def.sampleText.length).toInt();
        currentText = def.sampleText.substring(0, count);
        break;

      case TextAnimationType.slideUp:
        currentDy = (1.0 - Curves.easeOutCubic.transform(animProgress)) * 18.0;
        currentOpacity = animProgress;
        break;

      case TextAnimationType.slideDown:
        currentDy = -(1.0 - Curves.easeOutCubic.transform(animProgress)) * 18.0;
        currentOpacity = animProgress;
        break;

      case TextAnimationType.bounce:
        final b = Curves.bounceOut.transform(animProgress);
        currentDy = (1.0 - b) * -16.0;
        break;

      case TextAnimationType.zoomIn:
        currentScale = Curves.easeOutBack.transform(animProgress).clamp(0.01, 1.2);
        break;

      case TextAnimationType.wave:
        currentRotate = sin(animProgress * pi * 2) * 0.14;
        break;
    }

    final baseStyle = TextStyle(
      color: def.textColor,
      fontWeight: FontWeight.bold,
      fontSize: 12.0,
      letterSpacing: 0.5,
      shadows: dynamicShadows,
    );

    Widget textWidget;
    try {
      textWidget = Text(currentText, style: GoogleFonts.getFont(def.fontFamily, textStyle: baseStyle), maxLines: 1);
    } catch (_) {
      textWidget = Text(currentText, style: baseStyle, maxLines: 1);
    }

    if (def.backgroundColor != null) {
      textWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: def.backgroundColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: textWidget,
      );
    }

    return Transform.translate(
      offset: Offset(0, currentDy),
      child: Transform.rotate(
        angle: currentRotate,
        child: Transform.scale(
          scale: currentScale.clamp(0.01, 1.8),
          child: Opacity(
            opacity: currentOpacity.clamp(0.0, 1.0),
            child: textWidget,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 86,
        height: 54,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C),
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
              // Live animated text area
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => _buildLiveAnimatedText(_controller.value),
                  ),
                ),
              ),
              // Template name label
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
