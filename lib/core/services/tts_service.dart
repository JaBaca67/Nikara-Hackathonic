import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Envoltorio de `flutter_tts` para la navegación de voz de [MapScreen]; cada llamada traga sus propios errores, un dispositivo sin voz TTS no debe interrumpir la navegación.
class TtsService {
  factory TtsService() => instance;

  TtsService._internal() {
    // es-419 no está garantizado en todos los motores TTS; es-US es más ampliamente disponible.
    unawaited(_tts.setLanguage('es-US'));
    unawaited(_tts.setSpeechRate(0.5));
    unawaited(_tts.setVolume(1.0));
    unawaited(_tts.awaitSpeakCompletion(true));
  }

  static final TtsService instance = TtsService._internal();

  final FlutterTts _tts = FlutterTts();

  /// Corta cualquier frase en curso: una nueva instrucción de maniobra siempre tiene prioridad.
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
