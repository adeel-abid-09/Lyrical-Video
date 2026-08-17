import 'package:flutter/material.dart';

enum AspectRatioType {
  ratio9x16, // TikTok / Reels / Shorts (1080x1920)
  ratio16x9, // YouTube Landscape (1920x1080)
  ratio1x1,  // Instagram Square (1080x1080)
  ratio4x5,  // Instagram Portrait (1080x1350)
  custom,    // Custom user width & height
  auto,      // Auto match imported video
}

class ProjectAspectRatio {
  final AspectRatioType type;
  final String label;
  final String sublabel;
  final double ratio; // width / height
  final Size resolution; // Target resolution (width, height)
  final IconData icon;

  const ProjectAspectRatio({
    required this.type,
    required this.label,
    required this.sublabel,
    required this.ratio,
    required this.resolution,
    required this.icon,
  });

  static const ProjectAspectRatio default9x16 = ProjectAspectRatio(
    type: AspectRatioType.ratio9x16,
    label: '9:16',
    sublabel: 'TikTok / Reels',
    ratio: 9 / 16,
    resolution: Size(1080, 1920),
    icon: Icons.smartphone_rounded,
  );

  static const ProjectAspectRatio ratio16x9 = ProjectAspectRatio(
    type: AspectRatioType.ratio16x9,
    label: '16:9',
    sublabel: 'YouTube / Video',
    ratio: 16 / 9,
    resolution: Size(1920, 1080),
    icon: Icons.tv_rounded,
  );

  static const ProjectAspectRatio ratio1x1 = ProjectAspectRatio(
    type: AspectRatioType.ratio1x1,
    label: '1:1',
    sublabel: 'Instagram Post',
    ratio: 1 / 1,
    resolution: Size(1080, 1080),
    icon: Icons.crop_square_rounded,
  );

  static const ProjectAspectRatio ratio4x5 = ProjectAspectRatio(
    type: AspectRatioType.ratio4x5,
    label: '4:5',
    sublabel: 'Portrait Post',
    ratio: 4 / 5,
    resolution: Size(1080, 1350),
    icon: Icons.crop_5_4_rounded,
  );

  static const ProjectAspectRatio autoMatch = ProjectAspectRatio(
    type: AspectRatioType.auto,
    label: 'Auto',
    sublabel: 'Match Video',
    ratio: 9 / 16,
    resolution: Size(1080, 1920),
    icon: Icons.auto_awesome_rounded,
  );

  static ProjectAspectRatio createCustom(double width, double height) {
    final validW = width <= 0 ? 1080.0 : width;
    final validH = height <= 0 ? 1920.0 : height;
    return ProjectAspectRatio(
      type: AspectRatioType.custom,
      label: '${validW.toInt()}:${validH.toInt()}',
      sublabel: 'Custom Size',
      ratio: validW / validH,
      resolution: Size(validW, validH),
      icon: Icons.dashboard_customize_rounded,
    );
  }

  static ProjectAspectRatio fromType(AspectRatioType type) {
    switch (type) {
      case AspectRatioType.ratio16x9:
        return ratio16x9;
      case AspectRatioType.ratio1x1:
        return ratio1x1;
      case AspectRatioType.ratio4x5:
        return ratio4x5;
      case AspectRatioType.auto:
        return autoMatch;
      case AspectRatioType.ratio9x16:
      default:
        return default9x16;
    }
  }

  static List<ProjectAspectRatio> get allPresets => [
        default9x16,
        ratio16x9,
        ratio1x1,
        ratio4x5,
        autoMatch,
      ];
}
