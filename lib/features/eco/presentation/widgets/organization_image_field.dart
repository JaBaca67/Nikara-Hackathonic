import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:nikara_app/features/eco/data/organization_service.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_form_fields.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Estado de una imagen de fundación (logo o banner) mientras se edita el
/// formulario.
///
/// Distingue los tres casos que un `String?` no puede: conservar la que ya
/// está guardada, reemplazarla por una recién elegida, o quitarla. La subida a
/// Storage ocurre en [resolve], al guardar, para no dejar archivos huérfanos
/// si el usuario abandona el formulario.
class OrganizationImageSlot {
  OrganizationImageSlot({this.existingUrl});

  final String? existingUrl;
  XFile? _picked;
  bool _removed = false;

  /// Lo que se muestra: la recién elegida gana sobre la guardada.
  String? get previewPath {
    final picked = _picked;
    if (picked != null) return picked.path;
    return _removed ? null : existingUrl;
  }

  bool get hasImage => previewPath != null;

  void pick(XFile file) {
    _picked = file;
    _removed = false;
  }

  void clear() {
    _picked = null;
    // Descartar una recién elegida no debe borrar la que ya estaba guardada.
    if (existingUrl != null) _removed = true;
  }

  /// Sube la imagen nueva si la hay y devuelve qué mandar al servicio.
  Future<({String? url, bool clear})> resolve() async {
    final picked = _picked;
    if (picked != null) {
      return (
        url: await OrganizationService().uploadImage(picked),
        clear: false,
      );
    }
    return (url: null, clear: _removed);
  }
}

class OrganizationImageField extends StatelessWidget {
  const OrganizationImageField({
    super.key,
    required this.slot,
    required this.onChanged,
    required this.previewHeight,
    this.previewWidth,
    this.emptyHint = 'Aún sin imagen',
  });

  final OrganizationImageSlot slot;

  /// El slot es mutable: el padre hace `setState` para repintar la vista previa.
  final VoidCallback onChanged;

  final double previewHeight;
  final double? previewWidth;
  final String emptyHint;

  Future<void> _pick(BuildContext context) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    slot.pick(picked);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (slot.hasImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: previewHeight,
              width: previewWidth,
              child: LocalImage(path: slot.previewPath),
            ),
          )
        else
          Container(
            height: previewHeight,
            width: previewWidth,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.settingsBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.settingsTextDark.withValues(alpha: 0.07),
              ),
            ),
            child: Text(emptyHint, style: AppTextStyles.wizardCaption),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: EcoPickerButton(
                icon: slot.hasImage
                    ? Icons.autorenew_rounded
                    : Icons.image_outlined,
                label: slot.hasImage ? 'Cambiar' : 'Elegir imagen',
                isSet: slot.hasImage,
                onTap: () => _pick(context),
              ),
            ),
            if (slot.hasImage) ...[
              const SizedBox(width: 10),
              Expanded(
                child: EcoPickerButton(
                  icon: Icons.close_rounded,
                  label: 'Quitar',
                  onTap: () {
                    slot.clear();
                    onChanged();
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
