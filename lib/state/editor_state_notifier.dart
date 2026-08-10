import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/aspect_ratio_model.dart';
import '../models/editor_project_model.dart';
import '../models/media_layer_model.dart';
import '../models/text_layer_model.dart';

final editorProjectProvider = StateNotifierProvider<EditorProjectNotifier, EditorProjectModel>((ref) {
  return EditorProjectNotifier();
});

class EditorProjectNotifier extends StateNotifier<EditorProjectModel> {
  EditorProjectNotifier()
      : super(
          EditorProjectModel(
            id: const Uuid().v4(),
            title: 'New Lyrical Project',
            aspectRatio: ProjectAspectRatio.default9x16,
            duration: 15.0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

  final List<EditorProjectModel> _undoStack = [];
  final List<EditorProjectModel> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void _pushHistory() {
    _undoStack.add(state);
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isNotEmpty) {
      _redoStack.add(state);
      state = _undoStack.removeLast();
    }
  }

  void redo() {
    if (_redoStack.isNotEmpty) {
      _undoStack.add(state);
      state = _redoStack.removeLast();
    }
  }

  void setAspectRatio(ProjectAspectRatio ratio) {
    _pushHistory();
    state = state.copyWith(
      aspectRatio: ratio,
      updatedAt: DateTime.now(),
    );
  }

  void setDuration(double duration) {
    _pushHistory();
    state = state.copyWith(
      duration: duration,
      updatedAt: DateTime.now(),
    );
  }

  void seekPlayhead(double time) {
    state = state.copyWith(
      currentPlayheadTime: time.clamp(0.0, state.duration),
    );
  }

  void togglePlayPause() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  void selectLayer(String? layerId) {
    state = state.copyWith(selectedLayerId: layerId);
  }

  // --- Text Layer Operations ---

  void addTextLayer(String text, {Offset position = const Offset(0.5, 0.5)}) {
    _pushHistory();
    final newLayer = TextLayerModel(
      id: const Uuid().v4(),
      text: text,
      position: position,
      startTime: 0.0,
      endTime: state.duration,
      zIndex: state.textLayers.length + 10,
    );

    final updated = [...state.textLayers, newLayer];
    state = state.copyWith(
      textLayers: updated,
      selectedLayerId: newLayer.id,
      updatedAt: DateTime.now(),
    );
  }

  void addTextLayers(List<TextLayerModel> layers) {
    _pushHistory();
    final updated = [...state.textLayers, ...layers];
    state = state.copyWith(
      textLayers: updated,
      updatedAt: DateTime.now(),
    );
  }

  void updateTextLayer(TextLayerModel updatedLayer) {
    _pushHistory();
    final updated = state.textLayers.map((l) {
      return l.id == updatedLayer.id ? updatedLayer : l;
    }).toList();

    state = state.copyWith(
      textLayers: updated,
      updatedAt: DateTime.now(),
    );
  }

  void deleteTextLayer(String id) {
    _pushHistory();
    final updated = state.textLayers.where((l) => l.id != id).toList();
    state = state.copyWith(
      textLayers: updated,
      selectedLayerId: state.selectedLayerId == id ? null : state.selectedLayerId,
      updatedAt: DateTime.now(),
    );
  }

  // --- Media Layer Operations ---

  void addMediaLayer(MediaLayerModel media) {
    _pushHistory();
    final updated = [...state.mediaLayers, media];

    // If media duration > current project duration, extend project duration
    double newDuration = state.duration;
    if (media.mediaDuration > newDuration) {
      newDuration = media.mediaDuration;
    }

    state = state.copyWith(
      mediaLayers: updated,
      duration: newDuration,
      updatedAt: DateTime.now(),
    );
  }

  void updateMediaLayer(MediaLayerModel updatedMedia) {
    _pushHistory();
    final updated = state.mediaLayers.map((m) {
      return m.id == updatedMedia.id ? updatedMedia : m;
    }).toList();

    state = state.copyWith(
      mediaLayers: updated,
      updatedAt: DateTime.now(),
    );
  }

  void deleteMediaLayer(String id) {
    _pushHistory();
    final updated = state.mediaLayers.where((m) => m.id != id).toList();
    state = state.copyWith(
      mediaLayers: updated,
      selectedLayerId: state.selectedLayerId == id ? null : state.selectedLayerId,
      updatedAt: DateTime.now(),
    );
  }

  void toggleMuteMediaLayer(String id) {
    _pushHistory();
    final updated = state.mediaLayers.map((m) {
      if (m.id == id) {
        return m.copyWith(isMuted: !m.isMuted);
      }
      return m;
    }).toList();

    state = state.copyWith(
      mediaLayers: updated,
      updatedAt: DateTime.now(),
    );
  }

  void reorderTextLayers(int oldIndex, int newIndex) {
    _pushHistory();
    final list = List<TextLayerModel>.from(state.textLayers);
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    state = state.copyWith(
      textLayers: list,
      updatedAt: DateTime.now(),
    );
  }
}
