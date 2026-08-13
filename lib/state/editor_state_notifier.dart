import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/aspect_ratio_model.dart';
import '../models/editor_project_model.dart';
import '../models/media_layer_model.dart';
import '../models/text_layer_model.dart';
import '../services/project_storage_service.dart';

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
  Timer? _autoSaveTimer;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void _triggerAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1500), () async {
      await ProjectStorageService.saveProject(state);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_session_id', state.id);
    });
  }

  void pushHistory() {
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

  void loadProject(EditorProjectModel project) {
    _undoStack.clear();
    _redoStack.clear();
    state = project;
  }

  void resetProject() {
    _undoStack.clear();
    _redoStack.clear();
    state = EditorProjectModel(
      id: const Uuid().v4(),
      title: 'New Lyrical Project',
      aspectRatio: ProjectAspectRatio.default9x16,
      duration: 15.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  void setAspectRatio(ProjectAspectRatio ratio) {
    pushHistory();
    state = state.copyWith(
      aspectRatio: ratio,
      updatedAt: DateTime.now(),
    );
  }

  void setDuration(double duration) {
    pushHistory();
    state = state.copyWith(
      duration: duration,
      updatedAt: DateTime.now(),
    );
  }

  void setPlaying(bool isPlaying) {
    state = state.copyWith(isPlaying: isPlaying);
  }

  void setScrubbing(bool isScrubbing) {
    state = state.copyWith(isScrubbing: isScrubbing);
  }

  void setTrimMode(bool isTrimMode) {
    state = state.copyWith(isTrimMode: isTrimMode);
  }

  void seekPlayhead(double time) {
    if (time < 0) time = 0;
    if (time > state.duration) time = state.duration;
    state = state.copyWith(currentPlayheadTime: time);
  }

  void togglePlayPause() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  void selectLayer(String? id) {
    if (state.selectedLayerId == id) return;
    state = state.copyWith(selectedLayerId: id, isTrimMode: false);
  }

  // --- Text Layer Operations ---

  void addTextLayer(String text, {Offset position = const Offset(0.5, 0.5)}) {
    pushHistory();
    
    // Offset new layers so they don't overlap completely
    final existingLayers = state.textLayers.length;
    final yOffset = 0.5 + ((existingLayers % 5) * 0.08); // Drops slightly lower each time
    final finalPos = position == const Offset(0.5, 0.5) ? Offset(0.5, yOffset) : position;

    final start = state.currentPlayheadTime;
    double end = start + 3.0;
    if (end > state.duration) {
      // If we are at the end, just make it 3 seconds and extend duration, or clamp it?
      // Since it's text, let's just use 3s. If we need to extend duration, we can update state duration below.
      // But for simplicity, we'll just allow it to exceed the current duration temporarily, 
      // or clamp it. CapCut allows text to extend beyond video, making a black screen.
      // Let's just set end to start + 3.0.
    }

    final newLayer = TextLayerModel(
      id: const Uuid().v4(),
      text: text,
      position: finalPos,
      startTime: start,
      endTime: end,
      zIndex: state.textLayers.length + 10,
    );

    final updated = [...state.textLayers, newLayer];
    
    double newDuration = state.duration;
    if (end > newDuration) {
      newDuration = end;
    }
    
    state = state.copyWith(
      textLayers: updated,
      selectedLayerId: newLayer.id,
      duration: newDuration,
      updatedAt: DateTime.now(),
    );
  }

  // --- Queued Lyrics Operations ---
  void setQueuedLyrics(List<String> lyrics) {
    state = state.copyWith(
      queuedLyrics: lyrics,
      updatedAt: DateTime.now(),
    );
  }

  void popQueuedLyric() {
    if (state.queuedLyrics.isNotEmpty) {
      final updated = List<String>.from(state.queuedLyrics)..removeAt(0);
      state = state.copyWith(
        queuedLyrics: updated,
        updatedAt: DateTime.now(),
      );
    }
  }

  void clearQueuedLyrics() {
    state = state.copyWith(
      queuedLyrics: const [],
      updatedAt: DateTime.now(),
    );
  }

  void addTextLayers(List<TextLayerModel> layers) {
    pushHistory();
    final updated = [...state.textLayers, ...layers];
    state = state.copyWith(
      textLayers: updated,
      updatedAt: DateTime.now(),
    );
  }

  void updateTextLayer(TextLayerModel updatedLayer) {
    pushHistory();
    final updated = state.textLayers.map((l) {
      return l.id == updatedLayer.id ? updatedLayer : l;
    }).toList();

    state = state.copyWith(
      textLayers: updated,
      updatedAt: DateTime.now(),
    );
  }

  void deleteTextLayer(String id) {
    pushHistory();
    final updated = state.textLayers.where((l) => l.id != id).toList();
    state = state.copyWith(
      textLayers: updated,
      selectedLayerId: state.selectedLayerId == id ? null : state.selectedLayerId,
      updatedAt: DateTime.now(),
    );
  }


  // --- Text Layer Operations ---

  void splitTextLayer(String id, double splitTime) {
    final layerIndex = state.textLayers.indexWhere((l) => l.id == id);
    if (layerIndex == -1) return;
    
    final layer = state.textLayers[layerIndex];
    if (splitTime <= layer.startTime || splitTime >= layer.endTime) return; 
    
    pushHistory();
    
    final layer1 = layer.copyWith(endTime: splitTime);
    final layer2 = layer.copyWith(
      id: const Uuid().v4(),
      startTime: splitTime,
    );
    
    final newLayers = List<TextLayerModel>.from(state.textLayers);
    newLayers[layerIndex] = layer1;
    newLayers.insert(layerIndex + 1, layer2);
    
    state = state.copyWith(
      textLayers: newLayers,
      selectedLayerId: layer2.id,
    );
  }

  void trimTextLayerStart(String id, double time) {
    final layerIndex = state.textLayers.indexWhere((l) => l.id == id);
    if (layerIndex == -1) return;
    
    final layer = state.textLayers[layerIndex];
    if (time >= layer.endTime) return;
    
    pushHistory();
    
    final updated = List<TextLayerModel>.from(state.textLayers);
    updated[layerIndex] = layer.copyWith(startTime: time);
    state = state.copyWith(textLayers: updated);
  }

  void trimTextLayerEnd(String id, double time) {
    final layerIndex = state.textLayers.indexWhere((l) => l.id == id);
    if (layerIndex == -1) return;
    
    final layer = state.textLayers[layerIndex];
    if (time <= layer.startTime) return;
    
    pushHistory();
    
    final updated = List<TextLayerModel>.from(state.textLayers);
    updated[layerIndex] = layer.copyWith(endTime: time);
    state = state.copyWith(textLayers: updated);
  }

  void moveTextLayer(String id, double delta) {
    final layerIndex = state.textLayers.indexWhere((l) => l.id == id);
    if (layerIndex == -1) return;
    
    final layer = state.textLayers[layerIndex];
    final duration = layer.endTime - layer.startTime;
    double newStart = layer.startTime + delta;
    double newEnd = layer.endTime + delta;

    if (newStart < 0) {
      newStart = 0;
      newEnd = duration;
    }
    
    final updated = List<TextLayerModel>.from(state.textLayers);
    updated[layerIndex] = layer.copyWith(startTime: newStart, endTime: newEnd);
    state = state.copyWith(textLayers: updated);
  }

  // --- Media Layer Operations ---

  void addMediaLayer(MediaLayerModel media) {
    if (media.type == MediaType.video) {
      pushHistory();
    }
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
    pushHistory();
    final updated = state.mediaLayers.map((m) {
      return m.id == updatedMedia.id ? updatedMedia : m;
    }).toList();

    state = state.copyWith(
      mediaLayers: updated,
      updatedAt: DateTime.now(),
    );
  }

  void updateMediaLayerProperties(String id, {double? volume, double? playbackSpeed, double? startTime, double? trimStartTime, double? mediaDuration, bool? isMuted}) {
    pushHistory();
    state = state.copyWith(
      mediaLayers: state.mediaLayers.map((layer) {
        if (layer.id == id) {
          return layer.copyWith(
            volume: volume,
            playbackSpeed: playbackSpeed,
            startTime: startTime,
            trimStartTime: trimStartTime,
            mediaDuration: mediaDuration,
            isMuted: isMuted,
          );
        }
        return layer;
      }).toList(),
    );
  }

  void splitMediaLayer(String id, double splitTime) {
    final layerIndex = state.mediaLayers.indexWhere((l) => l.id == id);
    if (layerIndex == -1) return;
    
    final layer = state.mediaLayers[layerIndex];
    if (splitTime <= layer.startTime || splitTime >= layer.startTime + layer.mediaDuration) return; // Cannot split outside bounds
    
    pushHistory();
    
    final duration1 = splitTime - layer.startTime;
    final duration2 = layer.mediaDuration - duration1;
    
    final layer1 = layer.copyWith(mediaDuration: duration1);
    final layer2 = layer.copyWith(
      id: const Uuid().v4(),
      startTime: splitTime,
      trimStartTime: layer.trimStartTime + duration1,
      mediaDuration: duration2,
    );
    
    final newLayers = List<MediaLayerModel>.from(state.mediaLayers);
    newLayers[layerIndex] = layer1;
    newLayers.insert(layerIndex + 1, layer2);
    
    state = state.copyWith(
      mediaLayers: newLayers,
      selectedLayerId: layer2.id,
    );
  }

  void trimMediaLayerStart(String id, double delta) {
    final layerIndex = state.mediaLayers.indexWhere((l) => l.id == id);
    if (layerIndex == -1) return;
    
    final layer = state.mediaLayers[layerIndex];
    if (layer.mediaDuration - delta <= 0.5) return; // Prevent shrinking too small
    
    final updated = List<MediaLayerModel>.from(state.mediaLayers);
    updated[layerIndex] = layer.copyWith(
      startTime: layer.startTime + delta,
      trimStartTime: layer.trimStartTime + delta,
      mediaDuration: layer.mediaDuration - delta,
    );
    state = state.copyWith(mediaLayers: updated);
  }

  void trimMediaLayerEnd(String id, double delta) {
    final layerIndex = state.mediaLayers.indexWhere((l) => l.id == id);
    if (layerIndex == -1) return;
    
    final layer = state.mediaLayers[layerIndex];
    if (layer.mediaDuration + delta <= 0.5) return;
    
    final updated = List<MediaLayerModel>.from(state.mediaLayers);
    updated[layerIndex] = layer.copyWith(
      mediaDuration: layer.mediaDuration + delta,
    );
    state = state.copyWith(mediaLayers: updated);
  }

  void moveMediaLayer(String id, double delta) {
    final layerIndex = state.mediaLayers.indexWhere((l) => l.id == id);
    if (layerIndex == -1) return;
    
    final layer = state.mediaLayers[layerIndex];
    double newStart = layer.startTime + delta;
    if (newStart < 0) newStart = 0;
    
    final updated = List<MediaLayerModel>.from(state.mediaLayers);
    updated[layerIndex] = layer.copyWith(startTime: newStart);
    state = state.copyWith(mediaLayers: updated);
  }

  void replaceMediaLayerPath(String id, String newPath, double newDuration) {
    pushHistory();
    state = state.copyWith(
      mediaLayers: state.mediaLayers.map((layer) {
        if (layer.id == id) {
          return layer.copyWith(
            path: newPath,
            mediaDuration: newDuration,
            trimStartTime: 0.0,
          );
        }
        return layer;
      }).toList(),
    );
  }

  void extractAudio(String videoId, String audioPath, double duration) {
    final layerIndex = state.mediaLayers.indexWhere((l) => l.id == videoId);
    if (layerIndex == -1) return;
    final videoLayer = state.mediaLayers[layerIndex];
    
    pushHistory();
    final audioLayer = MediaLayerModel(
      id: const Uuid().v4(),
      path: audioPath,
      type: MediaType.audio,
      startTime: videoLayer.startTime,
      trimStartTime: videoLayer.trimStartTime,
      mediaDuration: duration,
    );
    
    final updated = [...state.mediaLayers, audioLayer].map((m) {
      if (m.id == videoId) return m.copyWith(isMuted: true);
      return m;
    }).toList();
    
    state = state.copyWith(mediaLayers: updated);
  }



  void deleteMediaLayer(String id) {
    pushHistory();
    final updated = state.mediaLayers.where((m) => m.id != id).toList();
    state = state.copyWith(
      mediaLayers: updated,
      selectedLayerId: state.selectedLayerId == id ? null : state.selectedLayerId,
      updatedAt: DateTime.now(),
    );
  }

  void toggleMuteMediaLayer(String id) {
    pushHistory();
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
    pushHistory();
    final list = List<TextLayerModel>.from(state.textLayers);
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    state = state.copyWith(
      textLayers: list,
      updatedAt: DateTime.now(),
    );
  }

  void reorderMediaLayers(int oldIndex, int newIndex) {
    pushHistory();
    final list = List<MediaLayerModel>.from(state.mediaLayers);
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    state = state.copyWith(
      mediaLayers: list,
      updatedAt: DateTime.now(),
    );
  }
}
