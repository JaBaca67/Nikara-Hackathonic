import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:nikara_app/core/models/legal_identity_model.dart';
import 'package:nikara_app/core/services/legal_identity_service.dart';
import 'package:nikara_app/core/utils/input_formatters.dart';
import 'package:nikara_app/core/utils/input_sanitizers.dart';
import 'package:nikara_app/features/business/presentation/screens/register_business_wizard.dart';
import 'package:nikara_app/features/eco/presentation/screens/create_organization_screen.dart';
import 'package:nikara_app/shared/widgets/circle_back_button.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Abre el flujo de registro de negocio: si la cuenta activa ya cargó su
/// identidad legal (RUC/cédula), va directo al wizard; si no, primero pasa
/// por [LegalIdentityGateScreen]. Único punto de entrada — home_screen.dart y
/// settings_screen.dart llaman a esto en vez de empujar `RegisterBusinessWizard`
/// directamente, así el gate no se puede saltear por otro camino.
Future<void> openBusinessRegistrationFlow(BuildContext context) =>
    _openLegalIdentityGatedFlow(
      context,
      destination: (_) => const RegisterBusinessWizard(),
    );

/// Misma puerta que [openBusinessRegistrationFlow], para registrar una
/// fundación. `legal_identity_service.dart` y `023_legal_identities.sql` ya
/// hablaban de "negocio, fundación o jornada ECO" desde el diseño original —
/// esta conexión faltaba, no era una decisión de dejarla afuera.
///
/// Una jornada ECO **no** tiene su propia puerta: solo se puede crear a
/// nombre de una fundación ya elegida (`create_eco_activity_screen.dart`
/// exige seleccionarla antes de guardar), y esa fundación ya pasó por este
/// mismo gate al registrarse. Pedir RUC/cédula otra vez en cada jornada sería
/// repetir una verificación que ya ocurrió — sí pasa por su propia cola de
/// revisión (pendiente/aprobada/rechazada), solo no por este gate.
Future<void> openOrganizationRegistrationFlow(BuildContext context) =>
    _openLegalIdentityGatedFlow(
      context,
      destination: (_) => const CreateOrganizationScreen(),
    );

Future<void> _openLegalIdentityGatedFlow(
  BuildContext context, {
  required WidgetBuilder destination,
}) async {
  LegalIdentityModel? identity;
  try {
    identity = await LegalIdentityService().getMine();
  } on LegalIdentityServiceException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.message)));
    return;
  }
  if (!context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => identity == null
          ? LegalIdentityGateScreen(destination: destination)
          : Builder(builder: destination),
    ),
  );
}

/// Pantalla previa a cualquiera de los tres wizards de registro (Fase C,
/// 2026-08-27): persona jurídica o natural, RUC/cédula validado, y foto(s)
/// del documento. Se carga **una sola vez por cuenta** — `legal_identities`
/// tiene `unique(user_id)` — y sirve para cualquier negocio, fundación o
/// jornada ECO que esa cuenta registre después, no solo el que disparó el
/// gate esta vez.
class LegalIdentityGateScreen extends StatefulWidget {
  const LegalIdentityGateScreen({super.key, required this.destination});

  /// A qué wizard pasar una vez guardada la identidad.
  final WidgetBuilder destination;

  @override
  State<LegalIdentityGateScreen> createState() =>
      _LegalIdentityGateScreenState();
}

class _LegalIdentityGateScreenState extends State<LegalIdentityGateScreen> {
  final _service = LegalIdentityService();
  final _documentController = TextEditingController();

  LegalIdentityKind? _kind;
  // Solo aplica dentro de persona natural: con cédula (formato con guiones,
  // dos fotos) o sin ella (número especial de la DGI que empieza con `N`,
  // igual de estructura que el RUC — una sola foto). Default `true` porque
  // es el caso más común.
  bool _hasCedula = true;
  XFile? _frontPhoto;
  XFile? _backPhoto;
  bool _isSaving = false;
  String? _documentError;

  bool get _isNatural => _kind == LegalIdentityKind.natural;
  bool get _requiresBackPhoto => _isNatural && _hasCedula;

  bool get _canSubmit =>
      _kind != null &&
      _documentController.text.trim().isNotEmpty &&
      _frontPhoto != null &&
      (!_requiresBackPhoto || _backPhoto != null);

  @override
  void dispose() {
    _documentController.dispose();
    super.dispose();
  }

  void _selectKind(LegalIdentityKind kind) {
    setState(() {
      _kind = kind;
      _hasCedula = true;
      _documentError = null;
      _documentController.clear();
      // Cambiar de tipo invalida el reverso: solo la cédula lo pide.
      if (kind == LegalIdentityKind.juridica) _backPhoto = null;
    });
  }

