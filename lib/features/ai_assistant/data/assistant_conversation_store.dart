import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:nikara_app/core/services/remote_user_data_service.dart';

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

/// Conversations belong to the authenticated account in Supabase.
/// Guest conversations remain in screen memory and are never saved to disk.
class AssistantConversationStore {
  factory AssistantConversationStore() => instance;

  AssistantConversationStore._internal() : _remote = RemoteUserDataService();
  AssistantConversationStore.forTesting(SupabaseClient client)
    : _remote = RemoteUserDataService(client: client);
  final RemoteUserDataService _remote;

  static final AssistantConversationStore instance =
      AssistantConversationStore._internal();

  /// Avisa a la UI que la lista cambió, sin que la pantalla tenga que
  /// recargarla a mano — mismo patrón que `FavoritesService.idsNotifier`.
  final ValueNotifier<int> revision = ValueNotifier(0);

  Future<List<AssistantConversation>> load() async {
    final userId = _remote.client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await _remote.client
        .from('assistant_conversations')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false)
        .limit(20);
    _remote.requireSameUser(userId);
    return rows
        .map(
          (row) =>
              _decodeConversation({...row, 'updatedAt': row['updated_at']}),
        )
        .whereType<AssistantConversation>()
        .toList();
  }

  Future<String> save({
    String? id,
    required List<AssistantMessage> messages,
  }) async {
    final userId = _remote.client.auth.currentUser?.id;
    if (userId == null) return '';
    final usable = messages.where((m) => !m.isError).toList();
    if (!usable.any((m) => m.isUser)) return id ?? '';
    final conversationId = id == null || id.isEmpty ? const Uuid().v4() : id;
    final saved = await _remote.client
        .from('assistant_conversations')
        .upsert({
          'id': conversationId,
          'user_id': userId,
          'title': _titleFrom(usable),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'messages': usable.map(_encodeMessage).toList(),
        }, onConflict: 'id')
        .select('id')
        .single();
    _remote.requireSameUser(userId);
    revision.value++;
    return saved['id'] as String;
  }

  Future<void> delete(String id) async {
    final userId = _remote.requireUser();
    await _remote.client
        .from('assistant_conversations')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
    _remote.requireSameUser(userId);
    revision.value++;
  }

  Future<void> clear() async {
    final userId = _remote.requireUser();
    await _remote.client
        .from('assistant_conversations')
        .delete()
        .eq('user_id', userId);
    _remote.requireSameUser(userId);
    revision.value++;
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
