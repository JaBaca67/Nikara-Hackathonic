import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:nikara_app/theme/app_motion.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Presentación expresiva de membresías basada en Nikara_Landing_compacta.
/// Precios y beneficios informativos; no activa planes ni pagos.
class ExplorerPlansScreen extends StatefulWidget {
  const ExplorerPlansScreen({super.key});

  @override
  State<ExplorerPlansScreen> createState() => _ExplorerPlansScreenState();
}

class _ExplorerPlansScreenState extends State<ExplorerPlansScreen> {
  final _explorerKey = GlobalKey();
  int _explorerAnimationVersion = 0;

  Future<void> _scrollToExplorer() async {
    final target = _explorerKey.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      duration: AppMotion.respect(context, AppMotion.largeDuration),
      curve: AppMotion.emphasized,
    );
    if (mounted) setState(() => _explorerAnimationVersion++);
  }

  void _showComingSoon() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _Palette.paper,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(alignment: Alignment.center, child: _ExplorerLogo()),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Tu próxima aventura está cerca',
                style: _type(26, bold: true),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Estamos preparando Níkara Explorador. Por US\$2.50 '
                'o C\$93 al mes podrás disfrutar de todos sus beneficios '
                'cuando esté disponible.',
                style: _type(17),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: _primaryButton(),
                child: const Text('Entendido'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Palette.paper,
      appBar: AppBar(
        backgroundColor: _Palette.paper,
        foregroundColor: _Palette.ink,
        title: Text('Planes', style: _type(20, bold: true)),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_Palette.paper, AppColors.background],
                ),
              ),
              child: SvgPicture.asset(
                'assets/images/topography.svg',
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                colorFilter: ColorFilter.mode(
                  _Palette.ink.withValues(alpha: 0.04),
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Reveal(child: _PlansIntro(onExplore: _scrollToExplorer)),
                      const SizedBox(height: AppSpacing.xxl),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          const free = _Reveal(
                            index: 1,
                            child: _FreePlanCard(),
                          );
                          final explorer = _Reveal(
                            index: 2,
                            child: _ExplorerPlanCard(
                              key: _explorerKey,
                              onInterested: _showComingSoon,
                              animationVersion: _explorerAnimationVersion,
                            ),
                          );
                          if (constraints.maxWidth >= 900 &&
                              MediaQuery.textScalerOf(context).scale(14) <=
                                  21) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Expanded(flex: 5, child: free),
                                const SizedBox(width: AppSpacing.xxl),
                                Expanded(flex: 7, child: explorer),
                              ],
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              free,
                              const SizedBox(height: AppSpacing.xxl),
                              explorer,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        'Estamos preparando Níkara Explorador. '
                        'Esta es una presentación de sus beneficios; '
                        'la activación estará disponible más adelante.',
                        textAlign: TextAlign.center,
                        style: _type(15),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlansIntro extends StatelessWidget {
  const _PlansIntro({required this.onExplore});
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          const TextSpan(
            children: [
              TextSpan(text: 'Gratis para explorar. Más poder con '),
              TextSpan(
                text: 'Explorador',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.goldFill,
                  decorationThickness: 2,
                ),
              ),
              TextSpan(text: '.'),
            ],
          ),
          style: _type(
            wide ? 56 : 36,
            bold: true,
            color: _Palette.ink,
          ).copyWith(height: 1.05, letterSpacing: -0.7),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Dos versiones de Níkara, el mismo mapa y las mismas comunidades '
          'verificadas. Tú eliges cuánto quieres llevar contigo.',
          style: _type(18),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextButton.icon(
          onPressed: onExplore,
          style: TextButton.styleFrom(
            foregroundColor: _Palette.ink,
            textStyle: _type(16, bold: true),
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
          ),
          label: const Text('Conocer Explorador'),
          icon: const Icon(Icons.south_rounded, size: 18),
          iconAlignment: IconAlignment.end,
        ),
      ],
    );
  }
}

