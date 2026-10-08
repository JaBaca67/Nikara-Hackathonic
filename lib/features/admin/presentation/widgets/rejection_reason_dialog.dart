import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Las causales de rechazo que ofrece el panel.
///
/// La lista vive **solo en la UI**: `rejection_reason` sigue siendo `text`
/// libre en Postgres, así que agregar o cambiar una causal no necesita
/// migración. Lo que viaja al RPC es la etiqueta elegida tal cual, o el texto
/// que el revisor escribió si eligió [otro].
///
/// Fase 2 va a sumar acá las causales de identidad legal (RUC o cédula
/// inválidos, documento faltante) sin tocar nada más.
enum RejectionReason {
  giroIncompatible(
    'No corresponde al propósito turístico/ecológico de la app '
    '(giro incompatible)',
  ),
  fueraDeZona('Ubicación fuera de zona de interés turístico'),
  informacionIncompleta(
    'Información incompleta o poco clara (descripción, fotos, contacto)',
  ),
  contenidoInapropiado(
    'Contenido inapropiado o no alineado a los valores de la marca',
  ),
  otro('Otro');

  const RejectionReason(this.label);

  final String label;
}

/// Diálogo de "Rechazar": causal de una lista cerrada, más un campo obligatorio
/// si la causal es [RejectionReason.otro].
///
/// Devuelve por `Navigator.pop` el string que se guarda en `rejection_reason`
/// (y que el dueño va a leer en su notificación y en su perfil), o `null` si se
/// canceló. Motivo libre desde el principio se descartó a propósito: obliga al
/// revisor a redactar en cada rechazo y produce mensajes desparejos para la
/// misma situación.
Future<String?> showRejectionReasonDialog(
  BuildContext context, {
  required String subjectName,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _RejectionReasonDialog(subjectName: subjectName),
  );
}

class _RejectionReasonDialog extends StatefulWidget {
  const _RejectionReasonDialog({required this.subjectName});

  final String subjectName;

  @override
  State<_RejectionReasonDialog> createState() => _RejectionReasonDialogState();
}

class _RejectionReasonDialogState extends State<_RejectionReasonDialog> {
  RejectionReason? _selected;
  final _otherController = TextEditingController();

  /// Se muestra recién al intentar confirmar, no mientras escribe: marcar en
  /// rojo un campo que todavía no se tocó es ruido.
  bool _showOtherError = false;

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  bool get _needsFreeText => _selected == RejectionReason.otro;

  void _confirm() {
    final selected = _selected;
    if (selected == null) return;
    if (selected == RejectionReason.otro) {
      final text = _otherController.text.trim();
      if (text.isEmpty) {
        setState(() => _showOtherError = true);
        return;
      }
      Navigator.of(context).pop(text);
      return;
    }
    Navigator.of(context).pop(selected.label);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      title: Text(
        'Motivo del rechazo',
        style: AppTextStyles.settingsTitle.copyWith(
          fontSize: 18,
          color: AppColors.textPrimary,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se lo vamos a mostrar tal cual al dueño de '
                '"${widget.subjectName}" para que sepa qué corregir.',
                style: AppTextStyles.settingsSubtitle.copyWith(
                  color: AppColors.settingsTextMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final reason in RejectionReason.values)
                _ReasonOption(
                  reason: reason,
                  selected: _selected == reason,
                  onTap: () => setState(() => _selected = reason),
                ),
              if (_needsFreeText) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _otherController,
                  autofocus: true,
                  maxLines: 3,
                  maxLength: 300,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  onChanged: (_) {
                    if (_showOtherError) {
                      setState(() => _showOtherError = false);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Explica qué tiene que corregir',
                    hintStyle: AppTextStyles.body.copyWith(
                      color: AppColors.settingsTextMuted,
                    ),
                    errorText: _showOtherError
                        ? 'Escribe el motivo para poder rechazar.'
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancelar',
            style: AppTextStyles.settingsRowValue.copyWith(
              color: AppColors.settingsTextMuted,
            ),
          ),
        ),
        TextButton(
          // Sin causal elegida el botón queda inerte en vez de esconderse: así
          // se ve que rechazar es posible y qué falta para poder hacerlo.
          onPressed: _selected == null ? null : _confirm,
          child: Text(
            'Rechazar',
            style: AppTextStyles.settingsRowTitle.copyWith(
              color: _selected == null
                  ? AppColors.settingsTextMuted
                  : AppColors.destructive,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReasonOption extends StatelessWidget {
  const _ReasonOption({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final RejectionReason reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected
                  ? AppColors.destructive
                  : AppColors.settingsTextMuted,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                reason.label,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
