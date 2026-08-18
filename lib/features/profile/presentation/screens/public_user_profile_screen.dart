import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/eco/data/eco_service.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/presentation/screens/eco_detail_screen.dart';
import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/presentation/screens/business_detail_screen.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_activity_card.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/shared/widgets/public_profile_header.dart';
import 'package:nikara_app/shared/widgets/user_avatar.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Sin correo ni teléfono (privados en `profiles`). La foto sale de
/// `profiles.avatar_url`, así que se ve para cualquier visitante — antes solo
/// aparecía en el dispositivo del propio dueño, porque el avatar vivía en
/// `SharedPreferences` (ver supabase/sql/015_profile_avatars.sql).
class PublicUserProfileScreen extends StatefulWidget {
  const PublicUserProfileScreen({
    super.key,
    required this.userId,
    this.fallbackName,
  });

  final String userId;

  /// `organizer_name` de la actividad: se pinta mientras carga y queda como respaldo si `profiles` no es legible (ej. invitado).
  final String? fallbackName;

  @override
  State<PublicUserProfileScreen> createState() =>
      _PublicUserProfileScreenState();
}

class _PublicUserProfileScreenState extends State<PublicUserProfileScreen> {
  UserModel? _profile;
  List<EcoActivityModel> _activities = const [];
  List<BusinessModel> _businesses = const [];
  bool _isLoading = true;

  bool get _isCurrentUser => AuthService().currentAuthUser?.id == widget.userId;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    UserModel? profile;
    try {
      profile = await AuthService().getProfileById(widget.userId);
    } on AuthServiceException {
      // RLS solo deja leer `profiles` a cuentas autenticadas; se queda con el nombre que ya traía la actividad.
    }
    List<EcoActivityModel> activities = const [];
    try {
      activities = await EcoService().getPersonalActivitiesByOrganizer(
        widget.userId,
      );
    } on EcoServiceException {
      // El perfil sigue siendo útil sin el listado: se muestra vacío en vez de romper toda la pantalla.
    }
    // Los negocios se filtran en el cliente porque BusinessStorageService ya
    // trae y cachea la lista completa; una consulta por owner_id sería un
    // round-trip extra para el mismo resultado.
    List<BusinessModel> businesses = const [];
    try {
      final all = await BusinessStorageService().getBusinesses();
      businesses = all
          .where((b) => b.ownerId == widget.userId)
          .toList(growable: false);
    } on BusinessServiceException {
      // Igual que arriba: sin negocios el perfil sigue siendo válido.
    }
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _activities = activities;
      _businesses = businesses;
      _isLoading = false;
    });
  }

  String get _displayName {
    final name = _profile?.fullName.trim();
    if (name != null && name.isNotEmpty) return name;
    final fallback = widget.fallbackName?.trim();
    return (fallback == null || fallback.isEmpty) ? 'Organizador' : fallback;
  }

  String get _roleLabel => switch (_profile?.role) {
    UserRole.emprendedor => 'Emprendedor local',
    UserRole.admin => 'Equipo Níkara',
    UserRole.auditor => 'Auditor Níkara',
    _ => 'Viajero Níkara',
  };

  int get _volunteers =>
      _activities.fold(0, (total, a) => total + a.participantCount);

  Future<void> _openActivity(EcoActivityModel activity) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EcoDetailScreen(activity: activity)),
    );
  }

  Future<void> _openBusiness(BusinessModel business) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BusinessDetailScreen(business: business),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Mismo fondo que EcoDetailScreen/BusinessDetailScreen: este perfil se
      // abre siempre desde una de esas pantallas.
      backgroundColor: AppColors.settingsBackground,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary500),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                PublicProfileHeader(
                  name: _displayName,
                  accent: AppColors.accent300,
                  badgeIcon: Icons.hiking_rounded,
                  badgeLabel: _roleLabel,
                  contextLine: _isCurrentUser ? 'Este eres tú' : null,
                  onBack: () => Navigator.of(context).maybePop(),
                  avatar: UserAvatar(
                    avatarUrl: _profile?.avatarUrl,
                    initials: _profile?.initials ?? _fallbackInitials,
                    borderRadius: BorderRadius.circular(25),
                    background: AppColors.detailActivityIconBg,
                    foreground: AppColors.accent300,
                    initialsStyle: AppTextStyles.sectionTitle.copyWith(
                      fontSize: 28,
                      color: AppColors.accent300,
                    ),
                  ),
                ),
                PublicProfileStats(
                  items: [
                    (value: '${_activities.length}', label: 'Jornadas ECO'),
                    (value: '${_businesses.length}', label: 'Negocios'),
                    (value: '$_volunteers', label: 'Voluntarios'),
                  ],
                ),
                _SectionTitle(
                  'Jornadas que organiza',
                  count: _activities.length,
                ),
                if (_activities.isEmpty)
                  const _EmptySection(
                    icon: Icons.eco_outlined,
                    message:
                        'Todavía no ha publicado jornadas a título '
                        'personal.',
                  )
                else
                  for (final activity in _activities)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: EcoActivityCard(
                        activity: activity,
                        onTap: () => _openActivity(activity),
                        showOrganizer: false,
                      ),
                    ),
                // Solo si tiene negocios: un viajero sin nada registrado no
                // necesita ver una sección vacía más.
                if (_businesses.isNotEmpty) ...[
                  _SectionTitle(
                    'Negocios que administra',
                    count: _businesses.length,
                  ),
                  for (final business in _businesses)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: _PublicBusinessRow(
                        business: business,
                        onTap: () => _openBusiness(business),
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  String get _fallbackInitials {
    final parts = _displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    final letters = parts.map((p) => p[0]).take(2).join().toUpperCase();
    return letters.isEmpty ? '?' : letters;
  }
}

/// Fila compacta de negocio para el perfil público. No reusa
/// `_MyBusinessCard` de ProfileScreen porque esa lleva acciones de
/// editar/eliminar que solo tienen sentido sobre los negocios propios.
class _PublicBusinessRow extends StatelessWidget {
  const _PublicBusinessRow({required this.business, required this.onTap});

  final BusinessModel business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface100,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.mapControlBorder),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 56,
                height: 56,
                child: LocalImage(
                  path: business.localImagePaths.isEmpty
                      ? null
                      : business.localImagePaths.first,
                  fallbackIcon: Icons.storefront_outlined,
                  fallbackIconSize: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    business.name,
                    style: AppTextStyles.mapRowTitle.copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    business.city.isEmpty
                        ? business.category
                        : '${business.category} · ${business.city}',
                    style: AppTextStyles.settingsSubtitle.copyWith(
                      fontSize: 11.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.neutral400,
            ),
          ],
        ),
      ),
    );
  }
}

/// Encabezado de sección con el conteo a la derecha, mismo tratamiento que
/// las secciones del detalle de negocio.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.detailSectionTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.detailActivityIconBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: AppTextStyles.mapRowTitle.copyWith(
                  fontSize: 11.5,
                  color: AppColors.ecoActive,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.mapControlBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: AppColors.neutral400),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.settingsSubtitle.copyWith(fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