  void _toggleHasCedula(bool hasCedula) {
    setState(() {
      _hasCedula = hasCedula;
      _documentError = null;
      // El formato cambia por completo (guiones sí/no) — un número a medio
      // escribir en el otro formato no sirve de nada.
      _documentController.clear();
      if (!hasCedula) _backPhoto = null;
    });
  }

  Future<void> _pickPhoto({required bool back}) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked == null || !mounted) return;
    setState(() {
      if (back) {
        _backPhoto = picked;
      } else {
        _frontPhoto = picked;
      }
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_isSaving || !_canSubmit) return;
    final kind = _kind!;
    final normalized = sanitizeLegalDocumentNumber(_documentController.text);
    final pattern = switch ((kind, _hasCedula)) {
      (LegalIdentityKind.juridica, _) => rucPattern,
      (LegalIdentityKind.natural, true) => cedulaPattern,
      (LegalIdentityKind.natural, false) => cedulaSinDocumentoPattern,
    };
    if (!pattern.hasMatch(normalized)) {
      setState(() {
        _documentError = switch ((kind, _hasCedula)) {
          (LegalIdentityKind.juridica, _) =>
            'El RUC debe ser la letra J seguida de 13 dígitos.',
          (LegalIdentityKind.natural, true) =>
            'La cédula debe tener el formato 001-201208-1009S.',
          (LegalIdentityKind.natural, false) =>
            'Debe ser la letra N seguida de 13 dígitos.',
        };
      });
      return;
    }

    setState(() {
      _documentError = null;
      _isSaving = true;
    });
    try {
      final frontPath = await _service.uploadDocumentPhoto(_frontPhoto!);
      final backPhoto = _backPhoto;
      final backPath = backPhoto == null
          ? null
          : await _service.uploadDocumentPhoto(backPhoto);
      await _service.save(
        kind: kind,
        documentNumber: normalized,
        documentPhotoUrl: frontPath,
        documentPhotoBackUrl: backPath,
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: widget.destination));
    } on LegalIdentityServiceException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.settingsBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Row(
                children: [
                  CircleBackButton(onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Identidad legal',
                      style: AppTextStyles.wizardAppBarTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Antes de continuar',
                            style: AppTextStyles.wizardStepHeading,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Níkara pide un documento oficial para poder '
                            'asociar la responsabilidad legal de cada '
                            'negocio o fundación que registres — se carga '
                            'una sola vez y se guarda de forma confidencial.',
                            style: AppTextStyles.wizardStepSubtitle,
                          ),
                        ],
                      ),
                    ),
                    _card(
                      children: [
                        Text(
                          '¿CÓMO ESTÁS CONSTITUIDO LEGALMENTE?',
                          style: AppTextStyles.wizardFieldLabel,
                        ),
                        const SizedBox(height: 10),
                        _KindOption(
                          title: 'Persona jurídica',
                          subtitle: 'Empresa constituida o fundación, con RUC.',
                          selected: _kind == LegalIdentityKind.juridica,
                          onTap: () => _selectKind(LegalIdentityKind.juridica),
                        ),
                        const SizedBox(height: 8),
                        _KindOption(
                          title: 'Persona natural',
                          subtitle:
                              'Emprendimiento local o coordinador de '
                              'actividades, con cédula.',
                          selected: _kind == LegalIdentityKind.natural,
                          onTap: () => _selectKind(LegalIdentityKind.natural),
                        ),
                      ],
                    ),
                    if (_kind case final kind?) ...[
                      if (_isNatural)
                        _card(
                          children: [
                            Text(
                              '¿TENÉS CÉDULA?',
                              style: AppTextStyles.wizardFieldLabel,
                            ),
                            const SizedBox(height: 10),
                            _KindOption(
                              title: 'Sí, tengo cédula',
                              subtitle: 'Formato 001-201208-1009S.',
                              selected: _hasCedula,
                              onTap: () => _toggleHasCedula(true),
                            ),
                            const SizedBox(height: 8),
                            _KindOption(
                              title: 'No tengo cédula',
                              subtitle:
                                  'Número especial de la DGI, empieza con '
                                  'la letra N.',
                              selected: !_hasCedula,
                              onTap: () => _toggleHasCedula(false),
                            ),
                          ],
                        ),
                      _card(
                        children: [
                          Text(
                            (kind == LegalIdentityKind.juridica || _hasCedula
                                    ? kind.documentLabel
                                    : 'Número sin cédula')
                                .toUpperCase(),
                            style: AppTextStyles.wizardFieldLabel,
                          ),
                          const SizedBox(height: 7),
                          TextField(
                            controller: _documentController,
                            style: AppTextStyles.wizardFieldValue,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters:
                                kind == LegalIdentityKind.natural && _hasCedula
                                ? const [CedulaInputFormatter()]
                                : [
                                    FilteringTextInputFormatter.allow(
                                      RegExp('[A-Za-z0-9]'),
                                    ),
                                    LengthLimitingTextInputFormatter(14),
                                    const UppercaseTextInputFormatter(),
                                  ],
                            onChanged: (_) {
                              if (_documentError != null) {
                                setState(() => _documentError = null);
                              }
                            },
                            decoration: InputDecoration(
                              hintText: switch ((kind, _hasCedula)) {
                                (LegalIdentityKind.juridica, _) =>
                                  'J0123456789012',
                                (LegalIdentityKind.natural, true) =>
                                  '001-201208-1009S',
                                (LegalIdentityKind.natural, false) =>
                                  'N0000000000019',
                              },
                              hintStyle: AppTextStyles.wizardFieldHint,
                              filled: true,
                              fillColor: AppColors.settingsBackground,
                              errorText: _documentError,
                              contentPadding: const EdgeInsets.all(14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: AppColors.settingsTextDark.withValues(
                                    alpha: 0.07,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(switch ((kind, _hasCedula)) {
                            (LegalIdentityKind.juridica, _) =>
                              'Letra J seguida de 13 dígitos.',
                            (LegalIdentityKind.natural, true) =>
                              'Departamento (3) - fecha de nacimiento (6) '
                                  '- control (4) y una letra.',
                            (LegalIdentityKind.natural, false) =>
                              'Letra N seguida de 13 dígitos.',
                          }, style: AppTextStyles.wizardCaption),
                        ],
                      ),
                      _card(
                        children: [
                          Text(
                            'FOTO DEL DOCUMENTO',
                            style: AppTextStyles.wizardFieldLabel,
                          ),
                          const SizedBox(height: 3),
                          Text(switch ((kind, _hasCedula)) {
                            (LegalIdentityKind.juridica, _) =>
                              'El documento de RUC o el código QR de '
                                  'validación de la DGI.',
                            (LegalIdentityKind.natural, true) =>
                              'La cédula física, clara y legible.',
                            (LegalIdentityKind.natural, false) =>
                              'El documento que respalda tu número '
                                  'especial de la DGI.',
                          }, style: AppTextStyles.wizardCaption),
                          const SizedBox(height: 10),
                          _DocumentPhotoTile(
                            label: _requiresBackPhoto ? 'Frente' : 'Documento',
                            photo: _frontPhoto,
                            onTap: () => _pickPhoto(back: false),
                          ),
                          if (_requiresBackPhoto) ...[
                            const SizedBox(height: 8),
                            _DocumentPhotoTile(
                              label: 'Reverso',
                              photo: _backPhoto,
                              onTap: () => _pickPhoto(back: true),
                            ),
                          ],
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              size: 14,
                              color: AppColors.oliveText,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Esta información se mantiene confidencial y '
                                'solo la ve el equipo de Níkara al revisar tu '
                                'solicitud.',
                                style: AppTextStyles.wizardCaption,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: !_canSubmit || _isSaving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      foregroundColor: AppColors.settingsTextDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: AppColors.settingsTextDark,
                            ),
                          )
                        : const Text('Continuar'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        border: Border.all(color: AppColors.mapControlBorder),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: AppColors.detailCardGlow,
            offset: Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _KindOption extends StatelessWidget {
  const _KindOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary500.withValues(alpha: 0.12)
          : AppColors.settingsBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primary500
                  : AppColors.settingsTextDark.withValues(alpha: 0.07),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected
                    ? AppColors.primary500
                    : AppColors.settingsTextMuted,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.wizardCardTitle),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.wizardCaption),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentPhotoTile extends StatelessWidget {
  const _DocumentPhotoTile({
    required this.label,
    required this.photo,
    required this.onTap,
  });

  final String label;
  final XFile? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.wizardUploadZoneBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: photo == null
                ? AppColors.primary500.withValues(alpha: 0.6)
                : AppColors.mapControlBorder,
            width: photo == null ? 1.5 : 1,
          ),
        ),
        margin: const EdgeInsets.only(bottom: 4),
        clipBehavior: Clip.antiAlias,
        child: photo == null
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.primary500,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tomar foto — $label',
                    style: AppTextStyles.wizardCardTitle,
                  ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  LocalImage(path: photo.path),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.detailCoverCounterBg,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        label,
                        style: AppTextStyles.homeMiniBadge.copyWith(
                          color: AppColors.surface100,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
