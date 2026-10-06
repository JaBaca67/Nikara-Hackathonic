import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/features/ai_assistant/domain/models/assistant_models.dart';

class AssistantServiceException implements Exception {
  const AssistantServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Cliente de la Edge Function `travel-assistant`.
///
/// ## Por qué pasa por una función de servidor y no habla con Gemini directo
///
/// La clave de API no puede vivir en el cliente: un `--dart-define` queda como
/// texto plano dentro del APK y se extrae con herramientas estándar. Además el
/// id del modelo es una variable de entorno del servidor, así que un retiro de
/// modelo (a `gemini-2.0-flash` le pasó nueve meses después de salir) se
/// resuelve sin publicar una versión nueva de la app.
///
/// Singleton con el patrón del proyecto; no guarda el historial — de eso se
/// encarga la pantalla, porque un hilo de conversación pertenece a la vista
/// abierta y no a toda la app.
class AssistantService {
  factory AssistantService() => instance;

  AssistantService._internal();

  static final AssistantService instance = AssistantService._internal();

  static const _functionName = 'travel-assistant';

  /// Cuántos mensajes se reenvían como contexto. El servidor igual recorta,
  /// pero no tiene sentido mandar de más por la red.
  static const _historyLimit = 6;

  SupabaseClient get _client => Supabase.instance.client;

  /// Manda el hilo y devuelve la respuesta del asistente.
  ///
  /// [history] va completo tal como se ve en pantalla; acá se filtran los
  /// avisos de error y se recortan los más viejos. Los errores no se reenvían
  /// a propósito: si el modelo lee sus propias disculpas, empieza a
  /// disculparse en cadena.
  Future<AssistantReply> send({
    required List<AssistantMessage> history,
    String? city,
  }) async {
    final usable = history.where((m) => !m.isError).toList(growable: false);
    if (usable.isEmpty) {
      throw const AssistantServiceException('Escribí un mensaje primero.');
    }

    final payload = <String, dynamic>{
      'messages': [
        for (final message in usable.sublist(
          usable.length > _historyLimit ? usable.length - _historyLimit : 0,
        ))
          {'role': message.isUser ? 'user' : 'assistant', 'text': message.text},
      ],
      if (city != null && city.isNotEmpty) 'city': city,
    };

    try {
      final response = await _client.functions.invoke(
        _functionName,
        body: payload,
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const AssistantServiceException(
          'El asistente respondió en un formato inesperado. Intentá de nuevo.',
        );
      }

      // La función devuelve `error` en español ya listo para mostrar (sin
      // cupo, sin configurar, etc.): se respeta ese mensaje en vez de
      // reemplazarlo por uno genérico.
      final error = data['error'];
      if (error is String && error.isNotEmpty) {
        throw AssistantServiceException(error);
      }

      return AssistantReply.fromJson(data);
    } on FunctionException catch (e) {
      // `FunctionException` trae el cuerpo de la respuesta de error, que es
      // donde la función puso su mensaje en español.
      final details = e.details;
      if (details is Map && details['error'] is String) {
        throw AssistantServiceException(details['error'] as String);
      }
      debugPrint('[AssistantService] FunctionException ${e.status}: $details');
      throw const AssistantServiceException(
        'No pude comunicarme con el asistente. Revisá tu internet e intentá de nuevo.',
      );
    } on AssistantServiceException {
      rethrow;
    } catch (e) {
      debugPrint('[AssistantService] error inesperado: $e');
      throw const AssistantServiceException(
        'Ocurrió un error al consultar al asistente. Intentá de nuevo.',
      );
    }
  }
}