class _FreePlanCard extends StatelessWidget {
  const _FreePlanCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _Palette.paper,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _Palette.ink.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -30,
            width: 250,
            height: 250,
            child: SvgPicture.asset(
              'assets/images/topography.svg',
              colorFilter: ColorFilter.mode(
                _Palette.ink.withValues(alpha: 0.10),
                BlendMode.srcIn,
              ),
              excludeFromSemantics: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PlanChip(label: 'Versión gratuita'),
                const SizedBox(height: AppSpacing.xxl),
                const _BrandLogo(width: 190),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Text(
                      'Gratis',
                      style: _type(60, bold: true).copyWith(height: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('sin costo', style: _type(16, bold: true)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Todo lo esencial para descubrir Nicaragua fuera de las '
                  'rutas de siempre.',
                  style: _type(18),
                ),
                const SizedBox(height: AppSpacing.xxl),
                for (final label in [
                  'Mapas integrados',
                  'Sistema de rutas: hasta 6 rutas guardadas',
                  'Participación en actividades ecológicas',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: AppColors.oliveFill,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 17,
                            color: _Palette.ink,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: Text(label, style: _type(17))),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _Palette.ink,
                    side: const BorderSide(color: _Palette.ink),
                    textStyle: _type(16, bold: true),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  label: const Text('Seguir explorando gratis'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  iconAlignment: IconAlignment.end,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplorerPlanCard extends StatelessWidget {
  const _ExplorerPlanCard({
    super.key,
    required this.onInterested,
    required this.animationVersion,
  });
  final VoidCallback onInterested;
  final int animationVersion;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: AppColors.goldFill.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _Palette.goldLight,
                    AppColors.goldFill,
                    _Palette.goldDeep,
                  ],
                  stops: [0, 0.52, 1],
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topRight,
                    radius: 1.1,
                    colors: [
                      _Palette.paper.withValues(alpha: 0.5),
                      _Palette.paper.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: _PlanChip(
                          label: 'Suscripción mensual · Próximamente',
                          pro: true,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth >= 490 &&
                              MediaQuery.textScalerOf(context).scale(14) <=
                                  21) {
                            return const Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: _ExplorerLogo()),
                                SizedBox(width: AppSpacing.xxl),
                                Expanded(child: _ExplorerPrice()),
                              ],
                            );
                          }
                          return const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ExplorerLogo(),
                              SizedBox(height: AppSpacing.xxl),
                              _ExplorerPrice(),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        'Todo lo de Níkara, y además:',
                        style: _type(18, bold: true),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const _BenefitsCarousel(),
                      const SizedBox(height: AppSpacing.xxl),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: onInterested,
                          style: _primaryButton(),
                          label: const Text('Quiero ser Explorador'),
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                          iconAlignment: IconAlignment.end,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        )
        .animate(key: ValueKey(animationVersion))
        .shimmer(
          duration: AppMotion.respect(context, AppMotion.largeDuration * 3),
          color: _Palette.paper.withValues(alpha: 0.15),
        );
  }
}

class _ExplorerPrice extends StatelessWidget {
  const _ExplorerPrice();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          Text(r'US$2.50', style: _type(48, bold: true).copyWith(height: 1)),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('al mes', style: _type(16, bold: true)),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      const _PlanChip(label: r'o C$93 / mes', pro: true),
    ],
  );
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({this.width = 220});
  final double width;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/images/nikara_membership_logo.svg',
    width: width,
    fit: BoxFit.contain,
    semanticsLabel: 'Níkara',
  );
}

