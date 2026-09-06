import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/eco/data/organization_service.dart';
import 'package:nikara_app/features/eco/domain/models/organization_model.dart';
import 'package:nikara_app/features/eco/presentation/screens/edit_organization_screen.dart';
import 'package:nikara_app/features/eco/presentation/screens/organization_profile_screen.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_form_fields.dart';
import 'package:nikara_app/features/eco/presentation/widgets/organization_image_field.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// `is_verified` no se pide ni se manda: arranca en `false` por default de
/// columna (`026_organizations_verified_default.sql`), igual que
/// `businesses.is_verified` — un admin lo marca aparte, después de aprobar.
class CreateOrganizationScreen extends StatefulWidget {
  const CreateOrganizationScreen({super.key});

  @override
  State<CreateOrganizationScreen> createState() =>
      _CreateOrganizationScreenState();
}

class _CreateOrganizationScreenState extends State<CreateOrganizationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _handleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Sin `existingUrl`: en el alta siempre se parte de cero.
  var _logo = OrganizationImageSlot();
  var _banner = OrganizationImageSlot();

  List<OrganizationModel> _myOrganizations = const [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMine());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadMine() async {
    try {
      final organizations = await OrganizationService().getMyOrganizations();
      if (!mounted) return;
      setState(() {
        _myOrganizations = organizations;
        _isLoading = false;
      });
    } on OrganizationServiceException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      // Las imágenes suben antes del insert: si Storage falla, no queda una
      // fundación registrada apuntando a una imagen que nunca se subió.
      final logo = await _logo.resolve();
      final banner = await _banner.resolve();

      final organization = await OrganizationService().createOrganization(
        name: _nameController.text.trim(),
        handle: _handleController.text,
        description: _descriptionController.text.trim(),
        logoUrl: logo.url,
        bannerUrl: banner.url,
      );
      // Mismo ascenso que `RegisterBusinessWizard._finish()` — sin esto, quien
      // solo registra una fundación (nunca un negocio) se queda con el rol
      // `turista` para siempre, aunque gestione una organización activa. Bug
      // real encontrado en la auditoría del 2026-09-04: hoy nada en la UI
      // depende de este rol para bloquear una acción, pero sí se ve en
      // Admin > Usuarios, así que quedaba mal etiquetado.
      try {
        await AuthService().markAsEmprendedor();
      } on AuthServiceException {
        // Se ignora: la fundación ya se guardó correctamente.
      }
      if (!mounted) return;
      _snack(
        '¡Solicitud enviada! Revisamos ${organization.name} en un máximo de '
        '24 horas.',
      );
      _nameController.clear();
      _handleController.clear();
      _descriptionController.clear();
      setState(() {
        _logo = OrganizationImageSlot();
        _banner = OrganizationImageSlot();
        _myOrganizations = [..._myOrganizations, organization];
      });
    } on OrganizationServiceException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openOrganization(OrganizationModel organization) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrganizationProfileScreen(organization: organization),
      ),
    );
    await _loadMine();
  }

  Future<void> _editOrganization(OrganizationModel organization) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditOrganizationScreen(organization: organization),
      ),
    );
    await _loadMine();
  }

  @override
  Widget build(BuildContext context) {
    // Mismo esqueleto que `EditOrganizationScreen` (header + secciones con
    // tarjeta + footer fijo): eran la misma pantalla en espíritu —gestionar
    // fundaciones— pero esta se había quedado con un `AppBar` plano y
    // secciones sueltas de antes de que existiera ese patrón. Encontrado en
    // la auditoría visual del 2026-09-06.
    return Scaffold(
      backgroundColor: AppColors.settingsBackground,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              EcoFormHeader(
                title: 'Fundaciones',
                subtitle: 'Publica jornadas a nombre de tu organización',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.oliveText,
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_myOrganizations.isNotEmpty) ...[
                              const EcoSectionIntro(
                                title: 'Tus fundaciones',
                                subtitle:
                                    'Tocá una para ver su perfil, o el ícono '
                                    'para gestionarla.',
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  0,
                                ),
                                child: Column(
                                  children: [
                                    for (final organization in _myOrganizations)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: _OrganizationRow(
                                          organization: organization,
                                          onTap: () =>
                                              _openOrganization(organization),
                                          onEdit: () =>
                                              _editOrganization(organization),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            EcoSectionIntro(
                              title: _myOrganizations.isEmpty
                                  ? 'Registrar tu fundación'
                                  : 'Registrar otra fundación',
                              subtitle:
                                  'Toda jornada ambiental se publica a nombre '
                                  'de una fundación, nunca a título personal: '
                                  'es lo que le da respaldo a una '
                                  'convocatoria. En cuanto la revisemos '
                                  '(máximo 24 horas), vas a poder publicar '
                                  'jornadas con su logo y su nombre.',
                            ),
                            EcoFormCard(
                              children: [
                                const EcoFieldLabel('Nombre'),
                                EcoTextField(
                                  controller: _nameController,
                                  hint: 'Ej. Fundación Cocibolca Vive',
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? 'Escribe el nombre de la fundación.'
                                      : null,
                                ),
                                const SizedBox(height: 18),
                                const EcoFieldLabel('Handle'),
                                EcoTextField(
                                  controller: _handleController,
                                  hint: 'cocibolcavive',
                                  prefixText: '@',
                                  validator: (v) {
                                    final normalized =
                                        OrganizationModel.normalizeHandle(
                                          v ?? '',
                                        );
                                    if (normalized.isEmpty) {
                                      return 'Escribe un handle (letras, '
                                          'números, punto o _).';
                                    }
                                    if (normalized.length < 3) {
                                      return 'El handle necesita al menos 3 '
                                          'caracteres.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                const EcoFieldLabel('Descripción / misión'),
                                EcoTextField(
                                  controller: _descriptionController,
                                  hint:
                                      'Qué hace la fundación y por qué '
                                      'importa.',
                                  maxLines: 4,
                                ),
                              ],
                            ),
                            const EcoSectionIntro(
                              title: 'Identidad visual',
                              subtitle:
                                  'El logo acompaña cada jornada; el banner '
                                  'es la portada de su perfil.',
                            ),
                            EcoFormCard(
                              children: [
                                const EcoFieldLabel('Logo'),
                                OrganizationImageField(
                                  slot: _logo,
                                  onChanged: () => setState(() {}),
                                  previewHeight: 96,
                                  previewWidth: 96,
                                  emptyHint: 'Sin logo · se usan las iniciales',
                                  isCircular: true,
                                ),
                                const SizedBox(height: 18),
                                const EcoFieldLabel('Banner'),
                                OrganizationImageField(
                                  slot: _banner,
                                  onChanged: () => setState(() {}),
                                  previewHeight: 120,
                                  emptyHint: 'Sin banner',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface100,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.detailBottomBarShadow,
                      offset: Offset(0, -2),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: EcoPrimaryButton(
                  label: 'Enviar solicitud',
                  isBusy: _isSaving,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrganizationRow extends StatelessWidget {
  const _OrganizationRow({
    required this.organization,
    required this.onTap,
    required this.onEdit,
  });

  final OrganizationModel organization;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface100,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.mapControlBorder),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: 44,
                height: 44,
                child: organization.logoUrl == null
                    ? Container(
                        color: AppColors.detailActivityIconBg,
                        alignment: Alignment.center,
                        child: Text(
                          organization.initials,
                          style: AppTextStyles.mapRowTitle.copyWith(
                            color: AppColors.oliveText,
                          ),
                        ),
                      )
                    : LocalImage(
                        path: organization.logoUrl,
                        fallbackIcon: Icons.eco_rounded,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          organization.name,
                          style: AppTextStyles.detailHostName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (organization.isVerified) ...[
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: AppColors.oliveText,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    organization.handleTag,
                    style: AppTextStyles.settingsSubtitle.copyWith(
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEdit,
              tooltip: 'Gestionar fundación',
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.tune_rounded,
                size: 18,
                color: AppColors.oliveText,
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.neutral400),
          ],
        ),
      ),
    );
  }
}
