import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nikara_app/features/ai_assistant/data/assistant_conversation_store.dart';
import 'package:nikara_app/features/ai_assistant/data/assistant_service.dart';
import 'package:nikara_app/features/ai_assistant/domain/models/assistant_models.dart';
import 'package:nikara_app/features/ai_assistant/domain/models/assistant_place.dart';
import 'package:nikara_app/features/ai_assistant/presentation/widgets/assistant_chat_widgets.dart';
import 'package:nikara_app/features/ai_assistant/presentation/widgets/assistant_travel_background.dart';
import 'package:nikara_app/features/ai_assistant/presentation/widgets/assistant_welcome.dart';
import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/presentation/screens/business_detail_screen.dart';
import 'package:nikara_app/features/eco/data/eco_service.dart';
import 'package:nikara_app/features/eco/presentation/screens/eco_detail_screen.dart';
import 'package:nikara_app/features/routes/data/route_service.dart';
import 'package:nikara_app/features/routes/domain/models/route_stop_model.dart';
import 'package:nikara_app/features/routes/presentation/screens/route_detail_screen.dart';
import 'package:nikara_app/shared/services/map_focus_controller.dart';
import 'package:nikara_app/shared/widgets/app_page_transition.dart';
import 'package:nikara_app/shared/widgets/circle_back_button.dart';
import 'package:nikara_app/shared/widgets/app_snackbar.dart';
import 'package:nikara_app/theme/app_motion.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Pantalla del asistente de Níkara.
///
/// ## Tier
///
/// Funcional, bajo la **excepción ECO autorizada**: conviven Gold (burbuja del
/// usuario, CTA de guardar ruta) y Olive (acciones, badges ECO), porque el
/// oliva acá no decora — distingue qué recomendación es ecológica. La mascota
/// es aparte: usa los colores del isotipo, que son identidad de marca y no
/// acentos de UI.
///
/// ## Por qué pantalla y no hoja inferior
///
/// La hoja servía mientras el asistente solo conversaba. Con historial de
/// conversaciones, tarjetas de lugares e itinerarios guardables, el contenido
/// dejó de caber cómodo sobre otra pantalla, y la mascota no tenía lugar donde
/// existir con un tamaño que se note.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, this.city});

  /// Ciudad aproximada del usuario, si quien abre la pantalla la sabe.
  final String? city;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  static const _quickReplies = [
    '¿Qué hay cerca de mí?',
    'Armame una ruta',
    'Solo lugares ECO',
    'Una escapada de fin de semana',
  ];

  final _service = AssistantService();
  final _store = AssistantConversationStore();
  final _businessService = BusinessStorageService();
  final _ecoService = EcoService();
  final _routeService = RouteService();

  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  final List<AssistantMessage> _messages = [];
  final Map<String, AssistantPlace> _places = {};

  /// Id del hilo abierto; null mientras la conversación todavía no se guardó
  /// (es decir, antes del primer mensaje del usuario).
  String? _conversationId;

  bool _isSending = false;
  final Set<String> _savedItineraries = {};
  String? _savingItinerary;

  /// True hasta que el usuario escribe algo: mientras tanto se muestra la
  /// portada con la mascota grande en vez del hilo.
  bool get _isEmpty => !_messages.any((m) => m.isUser);

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(AssistantMessage.user(text));
      _isSending = true;
      _controller.clear();
    });
    _scrollToEnd();

    try {
      final reply = await _service.send(history: _messages, city: widget.city);
      await _hydrate(reply);
      if (!mounted) return;
      setState(() => _messages.add(AssistantMessage.fromReply(reply)));
    } on AssistantServiceException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(AssistantMessage.error(e.message)));
    } finally {
      if (mounted) setState(() => _isSending = false);
      _scrollToEnd();
      try {
        _conversationId = await _store.save(
          id: _conversationId,
          messages: _messages,
        );
      } catch (_) {
        if (mounted) {
          AppSnackbar.showError(
            context,
            'No se pudo guardar la conversación. Verifica tu conexión.',
          );
        }
      }
    }
  }

  /// Convierte los ids que devolvió el asistente en datos reales.
  ///
  /// Los negocios se traen de una sola consulta (el catálogo aprobado son unas
  /// pocas filas, así que filtrar en memoria sale más barato que una consulta
  /// por id); las jornadas van de a una porque `EcoService` ya tiene
  /// `getActivityById`.
  Future<void> _hydrate(AssistantReply reply) async {
    final pending = <String, (AssistantItemKind, String)>{};

    void collect(String id, AssistantItemKind kind, String reason) {
      if (id.isEmpty || _places.containsKey(id)) return;
      pending[id] = (kind, reason);
    }

    for (final rec in reply.recommendations) {
      collect(rec.id, rec.kind, rec.reason);
    }
    for (final day in reply.itinerary?.days ?? const []) {
      for (final stop in day.stops) {
        collect(stop.id, stop.kind, stop.note);
      }
    }
    await _hydrateIds(pending);
  }

  Future<void> _hydrateIds(
    Map<String, (AssistantItemKind, String)> pending,
  ) async {
    if (pending.isEmpty) return;

    final needsBusinesses = pending.values.any(
      (entry) => entry.$1 == AssistantItemKind.business,
    );

    if (needsBusinesses) {
      try {
        final businesses = await _businessService.getBusinesses();
        for (final business in businesses) {
          final entry = pending[business.id];
          if (entry == null) continue;
          _places[business.id] = AssistantPlace.fromBusiness(
            business,
            entry.$2,
          );
        }
      } on BusinessServiceException catch (e) {
        // Un fallo de hidratación no invalida la respuesta: el texto se
        // muestra igual, solo sin tarjetas.
        debugPrint(
          '[AssistantScreen] no se pudo hidratar negocios: ${e.message}',
        );
      }
    }

    for (final id in pending.keys) {
      if (pending[id]!.$1 != AssistantItemKind.ecoActivity) continue;
      try {
        final activity = await _ecoService.getActivityById(id);
        if (activity == null) continue;
        _places[id] = AssistantPlace.fromActivity(activity, pending[id]!.$2);
      } catch (e) {
        debugPrint('[AssistantScreen] no se pudo hidratar la jornada $id: $e');
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: AppMotion.respect(context, AppMotion.standardDuration),
        curve: AppMotion.decelerate,
      );
    });
  }

  void _startNewConversation() {
    setState(() {
      _messages.clear();
      _places.clear();
      _savedItineraries.clear();
      _conversationId = null;
      _controller.clear();
    });
  }

  Future<void> _openHistory() async {
    final picked = await showAssistantHistorySheet(context, store: _store);
    if (picked == null || !mounted) return;

    setState(() {
      _messages
        ..clear()
        ..addAll(picked.messages);
      _places.clear();
      _savedItineraries.clear();
      _conversationId = picked.id;
    });

    // Las tarjetas guardadas son solo ids: se vuelven a hidratar para que
    // muestren los datos de hoy y no los del día que se guardó el hilo.
    final pending = <String, (AssistantItemKind, String)>{};
    for (final message in picked.messages) {
      for (final rec in message.recommendations) {
        pending[rec.id] = (rec.kind, rec.reason);
      }
      for (final day in message.itinerary?.days ?? const []) {
        for (final stop in day.stops) {
          pending[stop.id] = (stop.kind, stop.note);
        }
      }
    }
    await _hydrateIds(pending);
    if (mounted) setState(() {});
    _scrollToEnd();
  }

  void _openProfile(AssistantPlace place) {
    if (place.business != null) {
      pushSharedAxis(context, BusinessDetailScreen(business: place.business!));
      return;
    }
    if (place.activity != null) {
      pushSharedAxis(context, EcoDetailScreen(activity: place.activity!));
    }
  }

  void _showOnMap(AssistantPlace place) {
    if (!place.hasCoordinates) return;
    // Sale de la pantalla del asistente: el mapa es una tab, no algo que se
    // apile encima.
    Navigator.of(context).pop();

    // Una jornada ECO no es un `BusinessModel`, así que no tiene pin propio:
    // para ella se arranca el preview de ruta, igual que hace EcoDetailScreen.
    if (place.kind == AssistantItemKind.ecoActivity) {
      MapFocusController().startRoutePreview(
        MapRouteRequest(
          destinationId: place.id,
          destinationName: place.name,
          latitude: place.latitude!,
          longitude: place.longitude!,
        ),
      );
      return;
    }
    MapFocusController().focusOnBusiness(
      MapFocusRequest(
        businessId: place.id,
        name: place.name,
        latitude: place.latitude!,
        longitude: place.longitude!,
      ),
    );
  }

  Future<void> _saveItinerary(AssistantItinerary itinerary) async {
    setState(() => _savingItinerary = itinerary.title);

    try {
      final stops = <RouteStopModel>[];
      for (final day in itinerary.days) {
        var position = 0;
        for (final stop in day.stops) {
          final place = _places[stop.id];
          if (place == null) continue;
          stops.add(
            RouteStopModel(
              kind: place.kind == AssistantItemKind.ecoActivity
                  ? RouteStopKind.ecoActivity
                  : RouteStopKind.business,
              sourceId: place.id,
              title: place.name,
              subtitle: place.subtitle,
              category: place.kind == AssistantItemKind.ecoActivity
                  ? RouteStopCategory.eco
                  : RouteStopCategory.forBusinessCategory(
                      place.business?.category ?? '',
                    ),
              imagePath: place.imagePath,
              latitude: place.latitude,
              longitude: place.longitude,
              dayNumber: day.day,
              position: position++,
            ),
          );
        }
      }

      if (stops.isEmpty) {
        throw const AssistantServiceException(
          'Ese plan no tiene paradas que se puedan guardar.',
        );
      }

      final route = await _routeService.createRoute(
        title: itinerary.title,
        days: itinerary.days.length,
        isPublic: false,
        stops: stops,
      );

      if (!mounted) return;
      setState(() => _savedItineraries.add(itinerary.title));
      await pushSharedAxis(context, RouteDetailScreen(route: route));
    } catch (e) {
      if (!mounted) return;
      final message = e is AssistantServiceException
          ? e.message
          : 'No se pudo guardar la ruta. Revisá tu sesión e intentá de nuevo.';
      setState(() => _messages.add(AssistantMessage.error(message)));
      _scrollToEnd();
    } finally {
      if (mounted) setState(() => _savingItinerary = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.surface,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemStatusBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: AssistantTravelBackground(
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                _Header(
                  isThinking: _isSending,
                  onBack: () => Navigator.of(context).pop(),
                  onHistory: _openHistory,
                  onNew: _isEmpty || _isSending ? null : _startNewConversation,
                ),
                Expanded(
                  child: _isEmpty
                      ? AssistantWelcome(
                          onQuickReply: _send,
                          replies: _quickReplies,
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          itemCount: _messages.length + (_isSending ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _messages.length) {
                              return const AssistantTypingBubble();
                            }
                            return AssistantMessageBubble(
                              message: _messages[index],
                              places: _places,
                              onOpenProfile: _openProfile,
                              onShowOnMap: _showOnMap,
                              onSaveItinerary: _saveItinerary,
                              savingItinerary: _savingItinerary,
                              savedItineraries: _savedItineraries,
                            );
                          },
                        ),
                ),
                if (!_isEmpty)
                  AssistantQuickReplies(
                    replies: _quickReplies,
                    enabled: !_isSending,
                    onTap: _send,
                  ),
                AssistantComposer(
                  controller: _controller,
                  enabled: !_isSending,
                  onSubmit: _send,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isThinking,
    required this.onBack,
    required this.onHistory,
    required this.onNew,
  });

  final bool isThinking;
  final VoidCallback onBack;
  final VoidCallback onHistory;
  final VoidCallback? onNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.06)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md + MediaQuery.paddingOf(context).top,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          CircleBackButton(onTap: onBack),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Níkara IA',
                  style: AppTextStyles.heading.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  isThinking ? 'Pensando…' : 'Tu guía de viaje',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.settingsTextMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onHistory,
            icon: const Icon(Icons.history),
            color: AppColors.oliveText,
            tooltip: 'Conversaciones guardadas',
          ),
          IconButton(
            onPressed: onNew,
            icon: const Icon(Icons.add_comment_outlined),
            color: AppColors.oliveText,
            tooltip: 'Empezar una conversación nueva',
          ),
        ],
      ),
    );
  }
}
