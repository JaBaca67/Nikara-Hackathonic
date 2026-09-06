import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Envoltorio de `flutter_tts` para la navegación por voz del Modo Viaje.
///
/// Tres decisiones que no son obvias y que explican el "no se escucha nada"
/// que se reportaba antes:
///
///  1. **La configuración se espera.** Antes el constructor disparaba cuatro
///     `unawaited(...)` (`setLanguage`, `setSpeechRate`, `setVolume`,
///     `awaitSpeakCompletion`) y el primer `speak()` podía salir antes de que
///     el motor tuviera idioma configurado. En Android eso es silencio o una
///     frase en inglés. Ahora [_ensureReady] es un `Future` memoizado que todo
///     `speak()` aguarda.
///  2. **No se llama `stop()` antes de `speak()`.** Con
///     `awaitSpeakCompletion(true)`, `stop()` seguido inmediatamente de
///     `speak()` deja algunos motores de Android en un estado donde la
///     utterance nueva se cancela junto con la vieja. El reemplazo se hace con
///     `QUEUE_FLUSH`, que es la vía soportada para "esta frase pisa la anterior".
///  3. **Se pide foco de audio de navegación.** Sin
///     `setAudioAttributesForNavigation()` + `speak(focus: true)`, la voz
///     compite con la música en vez de bajarle el volumen (ducking).
///
/// Un dispositivo sin voz TTS no debe interrumpir la navegación, así que los
/// errores no se propagan — pero tampoco se pierden: quedan en [lastError] y
/// [isAvailable] para que la UI pueda saber que la voz está muerta.
class TtsService {
  factory TtsService() => instance;

  TtsService._internal();

  static final TtsService instance = TtsService._internal();

  final FlutterTts _tts = FlutterTts();

  /// Orden de preferencia de idioma. `es-NI` casi nunca está instalado, pero
  /// si estuviera es el acento correcto; el resto son los que sí suelen venir
  /// de fábrica en Android.
  static const List<String> _languageCandidates = [
    'es-NI',
    'es-MX',
    'es-US',
    'es-419',
    'es-ES',
    'es',
  ];

  Future<void>? _initialization;

  String? _resolvedLanguage;

  /// Último error de TTS, en español, o `null` si todo va bien. La navegación
  /// nunca se detiene por esto, pero deja de fallar en silencio.
  String? lastError;

  /// `false` cuando la inicialización falló o el dispositivo no tiene ninguna
  /// voz en español — la UI puede avisar en vez de dejar el toggle de voz
  /// encendido sin que suene nada.
  bool get isAvailable => _isAvailable;
  bool _isAvailable = true;

  /// Idioma efectivamente configurado (útil para diagnosticar en el teléfono).
  String? get resolvedLanguage => _resolvedLanguage;

  /// Idempotente: la primera llamada configura el motor, las siguientes
  /// esperan el mismo `Future`.
  Future<void> _ensureReady() {
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Sin esto, el `Future` de speak() resuelve al empezar a hablar y no al
      // terminar, y no hay forma de serializar dos anuncios seguidos.
      await _tts.awaitSpeakCompletion(true);

      _resolvedLanguage = await _pickLanguage();
      if (_resolvedLanguage == null) {
        _isAvailable = false;
        lastError =
            'Tu teléfono no tiene una voz en español instalada para la guía por voz.';
        debugPrint('[TtsService] no Spanish voice available on this device');
      } else {
        await _tts.setLanguage(_resolvedLanguage!);
      }

      // 0.5 es "media" en la escala de flutter_tts en Android; en navegación
      // conviene un poco más rápido para que la frase termine antes del giro.
      await _tts.setSpeechRate(0.55);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      await _setAndroidNavigationAudio();

      _tts.setErrorHandler((message) {
        lastError = 'La guía por voz falló: $message';
        debugPrint('[TtsService] engine error: $message');
      });
      _tts.setCompletionHandler(() => _speaking = false);
      _tts.setCancelHandler(() => _speaking = false);
    } catch (e) {
      _isAvailable = false;
      lastError = 'No se pudo iniciar la guía por voz.';
      debugPrint('[TtsService] initialization failed: $e');
    }
  }

  /// `setQueueMode` y `setAudioAttributesForNavigation` son solo de Android;
  /// en otras plataformas el canal responde `MissingPluginException` y eso no
  /// es un error real.
  Future<void> _setAndroidNavigationAudio() async {
    try {
      await _tts.setAudioAttributesForNavigation();
    } catch (e) {
      debugPrint('[TtsService] navigation audio attributes unavailable: $e');
    }
    try {
      // QUEUE_FLUSH: una instrucción nueva reemplaza a la anterior sin pasar
      // por stop(), que es lo que cortaba frases a la mitad.
      await _tts.setQueueMode(0);
    } catch (e) {
      debugPrint('[TtsService] queue mode unavailable: $e');
    }
  }

  Future<String?> _pickLanguage() async {
    for (final candidate in _languageCandidates) {
      try {
        final available = await _tts.isLanguageAvailable(candidate);
        if (available == true) return candidate;
      } catch (e) {
        debugPrint('[TtsService] isLanguageAvailable($candidate) failed: $e');
      }
    }
    // Algunos motores responden `false` a todo pero igual hablan español si se
    // les fija el idioma: se intenta el genérico antes de rendirse.
    try {
      final languages = await _tts.getLanguages;
      if (languages is List) {
        for (final language in languages) {
          final code = language.toString();
          if (code.toLowerCase().startsWith('es')) return code;
        }
      }
    } catch (e) {
      debugPrint('[TtsService] getLanguages failed: $e');
    }
    return null;
  }

  bool _speaking = false;

  /// True mientras hay una frase sonando (según el motor).
  bool get isSpeaking => _speaking;

  /// Lee [text]. Una frase nueva pisa a la anterior vía `QUEUE_FLUSH`.
  ///
  /// El `Future` resuelve cuando el motor termina de hablar, así que la
  /// navegación debe llamarlo con `unawaited` — nunca bloquear el manejo de un
  /// fix de GPS esperando a la voz.
  Future<void> speak(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    await _ensureReady();
    if (!_isAvailable) return;
    try {
      _speaking = true;
      // focus: true pide foco de audio transitorio en Android — le baja el
      // volumen a la música en vez de mezclarse con ella.
      await _tts.speak(clean, focus: true);
      lastError = null;
    } catch (e) {
      _speaking = false;
      lastError = 'La guía por voz falló: $e';
      debugPrint('[TtsService] speak failed: $e');
    }
  }

  Future<void> stop() async {
    _speaking = false;
    try {
      await _tts.stop();
    } catch (e) {
      lastError = 'No se pudo detener la guía por voz: $e';
      debugPrint('[TtsService] stop failed: $e');
    }
  }

  /// Fuerza que la próxima llamada vuelva a configurar el motor — sirve si el
  /// usuario instala la voz en español con la app abierta.
  void invalidate() {
    _initialization = null;
    _isAvailable = true;
    lastError = null;
  }
}
