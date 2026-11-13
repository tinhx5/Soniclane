import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceHudState {
  final bool isListening;
  final bool isAvailable;
  final String recognizedText;
  final String? errorMessage;

  const VoiceHudState({
    this.isListening = false,
    this.isAvailable = false,
    this.recognizedText = '',
    this.errorMessage,
  });

  VoiceHudState copyWith({
    bool? isListening,
    bool? isAvailable,
    String? recognizedText,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VoiceHudState(
      isListening: isListening ?? this.isListening,
      isAvailable: isAvailable ?? this.isAvailable,
      recognizedText: recognizedText ?? this.recognizedText,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Real cross-platform Speech-to-Text service (iOS, Android, Windows)
/// for hands-free cockpit voice queries.
class VoiceSearchService {
  VoiceSearchService._();
  static final VoiceSearchService instance = VoiceSearchService._();

  final SpeechToText _speech = SpeechToText();
  final _controller = StreamController<VoiceHudState>.broadcast();
  VoiceHudState _state = const VoiceHudState();
  bool _initialized = false;

  VoiceHudState get state => _state;
  Stream<VoiceHudState> get stream => _controller.stream;

  Future<bool> startListening({
    required ValueChanged<String> onFinalResult,
  }) async {
    try {
      if (!_initialized) {
        final ok = await _speech.initialize(
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') {
              _emit(_state.copyWith(isListening: false));
            }
          },
          onError: (err) {
            _emit(_state.copyWith(
              isListening: false,
              errorMessage: err.errorMsg,
            ));
          },
        );
        _initialized = true;
        _emit(_state.copyWith(isAvailable: ok));
      }

      if (!_state.isAvailable) {
        _emit(_state.copyWith(
          isListening: false,
          errorMessage: 'Microphone permission or speech engine unavailable. Use Voice Presets below.',
        ));
        return false;
      }

      _emit(_state.copyWith(
        isListening: true,
        recognizedText: '',
        clearError: true,
      ));

      await _speech.listen(
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.search,
          partialResults: true,
          cancelOnError: true,
        ),
        onResult: (result) {
          _emit(_state.copyWith(recognizedText: result.recognizedWords));
          if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
            _emit(_state.copyWith(isListening: false));
            onFinalResult(result.recognizedWords.trim());
          }
        },
      );
      return true;
    } catch (e) {
      debugPrint('[VoiceSearch] Init/listen fallback: $e');
      _emit(_state.copyWith(
        isListening: false,
        errorMessage: 'Voice recognition unavailable on this device. Tap a preset shortcut.',
      ));
      return false;
    }
  }

  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {}
    _emit(_state.copyWith(isListening: false));
  }

  void _emit(VoiceHudState next) {
    _state = next;
    if (!_controller.isClosed) {
      _controller.add(next);
    }
  }
}
