import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:nikara_app/features/eco/data/organization_service.dart';
import 'package:nikara_app/features/eco/domain/models/organization_model.dart';
import 'package:nikara_app/features/eco/presentation/screens/organization_profile_screen.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_form_fields.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// "Registrar / Gestionar Fundación" (Ajustes -> Comunidad ECO) — lista las
/// fundaciones que ya registró esta cuenta (tocar una abre su perfil
/// público) y debajo el formulario para dar de alta otra.
///
/// `is_verified` no se pide ni se manda: la columna arranca en `true` en
/// esta fase de prueba (ver supabase/sql/010_organizations.sql), igual que
/// `businesses.is_verified` nunca se escribe desde el cliente.
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
  final _logoController = TextEditingController();
  final _bannerController = TextEditingController();

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
    _logoController.dispose();
    _bannerController.dispose();
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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final organization = await OrganizationService().createOrganization(
        name: _nameController.text.trim(),
        handle: _handleController.text,
        description: _descriptionController.text.trim(),
        logoUrl: _emptyToNull(_logoController.text),
        bannerUrl: _emptyToNull(_bannerController.text),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('¡${organization.name} quedó registrada!')),
      );
      _nameController.clear();
      _handleController.clear();
      _descriptionController.clear();
      _logoController.clear();
      _bannerController.clear();
      setState(() => _myOrganizations = [..._myOrganizations, organization]);
    } on OrganizationServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  static String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _openOrganization(OrganizationModel organization) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrganizationProfileScreen(organization: organization),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundCream,
        elevation: 0,
        title: Text(
          'Fundaciones',
          style: AppTextStyles.sectionTitle.copyWith(fontSize: 17),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.ecoActive),
                ),
              )
            else if (_myOrganizations.isNotEmpty) ...[
              Text('Tus fundaciones', style: AppTextStyles.detailSectionTitle),
              const SizedBox(height: 10),
              for (final organization in _myOrganizations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _OrganizationRow(
                    organization: organization,
                    onTap: () => _openOrganization(organization),
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
            _ImageField(
              controller: _logoController,
              hint: 'Pega una URL o elige una imagen',
              previewHeight: 72,
              previewWidth: 72,
            ),
            const SizedBox(height: 16),
            const EcoFieldLabel('Banner'),
            _ImageField(
              controller: _bannerController,
              hint: 'Pega una URL o elige una imagen',
              previewHeight: 96,
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

/// Campo de imagen: una URL escrita a mano o la ruta de una imagen del
/// dispositivo (el botón la escribe en el mismo campo). Ambas se guardan
/// como texto plano, igual que las fotos de un negocio, y [LocalImage]
/// resuelve las dos formas al pintar la vista previa.
class _ImageField extends StatefulWidget {
  const _ImageField({
    required this.controller,
    required this.hint,
    required this.previewHeight,
    this.previewWidth,
  });

  final TextEditingController controller;
  final String hint;
  final double previewHeight;
  final double? previewWidth;

  @override
  State<_ImageField> createState() => _ImageFieldState();
}

class _ImageFieldState extends State<_ImageField> {
  @override
  void initState() {
    super.initState();
    // La vista previa sigue lo que hay en el campo, se haya escrito a mano
    // o lo haya puesto el selector. El controller es del padre, así que acá
    // solo se quita el listener, nunca se hace dispose.
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    widget.controller.text = picked.path;
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EcoTextField(controller: widget.controller, hint: widget.hint),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: EcoPickerButton(
                icon: Icons.image_outlined,
                label: 'Elegir del dispositivo',
                onTap: _pick,
              ),
            ),
            if (value.isNotEmpty) ...[
              const SizedBox(width: 10),
              EcoPickerButton(
                icon: Icons.close_rounded,
                label: 'Quitar',
                onTap: () => setState(() => widget.controller.clear()),
              ),
            ],
          ],
        ),
        if (value.isNotEmpty) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: widget.previewHeight,
              width: widget.previewWidth,
              child: LocalImage(path: value),
            ),
          ),
        ],
      ],
    );
  }
}

class _OrganizationRow extends StatelessWidget {
  const _OrganizationRow({required this.organization, required this.onTap});

  final OrganizationModel organization;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.mapControlBorder),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
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
                            color: AppColors.ecoActive,
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
                          color: AppColors.ecoActive,
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
            const Icon(Icons.chevron_right, color: AppColors.neutral400),
          ],
        ),
      ),
    );
  }
}
