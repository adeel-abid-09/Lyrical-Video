import 'dart:ui';

enum MediaType { video, audio, sticker }

enum VideoFitMode { fit, fill, stretch, contain, cover }

class MediaLayerModel {
  final String id;
  final String path;
  final MediaType type;
  
  final Offset position;
  final double scaleX;
  final double scaleY;
  final double rotation;
  final double opacity;
  
  final double startTime;
  final double trimStartTime;
  final double mediaDuration;
  final double originalDuration;
  final double volume;
  final double playbackSpeed;
  final bool isMuted;
  
  final bool isOverlay;
  final double cropLeft;
  final double cropTop;
  final double cropRight;
  final double cropBottom;

  final VideoFitMode fitMode;
  final int zIndex;
  final bool isVisible;
  final bool isLocked;
  final DateTime updatedAt;

  bool get isCropped => cropLeft > 0.001 || cropTop > 0.001 || cropRight < 0.999 || cropBottom < 0.999;
  Rect get cropRect => Rect.fromLTRB(cropLeft, cropTop, cropRight, cropBottom);
  double get cropWidthRatio => (cropRight - cropLeft).clamp(0.01, 1.0);
  double get cropHeightRatio => (cropBottom - cropTop).clamp(0.01, 1.0);

  MediaLayerModel({
    required this.id,
    required this.path,
    required this.type,
    this.isOverlay = false,
    this.cropLeft = 0.0,
    this.cropTop = 0.0,
    this.cropRight = 1.0,
    this.cropBottom = 1.0,
    this.position = const Offset(0.5, 0.5),
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.rotation = 0.0,
    this.opacity = 1.0,
    this.startTime = 0.0,
    this.trimStartTime = 0.0,
    this.mediaDuration = 10.0,
    double? originalDuration,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.isMuted = false,
    this.fitMode = VideoFitMode.cover,
    this.zIndex = 0,
    this.isVisible = true,
    this.isLocked = false,
    DateTime? updatedAt,
  })  : originalDuration = originalDuration ?? mediaDuration,
        updatedAt = updatedAt ?? DateTime.now();

  MediaLayerModel copyWith({
    String? id,
    String? path,
    MediaType? type,
    bool? isOverlay,
    double? cropLeft,
    double? cropTop,
    double? cropRight,
    double? cropBottom,
    Offset? position,
    double? scaleX,
    double? scaleY,
    double? rotation,
    double? opacity,
    double? startTime,
    double? trimStartTime,
    double? mediaDuration,
    double? originalDuration,
    double? volume,
    double? playbackSpeed,
    bool? isMuted,
    VideoFitMode? fitMode,
    int? zIndex,
    bool? isVisible,
    bool? isLocked,
    DateTime? updatedAt,
  }) {
    return MediaLayerModel(
      id: id ?? this.id,
      path: path ?? this.path,
      type: type ?? this.type,
      isOverlay: isOverlay ?? this.isOverlay,
      cropLeft: cropLeft ?? this.cropLeft,
      cropTop: cropTop ?? this.cropTop,
      cropRight: cropRight ?? this.cropRight,
      cropBottom: cropBottom ?? this.cropBottom,
      position: position ?? this.position,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      startTime: startTime ?? this.startTime,
      trimStartTime: trimStartTime ?? this.trimStartTime,
      mediaDuration: mediaDuration ?? this.mediaDuration,
      originalDuration: originalDuration ?? this.originalDuration,
      volume: volume ?? this.volume,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      isMuted: isMuted ?? this.isMuted,
      fitMode: fitMode ?? this.fitMode,
      zIndex: zIndex ?? this.zIndex,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'type': type.name,
      'isOverlay': isOverlay,
      'cropLeft': cropLeft,
      'cropTop': cropTop,
      'cropRight': cropRight,
      'cropBottom': cropBottom,
      'posX': position.dx,
      'posY': position.dy,
      'scaleX': scaleX,
      'scaleY': scaleY,
      'rotation': rotation,
      'opacity': opacity,
      'startTime': startTime,
      'trimStartTime': trimStartTime,
      'mediaDuration': mediaDuration,
      'originalDuration': originalDuration,
      'volume': volume,
      'playbackSpeed': playbackSpeed,
      'isMuted': isMuted,
      'fitMode': fitMode.name,
      'zIndex': zIndex,
      'isVisible': isVisible,
      'isLocked': isLocked,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MediaLayerModel.fromJson(Map<String, dynamic> json) {
    return MediaLayerModel(
      id: json['id'] as String? ?? '',
      path: json['path'] as String? ?? '',
      type: MediaType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MediaType.video,
      ),
      isOverlay: json['isOverlay'] as bool? ?? false,
      cropLeft: (json['cropLeft'] as num? ?? 0.0).toDouble(),
      cropTop: (json['cropTop'] as num? ?? 0.0).toDouble(),
      cropRight: (json['cropRight'] as num? ?? 1.0).toDouble(),
      cropBottom: (json['cropBottom'] as num? ?? 1.0).toDouble(),
      position: Offset(
        (json['posX'] as num? ?? 0.5).toDouble(),
        (json['posY'] as num? ?? 0.5).toDouble(),
      ),
      scaleX: (json['scaleX'] as num? ?? 1.0).toDouble(),
      scaleY: (json['scaleY'] as num? ?? 1.0).toDouble(),
      rotation: (json['rotation'] as num? ?? 0.0).toDouble(),
      opacity: (json['opacity'] as num? ?? 1.0).toDouble(),
      startTime: (json['startTime'] as num? ?? 0.0).toDouble(),
      trimStartTime: (json['trimStartTime'] as num? ?? 0.0).toDouble(),
      mediaDuration: (json['mediaDuration'] as num? ?? 15.0).toDouble(),
      originalDuration: (json['originalDuration'] as num? ?? json['mediaDuration'] as num? ?? 15.0).toDouble(),
      volume: (json['volume'] as num? ?? 1.0).toDouble(),
      playbackSpeed: (json['playbackSpeed'] as num? ?? 1.0).toDouble(),
      isMuted: json['isMuted'] as bool? ?? false,
      fitMode: VideoFitMode.values.firstWhere(
        (e) => e.name == json['fitMode'],
        orElse: () => VideoFitMode.cover,
      ),
      zIndex: json['zIndex'] as int? ?? 0,
      isVisible: json['isVisible'] as bool? ?? true,
      isLocked: json['isLocked'] as bool? ?? false,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
    );
  }
}
