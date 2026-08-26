import 'package:flutter/material.dart';

import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/permission_service.dart';
import 'package:nikara_app/features/admin/data/admin_service.dart';
import 'package:nikara_app/features/admin/domain/models/admin_business_summary.dart';
import 'package:nikara_app/features/admin/presentation/widgets/admin_widgets.dart';
import 'package:nikara_app/features/admin/presentation/widgets/rejection_reason_dialog.dart';
import 'package:nikara_app/shared/widgets/circle_back_button.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Ficha de revisión de un negocio — tier **Funcional**, único acento Olive.
///
/// Muestra los datos reales de la fila de `businesses` (no el modelo fusionado
/// con el cache local del dueño, que en el dispositivo del auditor estaría
/// vacío) para que la decisión de verificar se tome mirando lo que realmente
/// hay cargado, incluidos los campos que faltan.
///
/// Dos ejes de decisión, deliberadamente separados: **aprobar/rechazar**
/// (`status`) decide si el negocio se publica y pasa por el RPC
/// `review_business`; el **sello** (`is_verified`) solo agrega la insignia
/// sobre un negocio ya publicado, así que aparece recién cuando está aprobado.
///
/// Devuelve `true` por `Navigator.pop` si cambió alguno de los dos, para que
/// la cola de origen se recargue.
class AdminBusinessDetailScreen extends StatefulWidget {
  const AdminBusinessDetailScreen({super.key, required this.business});

  final AdminBusinessSummary business;

  @override
  State<AdminBusinessDetailScreen> createState() =>
      _AdminBusinessDetailScreenState();
}

class _AdminBusinessDetailScreenState extends State<AdminBusinessDetailScreen> {
  final _service = AdminService();

  late AdminBusinessSummary _business = widget.business;
  bool _saving = false;
  bool _changed = false;

