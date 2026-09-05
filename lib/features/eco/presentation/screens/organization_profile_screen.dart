import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/permission_service.dart';
import 'package:nikara_app/features/admin/data/admin_service.dart';
import 'package:nikara_app/features/admin/presentation/widgets/admin_widgets.dart';
import 'package:nikara_app/features/admin/presentation/widgets/rejection_reason_dialog.dart';
import 'package:nikara_app/features/eco/data/eco_service.dart';
import 'package:nikara_app/features/eco/data/organization_service.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/domain/models/organization_model.dart';
import 'package:nikara_app/features/eco/presentation/screens/eco_detail_screen.dart';
import 'package:nikara_app/features/eco/presentation/screens/edit_organization_screen.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_activity_card.dart';
import 'package:nikara_app/features/notifications/data/notification_service.dart';
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
  bool _savingReview = false;
  bool _savingSeal = false;

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

  bool get _canReview => PermissionService().can(Permission.verifyOrganization);

  Future<void> _approveOrganization() async {
    final organization = _organization;
    if (organization == null) return;
    setState(() => _savingReview = true);
    try {
      await AdminService().reviewOrganization(
        id: organization.id,
        status: ReviewStatus.aprobado,
      );
      await _notifyOwner(organization, approved: true);
      setState(() => _organization = null);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${organization.name}" quedó publicada.')),
      );
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } on PermissionDeniedException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _savingReview = false);
    }
  }

  Future<void> _rejectOrganization() async {
    final organization = _organization;
    if (organization == null) return;
    final reason = await showRejectionReasonDialog(
      context,
      subjectName: organization.name.isEmpty
          ? 'esta fundación'
          : organization.name,
    );
    if (reason == null || !mounted) return;
    setState(() => _savingReview = true);
    try {
      await AdminService().reviewOrganization(
        id: organization.id,
        status: ReviewStatus.rechazado,
        reason: reason,
      );
      await _notifyOwner(organization, approved: false, reason: reason);
      setState(() => _organization = null);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rechazaste "${organization.name}". Le avisamos a quien la registró.',
          ),
        ),
      );
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } on PermissionDeniedException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _savingReview = false);
    }
  }

  /// Mismo mecanismo que el sello de negocios
  /// (`admin_business_detail_screen.dart`), pero sobre `organizations` — el
  /// sello es independiente de aprobar/rechazar, así que solo se ofrece
  /// sobre una fundación ya aprobada.
  Future<void> _toggleVerification() async {
    final organization = _organization;
    if (organization == null) return;
    final target = !organization.isVerified;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AdminConfirmDialog(
        title: target ? 'Dar el sello' : 'Quitar el sello',
        message: target
            ? '"${organization.name}" va a mostrarse con el sello de '
                  'verificado en toda la app. No cambia si está publicada o '
                  'no. ¿Confirmas?'
            : '"${organization.name}" deja de mostrar el sello de '
                  'verificado, pero sigue publicada. ¿Confirmas?',
        confirmLabel: target ? 'Dar el sello' : 'Quitar el sello',
        confirmColor: target ? AppColors.oliveText : AppColors.destructive,
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _savingSeal = true);
    try {
      await AdminService().setOrganizationVerified(
        id: organization.id,
        isVerified: target,
      );
      if (!mounted) return;
      setState(() => _organization = null);
      await _load();
      if (!mounted) return;
      setState(() => _savingSeal = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            target
                ? '"${organization.name}" ya muestra el sello.'
                : 'Le quitaste el sello a "${organization.name}".',
          ),
        ),
      );
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      setState(() => _savingSeal = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } on PermissionDeniedException catch (e) {
      if (!mounted) return;
      setState(() => _savingSeal = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// El aviso al dueño no puede tumbar la revisión: si falla, se registra y
  /// se sigue — mismo criterio que `AdminService._notifyReviewed`.
  Future<void> _notifyOwner(
    OrganizationModel organization, {
    required bool approved,
    String? reason,
  }) async {
    if (organization.ownerId.isEmpty) return;
    try {
      await NotificationService().notifyOrganizationReviewed(
        ownerId: organization.ownerId,
        organizationId: organization.id,
        organizationName: organization.name,
        approved: approved,
        reason: reason,
      );
    } on NotificationServiceException catch (e) {
      debugPrint(
        '[OrganizationProfileScreen] _notifyOwner: no se pudo avisar — '
        '${e.message}',
      );
    }
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
                    (
                      value: '$_volunteers',
                      label: _volunteers == 1 ? 'Voluntario' : 'Voluntarios',
                    ),
                    (value: '$_upcoming', label: 'Próximas'),
                  ],
                ),
                if (_canReview)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.xl,
                      0,
                    ),
                    child: AdminInlineReviewCard(
                      status: organization.reviewStatus,
                      rejectionReason: organization.rejectionReason,
                      saving: _savingReview,
                      onApprove: _approveOrganization,
                      onReject: _rejectOrganization,
                    ),
                  ),
                // El sello solo tiene sentido sobre una fundación ya
                // publicada — ver `_toggleVerification`.
                if (_canReview && organization.reviewStatus.isAprobado)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.xl,
                      0,
                    ),
                    child: AdminSealRow(
                      isVerified: organization.isVerified,
                      enabled: !_savingSeal,
                      onChanged: (_) => _toggleVerification(),
                    ),
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
