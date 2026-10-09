import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:nikara_app/features/profile/presentation/screens/explorer_plans_screen.dart';
import 'package:nikara_app/shared/widgets/app_page_transition.dart';
import 'package:nikara_app/theme/app_motion.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Anuncio de prueba: primera visita y luego cada tres entradas al perfil.
/// El conteo vive en esta sesión; no modifica la cuenta ni usa el backend.
class ExplorerAnnouncementBanner extends StatefulWidget {
  const ExplorerAnnouncementBanner({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<ExplorerAnnouncementBanner> createState() =>
      _ExplorerAnnouncementBannerState();
}

class _ExplorerAnnouncementBannerState extends State<ExplorerAnnouncementBanner>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _reflection;
  int _visits = 0;
  bool _visible = false;
  bool _pressed = false;
  bool _hovered = false;
  bool _reducedMotion = true;
  bool _routeVisible = false;
  bool _tickersEnabled = true;
  bool _appActive = true;
  bool _openingPlans = false;

  @override
  void initState() {
    super.initState();
    // Firma del anuncio: una pasada de luz y una pausa, en un ciclo de 6.4 s.
    _reflection = AnimationController(
      vsync: this,
      duration: AppMotion.largeDuration * 20,
    );
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appActive = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    if (widget.isActive) _recordVisit();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = AppMotion.reduced(context);
    _routeVisible = ModalRoute.of(context)?.isCurrent ?? true;
    _tickersEnabled = TickerMode.valuesOf(context).enabled;
    _syncReflection();
  }

  @override
  void didUpdateWidget(covariant ExplorerAnnouncementBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _recordVisit();
    _syncReflection();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _syncReflection();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reflection.dispose();
    super.dispose();
  }

  void _recordVisit() {
    _visits++;
    _visible = (_visits - 1) % 3 == 0;
    _pressed = false;
    _hovered = false;
  }

  void _syncReflection() {
    final shouldAnimate =
        _visible &&
        widget.isActive &&
        !_reducedMotion &&
        _routeVisible &&
        _tickersEnabled &&
        _appActive;
    if (shouldAnimate) {
      if (!_reflection.isAnimating) _reflection.repeat();
    } else {
      _reflection.stop();
      if (_reducedMotion) _reflection.value = 0;
    }
  }

  void _close() {
    setState(() {
      _visible = false;
      _pressed = false;
    });
    _syncReflection();
  }

  Future<void> _openPlans() async {
    if (_openingPlans) return;
    _openingPlans = true;
    try {
      await pushSharedAxis(context, const ExplorerPlansScreen());
    } finally {
      _openingPlans = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.respect(context, AppMotion.quickDuration);
    final content = !widget.isActive || !_visible
        ? const SizedBox.shrink()
        : TweenAnimationBuilder<double>(
            key: ValueKey(_visits),
            tween: Tween(begin: _reducedMotion ? 1 : 0, end: 1),
            duration: AppMotion.respect(context, AppMotion.largeDuration),
            curve: AppMotion.decelerate,
            builder: (context, progress, child) => Opacity(
              opacity: progress,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - progress)),
                child: child,
              ),
            ),
            child: AnimatedScale(
              scale: _pressed ? 0.985 : 1,
              duration: duration,
              curve: AppMotion.emphasized,
              child: _buildCard(context, duration),
            ),
          );
    if (_reducedMotion) return content;
    return AnimatedSize(
      duration: duration,
      curve: AppMotion.emphasized,
      alignment: Alignment.topCenter,
      child: content,
    );
  }

  Widget _buildCard(BuildContext context, Duration duration) {
    final engaged = _pressed || _hovered;
    final title = Text(
      'Níkara Explorador',
      style: AppTextStyles.sectionTitle.copyWith(fontSize: 16, height: 1.15),
    );
    final expandedText = MediaQuery.textScalerOf(context).scale(14) > 21;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: AnimatedContainer(
        duration: duration,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: AppColors.goldFill.withValues(
                alpha: engaged ? 0.28 : 0.16,
              ),
              blurRadius: engaged ? 24 : 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.goldFill.withValues(alpha: 0.9),
                        Color.lerp(
                          AppColors.goldFill,
                          AppColors.textPrimary,
                          0.055,
                        )!.withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                  child: const CustomPaint(painter: _GoldTexturePainter()),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _GoldReflectionPainter(_reflection),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  side: BorderSide(
                    color: AppColors.surface.withValues(alpha: 0.4),
                  ),
                ),
                child: InkWell(
                  onTap: _openPlans,
                  onTapDown: (_) => setState(() => _pressed = true),
                  onTapUp: (_) => setState(() => _pressed = false),
                  onTapCancel: () => setState(() => _pressed = false),
                  onHover: (value) => setState(() => _hovered = value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.14,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.workspace_premium_outlined,
                                color: AppColors.textPrimary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: expandedText ? const SizedBox() : title,
                            ),
                            IconButton(
                              tooltip: 'Cerrar anuncio',
                              onPressed: _close,
                              constraints: const BoxConstraints.tightFor(
                                width: 32,
                                height: 32,
                              ),
                              icon: const Icon(Icons.close, size: 18),
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ],
                        ),
                        if (expandedText) ...[
                          const SizedBox(height: AppSpacing.md),
                          title,
                        ],
                        const SizedBox(height: AppSpacing.xs),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final price = Text(
                              r'US$2.50 al mes',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                            final button = FilledButton(
                              onPressed: _openPlans,
                              style: FilledButton.styleFrom(
                                backgroundColor: Color.alphaBlend(
                                  AppColors.surface.withValues(
                                    alpha: engaged ? 0.38 : 0.24,
                                  ),
                                  AppColors.goldFill,
                                ),
                                foregroundColor: AppColors.textPrimary,
                                textStyle: AppTextStyles.buttonMd.copyWith(
                                  fontSize: 13,
                                ),
                                minimumSize: const Size(0, 36),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text('Unirme'),
                            );
                            if (expandedText || constraints.maxWidth < 260) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  price,
                                  const SizedBox(height: AppSpacing.md),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: button,
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: price),
                                const SizedBox(width: AppSpacing.sm),
                                button,
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Textura discreta y estática: se repinta solo si cambia el tamaño del banner.
class _GoldTexturePainter extends CustomPainter {
  const _GoldTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(23);
    final paint = Paint()..color = AppColors.surface.withValues(alpha: 0.05);
    for (var index = 0; index < 420; index++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        0.5 + random.nextDouble() * 2,
        paint,
      );
    }
    final rect = Offset.zero & size;
    paint.color = AppColors.surface;
    paint.shader = RadialGradient(
      center: Alignment.bottomLeft,
      radius: 1.2,
      colors: [
        AppColors.surface.withValues(alpha: 0.13),
        AppColors.surface.withValues(alpha: 0),
      ],
    ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _GoldTexturePainter oldDelegate) => false;
}

/// Un reflejo diagonal recorre el fondo, seguido de una pausa más larga.
/// Repaint directo del lienzo: no reconstruye los textos en cada frame.
class _GoldReflectionPainter extends CustomPainter {
  _GoldReflectionPainter(this.animation) : super(repaint: animation);
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value / 0.35;
    if (progress <= 0 || progress >= 1) return;
    final opacity = math.sin(math.pi * progress) * 0.65;
    final bandWidth = size.width * 0.46;
    final x = -size.height + (size.width + size.height * 2) * progress;
    final rect = Rect.fromLTWH(
      -bandWidth / 2,
      -size.height * 2,
      bandWidth,
      size.height * 4,
    );
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.surface.withValues(alpha: 0),
          AppColors.surface.withValues(alpha: opacity * 0.5),
          AppColors.surface.withValues(alpha: opacity),
          AppColors.surface.withValues(alpha: opacity * 0.5),
          AppColors.surface.withValues(alpha: 0),
        ],
        stops: const [0, 0.35, 0.5, 0.65, 1],
      ).createShader(rect);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(x, size.height / 2);
    canvas.rotate(-0.35);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GoldReflectionPainter oldDelegate) =>
      oldDelegate.animation != animation;
}
