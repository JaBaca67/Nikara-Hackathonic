import 'package:flutter/material.dart';

import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/eco/domain/models/organization_model.dart';

/// Los tres tipos de cara que puede tener un login.
enum ProfileFaceKind {
  turista('Turista', Icons.person_rounded),
  business('Negocio', Icons.storefront_rounded),
  organization('Fundación', Icons.diversity_3_rounded);

  const ProfileFaceKind(this.label, this.icon);

  /// Etiqueta visible en la hoja de caras.
  final String label;

  final IconData icon;
}

/// Una identidad **dentro del mismo login**: turista, negocio X o fundación Y.
///
/// No confundir con las otras dos cosas que también suenan a "cuenta":
///
/// - **Login** = un correo + contraseña + una sesión de Supabase
///   (`AuthService`). Una cara no tiene correo ni contraseña propios.
/// - **Cambio de cuentas** = saltar entre logins distintos
///   (`AccountSwitcherService`). Cambiar de cara **no** cierra sesión ni toca
///   ese servicio; son mecanismos separados a propósito.
///
/// Un login tiene siempre la cara turista y gana una cara más por cada negocio
/// o fundación **aprobado**: la cara nace al aprobarse, no al solicitar. Eso es
/// justamente lo que le da sentido a la notificación de aprobación — avisa que
/// se sumó una cara nueva.
class ProfileFace {
  const ProfileFace({
    required this.id,
    required this.kind,
    required this.name,
    this.imageUrl,
    this.initials = '?',
    this.business,
    this.organization,
  });

  /// [turistaId] para la cara base; el uuid de la entidad para las demás. Es la
  /// clave con la que `ProfileFaceService` recuerda cuál está activa.
  final String id;

  final ProfileFaceKind kind;
  final String name;

  /// Avatar del perfil, logo de la fundación o primera imagen del negocio;
  /// nula se dibuja con [initials].
  final String? imageUrl;

  final String initials;

  /// El modelo original, para las pantallas que sí necesitan el tipo concreto.
  final BusinessModel? business;
  final OrganizationModel? organization;

  /// Id reservado de la cara base. No es un uuid a propósito: no hay ninguna
  /// fila que la respalde, existe por el solo hecho de haber iniciado sesión.
  static const turistaId = 'turista';

  bool get isTurista => kind == ProfileFaceKind.turista;

  /// Desde una cara de negocio o fundación no se interactúa como visitante
  /// (favoritos, reseñas, inscripción a jornadas, iniciar un viaje). Ver
  /// `FaceLimitationSheet`.
  bool get canInteractAsVisitor => isTurista;

  factory ProfileFace.turista({
    required String name,
    required String initials,
    String? avatarUrl,
  }) {
    return ProfileFace(
      id: turistaId,
      kind: ProfileFaceKind.turista,
      name: name,
      imageUrl: avatarUrl,
      initials: initials,
    );
  }

  factory ProfileFace.fromBusiness(BusinessModel business) {
    return ProfileFace(
      id: business.id,
      kind: ProfileFaceKind.business,
      name: business.name.isEmpty ? 'Negocio sin nombre' : business.name,
      // El logo propio (022/020) gana sobre la portada de la galería — son
      // dos cosas distintas: el logo identifica la cara, la portada vende el
      // lugar en el detalle público.
      imageUrl: business.logoUrl?.isNotEmpty == true
          ? business.logoUrl
          : (business.localImagePaths.isEmpty
                ? null
                : business.localImagePaths.first),
      initials: _initialsOf(business.name),
      business: business,
    );
  }

  factory ProfileFace.fromOrganization(OrganizationModel organization) {
    return ProfileFace(
      id: organization.id,
      kind: ProfileFaceKind.organization,
      name: organization.name.isEmpty ? 'Fundación' : organization.name,
      imageUrl: organization.logoUrl,
      initials: organization.initials,
      organization: organization,
    );
  }

  static String _initialsOf(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.map((p) => p[0]).take(2).join().toUpperCase();
    return letters.isEmpty ? '?' : letters;
  }
}
