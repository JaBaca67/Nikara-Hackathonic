import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/notifications/domain/models/app_notification.dart';
import 'package:nikara_app/features/notifications/domain/models/notification_message.dart';

class NotificationServiceException implements Exception {
  const NotificationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lee y escribe la tabla `notifications` (ver `docs/database_erd.md`).
/// Mismo patrón singleton que [AuthService]/`EcoService`.
///
/// El badge y el listado leen esta tabla; el webhook existente entrega las
/// nuevas filas por FCM a los dispositivos registrados.
class NotificationService {
  factory NotificationService() => instance;

  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();

  /// Se incrementa en cada escritura para que Inicio refresque el contador
  /// del badge sin pull-to-refresh (mismo mecanismo que
  /// `BusinessStorageService.revision`).
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static const _table = 'notifications';
  final Map<String, Future<void>> _demoInFlight = {};
  static const _deliveryTimeout = Duration(seconds: 10);

  SupabaseClient get _client => Supabase.instance.client;

  /// Un invitado no tiene fila propia en `notifications`; quien llama debería
  /// haber pasado antes por `GuestGuard`, así que esto es la última red y no
  /// el camino normal.
  String _requireUserId() {
    final user = AuthService().currentAuthUser;
    if (user == null) {
      throw const NotificationServiceException(
        'Inicia sesión para ver tus notificaciones.',
      );
    }
    return user.id;
  }

  /// Se llama después de guardar la inscripción. Un fallo del aviso nunca
  /// convierte una participación ya guardada en un error para el usuario.
  Future<void> notifyEcoActivityJoined(EcoActivityModel activity) async {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) return;
    try {
      try {
        // El trigger y este RPC comparten el mismo recibo: la respuesta del
        // cliente puede reintentarse sin enviar dos confirmaciones.
        await _client
            .rpc(
              'notify_eco_participation',
              params: {'p_activity_id': activity.id},
            )
            .timeout(_deliveryTimeout);
        revision.value++;
        return;
      } on PostgrestException catch (e) {
        // Mantiene la confirmación actual durante el despliegue de 045.
        if (e.code != 'PGRST202' && e.code != '42883') rethrow;
      }
      if (AuthService().currentAuthUser?.id != userId) return;
      await _client
          .from(_table)
          .insert([
            for (final message in NotificationMessage.participation(activity))
              message.toRow(userId),
          ])
          .timeout(_deliveryTimeout);
      revision.value++;
    } catch (e) {
      debugPrint(
        '[NotificationService] No se pudieron enviar los avisos ECO: $e',
      );
    }
  }

  Future<void> enableAutomations() async {
    if (AuthService().currentAuthUser == null) return;
    try {
      await _client
          .rpc('enable_user_notification_automations')
          .timeout(_deliveryTimeout);
    } catch (e) {
      debugPrint(
        '[NotificationService] No se pudieron activar los avisos automáticos: $e',
      );
    }
  }

  /// La colección permanece guardada aunque falle la red. Inicio vuelve a
  /// sincronizarla y los recibos del servidor evitan repetir premios.
  Future<void> syncPassportProgress({
    required String ownerId,
    required List<Map<String, dynamic>> trips,
  }) async {
    if (trips.isEmpty || AuthService().currentAuthUser?.id != ownerId) return;
    try {
      await _client
          .rpc('sync_passport_notification_events', params: {'p_trips': trips})
          .timeout(_deliveryTimeout);
      revision.value++;
    } catch (e) {
      debugPrint(
        '[NotificationService] No se pudieron sincronizar los avisos del pasaporte: $e',
      );
    }
  }

