import 'package:flutter/foundation.dart';

import 'package:nikara_app/core/models/profile_face.dart';
import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/eco/data/organization_service.dart';

/// Qué caras tiene el login activo y cuál está puesta ahora mismo.
///
/// Mecanismo **nuevo y separado** de `AccountSwitcherService`: ése salta entre
/// logins distintos (correo + contraseña + sesión de Supabase) y no se toca.
/// Acá no se cierra ni se abre ninguna sesión — se cambia la identidad con la
/// que el usuario se presenta dentro de su propio login. Ver [ProfileFace].
///
/// La cara activa vive **solo en memoria** y arranca en turista en cada inicio
/// de la app. Es deliberado: persistirla haría que alguien abriera Níkara
/// dentro de un negocio suyo sin acordarse de que lo dejó puesto, con la mitad
/// de las interacciones bloqueadas y sin una pista de por qué.
///
/// La caché se llavea por `userId`, igual que `PermissionService`: sin eso,
/// alternar de cuenta le dejaría al login entrante las caras del saliente.
class ProfileFaceService {
  factory ProfileFaceService() => instance;

  ProfileFaceService._internal();

  static final ProfileFaceService instance = ProfileFaceService._internal();

  AuthService get _auth => AuthService();

  /// Sube en cada cambio de cara o recarga de la lista, para que la UI se
  /// refresque sin recargar la pantalla entera (mismo patrón que
  /// `EcoService.revision`).
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  List<ProfileFace> _faces = const [];
  String _activeFaceId = ProfileFace.turistaId;
  String? _cachedUserId;

  /// Las caras conocidas del login activo, sin tocar la red.
  ///
  /// Devuelve solo la lista vacía mientras no se haya llamado a [load]; la
  /// cara turista aparece recién cuando hay un perfil con nombre que mostrar.
  List<ProfileFace> get faces =>
      _cachedUserId == _auth.currentAuthUser?.id ? _faces : const [];

  /// La cara puesta ahora mismo, o `null` si todavía no se cargó nada.
  ///
  /// Ante cualquier duda cae en la cara turista: es la única con la
  /// experiencia completa, así que degradar hacia ella nunca desbloquea algo
  /// que debería estar bloqueado.
  ProfileFace? get activeFace {
    final current = faces;
    if (current.isEmpty) return null;
    for (final face in current) {
      if (face.id == _activeFaceId) return face;
    }
    return current.first;
  }

  /// `true` si la cara activa es la de turista o si todavía no hay ninguna
  /// cargada — la lectura segura para condicionar la UI en un `build`.
  bool get isTuristaFace => activeFace?.isTurista ?? true;

  /// Atajo de las limitaciones por cara: favoritos, reseñas, inscripción a
  /// jornadas ECO e iniciar un viaje solo se pueden desde turista.
  bool get canInteractAsVisitor => activeFace?.canInteractAsVisitor ?? true;

  /// Reconstruye la lista de caras del login activo.
  ///
  /// Cada fuente falla por separado: si el módulo ECO no responde, el usuario
  /// tiene que poder seguir cambiando a la cara de su negocio igual. Un fallo
  /// total deja solo la cara turista, nunca una lista vacía.
  Future<List<ProfileFace>> load({bool force = false}) async {
    final userId = _auth.currentAuthUser?.id;
    if (userId == null) {
      invalidate();
      return const [];
    }
    if (!force && _cachedUserId == userId && _faces.isNotEmpty) return _faces;

    UserModel? profile;
    try {
      profile = await _auth.getCurrentProfile();
    } on AuthServiceException {
      // Sin perfil legible se usa igual un placeholder: quedarse sin cara
      // turista dejaría al usuario sin ninguna cara a la que volver.
    }

    final faces = <ProfileFace>[
      ProfileFace.turista(
        name: profile == null || profile.fullName.trim().isEmpty
            ? 'Viajero Níkara'
            : profile.fullName,
        initials: profile?.initials ?? '?',
        avatarUrl: profile?.avatarUrl,
      ),
    ];

    // Solo lo **aprobado** suma cara: mientras la solicitud está en revisión o
    // fue rechazada, el usuario sigue teniendo únicamente su cara de turista.
    try {
      final businesses = await BusinessStorageService().getMyBusinesses();
      faces.addAll(
        businesses
            .where((b) => b.reviewStatus.isAprobado)
            .map(ProfileFace.fromBusiness),
      );
    } on BusinessServiceException {
      // Se omiten las caras de negocio; la de turista sigue disponible.
    }

    try {
      final organizations = await OrganizationService().getMyOrganizations();
      faces.addAll(
        organizations
            .where((o) => o.reviewStatus.isAprobado)
            .map(ProfileFace.fromOrganization),
      );
    } on OrganizationServiceException {
      // Idem.
    }

    _cachedUserId = userId;
    _faces = List.unmodifiable(faces);
    // Una cara puede desaparecer entre recargas (negocio eliminado, o su
    // aprobación revocada): si era la activa, se vuelve a turista en vez de
    // dejar la app apuntando a algo que ya no existe.
    if (!_faces.any((f) => f.id == _activeFaceId)) {
      _activeFaceId = ProfileFace.turistaId;
    }
    revision.value++;
    return _faces;
  }

  /// Pone otra cara. No hace I/O: cambiar de cara es instantáneo, no es un
  /// login.
  void setActiveFace(String faceId) {
    if (_activeFaceId == faceId) return;
    if (!_faces.any((f) => f.id == faceId)) return;
    _activeFaceId = faceId;
    revision.value++;
  }

  /// Vuelve a la cara turista — la que tiene la experiencia completa. Es la
  /// acción del aviso "Cambiá a tu perfil de turista para hacer esto".
  void backToTurista() => setActiveFace(ProfileFace.turistaId);

  /// Olvida las caras cacheadas. Llamar al cerrar sesión o al alternar de
  /// cuenta.
  void invalidate() {
    _faces = const [];
    _activeFaceId = ProfileFace.turistaId;
    _cachedUserId = null;
    revision.value++;
  }
}
