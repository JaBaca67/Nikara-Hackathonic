import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/models/user_origin.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/shared/widgets/app_snackbar.dart';
import 'package:nikara_app/shared/widgets/origin_badge.dart';
import 'package:nikara_app/shared/widgets/origin_form_fields.dart';
import 'package:nikara_app/shared/widgets/user_avatar.dart';
import 'package:nikara_app/theme/app_theme.dart';

class EditPublicProfileScreen extends StatefulWidget {
  const EditPublicProfileScreen({super.key, required this.profile});
  final UserModel profile;
  @override
  State<EditPublicProfileScreen> createState() =>
      _EditPublicProfileScreenState();
}

class _EditPublicProfileScreenState extends State<EditPublicProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.profile.publicDisplayName,
  );
  late final _bio = TextEditingController(text: widget.profile.bio);
  late UserOrigin _origin = widget.profile.origin;
  late bool _showOrigin = widget.profile.showOrigin;
  late bool _showDetails = widget.profile.showOriginDetails;
  late String? _avatar = widget.profile.avatarUrl;
  bool _saving = false;
  bool _savingAvatar = false;
  bool get _busy => _saving || _savingAvatar;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;
      setState(() => _savingAvatar = true);
      final url = await AuthService().updateAvatar(image);
      if (mounted) setState(() => _avatar = url);
    } catch (_) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'No se pudo cambiar la foto. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _savingAvatar = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AuthService().updatePublicProfile(
        origin: _origin,
        publicDisplayName: _name.text,
        bio: _bio.text,
        showOrigin: _showOrigin,
        showOriginDetails: _showDetails,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on AuthServiceException catch (e) {
      if (mounted) AppSnackbar.showError(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _name.text.trim().isEmpty
        ? widget.profile.fullName
        : _name.text.trim();
    final displayInitials = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();
    final visibleOrigin = !_showOrigin
        ? const UserOrigin()
        : UserOrigin(
            residenceType: _origin.residenceType,
            countryCode: _origin.countryCode,
            city: _showDetails ? _origin.city : '',
            municipality: _showDetails ? _origin.municipality : '',
          );
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Editar perfil público')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface100,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        UserAvatar(
                          avatarUrl: _avatar,
                          initials: displayInitials.isEmpty
                              ? '?'
                              : displayInitials,
                          size: 88,
                          foreground: AppColors.neutral1100,
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.neutral1100,
                          ),
                          onPressed: _busy ? null : _changePhoto,
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: Text(
                            _savingAvatar ? 'Subiendo foto…' : 'Cambiar foto',
                          ),
                        ),
                        Text(
                          _name.text.trim().isEmpty
                              ? widget.profile.fullName
                              : _name.text.trim(),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.sectionTitle,
                        ),
                        if (_bio.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _bio.text.trim(),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.neutral800,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        OriginBadge(origin: visibleOrigin),
                        const SizedBox(height: 8),
                        Text(
                          'Así te verán al comentar o unirte a actividades',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 12,
                            color: AppColors.neutral800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _name,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.neutral800,
                    ),
                    enabled: !_busy,
                    maxLength: 80,
                    decoration: InputDecoration(
                      labelText: 'Nombre público',
                      hintText: widget.profile.fullName,
                      helperText:
                          'Si lo dejas vacío, se mostrará tu nombre de registro.',
                      helperMaxLines: 2,
                      helperStyle: AppTextStyles.body.copyWith(
                        fontSize: 12,
                        color: AppColors.neutral800,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bio,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.neutral800,
                    ),
                    enabled: !_busy,
                    maxLength: 300,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Sobre mí',
                      hintText:
                          'Comparte tus intereses y lo que te gusta explorar',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 24),
                  OriginFormFields(
                    initialValue: _origin,
                    onChanged: (value) => setState(() => _origin = value),
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mostrar mi procedencia'),
                    subtitle: Text(
                      'Bandera y país en tu perfil, reseñas y actividades.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.neutral800,
                      ),
                    ),
                    value: _showOrigin,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _showOrigin = v),
                  ),
                  if (_origin.isNicaraguan)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mostrar ciudad y municipio'),
                      value: _showDetails,
                      onChanged: _busy || !_showOrigin
                          ? null
                          : (v) => setState(() => _showDetails = v),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.goldFill,
                      foregroundColor: AppColors.neutral1100,
                    ),
                    onPressed: _busy ? null : _save,
                    child: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
