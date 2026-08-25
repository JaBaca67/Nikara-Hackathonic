import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nikara_app/features/eco/data/organization_service.dart';
import 'package:nikara_app/features/eco/domain/models/organization_model.dart';
import 'package:nikara_app/features/eco/presentation/screens/edit_organization_screen.dart';
import 'package:nikara_app/features/eco/presentation/screens/organization_profile_screen.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_form_fields.dart';
import 'package:nikara_app/features/eco/presentation/widgets/organization_image_field.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// `is_verified` no se pide ni se manda: arranca en `true` por default de columna, igual que `businesses.is_verified`.
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
      if (!mounted) return;
      _snack('¡${organization.name} quedó registrada!');
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Fundaciones',
          style: AppTextStyles.sectionTitle.copyWith(fontSize: 17),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xxxl,
          ),
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.oliveText),
                ),
              )
            else if (_myOrganizations.isNotEmpty) ...[
              Text('Tus fundaciones', style: AppTextStyles.detailSectionTitle),
              const SizedBox(height: 10),
              for (final organization in _myOrganizations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OrganizationRow(
                    organization: organization,
                    onTap: () => _openOrganization(organization),
                    onEdit: () => _editOrganization(organization),
                  ),
                ),
              const SizedBox(height: 22),
            ],
            Text(
              _myOrganizations.isEmpty
                  ? 'Registrar tu fundación'
                  : 'Registrar otra fundación',
              style: AppTextStyles.detailSectionTitle,
            ),
            const SizedBox(height: 4),
            Text(
              'Publica jornadas ambientales en nombre de tu organización, '
              'con su logo y su nombre.',
              style: AppTextStyles.settingsSubtitle,
            ),
            const SizedBox(height: 18),
            const EcoFieldLabel('Nombre de la fundación'),
            EcoTextField(
              controller: _nameController,
              hint: 'Ej. Fundación Cocibolca Vive',
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Escribe el nombre de la fundación.'
                  : null,
            ),
            const SizedBox(height: 16),
            const EcoFieldLabel('Handle'),
            EcoTextField(
              controller: _handleController,
              hint: 'cocibolcavive',
              prefixText: '@',
              validator: (v) {
                final normalized = OrganizationModel.normalizeHandle(v ?? '');
                if (normalized.isEmpty) {
                  return 'Escribe un handle (letras, números, punto o _).';
                }
                if (normalized.length < 3) {
                  return 'El handle necesita al menos 3 caracteres.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const EcoFieldLabel('Descripción / misión'),
            EcoTextField(
              controller: _descriptionController,
              hint: 'Qué hace la fundación y por qué importa.',
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            const EcoFieldLabel('Logo'),
            OrganizationImageField(
              slot: _logo,
              onChanged: () => setState(() {}),
              previewHeight: 96,
              previewWidth: 96,
              emptyHint: 'Sin logo · se usan las iniciales',
            ),
            const SizedBox(height: 16),
            const EcoFieldLabel('Banner'),
            OrganizationImageField(
              slot: _banner,
              onChanged: () => setState(() {}),
              previewHeight: 120,
              emptyHint: 'Sin banner',
            ),
            const SizedBox(height: 28),
            EcoPrimaryButton(
              label: 'Registrar fundación',
              isBusy: _isSaving,
              onPressed: _save,
            ),
          ],
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
