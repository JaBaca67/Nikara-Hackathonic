import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/permission_service.dart';
import 'package:nikara_app/features/admin/domain/models/admin_business_summary.dart';
import 'package:nikara_app/features/admin/domain/models/admin_metrics.dart';
import 'package:nikara_app/features/admin/domain/models/admin_user_summary.dart';
import 'package:nikara_app/features/notifications/data/notification_service.dart';

/// Error del panel de administración, con [message] ya en español.
class AdminServiceException implements Exception {
  const AdminServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Acceso a datos del panel de administración/auditoría.
///
/// Vive aparte de `BusinessStorageService` a propósito, aunque las dos hablen
/// con `businesses`: aquel servicio modela el negocio **desde su dueño**
/// (fusiona el cache local del dispositivo, filtra por `owner_id`, escribe el
/// wizard). Éste lo modela **desde quien lo revisa**: lecturas deliberadamente
/// cross-usuario y escrituras que deciden qué se publica.
///
/// Aprobar y rechazar pasan **siempre** por los RPC `review_business` /
/// `review_organization` / `review_eco_activity` de `019_review_status.sql`,
/// nunca por un `update` de `status` desde el cliente: esos RPC son
/// `security definer` y comprueban el rol contra `profiles` del lado del
/// servidor. Con RLS deshabilitada es lo único que impide que cualquiera con
/// la `anon key` se apruebe su propio negocio llamando directo a Postgrest.
///
/// El [PermissionService.require] que va antes de cada mutación no reemplaza
/// eso: es la capa de producto (mensaje en español, botón oculto), no la
/// barrera. La barrera vive en el RPC.
class AdminService {
  factory AdminService() => instance;

  AdminService._internal();

  static final AdminService instance = AdminService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  PermissionService get _permissions => PermissionService();

  /// Columnas de `businesses` que el panel necesita. Explícitas y no `*` para
  /// no arrastrar el `geography` de `location`, que llega como hex WKB y acá
  /// no se usa para nada.
  static const _businessColumns =
      'id, owner_id, name, category, description, city, address_text, '
      'phone, instagram_handle, facebook_handle, schedules, photos, '
      'is_verified, status, rejection_reason, reviewed_at, created_at';

  // ==================== Cola de revisión ====================