  Future<void> _approve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDialog(
        title: 'Aprobar negocio',
        message:
            'Al aprobarlo, "${_business.name}" queda publicado y visible '
            'para toda la comunidad. Le avisamos a su dueño. ¿Confirmas?',
        confirmLabel: 'Aprobar',
        confirmColor: AppColors.oliveText,
      ),
    );
    if (confirmed != true || !mounted) return;
    await _review(ReviewStatus.aprobado);
  }

  Future<void> _reject() async {
    // El motivo se pide antes de tocar la red: si el revisor cancela el
    // diálogo, no llegó a pasar nada que haya que deshacer.
    final reason = await showRejectionReasonDialog(
      context,
      subjectName: _business.name.isEmpty ? 'este negocio' : _business.name,
    );
    if (reason == null || !mounted) return;
    await _review(ReviewStatus.rechazado, reason: reason);
  }

  Future<void> _review(ReviewStatus status, {String? reason}) async {
    setState(() => _saving = true);
    try {
      final updated = await _service.reviewBusiness(
        id: _business.id,
        status: status,
        reason: reason,
      );
      if (!mounted) return;
      setState(() {
        _business = updated;
        _changed = true;
        _saving = false;
      });
      _showSnack(
        status.isAprobado
            ? '"${updated.name}" quedó publicado.'
            : 'Rechazaste "${updated.name}". Le avisamos a su dueño.',
      );
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack(e.message);
    } on PermissionDeniedException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack(e.message);
    }
  }

  Future<void> _toggleVerification() async {
    final target = !_business.isVerified;
    final confirmed = await _confirm(target);
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final updated = await _service.setBusinessVerified(
        id: _business.id,
        isVerified: target,
      );
      if (!mounted) return;
      setState(() {
        _business = updated;
        _changed = true;
        _saving = false;
      });
      _showSnack(
        target
            ? '"${updated.name}" ya muestra el sello.'
            : 'Le quitaste el sello a "${updated.name}".',
      );
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack(e.message);
    } on PermissionDeniedException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack(e.message);
    }
  }

  Future<bool?> _confirm(bool target) {
    return showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDialog(
        title: target ? 'Dar el sello' : 'Quitar el sello',
        message: target
            ? '"${_business.name}" va a mostrarse con el sello de verificado '
                  'en toda la app. No cambia si está publicado o no. '
                  '¿Confirmas?'
            : '"${_business.name}" deja de mostrar el sello de verificado, '
                  'pero sigue publicado. ¿Confirmas?',
        confirmLabel: target ? 'Dar el sello' : 'Quitar el sello',
        confirmColor: target ? AppColors.oliveText : AppColors.destructive,
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final canVerify = PermissionService().can(Permission.verifyBusiness);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _Header(
                title: 'Ficha de revisión',
                subtitle: _business.category.isEmpty
                    ? 'Sin categoría declarada'
                    : _business.category,
                onBack: () => Navigator.of(context).pop(_changed),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xxxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _business.name.isEmpty
                                  ? 'Sin nombre'
                                  : _business.name,
                              style: AppTextStyles.sectionTitle.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          AdminStatusPill(status: _business.reviewStatus),
                        ],
                      ),
                      if (_business.reviewStatus.isRechazado &&
                          (_business.rejectionReason ?? '').trim().isNotEmpty)
                        _RejectionNotice(
                          reason: _business.rejectionReason!.trim(),
                          reviewedAt: _business.reviewedAt,
                        ),
                      // El sello solo tiene sentido sobre algo ya publicado:
                      // ofrecerlo en un negocio pendiente invitaría a marcar
                      // como "verificado" algo que nadie ve todavía.
                      if (canVerify && _business.reviewStatus.isAprobado) ...[
                        const AdminSectionLabel(label: 'Sello de verificado'),
                        _SealRow(
                          isVerified: _business.isVerified,
                          enabled: !_saving,
                          onChanged: (_) => _toggleVerification(),
                        ),
                      ],
                      const AdminSectionLabel(label: 'Datos del registro'),
                      _DetailField(
                        label: 'Descripción',
                        value: _business.description,
                      ),
                      _DetailField(label: 'Ciudad', value: _business.city),
                      _DetailField(
                        label: 'Dirección',
                        value: _business.addressText,
                      ),
                      _DetailField(label: 'Teléfono', value: _business.phone),
                      _DetailField(
                        label: 'Horarios',
                        value: _business.schedules,
                      ),
                      _DetailField(
                        label: 'Instagram',
                        value: _business.instagramHandle.isEmpty
                            ? ''
                            : '@${_business.instagramHandle}',
                      ),
                      _DetailField(
                        label: 'Facebook',
                        value: _business.facebookHandle,
                      ),
                      _DetailField(
                        label: 'Fotos cargadas',
                        value: _business.photos.isEmpty
                            ? ''
                            : '${_business.photos.length}',
                      ),
                      const AdminSectionLabel(label: 'Responsable'),
                      _DetailField(
                        label: 'Dueño',
                        value: _business.ownerName,
                        fallback: 'Perfil no encontrado',
                      ),
                      _DetailField(
                        label: 'Correo',
                        value: _business.ownerEmail,
                        fallback: 'Sin correo',
                      ),
                      _DetailField(
                        label: 'Registrado el',
                        value: _business.createdAt == null
                            ? ''
                            : _formatDate(_business.createdAt!),
                      ),
                    ],
                  ),
                ),
              ),
              if (PermissionService().can(Permission.reviewSubmissions))
                _ActionBar(
                  status: _business.reviewStatus,
                  saving: _saving,
                  onApprove: _saving ? null : _approve,
                  onReject: _saving ? null : _reject,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}