  /// Cada cuenta recibe el lote una vez. La marca local conserva la decisión
  /// aunque se borren los avisos; la consulta al servidor evita repetirlos
  /// tras reinstalar la app o entrar desde otro dispositivo.
  Future<void> ensureDemoNotifications(List<BusinessModel> businesses) {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) return Future<void>.value();
    return _demoInFlight.putIfAbsent(
      userId,
      () => _seedDemo(userId, businesses).whenComplete(() {
        _demoInFlight.remove(userId);
      }),
    );
  }

  Future<void> _seedDemo(String userId, List<BusinessModel> businesses) async {
    try {
      final existing = await _client
          .from(_table)
          .select('type')
          .eq('user_id', userId)
          .inFilter('type', [
            NotificationType.demoWelcome.wireValue,
            NotificationType.businessRecommendation.wireValue,
          ])
          .timeout(_deliveryTimeout);
      final types = existing.map((row) => row['type']).toSet();
      final recommendations = NotificationMessage.recommendations(businesses);
      final hasRecommendations = types.contains(
        NotificationType.businessRecommendation.wireValue,
      );
      final messages = [
        if (!types.contains(NotificationType.demoWelcome.wireValue))
          ...NotificationMessage.welcome,
        if (!hasRecommendations) ...recommendations,
      ];
      // La sesión puede cambiar mientras esperan las lecturas anteriores.
      if (AuthService().currentAuthUser?.id != userId) return;
      if (messages.isNotEmpty) {
        await _client
            .from(_table)
            .insert([for (final message in messages) message.toRow(userId)])
            .timeout(_deliveryTimeout);
        revision.value++;
      }
    } catch (e) {
      debugPrint('[NotificationService] No se pudo cargar la demostración: $e');
    }
  }

  /// Consulta "mis X": el filtro por dueño es obligatorio (ver CLAUDE.md >
  /// Supabase & Security Guidelines). El id sale siempre de la sesión activa,
  /// nunca de un parámetro que venga de la UI.
  Future<List<AppNotification>> getMine() async {
    final userId = _requireUserId();
    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return rows
          .map((row) => AppNotification.fromRow(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw NotificationServiceException(
        'No se pudieron cargar tus notificaciones: ${e.message}',
      );
    } catch (_) {
      throw const NotificationServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Cuántas notificaciones sin leer tiene el usuario actual.
  ///
  /// Trae solo la columna `id` y cuenta en el cliente en vez de usar el
  /// `count` de PostgREST: el volumen por usuario es de decenas de filas y
  /// así el método no depende de una API que cambia entre versiones del SDK.
  Future<int> unreadCount() async {
    final userId = _requireUserId();
    try {
      final rows = await _client
          .from(_table)
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      return rows.length;
    } on PostgrestException catch (e) {
      throw NotificationServiceException(
        'No se pudo contar tus notificaciones: ${e.message}',
      );
    } catch (_) {
      throw const NotificationServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// El filtro de dueño va en la **misma sentencia** del `update`, no en un
  /// `select` previo: así activar RLS más adelante no cambia el resultado.
  Future<void> markAsRead(String id) async {
    final userId = _requireUserId();
    try {
      await _client
          .from(_table)
          .update({'is_read': true})
          .eq('id', id)
          .eq('user_id', userId);
      revision.value++;
    } on PostgrestException catch (e) {
      throw NotificationServiceException(
        'No se pudo marcar la notificación como leída: ${e.message}',
      );
    } catch (_) {
      throw const NotificationServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  Future<void> markAllAsRead() async {
    final userId = _requireUserId();
    try {
      await _client
          .from(_table)
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
      revision.value++;
    } on PostgrestException catch (e) {
      throw NotificationServiceException(
        'No se pudieron marcar tus notificaciones como leídas: ${e.message}',
      );
    } catch (_) {
      throw const NotificationServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  Future<void> delete(String id) async {
    final userId = _requireUserId();
    try {
      await _client.from(_table).delete().eq('id', id).eq('user_id', userId);
      revision.value++;
    } on PostgrestException catch (e) {
      throw NotificationServiceException(
        'No se pudo eliminar la notificación: ${e.message}',
      );
    } catch (_) {
      throw const NotificationServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Avisa al dueño de un negocio que la administración lo revisó.
  ///
  /// La consume `AdminService.reviewBusiness`, justo después de que el RPC
  /// `review_business` respondió.
  ///
  /// [reason] es el motivo del rechazo y viaja dentro del cuerpo: sin él la
  /// notificación diría "no pasó la revisión" sin decir qué corregir, que es
  /// exactamente la queja que originó este flujo. Se recorta porque el
  /// listado muestra el cuerpo completo y un motivo largo empujaría el resto
  /// de la notificación fuera de la tarjeta.
  Future<void> notifyBusinessReviewed({
    required String ownerId,
    required String businessId,
    required String businessName,
    required bool approved,
    String? reason,
  }) {
    final trimmed = reason?.trim() ?? '';
    final motive = trimmed.isEmpty
        ? ''
        : ' Motivo: ${trimmed.length > 160 ? '${trimmed.substring(0, 160)}…' : trimmed}';
    return _create(
      recipientId: ownerId,
      title: approved
          ? 'Tu negocio fue aprobado'
          : 'Tu negocio necesita ajustes',
      body: approved
          ? '"$businessName" ya está publicado en Níkara. ¡Felicidades!'
          : '"$businessName" no pasó la revisión.$motive Corrige los datos y '
                'vuelve a enviarlo desde tu perfil.',
      type: approved
          ? NotificationType.businessApproved
          : NotificationType.businessUnverified,
      referenceId: businessId,
    );
  }

  /// Avisa a quien organiza una jornada ECO que la administración la revisó
  /// — mismo mecanismo que [notifyBusinessReviewed]. La consumen
  /// `EcoDetailScreen`/`OrganizationProfileScreen` justo después de que
  /// `AdminService.reviewEcoActivity`/`reviewOrganization` respondieron (esos
  /// métodos no notifican solos: a diferencia de `reviewBusiness`, no
  /// vuelven a leer la fila, así que quien ya tiene el modelo en memoria —la
  /// pantalla— es quien puede armar el aviso sin un viaje de más).
  Future<void> notifyEcoActivityReviewed({
    required String organizerId,
    required String activityId,
    required String activityTitle,
    required bool approved,
    String? reason,
  }) {
    final trimmed = reason?.trim() ?? '';
    final motive = trimmed.isEmpty
        ? ''
        : ' Motivo: ${trimmed.length > 160 ? '${trimmed.substring(0, 160)}…' : trimmed}';
    return _create(
      recipientId: organizerId,
      title: approved
          ? 'Tu jornada fue aprobada'
          : 'Tu jornada necesita ajustes',
      body: approved
          ? '"$activityTitle" ya está publicada en Níkara. ¡Felicidades!'
          : '"$activityTitle" no pasó la revisión.$motive Corrige los datos '
                'y vuelve a enviarla.',
      type: approved
          ? NotificationType.ecoActivityApproved
          : NotificationType.ecoActivityRejected,
      referenceId: activityId,
    );
  }

  /// Mismo mecanismo sobre una fundación.
  Future<void> notifyOrganizationReviewed({
    required String ownerId,
    required String organizationId,
    required String organizationName,
    required bool approved,
    String? reason,
  }) {
    final trimmed = reason?.trim() ?? '';
    final motive = trimmed.isEmpty
        ? ''
        : ' Motivo: ${trimmed.length > 160 ? '${trimmed.substring(0, 160)}…' : trimmed}';
    return _create(
      recipientId: ownerId,
      title: approved
          ? 'Tu fundación fue aprobada'
          : 'Tu fundación necesita ajustes',
      body: approved
          ? '"$organizationName" ya está publicada en Níkara. ¡Felicidades!'
          : '"$organizationName" no pasó la revisión.$motive Corrige los '
                'datos y vuelve a enviarla.',
      type: approved
          ? NotificationType.organizationApproved
          : NotificationType.organizationRejected,
      referenceId: organizationId,
    );
  }

  /// Avisa a **cada** cuenta admin que hay un negocio/jornada/fundación
  /// nuevo esperando revisión.
  ///
  /// La consumen los servicios de creación (`BusinessStorageService.addBusiness`,
  /// `EcoService.createActivity`, `OrganizationService.createOrganization`)
  /// justo después de insertar la fila en estado pendiente.
  ///
  /// El fan-out ocurre **server-side**, en el RPC
  /// `notify_admins_of_pending_review` (`supabase/sql/028`): acá solo viajan
  /// el título y el cuerpo, y el servidor resuelve los destinatarios. Dos
  /// razones, en orden de importancia:
  ///
  /// 1. Quien llama es el propio emprendedor/turista que está registrando
  ///    algo, no un admin — así que insertar la notificación para otro
  ///    usuario no encaja en ninguna policy razonable de `notifications` una
  ///    vez que RLS está activa (ver `029_enable_rls.sql`). El RPC es
  ///    `security definer` y no pasa por esas policies.
  /// 2. La versión anterior leía `profiles where role = 'admin'` desde el
  ///    cliente. Con la anon key — pública, viaja dentro del APK — eso
  ///    permitía enumerar qué cuentas son administradoras llamando directo a
  ///    Postgrest. Ahora el cliente ya no necesita ni puede leer esa lista.
  ///
  /// Sigue siendo best-effort: un fallo acá no debe tumbar la creación que ya
  /// se guardó, así que el método nunca lanza.
  Future<void> notifyAdminsOfPendingReview({
    required String title,
    required String body,
  }) async {
    if (AuthService().currentAuthUser == null) return;
    try {
      await _client.rpc(
        'notify_admins_of_pending_review',
        params: {
          'p_title': title,
          'p_body': body,
          'p_type': NotificationType.reviewPending.wireValue,
        },
      );
      revision.value++;
    } on PostgrestException catch (e) {
      debugPrint(
        '[NotificationService] notifyAdminsOfPendingReview: el fan-out no '
        'entró (${e.code}) ${e.message}',
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] notifyAdminsOfPendingReview: el fan-out no '
        'entró — $e',
      );
    }
  }

  /// Inserción genérica que usan los `notifyX` de arriba.
  ///
  /// Ojo con la regla de "la columna de dueño se estampa con
  /// `currentUser.id`": acá **no aplica**, porque `user_id` identifica al
  /// **destinatario** del aviso, no a quien lo genera. Un admin notificando a
  /// un emprendedor tiene que escribir el id del emprendedor. Lo que sí se
  /// exige es que haya sesión activa: nadie inserta notificaciones anónimo.
  Future<void> _create({
    required String recipientId,
    required String title,
    required String body,
    required NotificationType type,
    String? referenceId,
  }) async {
    if (AuthService().currentAuthUser == null) {
      throw const NotificationServiceException(
        'Inicia sesión para enviar notificaciones.',
      );
    }
    if (recipientId.trim().isEmpty) {
      throw const NotificationServiceException(
        'No se pudo enviar la notificación: falta el destinatario.',
      );
    }
    try {
      await _client.from(_table).insert({
        'user_id': recipientId,
        'title': title,
        'body': body,
        'type': type.wireValue,
        'reference_id': referenceId,
      });
      revision.value++;
    } on PostgrestException catch (e) {
      throw NotificationServiceException(
        'No se pudo enviar la notificación: ${e.message}',
      );
    } catch (_) {
      throw const NotificationServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }
}
