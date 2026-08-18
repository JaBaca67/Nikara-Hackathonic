import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Wraps `flutter_tts` for [MapScreen]'s live turn-by-turn voice guidance —
/// singleton like every other service in this app (see
/// `lib/core/services/auth_service.dart`'s canonical pattern). Every call
/// is best-effort and swallows its own errors: a device/platform without a
/// working TTS voice should never crash or interrupt navigation, it should
/// just stay silent.
class TtsService {
  factory TtsService() => instance;

  TtsService._internal() {
    // es-419 (Latin American Spanish) isn't a guaranteed-installed voice on
    // every Android/iOS/web/desktop TTS engine, so es-US is the safer,
    // broadly-available default for Spanish speech across platforms.
    unawaited(_tts.setLanguage('es-US'));
    unawaited(_tts.setSpeechRate(0.5));
    unawaited(_tts.setVolume(1.0));
    unawaited(_tts.awaitSpeakCompletion(true));
  }

  static final TtsService instance = TtsService._internal();

  final FlutterTts _tts = FlutterTts();

  /// Speaks [text] out loud, cutting off whatever utterance is already
  /// in-flight — a new maneuver instruction always takes priority over
  /// finishing the previous one, since Directions steps can arrive faster
  /// than a sentence takes to read.
  Future<void> speak(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[TtsService] speak failed: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('[TtsService] stop failed: $e');
    }
  }
}