/// Fila etiqueta/valor. Un campo vacío se muestra igual, en gris y con el
/// texto "Sin completar": para decidir una verificación importa tanto lo que
/// el emprendedor cargó como lo que dejó en blanco, así que esconder los
/// vacíos ocultaría justo la información que hace falta.
class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.label,
    required this.value,
    this.fallback = 'Sin completar',
  });

  final String label;
  final String value;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final filled = value.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.settingsRowCaption.copyWith(
              color: AppColors.settingsTextMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            filled ? value : fallback,
            style: AppTextStyles.body.copyWith(
              color: filled
                  ? AppColors.textPrimary
                  : AppColors.settingsTextMuted,
              fontStyle: filled ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Row(
        children: [
          CircleBackButton(onTap: onBack),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.settingsTitle.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.settingsSubtitle.copyWith(
                    color: AppColors.settingsTextMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Diálogo de confirmación del panel: mismo cuerpo para las tres decisiones
/// (aprobar, dar el sello, quitarlo) para que no se separen visualmente.
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text(
        title,
        style: AppTextStyles.settingsTitle.copyWith(
          fontSize: 18,
          color: AppColors.textPrimary,
        ),
      ),
      content: Text(
        message,
        style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancelar',
            style: AppTextStyles.settingsRowValue.copyWith(
              color: AppColors.settingsTextMuted,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmLabel,
            style: AppTextStyles.settingsRowTitle.copyWith(color: confirmColor),
          ),
        ),
      ],
    );
  }
}

/// Motivo con el que ya se rechazó este negocio, tal cual lo lee su dueño.
///
/// Se muestra dentro de la ficha y no solo en la cola: al reabrir un rechazo
/// hay que poder ver qué se le pidió, para no contradecirse si se vuelve a
/// revisar.
class _RejectionNotice extends StatelessWidget {
  const _RejectionNotice({required this.reason, this.reviewedAt});

  final String reason;
  final DateTime? reviewedAt;

  @override
  Widget build(BuildContext context) {
    final date = reviewedAt;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            date == null
                ? 'Motivo del rechazo'
                : 'Motivo del rechazo · '
                      '${date.toLocal().day.toString().padLeft(2, '0')}/'
                      '${date.toLocal().month.toString().padLeft(2, '0')}/'
                      '${date.toLocal().year}',
            style: AppTextStyles.settingsRowCaption.copyWith(
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            reason,
            style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Fila del sello de verificado. Va como interruptor y no como botón de la
/// barra inferior porque es la acción secundaria: la decisión principal de
/// esta pantalla es publicar o no.
class _SealRow extends StatelessWidget {
  const _SealRow({
    required this.isVerified,
    required this.enabled,
    required this.onChanged,
  });

  final bool isVerified;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            isVerified
                ? 'Muestra el sello de verificado'
                : 'Sin sello de verificado',
            style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
          ),
        ),
        Switch(
          value: isVerified,
          onChanged: enabled ? onChanged : null,
          activeThumbColor: AppColors.oliveText,
        ),
      ],
    );
  }
}

/// Barra inferior con la decisión principal: publicar o no.
///
/// Aprobar usa [AppColors.oliveFill] (relleno de marca con texto oscuro
/// encima, el único acento del panel); rechazar no es un segundo Fill sino un
/// botón de contorno en [AppColors.destructive] — es una acción reversible
/// pero negativa, y el token de estado no cuenta como acento de marca.
///
/// Un negocio pendiente ofrece las dos salidas; uno ya resuelto ofrece solo la
/// contraria, que es lo único que queda por decidir.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.status,
    required this.saving,
    required this.onApprove,
    required this.onReject,
  });

  final ReviewStatus status;
  final bool saving;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final showApprove = !status.isAprobado;
    final showReject = !status.isRechazado;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            if (showReject)
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.destructive),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  child: saving
                      ? const AdminLoading()
                      : Text(
                          status.isAprobado ? 'Quitar de la app' : 'Rechazar',
                          style: AppTextStyles.buttonMd.copyWith(
                            color: AppColors.destructive,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            if (showReject && showApprove) const SizedBox(width: AppSpacing.md),
            if (showApprove)
              Expanded(
                child: ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.oliveFill,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  child: saving
                      ? const AdminLoading()
                      : Text(
                          'Aprobar',
                          style: AppTextStyles.buttonMd.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
