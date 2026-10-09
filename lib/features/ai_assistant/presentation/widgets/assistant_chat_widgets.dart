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
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              isUser ? 'Vos' : 'Níkara IA',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.settingsTextMuted,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                  ),
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
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withValues(alpha: 0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: AppTextStyles.bodyText1.copyWith(
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
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
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
            mainAxisSize: MainAxisSize.min,
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
              Flexible(
                child: Text(
                  'Buscando ideas para tu viaje…',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.settingsTextMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
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
    // Scaffold ya reserva el espacio del teclado. Sumar viewInsets otra vez
    // desplazaba el campo y podía dejar el chat sin espacio visible.
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.07),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: enabled ? onSubmit : null,
                minLines: 1,
                maxLines: 4,
                style: AppTextStyles.bodyText1.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Preguntale a tu guía…',
                  hintStyle: AppTextStyles.body.copyWith(
                    color: AppColors.settingsTextMuted,
                  ),
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final canSend = enabled && value.text.trim().isNotEmpty;
                return IconButton.filled(
                  onPressed: canSend ? () => onSubmit(controller.text) : null,
                  tooltip: 'Enviar mensaje',
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(48),
                    backgroundColor: AppColors.goldFill,
                    foregroundColor: AppColors.textPrimary,
                    disabledBackgroundColor: AppColors.background,
                    disabledForegroundColor: AppColors.settingsTextMuted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 24),
                );
              },
            ),
          ],
        ),
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

  @override
  void initState() {
    super.initState();
    widget.store.revision.addListener(_reload);
  }

  @override
  void dispose() {
    widget.store.revision.removeListener(_reload);
    super.dispose();
  }

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
                if (snapshot.hasError) {
                  return Center(
                    child: TextButton(
                      onPressed: _reload,
                      child: const Text(
                        'No se pudo cargar el historial. Reintentar',
                      ),
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
                        'tengas se guardan en tu cuenta.',
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
                          try {
                            await widget.store.delete(conversation.id);
                            if (mounted) _reload();
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No se pudo borrar la conversación.',
                                  ),
                                ),
                              );
                            }
                          }
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
