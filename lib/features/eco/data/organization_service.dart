import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/eco/domain/models/organization_model.dart';

class OrganizationServiceException implements Exception {
  const OrganizationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lee y escribe `public.organizations` (supabase/sql/010_organizations.sql); mismo patrón singleton que [EcoService]/[AuthService].
class OrganizationService {
  factory OrganizationService() => OrganizationService.instance;

  OrganizationService._internal();

  static final OrganizationService instance = OrganizationService._internal();

  /// Sube en cada escritura local, igual que `EcoService.revision`, para refrescar sin pull-to-refresh.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  SupabaseClient get _client => Supabase.instance.client;

  /// Lista vacía si no hay sesión o si la migración 010 no se ha corrido (la tabla no existe aún).
  Future<List<OrganizationModel>> getMyOrganizations() async {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) return const [];
    return getOrganizationsByOwner(userId);
  }

  Future<List<OrganizationModel>> getOrganizationsByOwner(
    String ownerId,
  ) async {
    try {
      final rows = await _client
          .from('organizations')
          .select()
          .eq('owner_id', ownerId)
          .order('created_at');
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(OrganizationModel.fromRow)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      // 42P01 = migración 010 sin correr; se degrada a "no tienes fundaciones" en vez de bloquear el formulario.
      if (e.code == '42P01') return const [];
      throw OrganizationServiceException(
        'No se pudieron cargar tus fundaciones: ${e.message}',
      );
    } catch (_) {
      throw const OrganizationServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  Future<OrganizationModel?> getById(String id) async {
    try {
      final row = await _client
          .from('organizations')
          .select()
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : OrganizationModel.fromRow(row);
    } on PostgrestException catch (e) {
      throw OrganizationServiceException(
        'No se pudo cargar la fundación: ${e.message}',
      );
    } catch (_) {
      throw const OrganizationServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// `is_verified` queda en su default de columna; el cliente nunca lo envía, igual que `businesses.is_verified`.
  Future<OrganizationModel> createOrganization({
    required String name,
    required String handle,
    String description = '',
    String? logoUrl,
    String? bannerUrl,
  }) async {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) {
      throw const OrganizationServiceException(
        'Necesitas iniciar sesión para registrar una fundación.',
      );
    }
    final normalizedHandle = OrganizationModel.normalizeHandle(handle);
    if (normalizedHandle.isEmpty) {
      throw const OrganizationServiceException(
        'El handle solo puede tener letras, números, puntos o guiones bajos.',
      );
    }
    try {
      final row = await _client
          .from('organizations')
          .insert({
            'name': name,
            'handle': normalizedHandle,
            'description': description,
            'logo_url': logoUrl,
            'banner_url': bannerUrl,
            'owner_id': userId,
          })
          .select()
          .single();
      revision.value++;
      return OrganizationModel.fromRow(row);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw OrganizationServiceException(
          'El handle "@$normalizedHandle" ya está en uso. Elige otro.',
        );
      }
      if (e.code == '42P01') {
        throw const OrganizationServiceException(
          'Falta correr la migración de fundaciones en Supabase '
          '(supabase/sql/010_organizations.sql).',
        );
      }
      throw OrganizationServiceException(
        'No se pudo registrar la fundación: ${e.message}',
      );
    } catch (_) {
      throw const OrganizationServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }
}
