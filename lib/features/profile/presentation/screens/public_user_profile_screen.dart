import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/local_profile_extras_service.dart';
import 'package:nikara_app/features/eco/data/eco_service.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/presentation/screens/eco_detail_screen.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_activity_card.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/shared/widgets/public_profile_header.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Perfil público de una persona — a donde lleva tocar el bloque
/// "Organizador" de una jornada publicada a título personal (sin fundación).
///
/// Solo muestra lo que realmente existe en el backend: el nombre y el rol de
/// su fila en `profiles` y las jornadas ECO que esa persona publicó. No hay
/// correo ni teléfono acá — son datos privados de `profiles` que este perfil
/// público no tiene por qué exponer. La foto solo aparece cuando el perfil
/// es el de quien está usando el dispositivo: los avatares se guardan en
/// local ([LocalProfileExtrasService]), `profiles` no tiene columna de foto.
class PublicUserProfileScreen extends StatefulWidget {
  const PublicUserProfileScreen({
    super.key,
    required this.userId,
    this.fallbackName,
  });

  final String userId;

  /// Nombre que ya traía quien navegó hasta acá (`organizer_name` de la
  /// actividad) — se pinta mientras carga el perfil real, y queda como
  /// respaldo si la fila de `profiles` no es legible (por ejemplo, cuando
  /// quien mira entró como invitado).
  final String? fallbackName;

  @override
  State<PublicUserProfileScreen> createState() =>
      _PublicUserProfileScreenState();
}

class _PublicUserProfileScreenState extends State<PublicUserProfileScreen> {
  UserModel? _profile;
  String? _avatarPath;
  List<EcoActivityModel> _activities = const [];
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
      // `profiles` no es legible para quien entró como invitado (RLS solo
      // deja leerla a cuentas autenticadas). La pantalla se queda con el
      // nombre que ya traía la actividad en vez de romperse.
    }
    final avatarPath = _isCurrentUser
        ? await LocalProfileExtrasService().getAvatarPath()
        : null;
    List<EcoActivityModel> activities = const [];
    try {
      activities = await EcoService().getPersonalActivitiesByOrganizer(
        widget.userId,
      );
    } on EcoServiceException {
      // El perfil sigue siendo útil sin el listado — se muestra vacío en
      // lugar de convertir toda la pantalla en un error.
    }
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _avatarPath = avatarPath;
      _activities = activities;
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

  @override
  Widget build(BuildContext context) {
    final avatarPath = _avatarPath;

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
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
                  verified: false,
                  badgeIcon: Icons.hiking_rounded,
                  badgeLabel: _roleLabel,
                  contextLine: _isCurrentUser ? 'Este eres tú' : null,
                  onBack: () => Navigator.of(context).maybePop(),
                  avatar: avatarPath != null && avatarPath.isNotEmpty
                      ? LocalImage(path: avatarPath)
                      : _InitialsAvatar(
                          initials: _profile?.initials ?? _fallbackInitials,
                        ),
                ),
                PublicProfileStats(
                  items: [
                    (value: '${_activities.length}', label: 'Jornadas ECO'),
                    (value: '$_volunteers', label: 'Voluntarios'),
                    (value: '${_profile?.points ?? 0}', label: 'Puntos'),
                  ],
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Jornadas que organiza',
                    style: AppTextStyles.detailSectionTitle,
                  ),
                ),
                const SizedBox(height: 12),
                if (_activities.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: Text(
                      'Todavía no ha publicado jornadas a título personal.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.settingsSubtitle,
                    ),
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

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.accent300,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppTextStyles.h6.copyWith(color: AppColors.surface100),
      ),
    );
  }
}
