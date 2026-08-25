import 'package:flutter/material.dart';

import 'package:nikara_app/features/eco/data/organization_service.dart';
import 'package:nikara_app/features/eco/domain/models/organization_model.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_form_fields.dart';
import 'package:nikara_app/features/eco/presentation/widgets/organization_image_field.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Gestión de una fundación ya registrada: editar sus datos o eliminarla.
///
/// Devuelve `true` al guardar y `false` al eliminar, para que quien la abrió
/// sepa si debe recargar o salir de la pantalla de la fundación borrada.
class EditOrganizationScreen extends StatefulWidget {
  const EditOrganizationScreen({super.key, required this.organization});

  final OrganizationModel organization;

  @override
  State<EditOrganizationScreen> createState() => _EditOrganizationScreenState();
}

class _EditOrganizationScreenState extends State<EditOrganizationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.organization.name,
  );
  late final _handleController = TextEditingController(
    text: widget.organization.handle,
  );
  late final _descriptionController = TextEditingController(
    text: widget.organization.description,
  );

  late final _logo = OrganizationImageSlot(
    existingUrl: widget.organization.logoUrl,
  );
  late final _banner = OrganizationImageSlot(
    existingUrl: widget.organization.bannerUrl,
  );

  bool _isSaving = false;
  bool _isDeleting = false;

  bool get _isBusy => _isSaving || _isDeleting;

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      // Las imágenes suben antes del update: si Storage falla, no queda una
      // fundación guardada apuntando a una imagen que nunca se subió.
      final logo = await _logo.resolve();
      final banner = await _banner.resolve();

      final updated = await OrganizationService().updateOrganization(
        id: widget.organization.id,
        name: _nameController.text.trim(),
        handle: _handleController.text,
        description: _descriptionController.text.trim(),
        logoUrl: logo.url,
        clearLogo: logo.clear,
        bannerUrl: banner.url,
        clearBanner: banner.clear,
      );
      if (!mounted) return;
      _snack('Se guardaron los cambios de ${updated.name}.');
      Navigator.of(context).pop(true);
    } on OrganizationServiceException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          '¿Eliminar fundación?',
          style: AppTextStyles.settingsTitle.copyWith(fontSize: 18),
        ),
        content: Text(
          'Se eliminará "${widget.organization.name}" de forma permanente. '
          'Las jornadas que publicaste en su nombre no se borran: pasan a '
          'figurar como publicaciones tuyas a título personal.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar', style: AppTextStyles.settingsRowValue),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Eliminar',
              style: AppTextStyles.settingsRowTitle.copyWith(
                color: AppColors.destructive,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await OrganizationService().deleteOrganization(widget.organization.id);
      if (!mounted) return;
      _snack('Se eliminó ${widget.organization.name}.');
      Navigator.of(context).pop(false);
    } on OrganizationServiceException catch (e) {
      _snack(e.message);
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.settingsBackground,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              EcoFormHeader(
                title: 'Editar fundación',
                subtitle: widget.organization.handleTag,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EcoSectionIntro(
                        title: 'Datos de la fundación',
                        subtitle:
                            'Es lo que ve la gente en el feed ECO y en cada '
                            'jornada que publiques a su nombre.',
                      ),
                      EcoFormCard(
                        children: [
                          const EcoFieldLabel('Nombre'),
                          EcoTextField(
                            controller: _nameController,
                            hint: 'Ej. Fundación Cocibolca Vive',
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Escribe el nombre de la fundación.'
                                : null,
                          ),
                          const SizedBox(height: 18),
                          const EcoFieldLabel('Handle'),
                          EcoTextField(
                            controller: _handleController,
                            hint: 'cocibolcavive',
                            prefixText: '@',
                            validator: _validateHandle,
                          ),
                          const SizedBox(height: 18),
                          const EcoFieldLabel('Descripción / misión'),
                          EcoTextField(
                            controller: _descriptionController,
                            hint: 'Qué hace la fundación y por qué importa.',
                            maxLines: 4,
                          ),
                        ],
                      ),
                      const EcoSectionIntro(
                        title: 'Identidad visual',
                        subtitle:
                            'El logo acompaña cada jornada; el banner es la '
                            'portada de su perfil.',
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
                      const EcoSectionIntro(
                        title: 'Zona de peligro',
                        subtitle:
                            'Eliminar la fundación no borra sus jornadas '
                            'publicadas.',
                      ),
                      EcoFormCard(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _isBusy ? null : _confirmDelete,
                              icon: _isDeleting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.destructive,
                                      ),
                                    )
                                  : const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Eliminar fundación'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.destructive,
                                side: BorderSide(
                                  color: AppColors.destructive.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                textStyle: AppTextStyles.wizardChipLabel,
                              ),
                            ),
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
                  label: 'Guardar cambios',
                  isBusy: _isBusy,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _validateHandle(String? value) {
    final normalized = OrganizationModel.normalizeHandle(value ?? '');
    if (normalized.isEmpty) {
      return 'Escribe un handle (letras, números, punto o _).';
    }
    if (normalized.length < 3) {
      return 'El handle necesita al menos 3 caracteres.';
    }
    return null;
  }
}
