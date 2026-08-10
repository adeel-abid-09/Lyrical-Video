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
  final double volume;
  final double playbackSpeed;
  final bool isMuted;
  
  final VideoFitMode fitMode;
  final int zIndex;
  final bool isVisible;
  final bool isLocked;
  final DateTime updatedAt;

  MediaLayerModel({
    required this.id,
    required this.path,
    required this.type,
    this.position = const Offset(0.5, 0.5),
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.rotation = 0.0,
    this.opacity = 1.0,
    this.startTime = 0.0,
    this.trimStartTime = 0.0,
    this.mediaDuration = 10.0,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.isMuted = false,
    this.fitMode = VideoFitMode.contain,
    this.zIndex = 0,
    this.isVisible = true,
    this.isLocked = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  MediaLayerModel copyWith({
    String? id,
    String? path,
    MediaType? type,
    Offset? position,
    double? scaleX,
    double? scaleY,
    double? rotation,
    double? opacity,
    double? startTime,
    double? trimStartTime,
    double? mediaDuration,
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
      position: position ?? this.position,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      startTime: startTime ?? this.startTime,
      trimStartTime: trimStartTime ?? this.trimStartTime,
      mediaDuration: mediaDuration ?? this.mediaDuration,
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
      'startTime': startTime,
      'mediaDuration': mediaDuration,
      'volume': volume,
      'isMuted': isMuted,
      'zIndex': zIndex,
      'isVisible': isVisible,
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
      startTime: (json['startTime'] as num? ?? 0.0).toDouble(),
      mediaDuration: (json['mediaDuration'] as num? ?? 15.0).toDouble(),
      volume: (json['volume'] as num? ?? 1.0).toDouble(),
      isMuted: json['isMuted'] as bool? ?? false,
      zIndex: json['zIndex'] as int? ?? 0,
      isVisible: json['isVisible'] as bool? ?? true,
    );
  }
}
