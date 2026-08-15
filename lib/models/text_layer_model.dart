import 'package:flutter/material.dart';

enum TextAnimationType {
  none,
  fadeIn,
  popIn,
  blurIn,
  slideUp,
  slideDown,
  typewriter,
  bounce,
  glow,
  stamp,
  zoomIn,
  wave,
}

class TextLayerModel {
  final String id;
  final String text;
  final Offset position; // Normalized position (0.0 to 1.0 on canvas)
  final double scaleX;
  final double scaleY;
  final double rotation; // Radians
  final Color textColor;
  final Color? strokeColor;
  final double strokeWidth;
  final Color? backgroundColor;
  final String fontFamily;
  final double fontSize;
  final FontWeight fontWeight;
  final FontStyle fontStyle;
  final TextAlign textAlign;
  final double letterSpacing;
  final double lineSpacing;
  final double opacity;
  
  // Box/Bubble Properties
  final double? boxWidth;
  final double? boxHeight;
  final double boxBorderRadius;
  final String? bubbleStyle;

  final double startTime; // In seconds
  final double endTime;   // In seconds
  final int zIndex;
  final bool isVisible;
  final bool isLocked;
  final TextAnimationType animation;
  final bool isAutoLyric;

  const TextLayerModel({
    required this.id,
    required this.text,
    this.position = const Offset(0.5, 0.5),
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.rotation = 0.0,
    this.textColor = Colors.white,
    this.strokeColor,
    this.strokeWidth = 0.0,
    this.backgroundColor,
    this.fontFamily = 'Outfit',
    this.fontSize = 20.0,
    this.fontWeight = FontWeight.bold,
    this.fontStyle = FontStyle.normal,
    this.textAlign = TextAlign.center,
    this.letterSpacing = 1.0,
    this.lineSpacing = 1.2,
    this.opacity = 1.0,
    this.boxWidth,
    this.boxHeight,
    this.boxBorderRadius = 8.0,
    this.bubbleStyle,
    this.startTime = 0.0,
    this.endTime = 10.0,
    this.zIndex = 0,
    this.isVisible = true,
    this.isLocked = false,
    this.animation = TextAnimationType.none,
    this.isAutoLyric = false,
  });

  TextLayerModel copyWith({
    String? id,
    String? text,
    Offset? position,
    double? scaleX,
    double? scaleY,
    double? rotation,
    Color? textColor,
    Color? strokeColor,
    double? strokeWidth,
    Color? backgroundColor,
    String? fontFamily,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    TextAlign? textAlign,
    double? letterSpacing,
    double? lineSpacing,
    double? opacity,
    double? boxWidth,
    double? boxHeight,
    double? boxBorderRadius,
    String? bubbleStyle,
    double? startTime,
    double? endTime,
    int? zIndex,
    bool? isVisible,
    bool? isLocked,
    TextAnimationType? animation,
    bool? isAutoLyric,
    bool clearBackground = false,
    bool clearStroke = false,
    bool clearBubble = false,
    bool clearBoxSize = false,
  }) {
    return TextLayerModel(
      id: id ?? this.id,
      text: text ?? this.text,
      position: position ?? this.position,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotation: rotation ?? this.rotation,
      textColor: textColor ?? this.textColor,
      strokeColor: clearStroke ? null : (strokeColor ?? this.strokeColor),
      strokeWidth: strokeWidth ?? this.strokeWidth,
      backgroundColor: clearBackground ? null : (backgroundColor ?? this.backgroundColor),
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: fontStyle ?? this.fontStyle,
      textAlign: textAlign ?? this.textAlign,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      opacity: opacity ?? this.opacity,
      boxWidth: clearBoxSize ? null : (boxWidth ?? this.boxWidth),
      boxHeight: clearBoxSize ? null : (boxHeight ?? this.boxHeight),
      boxBorderRadius: boxBorderRadius ?? this.boxBorderRadius,
      bubbleStyle: clearBubble ? 'none' : (bubbleStyle ?? this.bubbleStyle),
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      zIndex: zIndex ?? this.zIndex,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      animation: animation ?? this.animation,
      isAutoLyric: isAutoLyric ?? this.isAutoLyric,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'dx': position.dx,
      'dy': position.dy,
      'scaleX': scaleX,
      'scaleY': scaleY,
      'rotation': rotation,
      'textColor': textColor.value,
      'strokeColor': strokeColor?.value,
      'strokeWidth': strokeWidth,
      'backgroundColor': backgroundColor?.value,
      'fontWeight': fontWeight.index,
      'fontStyle': fontStyle.index,
      'textAlign': textAlign.index,
      'fontSize': fontSize,
      'fontFamily': fontFamily,
      'letterSpacing': letterSpacing,
      'lineSpacing': lineSpacing,
      'boxWidth': boxWidth,
      'boxHeight': boxHeight,
      'boxBorderRadius': boxBorderRadius,
      'bubbleStyle': bubbleStyle,
      'startTime': startTime,
      'endTime': endTime,
      'zIndex': zIndex,
      'isVisible': isVisible,
      'isAutoLyric': isAutoLyric,
    };
  }

  factory TextLayerModel.fromJson(Map<String, dynamic> json) {
    return TextLayerModel(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      position: Offset(
        (json['dx'] as num? ?? 0.5).toDouble(),
        (json['dy'] as num? ?? 0.5).toDouble(),
      ),
      scaleX: (json['scaleX'] as num? ?? 1.0).toDouble(),
      scaleY: (json['scaleY'] as num? ?? 1.0).toDouble(),
      rotation: (json['rotation'] as num? ?? 0.0).toDouble(),
      textColor: Color(json['textColor'] as int? ?? Colors.white.value),
      strokeColor: json['strokeColor'] != null ? Color(json['strokeColor'] as int) : null,
      strokeWidth: (json['strokeWidth'] as num? ?? 2.0).toDouble(),
      backgroundColor: json['backgroundColor'] != null ? Color(json['backgroundColor'] as int) : null,
      fontWeight: FontWeight.values[json['fontWeight'] as int? ?? FontWeight.normal.index],
      fontStyle: FontStyle.values[json['fontStyle'] as int? ?? FontStyle.normal.index],
      textAlign: TextAlign.values[json['textAlign'] as int? ?? TextAlign.center.index],
      fontSize: (json['fontSize'] as num? ?? 24.0).toDouble(),
      fontFamily: json['fontFamily'] as String? ?? 'Outfit',
      letterSpacing: (json['letterSpacing'] as num?)?.toDouble() ?? 1.0,
      lineSpacing: (json['lineSpacing'] as num?)?.toDouble() ?? 1.2,
      boxWidth: (json['boxWidth'] as num?)?.toDouble(),
      boxHeight: (json['boxHeight'] as num?)?.toDouble(),
      boxBorderRadius: (json['boxBorderRadius'] as num?)?.toDouble() ?? 8.0,
      bubbleStyle: json['bubbleStyle'] as String?,
      startTime: (json['startTime'] as num?)?.toDouble() ?? 0.0,
      endTime: (json['endTime'] as num? ?? 10.0).toDouble(),
      zIndex: json['zIndex'] as int? ?? 0,
      isVisible: json['isVisible'] as bool? ?? true,
      isAutoLyric: json['isAutoLyric'] as bool? ?? false,
    );
  }
}
