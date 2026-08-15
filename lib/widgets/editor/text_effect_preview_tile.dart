import 'package:flutter/material.dart';
import '../../models/text_layer_model.dart';

class TextEffectDefinition {
  final String id;
  final String name;
  final Color textColor;
  final Color? strokeColor;
  final double strokeWidth;
  final Color? backgroundColor;
  final List<Shadow>? customShadows;

  const TextEffectDefinition({
    required this.id,
    required this.name,
    required this.textColor,
    this.strokeColor,
    this.strokeWidth = 2.5,
    this.backgroundColor,
    this.customShadows,
  });
}

class TextEffectRegistry {
  static const List<TextEffectDefinition> effects = [
    TextEffectDefinition(
      id: 'none',
      name: 'None',
      textColor: Colors.white,
    ),
    TextEffectDefinition(
      id: 'white_grunge',
      name: 'White Brush',
      textColor: Colors.white,
      strokeColor: Colors.white70,
      strokeWidth: 3.5,
      customShadows: [
        Shadow(color: Colors.white, blurRadius: 6),
        Shadow(color: Colors.white54, blurRadius: 12),
      ],
    ),
    TextEffectDefinition(
      id: 'neon_red',
      name: 'Neon Red',
      textColor: Colors.white,
      strokeColor: Color(0xFFFF1744),
      strokeWidth: 3.0,
      customShadows: [
        Shadow(color: Color(0xFFFF1744), blurRadius: 8),
        Shadow(color: Color(0xFFFF5252), blurRadius: 14),
      ],
    ),
    TextEffectDefinition(
      id: 'deep_shadow',
      name: 'Deep 3D',
      textColor: Colors.white,
      strokeColor: Colors.black,
      strokeWidth: 3.0,
      customShadows: [
        Shadow(color: Colors.black, offset: Offset(2.5, 2.5), blurRadius: 3),
        Shadow(color: Colors.black, offset: Offset(3.5, 3.5), blurRadius: 6),
      ],
    ),
    TextEffectDefinition(
      id: 'flame_fire',
      name: 'Fire Blaze',
      textColor: Color(0xFFFFD54F),
      strokeColor: Color(0xFFFF3D00),
      strokeWidth: 3.0,
      customShadows: [
        Shadow(color: Color(0xFFFF3D00), blurRadius: 6),
        Shadow(color: Color(0xFFFF9100), blurRadius: 12),
      ],
    ),
    TextEffectDefinition(
      id: 'drip_crimson',
      name: 'Crimson Drip',
      textColor: Color(0xFFFF1744),
      strokeColor: Colors.black,
      strokeWidth: 3.0,
      customShadows: [
        Shadow(color: Colors.black, offset: Offset(0, 3), blurRadius: 4),
      ],
    ),
    TextEffectDefinition(
      id: 'smoke_glow',
      name: 'Smoke Aura',
      textColor: Colors.white,
      strokeColor: Color(0xFF78909C),
      strokeWidth: 2.5,
      customShadows: [
        Shadow(color: Color(0xFF90A4AE), blurRadius: 10),
      ],
    ),
    TextEffectDefinition(
      id: 'parchment_vintage',
      name: 'Vintage',
      textColor: Color(0xFF3E2723),
      backgroundColor: Color(0xFFFFF8E1),
      strokeColor: Color(0xFF8D6E63),
      strokeWidth: 1.0,
    ),
    TextEffectDefinition(
      id: 'yellow_graffiti',
      name: 'Yellow Pop',
      textColor: Colors.black,
      backgroundColor: Color(0xFFFFD600),
    ),
    TextEffectDefinition(
      id: 'pink_brush',
      name: 'Pink Oil',
      textColor: Colors.white,
      backgroundColor: Color(0xFFE91E63),
      strokeColor: Color(0xFF880E4F),
      strokeWidth: 1.5,
    ),
    TextEffectDefinition(
      id: 'red_comic_stamp',
      name: 'Comic Red',
      textColor: Colors.white,
      backgroundColor: Color(0xFFD50000),
      strokeColor: Colors.black,
      strokeWidth: 2.5,
    ),
    TextEffectDefinition(
      id: 'comic_gold',
      name: 'Comic Gold',
      textColor: Color(0xFFFFEA00),
      strokeColor: Colors.black,
      strokeWidth: 3.5,
      customShadows: [
        Shadow(color: Color(0xFFFFAB00), blurRadius: 8),
      ],
    ),
    TextEffectDefinition(
      id: 'cyber_cyan',
      name: 'Cyber Cyan',
      textColor: Color(0xFF00E5FF),
      strokeColor: Color(0xFF0059FF),
      strokeWidth: 3.0,
      customShadows: [
        Shadow(color: Color(0xFF00E5FF), blurRadius: 8),
      ],
    ),
    TextEffectDefinition(
      id: 'purple_magic',
      name: 'Mystic Purple',
      textColor: Color(0xFFE040FB),
      strokeColor: Color(0xFF651FFF),
      strokeWidth: 3.0,
      customShadows: [
        Shadow(color: Color(0xFFD500F9), blurRadius: 8),
      ],
    ),
    TextEffectDefinition(
      id: 'green_emerald',
      name: 'Emerald Laser',
      textColor: Color(0xFF00E676),
      strokeColor: Color(0xFF004D40),
      strokeWidth: 3.0,
      customShadows: [
        Shadow(color: Color(0xFF00E676), blurRadius: 8),
      ],
    ),
  ];
}

/// CapCut-style ART Preview Card for Text Effects in Horizontal Toolbars.
class TextEffectPreviewTile extends StatelessWidget {
  final TextEffectDefinition def;
  final bool isSelected;
  final VoidCallback onTap;

  const TextEffectPreviewTile({
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
        width: 76,
        height: 54,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: def.id == 'none'
                      ? const Icon(Icons.do_not_disturb_alt_rounded, color: Colors.white54, size: 22)
                      : Container(
                          padding: def.backgroundColor != null
                              ? const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5)
                              : null,
                          decoration: def.backgroundColor != null
                              ? BoxDecoration(
                                  color: def.backgroundColor,
                                  borderRadius: BorderRadius.circular(3),
                                )
                              : null,
                          child: Text(
                            'ART',
                            style: TextStyle(
                              color: def.textColor,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              shadows: def.customShadows ?? (def.strokeColor != null
                                  ? [
                                      Shadow(
                                        color: def.strokeColor!,
                                        blurRadius: def.strokeWidth * 1.5,
                                      ),
                                      Shadow(
                                        color: def.strokeColor!,
                                        offset: const Offset(1, 1),
                                      ),
                                      Shadow(
                                        color: def.strokeColor!,
                                        offset: const Offset(-1, -1),
                                      ),
                                    ]
                                  : null),
                            ),
                          ),
                        ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(bottom: 3),
                alignment: Alignment.center,
                child: Text(
                  def.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
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
