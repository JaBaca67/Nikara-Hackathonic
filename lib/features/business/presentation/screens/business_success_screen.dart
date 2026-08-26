import 'package:flutter/material.dart';

import 'package:nikara_app/shared/widgets/main_layout.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Beat celebratorio tras **enviar** un negocio a revisión, antes de volver a
/// Home.
///
/// Ya no dice "está en vivo": desde `019_review_status.sql` el negocio nace en
/// `pendiente` y no aparece en ningún listado público hasta que un admin o
/// auditor lo aprueba. No lleva parámetro para distinguir "publicado" de "en
/// revisión" porque no hace falta: el único camino que llega acá es la
/// creación desde el wizard (editar hace `pop`, no navega), y una creación
/// siempre queda pendiente.
class BusinessSuccessScreen extends StatefulWidget {
  const BusinessSuccessScreen({super.key, required this.businessName});

  final String businessName;

  @override
  State<BusinessSuccessScreen> createState() => _BusinessSuccessScreenState();
}

class _BusinessSuccessScreenState extends State<BusinessSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _checkScale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _checkScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.15,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
    ]).animate(_controller);
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainLayout()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.surface100,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _checkScale,
                  child: Container(
                    width: 120,
                    height: 120,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary500,
                          AppColors.successBadgeGradientEnd,
                        ],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.successBadgeGlow,
                          offset: Offset(0, 12),
                          blurRadius: 32,
                        ),
                      ],
                    ),
                    // Reloj y no check: el check afirmaba que el negocio ya
                    // estaba publicado, que es justo lo que dejó de ser cierto.
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      size: 64,
                      color: AppColors.textInk,
                      semanticLabel: 'Solicitud en revisión',
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                FadeTransition(
                  opacity: _fade,
                  child: Column(
                    children: [
                      Text(
                        '¡Tu solicitud fue enviada!',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h4.copyWith(
                          color: AppColors.textInk,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'La revisamos en un máximo de 24 horas y te avisamos '
                        'cuando quede visible para la comunidad de Níkara',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyText2.copyWith(
                          color: AppColors.neutral600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.businessName,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subtitle1.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                FadeTransition(
                  opacity: _fade,
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _goToHome,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary500,
                        foregroundColor: AppColors.textInk,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: Text(
                        'Ir al Inicio',
                        style: AppTextStyles.buttonLg,
                      ),
                    ),
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
