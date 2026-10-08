import 'package:flutter/material.dart';

import 'package:nikara_app/features/ai_assistant/presentation/widgets/nikara_butterfly.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

class AssistantWelcome extends StatelessWidget {
  const AssistantWelcome({
    super.key,
    required this.onQuickReply,
    required this.replies,
  });

  final void Function(String) onQuickReply;
  final List<String> replies;

  static const _ideas = [
    (Icons.near_me_outlined, 'Cerca de mí', 'Lugares por descubrir'),
    (Icons.route_outlined, 'Mi próxima ruta', 'Un plan a mi medida'),
    (Icons.eco_outlined, 'Naturaleza y ECO', 'Viajá con propósito'),
    (Icons.weekend_outlined, 'Una escapada', 'Ideas para el finde'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.surface),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.045),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.explore_outlined,
                          size: 16,
                          color: AppColors.settingsTextMuted,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            'DESCUBRÍ NICARAGUA',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.settingsTextMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: 144,
                      height: 128,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.goldFill.withValues(alpha: 0.24),
                                  AppColors.goldFill.withValues(alpha: 0.04),
                                ],
                              ),
                              border: Border.all(
                                color: AppColors.goldFill.withValues(
                                  alpha: 0.18,
                                ),
                              ),
                            ),
                          ),
                          // El dibujo ocupa un área descentrada dentro del
                          // lienzo SVG original (1024 × 1028).
                          Transform.translate(
                            offset: const Offset(4.6, -7.3),
                            child: const NikaraButterfly(size: 120),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Icon(
                                Icons.location_on_outlined,
                                size: 20,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '¿A dónde vamos hoy?',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.heading.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Contame qué te gustaría descubrir.\n'
                      'Armamos tu viaje por Nicaragua.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.settingsTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Empecemos con una idea',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final singleColumn =
                      constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(14) > 20;
                  final cardWidth = singleColumn
                      ? constraints.maxWidth
                      : (constraints.maxWidth - AppSpacing.md) / 2;
                  return Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      for (var i = 0; i < replies.length; i++)
                        SizedBox(
                          width: cardWidth,
                          child: _IdeaCard(
                            icon: _ideas[i % _ideas.length].$1,
                            title: _ideas[i % _ideas.length].$2,
                            subtitle: _ideas[i % _ideas.length].$3,
                            onTap: () => onQuickReply(replies[i]),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdeaCard extends StatelessWidget {
  const _IdeaCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.07)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, size: 22, color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.settingsTextMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
