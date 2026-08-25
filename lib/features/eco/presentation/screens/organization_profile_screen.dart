import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/eco/data/eco_service.dart';
import 'package:nikara_app/features/eco/data/organization_service.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/domain/models/organization_model.dart';
import 'package:nikara_app/features/eco/presentation/screens/eco_detail_screen.dart';
import 'package:nikara_app/features/eco/presentation/screens/edit_organization_screen.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_activity_card.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/shared/widgets/public_profile_header.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Acepta [organization] ya cargada (pantalla de gestión) o solo [organizationId] (feed, que no tiene el objeto completo).
class OrganizationProfileScreen extends StatefulWidget {
  const OrganizationProfileScreen({
    super.key,
    this.organization,
    this.organizationId,
  }) : assert(
         organization != null || organizationId != null,
         'Se necesita la fundación o su id.',
       );

  final OrganizationModel? organization;
  final String? organizationId;

  @override
  State<OrganizationProfileScreen> createState() =>
      _OrganizationProfileScreenState();
}

class _OrganizationProfileScreenState extends State<OrganizationProfileScreen> {
  late OrganizationModel? _organization = widget.organization;
  List<EcoActivityModel> _activities = const [];
  bool _isLoading = true;
  String? _loadError;

  String get _organizationId =>
      widget.organization?.id ?? widget.organizationId!;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final organization =
          _organization ?? await OrganizationService().getById(_organizationId);
      final activities = await EcoService().getActivitiesByOrganization(
        _organizationId,
      );
      if (!mounted) return;
      setState(() {
        _organization = organization;
        _activities = activities;
        _loadError = organization == null
            ? 'No encontramos esta fundación.'
            : null;
        _isLoading = false;
      });
    } on OrganizationServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    } on EcoServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    }
  }

  int get _volunteers =>
      _activities.fold(0, (total, a) => total + a.participantCount);

  int get _upcoming => _activities.where((a) => !a.isPast).length;

  /// Solo el dueño ve el acceso a gestionarla; para el resto es un perfil
  /// público de lectura.
  bool get _isOwner {
    final organization = _organization;
    return organization != null &&
        organization.ownerId.isNotEmpty &&
        organization.ownerId == AuthService().currentAuthUser?.id;
  }

  Future<void> _manage(OrganizationModel organization) async {
    final stillExists = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditOrganizationScreen(organization: organization),
      ),
    );
    if (!mounted) return;
    // `false` = se eliminó desde esa pantalla: este perfil ya no tiene qué
    // mostrar, así que se cierra en vez de recargar un id inexistente.
    if (stillExists == false) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _organization = null);
    await _load();
  }

  Future<void> _openActivity(EcoActivityModel activity) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EcoDetailScreen(activity: activity)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final organization = _organization;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.oliveText),
            )
          : organization == null
          ? _ErrorState(
              message: _loadError ?? 'No encontramos esta fundación.',
              onBack: () => Navigator.of(context).maybePop(),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
              children: [
                PublicProfileHeader(
                  name: organization.name,
                  handle: organization.handleTag,
                  bannerPath: organization.bannerUrl,
                  accent: AppColors.oliveText,
                  verified: organization.isVerified,
                  badgeIcon: Icons.eco_rounded,
                  badgeLabel: organization.isVerified
                      ? 'Fundación Ecológica Verificada'
                      : 'Fundación en revisión',
                  onBack: () => Navigator.of(context).maybePop(),
                  action: _isOwner
                      ? _ManageButton(onTap: () => _manage(organization))
                      : null,
                  avatar: organization.logoUrl == null
                      ? _InitialsAvatar(initials: organization.initials)
                      : LocalImage(
                          path: organization.logoUrl,
                          fallbackIcon: Icons.eco_rounded,
                        ),
                ),
                PublicProfileStats(
                  items: [
                    (value: '${_activities.length}', label: 'Jornadas'),
                    (value: '$_volunteers', label: 'Voluntarios'),
                    (value: '$_upcoming', label: 'Próximas'),
                  ],
                ),
                if (organization.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sobre nosotros',
                          style: AppTextStyles.detailSectionTitle,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          organization.description,
                          style: AppTextStyles.detailDescriptionText,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: Text(
                    'Próximas jornadas',
                    style: AppTextStyles.detailSectionTitle,
                  ),
                ),
                const SizedBox(height: 12),
                if (_activities.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.xxl,
                    ),
                    child: Text(
                      'Esta fundación todavía no ha publicado jornadas.',
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
}

/// Acceso a "Gestionar" desde la cabecera del perfil, en el slot de acción de
/// [PublicProfileHeader].
class _ManageButton extends StatelessWidget {
  const _ManageButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surface100,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.oliveText.withValues(alpha: 0.4)),
          boxShadow: const [
            BoxShadow(
              color: AppColors.mapControlShadowSoft,
              offset: Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.tune_rounded,
              size: 15,
              color: AppColors.oliveText,
            ),
            const SizedBox(width: 6),
            Text(
              'Gestionar',
              style: AppTextStyles.mapRowTitle.copyWith(
                fontSize: 12,
                color: AppColors.oliveText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.detailActivityIconBg,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppTextStyles.h6.copyWith(color: AppColors.oliveText),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 40,
                color: AppColors.neutral400,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.settingsSubtitle,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.settingsTextDark,
                  side: const BorderSide(color: AppColors.mapControlBorder),
                ),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
