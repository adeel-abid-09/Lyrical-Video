enum MediaType { video, audio, sticker }

enum VideoFitMode { fit, fill, stretch }

class MediaLayerModel {
  final String id;
  final String path;
  final MediaType type;
  final double startTime; // Offset in timeline (seconds)
  final double mediaDuration; // Duration of source file (seconds)
  final double volume; // 0.0 to 1.0
  final bool isMuted;
  final VideoFitMode fitMode;
  final int zIndex;
  final bool isVisible;
  final bool isLocked;

  const MediaLayerModel({
    required this.id,
    required this.path,
    required this.type,
    this.startTime = 0.0,
    required this.mediaDuration,
    this.volume = 1.0,
    this.isMuted = false,
    this.fitMode = VideoFitMode.fill,
    this.zIndex = 0,
    this.isVisible = true,
    this.isLocked = false,
  });

  MediaLayerModel copyWith({
    String? id,
    String? path,
    MediaType? type,
    double? startTime,
    double? mediaDuration,
    double? volume,
    bool? isMuted,
    VideoFitMode? fitMode,
    int? zIndex,
    bool? isVisible,
    bool? isLocked,
  }) {
    return MediaLayerModel(
      id: id ?? this.id,
      path: path ?? this.path,
      type: type ?? this.type,
      startTime: startTime ?? this.startTime,
      mediaDuration: mediaDuration ?? this.mediaDuration,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      fitMode: fitMode ?? this.fitMode,
      zIndex: zIndex ?? this.zIndex,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
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
