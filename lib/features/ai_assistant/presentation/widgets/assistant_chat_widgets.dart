import 'package:flutter/material.dart';

import 'package:nikara_app/features/ai_assistant/data/assistant_conversation_store.dart';
import 'package:nikara_app/features/ai_assistant/domain/models/assistant_models.dart';
import 'package:nikara_app/features/ai_assistant/domain/models/assistant_place.dart';
import 'package:nikara_app/features/ai_assistant/presentation/widgets/assistant_cards.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Piezas del hilo de chat. Viven aparte de la pantalla para que esta se lea
/// como lo que hace (enviar, hidratar, guardar) y no como una pila de widgets.

/// Una burbuja del hilo, con sus tarjetas de recomendación e itinerario.
class AssistantMessageBubble extends StatelessWidget {
  const AssistantMessageBubble({
    super.key,
    required this.message,
    required this.places,
    required this.onOpenProfile,
    required this.onShowOnMap,
    required this.onSaveItinerary,
    required this.savingItinerary,
    required this.savedItineraries,
  });

  final AssistantMessage message;
  final Map<String, AssistantPlace> places;
  final void Function(AssistantPlace) onOpenProfile;
  final void Function(AssistantPlace) onShowOnMap;
  final void Function(AssistantItinerary) onSaveItinerary;
  final String? savingItinerary;
  final Set<String> savedItineraries;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final itinerary = message.itinerary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    // Gold para la voz del usuario (es el acento primario de
                    // la app); superficie neutra para el asistente.
                    color: isUser ? AppColors.goldFill : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppRadius.md),
                      topRight: const Radius.circular(AppRadius.md),
                      bottomLeft: Radius.circular(
                        isUser ? AppRadius.md : AppRadius.xs,
                      ),
                      bottomRight: Radius.circular(
                        isUser ? AppRadius.xs : AppRadius.md,
                      ),
                    ),
                    border: isUser
                        ? null
                        : Border.all(
                            color: message.isError
                                ? AppColors.error
                                : AppColors.border,
                          ),
                  ),
                  child: Text(
                    message.text,
                    style: AppTextStyles.body.copyWith(
                      color: message.isError
                          ? AppColors.error
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          for (final rec in message.recommendations)
            if (places[rec.id] case final place?)
              AssistantRecommendationCard(
                place: place,
                onOpenProfile: () => onOpenProfile(place),
                onShowOnMap: () => onShowOnMap(place),
              ),
          if (itinerary != null && itinerary.totalStops > 0)
            AssistantItineraryCard(
              itinerary: itinerary,
              placeResolver: (id) => places[id],
              onSave: () => onSaveItinerary(itinerary),
              isSaving: savingItinerary == itinerary.title,
              isSaved: savedItineraries.contains(itinerary.title),
            ),
        ],
      ),
    );
  }
}

class AssistantTypingBubble extends StatelessWidget {
  const AssistantTypingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.oliveText,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Pensando…',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.settingsTextMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AssistantQuickReplies extends StatelessWidget {
  const AssistantQuickReplies({
    super.key,
    required this.replies,
    required this.enabled,
    required this.onTap,
  });

  final List<String> replies;
  final bool enabled;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          for (final reply in replies)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ActionChip(
                label: Text(
                  reply,
                  style: AppTextStyles.homeChipLabel.copyWith(
                    color: AppColors.oliveText,
                  ),
                ),
                onPressed: enabled ? () => onTap(reply) : null,
                backgroundColor: AppColors.surface,
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AssistantComposer extends StatelessWidget {
  const AssistantComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool enabled;
  final void Function(String) onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              textInputAction: TextInputAction.send,
              onSubmitted: onSubmit,
              minLines: 1,
              maxLines: 4,
              style: AppTextStyles.inputText.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Preguntale a Níkara IA…',
                hintStyle: AppTextStyles.inputText.copyWith(
                  color: AppColors.settingsTextMuted,
                ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: const BorderSide(color: AppColors.oliveText),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // 48x48 para cumplir el mínimo de target táctil accesible.
          SizedBox(
            width: 48,
            height: 48,
            child: Material(
              color: enabled
                  ? AppColors.oliveFill
                  : AppColors.oliveFill.withValues(alpha: 0.5),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: enabled ? () => onSubmit(controller.text) : null,
                child: Icon(
                  Icons.arrow_upward,
                  size: 20,
                  // Ningún Fill de marca lleva ícono blanco encima: los tres
                  // son claros (regla del sistema de diseño).
                  color: AppColors.textPrimary,
                  semanticLabel: 'Enviar mensaje',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista de conversaciones guardadas. Devuelve la elegida, o null si se cerró
/// sin elegir.
Future<AssistantConversation?> showAssistantHistorySheet(
  BuildContext context, {
  required AssistantConversationStore store,
}) {
  return showModalBottomSheet<AssistantConversation>(
    context: context,
    backgroundColor: AppColors.surface,
    useSafeArea: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (sheetContext) => _HistorySheet(store: store),
  );
}

class _HistorySheet extends StatefulWidget {
  const _HistorySheet({required this.store});

  final AssistantConversationStore store;

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  late Future<List<AssistantConversation>> _future = widget.store.load();

  void _reload() => setState(() => _future = widget.store.load());

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Tus conversaciones',
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  color: AppColors.settingsTextMuted,
                  tooltip: 'Cerrar',
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<AssistantConversation>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppColors.oliveText,
                    ),
                  );
                }
                final conversations = snapshot.data ?? const [];
                if (conversations.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Center(
                      child: Text(
                        'Todavía no tenés conversaciones guardadas. Las que '
                        'tengas se guardan solas en este teléfono.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.settingsTextMuted,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  itemCount: conversations.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        conversation.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        _relativeDate(conversation.updatedAt),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.settingsTextMuted,
                        ),
                      ),
                      trailing: IconButton(
                        onPressed: () async {
                          await widget.store.delete(conversation.id);
                          _reload();
                        },
                        icon: const Icon(Icons.delete_outline),
                        color: AppColors.destructive,
                        tooltip: 'Borrar esta conversación',
                      ),
                      onTap: () => Navigator.of(
                        context,
                      ).pop<AssistantConversation>(conversation),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Fecha en lenguaje natural: "hoy" y "ayer" son lo que la gente busca en
  /// una lista de chats, no una fecha completa.
  String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final difference = today.difference(day).inDays;

    final time =
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';

    if (difference == 0) return 'Hoy · $time';
    if (difference == 1) return 'Ayer · $time';
    if (difference < 7) return 'Hace $difference días';
    return '${date.day}/${date.month}/${date.year}';
  }
}
