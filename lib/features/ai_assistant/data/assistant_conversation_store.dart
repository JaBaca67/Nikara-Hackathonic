import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nikara_app/features/ai_assistant/domain/models/assistant_models.dart';

/// Una conversación guardada, con lo mínimo para reabrirla.
@immutable
class AssistantConversation {
  const AssistantConversation({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
  });

  final String id;

  /// Se deriva del primer mensaje del usuario — nadie quiere ponerle nombre a
  /// un chat antes de tenerlo.
  final String title;

  final DateTime updatedAt;
  final List<AssistantMessage> messages;
}

/// Guarda los hilos del asistente en el teléfono.
///
/// ## Por qué `SharedPreferences` y no Supabase
///
/// Un historial de chat es texto y se consulta solo desde el aparato donde se
/// escribió, así que no justifica una tabla con sus policies. Es además el
/// mismo criterio que ya usa la app para la sesión de invitado y los extras de
/// perfil. Consecuencia aceptada: no sincroniza entre dispositivos y se pierde
/// al desinstalar — a cambio funciona también sin cuenta.
///
/// ## Qué se guarda y qué no
///
/// De cada recomendación se persiste **solo el id**, no el nombre ni la foto.
/// Al reabrir el hilo las tarjetas se vuelven a hidratar desde Supabase, así
/// que muestran los datos de hoy y no los de la semana pasada. Si un negocio
/// se dio de baja, su tarjeta simplemente no aparece — mejor eso que una ficha
/// fantasma.
class AssistantConversationStore {
  factory AssistantConversationStore() => instance;

  AssistantConversationStore._internal();

  static final AssistantConversationStore instance =
      AssistantConversationStore._internal();

  static const _key = 'assistant_conversations_v1';

  /// Tope de hilos guardados. Las preferencias no son una base de datos: con
  /// un historial sin límite, cada arranque pagaría el costo de leer y
  /// deserializar todo.
  static const _maxConversations = 20;

  /// Avisa a la UI que la lista cambió, sin que la pantalla tenga que
  /// recargarla a mano — mismo patrón que `FavoritesService.idsNotifier`.
  final ValueNotifier<int> revision = ValueNotifier(0);

  Future<List<AssistantConversation>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      final conversations = decoded
          .whereType<Map<String, dynamic>>()
          .map(_decodeConversation)
          .whereType<AssistantConversation>()
          .toList();

      conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return conversations;
    } catch (e) {
      // Un historial corrupto no puede impedir abrir el asistente: se reporta
      // y se sigue con la lista vacía.
      debugPrint('[AssistantConversationStore] no se pudo leer: $e');
      return const [];
    }
  }

  /// Crea o actualiza un hilo. Devuelve el id con el que quedó guardado.
  Future<String> save({
    String? id,
    required List<AssistantMessage> messages,
  }) async {
    final usable = messages.where((m) => !m.isError).toList();
    // Un hilo con solo el saludo del asistente no es una conversación.
    if (!usable.any((m) => m.isUser)) return id ?? '';

    final conversationId =
        id ?? DateTime.now().microsecondsSinceEpoch.toString();

    try {
      final current = await load();
      final others = current.where((c) => c.id != conversationId).toList();

      others.insert(
        0,
        AssistantConversation(
          id: conversationId,
          title: _titleFrom(usable),
          updatedAt: DateTime.now(),
          messages: messages,
        ),
      );

      final trimmed = others.take(_maxConversations).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(trimmed.map(_encodeConversation).toList()),
      );
      revision.value++;
    } catch (e) {
      debugPrint('[AssistantConversationStore] no se pudo guardar: $e');
    }
    return conversationId;
  }

  Future<void> delete(String id) async {
    try {
      final remaining = (await load()).where((c) => c.id != id).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(remaining.map(_encodeConversation).toList()),
      );
      revision.value++;
    } catch (e) {
      debugPrint('[AssistantConversationStore] no se pudo borrar: $e');
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      revision.value++;
    } catch (e) {
      debugPrint('[AssistantConversationStore] no se pudo limpiar: $e');
    }
  }

  String _titleFrom(List<AssistantMessage> messages) {
    final first = messages.firstWhere(
      (m) => m.isUser,
      orElse: () => messages.first,
    );
    final text = first.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length <= 42) return text;
    return '${text.substring(0, 41)}…';
  }

  // --- Serialización ------------------------------------------------------
  // Deliberadamente separada de la de los modelos: lo que viaja a la Edge
  // Function y lo que se guarda en el teléfono son dos contratos distintos y
  // cambian por motivos distintos.

  Map<String, dynamic> _encodeConversation(AssistantConversation c) => {
    'id': c.id,
    'title': c.title,
    'updatedAt': c.updatedAt.toIso8601String(),
    'messages': c.messages
        .where((m) => !m.isError)
        .map(_encodeMessage)
        .toList(),
  };

  Map<String, dynamic> _encodeMessage(AssistantMessage m) => {
    'author': m.isUser ? 'user' : 'assistant',
    'text': m.text,
    if (m.recommendations.isNotEmpty)
      'recommendations': [
        for (final r in m.recommendations)
          {'id': r.id, 'kind': _kindToWire(r.kind), 'reason': r.reason},
      ],
    if (m.itinerary != null)
      'itinerary': {
        'title': m.itinerary!.title,
        'days': [
          for (final day in m.itinerary!.days)
            {
              'day': day.day,
              'stops': [
                for (final stop in day.stops)
                  {
                    'id': stop.id,
                    'kind': _kindToWire(stop.kind),
                    'note': stop.note,
                  },
              ],
            },
        ],
      },
  };

  static String _kindToWire(AssistantItemKind kind) =>
      kind == AssistantItemKind.ecoActivity ? 'eco_activity' : 'business';

  AssistantConversation? _decodeConversation(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null) return null;

    final messages = ((json['messages'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_decodeMessage)
        .toList();
    if (messages.isEmpty) return null;

    return AssistantConversation(
      id: id,
      title: json['title'] as String? ?? 'Conversación',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      messages: messages,
    );
  }

  AssistantMessage _decodeMessage(Map<String, dynamic> json) {
    final isUser = json['author'] == 'user';
    final text = json['text'] as String? ?? '';
    if (isUser) return AssistantMessage.user(text);

    return AssistantMessage(
      author: AssistantAuthor.assistant,
      text: text,
      recommendations: ((json['recommendations'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AssistantRecommendation.fromJson)
          .toList(),
      itinerary: json['itinerary'] is Map<String, dynamic>
          ? AssistantItinerary.fromJson(
              json['itinerary'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}
