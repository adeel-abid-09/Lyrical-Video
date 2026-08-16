import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/media_layer_model.dart';
import '../models/text_layer_model.dart';
import '../services/groq_auto_lyrics_service.dart';
import 'editor_state_notifier.dart';

enum AutoLyricsStatus { idle, generating, success, error }

class AutoLyricsState {
  final AutoLyricsStatus status;
  final String errorMessage;
  final bool isNetworkError;
  final int generatedCount;
  final String? activeTrackName;

  const AutoLyricsState({
    this.status = AutoLyricsStatus.idle,
    this.errorMessage = '',
    this.isNetworkError = false,
    this.generatedCount = 0,
    this.activeTrackName,
  });

  AutoLyricsState copyWith({
    AutoLyricsStatus? status,
    String? errorMessage,
    bool? isNetworkError,
    int? generatedCount,
    String? activeTrackName,
  }) {
    return AutoLyricsState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      isNetworkError: isNetworkError ?? this.isNetworkError,
      generatedCount: generatedCount ?? this.generatedCount,
      activeTrackName: activeTrackName ?? this.activeTrackName,
    );
  }
}

class AutoLyricsNotifier extends StateNotifier<AutoLyricsState> {
  final Ref _ref;

  AutoLyricsNotifier(this._ref) : super(const AutoLyricsState());

  Future<void> startGeneration(MediaLayerModel targetLayer) async {
    if (state.status == AutoLyricsStatus.generating) return;

    state = state.copyWith(
      status: AutoLyricsStatus.generating,
      errorMessage: '',
      isNetworkError: false,
      generatedCount: 0,
      activeTrackName: targetLayer.path.split(RegExp(r'[\\/]')).last,
    );

    try {
      final project = _ref.read(editorProjectProvider);
      final lyrics = await GroqAutoLyricsService.generateLyricsFromAudio(
        targetLayer.path,
        totalDuration: project.duration,
      );

      // Add to project timeline directly
      _ref.read(editorProjectProvider.notifier).addTextLayers(lyrics);

      state = state.copyWith(
        status: AutoLyricsStatus.success,
        generatedCount: lyrics.length,
      );
    } catch (e) {
      final errStr = e.toString();
      final isNet = errStr.toLowerCase().contains('socket') ||
          errStr.toLowerCase().contains('network') ||
          errStr.toLowerCase().contains('failed host lookup') ||
          errStr.toLowerCase().contains('timeout') ||
          errStr.toLowerCase().contains('connection');

      state = state.copyWith(
        status: AutoLyricsStatus.error,
        isNetworkError: isNet,
        errorMessage: isNet
            ? 'Please check your internet connection and try again.'
            : (errStr.contains('Exception:') ? errStr.replaceAll('Exception:', '').trim() : errStr),
      );
    }
  }

  void reset() {
    state = const AutoLyricsState();
  }
}

final autoLyricsProvider = StateNotifierProvider<AutoLyricsNotifier, AutoLyricsState>((ref) {
  return AutoLyricsNotifier(ref);
});