  /// Negocios filtrados por estado de revisión, del más nuevo al más
  /// viejo (un pendiente recién creado tiene que aparecer arriba).
  Future<List<AdminBusinessSummary>> getBusinesses({
    required ReviewStatus status,
  }) async {
    await _permissions.require(
      Permission.reviewSubmissions,
      action: 'revisar negocios',
    );
    try {
      final rows = await _client
          .from('businesses')
          .select(_businessColumns)
          .eq('status', status.wireValue)
          .order('created_at', ascending: false);
      final businesses = (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(AdminBusinessSummary.fromRow)
          .toList(growable: false);
      return _withOwners(businesses);
    } on PostgrestException catch (e) {
      throw AdminServiceException(_friendlyError(e, 'cargar los negocios'));
    } catch (_) {
      throw const AdminServiceException(_connectionError);
    }
  }

  /// Vuelve a leer un negocio puntual (tras verificarlo, o al abrir el
  /// detalle desde una lista ya vieja).
  Future<AdminBusinessSummary?> getBusinessById(String id) async {
    await _permissions.require(
      Permission.reviewSubmissions,
      action: 'revisar negocios',
    );
    try {
      final row = await _client
          .from('businesses')
          .select(_businessColumns)
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      final business = AdminBusinessSummary.fromRow(row);
      final enriched = await _withOwners([business]);
      return enriched.first;
    } on PostgrestException catch (e) {
      throw AdminServiceException(_friendlyError(e, 'cargar el negocio'));
    } catch (_) {
      throw const AdminServiceException(_connectionError);
    }
  }

  /// Rellena nombre y correo del dueño con una segunda consulta a `profiles`.
  ///
  /// Va como consulta aparte y no como embed de PostgREST
  /// (`owner:profiles(...)`) para que un problema de resolución de la FK no
  /// tumbe la cola entera. Si el enriquecimiento falla se registra y se
  /// devuelven los negocios sin dueño: la revisión sigue siendo posible sin
  /// ese dato, perderla del todo no.
  Future<List<AdminBusinessSummary>> _withOwners(
    List<AdminBusinessSummary> businesses,
  ) async {
    final ownerIds = businesses
        .map((b) => b.ownerId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ownerIds.isEmpty) return businesses;

    Map<String, Map<String, dynamic>> owners = const {};
    try {
      final rows = await _client
          .from('profiles')
          .select('id, full_name, email')
          .inFilter('id', ownerIds);
      owners = {
        for (final row in (rows as List<dynamic>).cast<Map<String, dynamic>>())
          row['id'] as String: row,
      };
    } on PostgrestException catch (e) {
      debugPrint(
        '[AdminService] _withOwners: no se pudieron cargar los dueños '
        '(${e.code}) ${e.message} — la cola se muestra sin nombre de dueño.',
      );
      return businesses;
    }

    return businesses
        .map((business) {
          final owner = owners[business.ownerId];
          if (owner == null) return business;
          return AdminBusinessSummary(
            id: business.id,
            name: business.name,
            category: business.category,
            description: business.description,
            city: business.city,
            addressText: business.addressText,
            phone: business.phone,
            instagramHandle: business.instagramHandle,
            facebookHandle: business.facebookHandle,
            schedules: business.schedules,
            photos: business.photos,
            ownerId: business.ownerId,
            isVerified: business.isVerified,
            reviewStatus: business.reviewStatus,
            rejectionReason: business.rejectionReason,
            reviewedAt: business.reviewedAt,
            createdAt: business.createdAt,
            ownerName: owner['full_name'] as String? ?? '',
            ownerEmail: owner['email'] as String? ?? '',
          );
        })
        .toList(growable: false);
  }

  // ==================== Verificación ====================

  /// Escribe `businesses.is_verified` — el **sello**, no la publicación.
  ///
  /// Sigue siendo un `update` directo y no un RPC porque es un eje distinto
  /// de [reviewBusiness]: no decide si el negocio se ve, solo si lleva la
  /// insignia de "confirmado por Níkara" una vez ya publicado. Tampoco
  /// notifica: al dueño le importa que lo aprueben, y de eso ya avisa
  /// [reviewBusiness].
  Future<AdminBusinessSummary> setBusinessVerified({
    required String id,
    required bool isVerified,
  }) async {
    await _permissions.require(
      Permission.verifyBusiness,
      action: isVerified ? 'verificar negocios' : 'quitar verificaciones',
    );
    try {
      final rows = await _client
          .from('businesses')
          .update({'is_verified': isVerified})
          .eq('id', id)
          .select(_businessColumns);
      final list = (rows as List<dynamic>).cast<Map<String, dynamic>>();
      if (list.isEmpty) {
        throw const AdminServiceException(
          'Ese negocio ya no existe o fue eliminado por su dueño.',
        );
      }
      final updated = AdminBusinessSummary.fromRow(list.first);
      final enriched = await _withOwners([updated]);
      return enriched.first;
    } on PostgrestException catch (e) {
      throw AdminServiceException(
        _friendlyError(
          e,
          isVerified ? 'verificar el negocio' : 'quitar la verificación',
        ),
      );
    } on AdminServiceException {
      rethrow;
    } catch (_) {
      throw const AdminServiceException(_connectionError);
    }
  }

  /// Mismo mecanismo que [setBusinessVerified] sobre `organizations`.
  ///
  /// El panel todavía no lista organizaciones (la cola de revisión arranca
  /// solo con negocios), pero el permiso `verifyOrganization` existe y el rol
  /// auditor lo tiene: esto es lo que evita que sea un permiso decorativo.
  Future<void> setOrganizationVerified({
    required String id,
    required bool isVerified,
  }) async {
    await _permissions.require(
      Permission.verifyOrganization,
      action: isVerified
          ? 'verificar organizaciones'
          : 'quitar verificaciones de organizaciones',
    );
    try {
      await _client
          .from('organizations')
          .update({'is_verified': isVerified})
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw AdminServiceException(
        _friendlyError(e, 'actualizar la organización'),
      );
    } catch (_) {
      throw const AdminServiceException(_connectionError);
    }
  }

  // ==================== Revisión (aprobar / rechazar) ====================

  /// Aprueba o rechaza un negocio y le avisa a su dueño.
  ///
  /// [reason] solo se usa cuando [status] es [ReviewStatus.rechazado]; el RPC
  /// lo ignora (y limpia `rejection_reason`) en cualquier otro caso, así que
  /// no hace falta blanquearlo desde acá.
  ///
  /// La notificación va **después** de que el RPC respondió y en su propio
  /// `try`: si `notifications` falla, la revisión ya ocurrió y sería peor
  /// deshacerla o hacerla parecer fallida. El aviso se pierde, el estado no.
  Future<AdminBusinessSummary> reviewBusiness({
    required String id,
    required ReviewStatus status,
    String? reason,
  }) async {
    await _permissions.require(
      Permission.reviewSubmissions,
      action: status.isRechazado ? 'rechazar negocios' : 'aprobar negocios',
    );
    try {
      await _client.rpc(
        'review_business',
        params: {
          'p_business_id': id,
          'p_new_status': status.wireValue,
          'p_reason': reason,
        },
      );
    } on PostgrestException catch (e) {
      throw AdminServiceException(
        _friendlyError(e, status.isRechazado ? 'rechazar' : 'aprobar'),
      );
    } catch (_) {
      throw const AdminServiceException(_connectionError);
    }

    final updated = await getBusinessById(id);
    if (updated == null) {
      throw const AdminServiceException(
        'Ese negocio ya no existe o fue eliminado por su dueño.',
      );
    }
    await _notifyReviewed(updated, status);
    return updated;
  }

  /// Mismo mecanismo sobre `organizations`.
  Future<void> reviewOrganization({
    required String id,
    required ReviewStatus status,
    String? reason,
  }) async {
    await _permissions.require(
      Permission.verifyOrganization,
      action: status.isRechazado
          ? 'rechazar fundaciones'
          : 'aprobar fundaciones',
    );
    await _runReviewRpc(
      'review_organization',
      params: {
        'p_organization_id': id,
        'p_new_status': status.wireValue,
        'p_reason': reason,
      },
      status: status,
      subject: 'la fundación',
    );
  }

  /// Mismo mecanismo sobre `eco_activities`.
  Future<void> reviewEcoActivity({
    required String id,
    required ReviewStatus status,
    String? reason,
  }) async {
    await _permissions.require(
      Permission.reviewSubmissions,
      action: status.isRechazado ? 'rechazar jornadas' : 'aprobar jornadas',
    );
    await _runReviewRpc(
      'review_eco_activity',
      params: {
        'p_activity_id': id,
        'p_new_status': status.wireValue,
        'p_reason': reason,
      },
      status: status,
      subject: 'la jornada',
    );
  }

  Future<void> _runReviewRpc(
    String function, {
    required Map<String, dynamic> params,
    required ReviewStatus status,
    required String subject,
  }) async {
    try {
      await _client.rpc(function, params: params);
    } on PostgrestException catch (e) {
      throw AdminServiceException(
        _friendlyError(
          e,
          '${status.isRechazado ? 'rechazar' : 'aprobar'} $subject',
        ),
      );
    } catch (_) {
      throw const AdminServiceException(_connectionError);
    }
  }

  /// El aviso al dueño no puede tumbar la revisión, así que su error se
  /// registra y se sigue. Un negocio sin dueño (seed de prototipo) tampoco
  /// tiene a quién avisarle.
  Future<void> _notifyReviewed(
    AdminBusinessSummary business,
    ReviewStatus status,
  ) async {
    if (business.ownerId.isEmpty || status.isPendiente) return;
    try {
      await NotificationService().notifyBusinessReviewed(
        ownerId: business.ownerId,
        businessId: business.id,
        businessName: business.name,
        approved: status.isAprobado,
        reason: business.rejectionReason,
      );
    } on NotificationServiceException catch (e) {
      debugPrint(
        '[AdminService] _notifyReviewed: no se pudo avisarle al dueño de '
        '"${business.name}" — ${e.message}',
      );
    }
  }

  // ==================== Usuarios (solo admin) ====================

  Future<List<AdminUserSummary>> getUsers() async {
    await _permissions.require(
      Permission.manageUsers,
      action: 'ver el listado de usuarios',
    );
    try {
      final rows = await _client
          .from('profiles')
          .select('id, full_name, email, role, avatar_url')
          .order('full_name');
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(AdminUserSummary.fromRow)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw AdminServiceException(_friendlyError(e, 'cargar los usuarios'));
    } catch (_) {
      throw const AdminServiceException(_connectionError);
    }
  }

  // ==================== Métricas (solo admin) ====================

  Future<AdminMetrics> getMetrics() async {
    await _permissions.require(
      Permission.viewGlobalMetrics,
      action: 'ver las métricas de la plataforma',
    );
    try {
      final results = await Future.wait([
        _client.from('businesses').select('is_verified'),
        _client.from('organizations').select('is_verified'),
        _client.from('eco_activities').select('start_time'),
        _client.from('profiles').select('role'),
      ]);

      final businesses = _asRows(results[0]);
      final organizations = _asRows(results[1]);
      final ecoActivities = _asRows(results[2]);
      final profiles = _asRows(results[3]);

      final now = DateTime.now();
      final usersByRole = <UserRole, int>{};
      for (final row in profiles) {
        final role = UserRole.values.firstWhere(
          (r) => r.name == row['role'],
          orElse: () => UserRole.turista,
        );
        usersByRole[role] = (usersByRole[role] ?? 0) + 1;
      }

      return AdminMetrics(
        totalBusinesses: businesses.length,
        verifiedBusinesses: businesses
            .where((row) => row['is_verified'] == true)
            .length,
        totalOrganizations: organizations.length,
        verifiedOrganizations: organizations
            .where((row) => row['is_verified'] == true)
            .length,
        totalEcoActivities: ecoActivities.length,
        upcomingEcoActivities: ecoActivities.where((row) {
          final start = DateTime.tryParse(row['start_time'] as String? ?? '');
          return start != null && start.isAfter(now);
        }).length,
        usersByRole: usersByRole,
      );
    } on PostgrestException catch (e) {
      throw AdminServiceException(_friendlyError(e, 'cargar las métricas'));
    } catch (_) {
      throw const AdminServiceException(_connectionError);
    }
  }

  List<Map<String, dynamic>> _asRows(dynamic raw) =>
      (raw as List<dynamic>).cast<Map<String, dynamic>>();

  // ==================== Errores ====================

  static const _connectionError =
      'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.';

  /// Traduce un [PostgrestException] a español.
  ///
  /// El caso `42501` está separado porque es el fallo más probable de este
  /// panel y el más confuso si llega crudo: `001_profiles_trigger_and_rls.sql`
  /// hizo `revoke update` sobre `profiles`, y si alguna vez se aplica el mismo
  /// endurecimiento a `businesses`, escribir `is_verified` desde el cliente
  /// empezaría a fallar con ese código aunque el rol de la app sea correcto.
  /// Aprobar/rechazar ya no puede caer acá: pasa por un RPC `security
  /// definer`, que corre con privilegio propio.
  ///
  /// `P0001` es el `raise exception` de los propios RPC de revisión — el
  /// mensaje ya viene en español desde Postgres ("No autorizado: se requiere
  /// rol admin o auditor"), así que se muestra tal cual en vez de envolverlo.
  String _friendlyError(PostgrestException e, String action) {
    if (e.code == 'P0001') return e.message;
    if (e.code == '42501') {
      return 'Supabase rechazó la escritura por falta de permisos en la base '
          'de datos (no por tu rol en la app). Revisa que '
          'supabase/sql/019_review_status.sql esté aplicado.';
    }
    if (e.code == '42703' || e.code == 'PGRST204') {
      return 'A la base de datos le falta una columna que el panel necesita. '
          'Revisa que las migraciones de supabase/sql/ estén aplicadas.';
    }
    return 'No se pudo $action: ${e.message}';
  }
}
