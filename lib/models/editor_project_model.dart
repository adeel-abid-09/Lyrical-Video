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
  final String? selectedLayerId;
  final double currentPlayheadTime; // Current playback position in seconds
  final bool isPlaying;
  final bool isScrubbing;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? exportedFilePath;

  const EditorProjectModel({
    required this.id,
    required this.title,
    required this.aspectRatio,
    this.duration = 15.0,
    this.mediaLayers = const [],
    this.textLayers = const [],
    this.selectedLayerId,
    this.currentPlayheadTime = 0.0,
    this.isPlaying = false,
    this.isScrubbing = false,
    required this.createdAt,
    required this.updatedAt,
    this.exportedFilePath,
  });

  EditorProjectModel copyWith({
    String? id,
    String? title,
    ProjectAspectRatio? aspectRatio,
    double? duration,
    List<MediaLayerModel>? mediaLayers,
    List<TextLayerModel>? textLayers,
    String? selectedLayerId,
    double? currentPlayheadTime,
    bool? isPlaying,
    bool? isScrubbing,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? exportedFilePath,
  }) {
    return EditorProjectModel(
      id: id ?? this.id,
      title: title ?? this.title,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      duration: duration ?? this.duration,
      mediaLayers: mediaLayers ?? this.mediaLayers,
      textLayers: textLayers ?? this.textLayers,
      selectedLayerId: selectedLayerId ?? this.selectedLayerId,
      currentPlayheadTime: currentPlayheadTime ?? this.currentPlayheadTime,
      isPlaying: isPlaying ?? this.isPlaying,
      isScrubbing: isScrubbing ?? this.isScrubbing,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      exportedFilePath: exportedFilePath ?? this.exportedFilePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'duration': duration,
      'currentPlayheadTime': currentPlayheadTime,
      'isPlaying': isPlaying,
      'isScrubbing': isScrubbing,
      'mediaLayers': mediaLayers.map((m) => m.toJson()).toList(),
      'textLayers': textLayers.map((t) => t.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory EditorProjectModel.fromJson(Map<String, dynamic> json) {
    return EditorProjectModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Lyrical Project',
      aspectRatio: ProjectAspectRatio.default9x16,
      duration: (json['duration'] as num? ?? 15.0).toDouble(),
      mediaLayers: (json['mediaLayers'] as List<dynamic>? ?? [])
          .map((m) => MediaLayerModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      textLayers: (json['textLayers'] as List<dynamic>? ?? [])
          .map((t) => TextLayerModel.fromJson(t as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
