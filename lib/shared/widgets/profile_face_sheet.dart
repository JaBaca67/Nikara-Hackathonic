import 'package:flutter/material.dart';

import 'package:nikara_app/core/models/profile_face.dart';
import 'package:nikara_app/core/services/profile_face_service.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Abre la lista de caras del login activo. Devuelve `true` si el usuario
/// cambió de cara, para que la pantalla que la abrió se recargue.
///
/// No cierra ni abre ninguna sesión: cambiar de cara es un cambio de identidad
/// **dentro del mismo login** (ver [ProfileFace]). El selector de cuentas
/// —logins distintos— sigue siendo `showAccountSwitcherSheet`, aparte.
Future<bool> showProfileFaceSheet(BuildContext context) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface100,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const ProfileFaceSheet(),
  );
  return changed ?? false;
}

/// Hoja inferior con las caras del login.
///
/// Está pensada para **lista larga**, no para dos o tres elementos: no hay
/// límite de caras por cuenta, así que la lista scrollea dentro de la hoja en
/// vez de estirarla hasta salirse de la pantalla.
class ProfileFaceSheet extends StatefulWidget {
  const ProfileFaceSheet({super.key});

  @override
  State<ProfileFaceSheet> createState() => _ProfileFaceSheetState();
}

class _ProfileFaceSheetState extends State<ProfileFaceSheet> {
  final _faceService = ProfileFaceService();

  bool _isLoading = true;
  List<ProfileFace> _faces = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // `force: true` a propósito: `ProfileFaceService.load()` cachea por
    // sesión, así que sin esto una fundación/negocio recién aprobado no
    // aparecería acá hasta cerrar sesión — justo el momento en que la
    // notificación de aprobación invita a abrir esta hoja.
    final faces = await _faceService.load(force: true);
    if (!mounted) return;
    setState(() {
      _faces = faces;
      _isLoading = false;
    });
  }

  void _select(ProfileFace face) {
    final changed = face.id != _faceService.activeFace?.id;
    _faceService.setActiveFace(face.id);
    Navigator.of(context).pop(changed);
  }

  @override
  Widget build(BuildContext context) {
    final activeId = _faceService.activeFace?.id;
    // La hoja no pasa de dos tercios de la pantalla: con muchas caras el resto
    // scrollea, y el usuario sigue viendo que hay una pantalla debajo.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.66;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surface200,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Tus perfiles',
                style: AppTextStyles.settingsTitle.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                'Cambiá de perfil sin cerrar sesión. Cada negocio o fundación '
                'aprobado suma el suyo.',
                style: AppTextStyles.settingsSubtitle.copyWith(fontSize: 12.5),
              ),
              const SizedBox(height: 18),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _faces.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final face = _faces[index];
                      return _FaceTile(
                        face: face,
                        isActive: face.id == activeId,
                        onTap: () => _select(face),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaceTile extends StatelessWidget {
  const _FaceTile({
    required this.face,
    required this.isActive,
    required this.onTap,
  });

  final ProfileFace face;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? AppColors.warmChipBackground : AppColors.surface100,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive
                  ? AppColors.primary500
                  : AppColors.mapControlBorder,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              _FaceAvatar(face: face),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      face.name,
                      style: AppTextStyles.settingsRowTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    _KindPill(kind: face.kind, isActive: isActive),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isActive)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 22,
                  color: AppColors.statusSuccess,
                  semanticLabel: 'Perfil activo',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindPill extends StatelessWidget {
  const _KindPill({required this.kind, required this.isActive});

  final ProfileFaceKind kind;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? AppColors.surface100 : AppColors.detailActivityIconBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        isActive ? 'Perfil activo · ${kind.label}' : kind.label,
        style: AppTextStyles.settingsRowCaption.copyWith(
          fontSize: 10.5,
          color: isActive ? AppColors.settingsTextDark : AppColors.oliveText,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _FaceAvatar extends StatelessWidget {
  const _FaceAvatar({required this.face});

  final ProfileFace face;

  @override
  Widget build(BuildContext context) {
    final url = face.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 44,
        height: 44,
        child: url == null || url.isEmpty
            ? Container(
                color: AppColors.goldPaleFill,
                alignment: Alignment.center,
                child: Text(
                  face.initials,
                  style: AppTextStyles.settingsRowTitle.copyWith(
                    fontSize: 15,
                    color: AppColors.goldDeepText,
                  ),
                ),
              )
            : LocalImage(path: url, fallbackIcon: face.kind.icon),
      ),
    );
  }
}
