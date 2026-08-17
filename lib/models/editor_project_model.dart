import 'aspect_ratio_model.dart';
import 'media_layer_model.dart';
import 'text_layer_model.dart';

class EditorProjectModel {
  final String id;
  final String title;
  final ProjectAspectRatio aspectRatio;
  final double duration; // Total project duration in seconds
  final List<MediaLayerModel> mediaLayers;
  final List<TextLayerModel> textLayers;
  final List<String> queuedLyrics; // List of manual/imported lyrics waiting to be dropped
  final String? selectedLayerId;
  final double currentPlayheadTime; // Current playback position in seconds
  final bool isPlaying;
  final bool isScrubbing;
  final bool isTrimMode; // Whether the user is actively trimming the selected layer
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? exportedFilePath;
  final double canvasWidth;
  final double canvasHeight;

  const EditorProjectModel({
    required this.id,
    required this.title,
    required this.aspectRatio,
    this.duration = 15.0,
    this.mediaLayers = const [],
    this.textLayers = const [],
    this.queuedLyrics = const [],
    this.selectedLayerId,
    this.currentPlayheadTime = 0.0,
    this.isPlaying = false,
    this.isScrubbing = false,
    this.isTrimMode = false,
    required this.createdAt,
    required this.updatedAt,
    this.exportedFilePath,
    this.canvasWidth = 400.0,
    this.canvasHeight = 711.0,
  });

  EditorProjectModel copyWith({
    String? id,
    String? title,
    ProjectAspectRatio? aspectRatio,
    double? duration,
    List<MediaLayerModel>? mediaLayers,
    List<TextLayerModel>? textLayers,
    List<String>? queuedLyrics,
    String? selectedLayerId,
    double? currentPlayheadTime,
    bool? isPlaying,
    bool? isScrubbing,
    bool? isTrimMode,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? exportedFilePath,
    double? canvasWidth,
    double? canvasHeight,
  }) {
    return EditorProjectModel(
      id: id ?? this.id,
      title: title ?? this.title,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      duration: duration ?? this.duration,
      mediaLayers: mediaLayers ?? this.mediaLayers,
      textLayers: textLayers ?? this.textLayers,
      queuedLyrics: queuedLyrics ?? this.queuedLyrics,
      selectedLayerId: selectedLayerId ?? this.selectedLayerId,
      currentPlayheadTime: currentPlayheadTime ?? this.currentPlayheadTime,
      isPlaying: isPlaying ?? this.isPlaying,
      isScrubbing: isScrubbing ?? this.isScrubbing,
      isTrimMode: isTrimMode ?? this.isTrimMode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      exportedFilePath: exportedFilePath ?? this.exportedFilePath,
      canvasWidth: canvasWidth ?? this.canvasWidth,
      canvasHeight: canvasHeight ?? this.canvasHeight,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'aspectRatio': aspectRatio.type.name,
      'duration': duration,
      'currentPlayheadTime': currentPlayheadTime,
      'isPlaying': isPlaying,
      'isScrubbing': isScrubbing,
      'isTrimMode': isTrimMode,
      'mediaLayers': mediaLayers.map((m) => m.toJson()).toList(),
      'textLayers': textLayers.map((t) => t.toJson()).toList(),
      'queuedLyrics': queuedLyrics,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'canvasWidth': canvasWidth,
      'canvasHeight': canvasHeight,
    };
  }

  factory EditorProjectModel.fromJson(Map<String, dynamic> json) {
    return EditorProjectModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Lyrical Project',
      aspectRatio: json['aspectRatio'] != null
          ? ProjectAspectRatio.fromType(AspectRatioType.values.firstWhere(
              (e) => e.name == json['aspectRatio'],
              orElse: () => AspectRatioType.ratio9x16,
            ))
          : ProjectAspectRatio.default9x16,
      duration: (json['duration'] as num? ?? 15.0).toDouble(),
      mediaLayers: (json['mediaLayers'] as List<dynamic>? ?? [])
          .map((m) => MediaLayerModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      textLayers: (json['textLayers'] as List<dynamic>? ?? [])
          .map((t) => TextLayerModel.fromJson(t as Map<String, dynamic>))
          .toList(),
      queuedLyrics: (json['queuedLyrics'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      currentPlayheadTime: (json['currentPlayheadTime'] as num? ?? 0.0).toDouble(),
      isPlaying: json['isPlaying'] as bool? ?? false,
      isScrubbing: json['isScrubbing'] as bool? ?? false,
      isTrimMode: json['isTrimMode'] as bool? ?? false,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : DateTime.now(),
      canvasWidth: (json['canvasWidth'] as num? ?? 400.0).toDouble(),
      canvasHeight: (json['canvasHeight'] as num? ?? 711.0).toDouble(),
    );
  }
}
