import 'package:flutter/material.dart';

import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/presentation/screens/business_detail_screen.dart';
import 'package:nikara_app/features/business/presentation/screens/register_business_wizard.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// "Editar negocio publicado" — Pantalla 4e. Reached from Profile's "Mis
/// negocios" instead of jumping straight into the wizard: shows real
/// publish/verification status, then deep-links each row into the
/// specific [RegisterBusinessWizard] step instead of re-walking all 4.
///
/// Deliberately does NOT show the wireframe's "Rendimiento del último mes"
/// (412 visitas / 58 mensajes / 31 guardados) — this app has no analytics
/// pipeline to back those numbers, and showing fabricated stats to a real
/// business owner would be actively misleading. "Pausar" is stubbed as
/// "Próximamente" for the same reason: pausing visibility needs a real
/// `is_active`-style column this project doesn't have yet, and a
/// device-local flag wouldn't actually hide the listing from anyone else.
class EditBusinessHubScreen extends StatefulWidget {
  const EditBusinessHubScreen({super.key, required this.business});

  final BusinessModel business;

  @override
  State<EditBusinessHubScreen> createState() => _EditBusinessHubScreenState();
}

class _EditBusinessHubScreenState extends State<EditBusinessHubScreen> {
  final _storageService = BusinessStorageService();
  late BusinessModel _business = widget.business;
  bool _changed = false;

  Future<void> _editSection(int step) async {
    final updated = await Navigator.of(context).push<BusinessModel>(
      MaterialPageRoute(
        builder: (_) => RegisterBusinessWizard(
          existingBusiness: _business,
          initialStep: step,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _business = updated;
      _changed = true;
    });
  }

  void _openPreview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BusinessDetailScreen(business: _business),
      ),
    );
  }

  void _comingSoon() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Próximamente')));
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Eliminar negocio?'),
        content: Text(
          'Se eliminará "${_business.name}" de forma permanente. Esta '
          'acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Eliminar',
              style: TextStyle(color: AppColors.settingsDanger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _storageService.deleteBusiness(_business.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final photos = _business.localImagePaths;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && result == null && _changed) {
          // Nothing to do — the pushed wizard already persisted every
          // change immediately; this just makes sure Navigator carries the
          // freshest copy back to Profile's list.
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.settingsBackground,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(
                        context,
                      ).pop(_changed ? _business : null),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.profileDivider,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: AppColors.settingsTextDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Editar negocio',
                            style: AppTextStyles.wizardAppBarTitle,
                          ),
                          Text(
                            '${_business.name} · ${_business.city}',
                            style: AppTextStyles.wizardCaption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface100,
                          border: Border.all(
                            color: AppColors.accent300.withValues(alpha: 0.28),
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent300.withValues(
                                alpha: 0.10,
                              ),
                              offset: const Offset(0, 2),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.detailActivityIconBg,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                _business.isVerified
                                    ? Icons.verified
                                    : Icons.verified_outlined,
                                size: 18,
                                color: AppColors.accent300,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _business.isVerified
                                        ? 'Publicado y verificado'
                                        : 'Publicado, en revisión',
                                    style: AppTextStyles.wizardCardTitle
                                        .copyWith(fontSize: 12.5),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Visible en Inicio, Mapa y búsquedas',
                                    style: AppTextStyles.wizardCaption,
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: _comingSoon,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.settingsBackground,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Pausar',
                                  style: AppTextStyles.detailPillAction,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Qué querés cambiar',
                              style: AppTextStyles.wizardCardTitle.copyWith(
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Entrá directo a la sección, sin repetir todo el registro.',
                              style: AppTextStyles.wizardStepSubtitle,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Column(
                          children: [
                            _EditRow(
                              icon: Icons.store,
                              title: 'Datos y contacto',
                              subtitle:
                                  'Nombre, categoría, descripción, WhatsApp, horarios',
                              onTap: () => _editSection(0),
                            ),
                            const SizedBox(height: 8),
                            _EditRow(
                              icon: Icons.location_on,
                              title: 'Ubicación y pin',
                              subtitle:
                                  'Cambiarlo envía el negocio a nueva revisión',
                              badge: 'REVISIÓN',
                              onTap: () => _editSection(1),
                            ),
                            const SizedBox(height: 8),
                            _EditRow(
                              icon: Icons.photo_library,
                              title: 'Galería',
                              subtitle: photos.length >= 5
                                  ? '${photos.length} fotos'
                                  : '${photos.length} ${photos.length == 1 ? 'foto' : 'fotos'} · '
                                        'agregá ${5 - photos.length} más para Destacados',
                              onTap: () => _editSection(2),
                            ),
                            const SizedBox(height: 8),
                            _EditRow(
                              icon: Icons.eco,
                              iconBg: AppColors.detailActivityIconBg,
                              iconColor: AppColors.accent300,
                              title: 'Sello ECO y actividades',
                              subtitle:
                                  '${_business.ecoSealRequested ? 'Sello activo' : 'Sin sello ECO'} · '
                                  '${_business.activities.length} actividades marcadas',
                              badge: 'REVISIÓN',
                              onTap: () => _editSection(2),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Center(
                          child: GestureDetector(
                            onTap: _confirmDelete,
                            child: Text(
                              'Eliminar este negocio',
                              style: AppTextStyles.detailInlineLink.copyWith(
                                color: AppColors.wizardDangerLink,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                decoration: const BoxDecoration(
                  color: AppColors.surface100,
                  border: Border(
                    top: BorderSide(color: AppColors.mapControlBorder),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowAmbient,
                      offset: Offset(0, -6),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _openPreview,
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: AppColors.settingsBackground,
                          border: Border.all(color: AppColors.mapControlBorder),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.visibility,
                              size: 17,
                              color: AppColors.settingsTextDark,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Vista previa',
                              style: AppTextStyles.detailBottomBarSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(
                          context,
                        ).pop(_changed ? _business : null),
                        child: Container(
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primary500,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.detailPrimaryButtonGlow,
                                offset: Offset(0, 4),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: Text(
                            'Listo',
                            style: AppTextStyles.detailBottomBarPrimary,
                          ),
                        ),
                      ),
                    ),
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

class _EditRow extends StatelessWidget {
  const _EditRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconBg = AppColors.settingsBackground,
    this.iconColor = AppColors.settingsTextMuted,
    this.badge,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface100,
          border: Border.all(color: AppColors.mapControlBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.wizardCardTitle.copyWith(
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: AppTextStyles.wizardCaption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.wizardReviewBadgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge!,
                  style: AppTextStyles.detailEcoBadge.copyWith(
                    color: AppColors.wizardReviewBadgeText,
                    fontSize: 9,
                  ),
                ),
              )
            else
              const Icon(Icons.chevron_right, color: AppColors.neutral400),
          ],
        ),
      ),
    );
  }
}
