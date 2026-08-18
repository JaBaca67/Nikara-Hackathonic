import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// 3-segment progress bar + "Paso X de 3 · {label}" caption for the
/// registration wizard (Identidad → Perfil → Verificación) — per the
/// Claude Design canvas "Nikara Inicio y Mapa" (turn 10, "Registro en 3
/// pasos"). Filled segments use [AppColors.coral500]; unreached ones sit at
/// low alpha instead of a separate flat color.
class StepProgressIndicator extends StatelessWidget {
  const StepProgressIndicator({
    super.key,
    required this.step,
    required this.labels,
  });

  /// 0-based current step index.
  final int step;

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i != 0) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= step
                        ? AppColors.coral500
                        : AppColors.coral500.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Paso ${step + 1} de ${labels.length} · ${labels[step]}',
          style: AppTextStyles.authStepCaption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