class _ExplorerLogo extends StatelessWidget {
  const _ExplorerLogo();

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.respect(context, AppMotion.largeDuration);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 270),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _BrandLogo(),
              ),
              ClipPath(
                clipper: _RibbonClipper(),
                child: Container(
                  color: _Palette.ink,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.eco_outlined,
                        size: 17,
                        color: AppColors.oliveFill,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'EXPLORADOR',
                          textAlign: TextAlign.center,
                          style: _type(
                            15,
                            bold: true,
                            color: AppColors.goldFill,
                          ).copyWith(letterSpacing: 2),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(
                        Icons.eco_outlined,
                        size: 17,
                        color: AppColors.orangeFill,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            right: 1,
            top: 0,
            child: ExcludeSemantics(
              child:
                  const Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: _Palette.paper,
                      )
                      .animate()
                      .scale(begin: const Offset(0.5, 0.5), duration: duration)
                      .shimmer(
                        duration: duration * 3,
                        color: AppColors.goldFill,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width - 10, size.height / 2)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..lineTo(10, size.height / 2)
    ..close();

  @override
  bool shouldReclip(covariant _RibbonClipper oldClipper) => false;
}

class _BenefitsCarousel extends StatefulWidget {
  const _BenefitsCarousel();

  @override
  State<_BenefitsCarousel> createState() => _BenefitsCarouselState();
}

class _BenefitsCarouselState extends State<_BenefitsCarousel> {
  static const _benefits = [
    (
      Icons.auto_awesome_outlined,
      'Acceso completo a la IA de Níkara',
      'Todas sus funciones, más tokens y menos restricciones '
          'para crear rutas completas y variadas.',
    ),
    (
      Icons.download_for_offline_outlined,
      'Mapas sin conexión',
      'Descarga de mapas y navegación sin conexión',
    ),
    (
      Icons.alt_route,
      'Rutas guardadas ilimitadas',
      'Guarda todas las rutas que quieras para tu próxima aventura.',
    ),
    (
      Icons.palette_outlined,
      'Un perfil a tu estilo',
      'Personalización extra: banner, colores y marcos para tu perfil.',
    ),
    (
      Icons.workspace_premium_outlined,
      'Insignia de explorador',
      'Una insignia distintiva de explorador en tu perfil.',
    ),
    (
      Icons.support_agent_outlined,
      'Atención prioritaria',
      'Atención más rápida cuando la necesites en el camino.',
    ),
  ];

  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    final duration = AppMotion.respect(context, AppMotion.largeDuration);
    if (duration == Duration.zero) {
      _controller.jumpToPage(index);
      return;
    }
    _controller.animateToPage(
      index,
      duration: duration,
      curve: AppMotion.emphasized,
    );
  }

  double _textHeight(String text, TextStyle style, double width) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.localeOf(context),
    )..layout(maxWidth: width);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Reserva lo que necesita el beneficio más largo a este ancho y escala
        // de texto. Así no corta contenido ni salta de altura al deslizar.
        final textWidth = constraints.maxWidth - 2 * (AppSpacing.lg + 1);
        var height = 0.0;
        for (final (_, title, description) in _benefits) {
          final candidate =
              40 +
              AppSpacing.md +
              AppSpacing.sm +
              2 * (AppSpacing.lg + 1) +
              AppSpacing.xs +
              _textHeight(
                title,
                _type(22, bold: true).copyWith(height: 1.1),
                textWidth,
              ) +
              _textHeight(description, _type(16), textWidth);
          if (candidate > height) height = candidate;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: height,
              child: PageView.builder(
                key: const ValueKey('explorer-benefits-carousel'),
                controller: _controller,
                itemCount: _benefits.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) {
                  final (icon, title, description) = _benefits[index];
                  return _BenefitTile(
                    icon: icon,
                    title: title,
                    description: description,
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                IconButton(
                  tooltip: 'Beneficio anterior',
                  onPressed: _index == 0 ? null : () => _goTo(_index - 1),
                  color: _Palette.ink,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Column(
                    children: [
                      ExcludeSemantics(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (
                              var index = 0;
                              index < _benefits.length;
                              index++
                            )
                              AnimatedContainer(
                                duration: AppMotion.respect(
                                  context,
                                  AppMotion.quickDuration,
                                ),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: index == _index ? 20 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _Palette.ink.withValues(
                                    alpha: index == _index ? 1 : 0.25,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xs,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          '${_index + 1} de ${_benefits.length} beneficios',
                          textAlign: TextAlign.center,
                          style: _type(12, bold: true),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Siguiente beneficio',
                  onPressed: _index == _benefits.length - 1
                      ? null
                      : () => _goTo(_index + 1),
                  color: _Palette.ink,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _BenefitTile extends StatefulWidget {
  const _BenefitTile({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;

  @override
  State<_BenefitTile> createState() => _BenefitTileState();
}

class _BenefitTileState extends State<_BenefitTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: AnimatedContainer(
      duration: AppMotion.respect(context, AppMotion.quickDuration),
      curve: AppMotion.emphasized,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: _Palette.paper.withValues(alpha: _hovered ? 0.85 : 0.65),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _Palette.paper.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _Palette.ink,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(widget.icon, color: AppColors.goldFill, size: 22),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            widget.title,
            style: _type(22, bold: true).copyWith(height: 1.1),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(widget.description, style: _type(16)),
        ],
      ),
    ),
  );
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({required this.label, this.pro = false});
  final String label;
  final bool pro;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: pro ? _Palette.ink : _Palette.ink.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    child: Text(
      label,
      style: _type(
        12,
        bold: true,
        color: pro ? AppColors.goldFill : _Palette.ink,
      ),
    ),
  );
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) => child
      .animate(
        delay: AppMotion.respect(context, AppMotion.microDuration * index),
      )
      .fadeIn(duration: AppMotion.respect(context, AppMotion.largeDuration))
      .slideY(
        begin: 0.04,
        curve: AppMotion.decelerate,
        duration: AppMotion.respect(context, AppMotion.largeDuration),
      );
}

TextStyle _type(double size, {bool bold = false, Color color = _Palette.ink}) =>
    TextStyle(
      fontFamily: 'NikaraMembership',
      fontSize: size,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: color,
      height: 1.4,
    );

ButtonStyle _primaryButton() => FilledButton.styleFrom(
  backgroundColor: _Palette.ink,
  foregroundColor: _Palette.paper,
  textStyle: _type(16, bold: true),
  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
);

/// Paleta de la landing aportada por el usuario, limitada a esta presentación.
abstract class _Palette {
  static const ink = Color(0xFF442816);
  static const paper = Color(0xFFFAF5EB);
  static const goldLight = Color(0xFFFFE27A);
  static const goldDeep = Color(0xFFF29A06);
}
