import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:nikara_app/features/profile/domain/models/travel_postcard.dart';
import 'package:nikara_app/shared/services/map_focus_controller.dart';
import 'package:nikara_app/theme/app_motion.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Expressive passport preview based on the user's ecotourism HTML export.
/// Until visits can be verified, the example stays outside the real stats.
class PassportTab extends StatelessWidget {
  const PassportTab({super.key});

  @override
  Widget build(BuildContext context) {
    const postcard = TravelPostcard.miraflorExample;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tu pasaporte', style: AppTextStyles.heading),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Cada lugar, una historia para llevar contigo.',
          style: AppTextStyles.body.copyWith(
            color: AppColors.settingsTextMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.oliveFill.withValues(alpha: .25),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              'Postal de ejemplo',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TravelPostcardCard(
          postcard: postcard,
          onMapRequested: () => MapFocusController().focusOnBusiness(
            MapFocusRequest(
              businessId: postcard.id,
              name: postcard.title,
              latitude: postcard.latitude,
              longitude: postcard.longitude,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Así se verá un recuerdo en tu colección. La idea es recibir '
          'una postal al confirmar tu visita a un negocio o lugar.',
          style: AppTextStyles.body.copyWith(
            color: AppColors.settingsTextMuted,
          ),
        ),
      ],
    );
  }
}

class TravelPostcardCard extends StatefulWidget {
  const TravelPostcardCard({
    super.key,
    required this.postcard,
    required this.onMapRequested,
  });

  final TravelPostcard postcard;
  final VoidCallback onMapRequested;

  @override
  State<TravelPostcardCard> createState() => _TravelPostcardCardState();
}

class _TravelPostcardCardState extends State<TravelPostcardCard> {
  bool _showBack = false;

  void _flip() => setState(() => _showBack = !_showBack);

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            height: math.max(constraints.maxWidth / 1.5, 232 * textScale) + 12,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: _showBack ? math.pi : 0),
              duration: AppMotion.respect(context, AppMotion.largeDuration),
              curve: AppMotion.emphasized,
              builder: (context, angle, child) {
                final backVisible = angle > math.pi / 2;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .001)
                    ..rotateY(backVisible ? angle - math.pi : angle),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        top: AppSpacing.md,
                        child: Semantics(
                          button: true,
                          label: backVisible
                              ? 'Reverso de ${widget.postcard.title}'
                              : 'Frente de ${widget.postcard.title}',
                          hint: 'Toca para voltear la postal',
                          onTap: _flip,
                          child: GestureDetector(
                            onTap: _flip,
                            excludeFromSemantics: true,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.textPrimary.withValues(
                                      alpha: .14,
                                    ),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                child: backVisible
                                    ? _PostcardBack(
                                        postcard: widget.postcard,
                                        onMapRequested: widget.onMapRequested,
                                      )
                                    : _PostcardFront(postcard: widget.postcard),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: IgnorePointer(
                          child: Transform.rotate(
                            angle: -.06,
                            child: CustomPaint(
                              size: const Size(88, 24),
                              painter: _TapePainter(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: _flip,
          icon: const Icon(Icons.flip_rounded, size: 20),
          label: Text(_showBack ? 'Ver paisaje' : 'Leer postal'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size(48, 48),
          ),
        ),
      ],
    );
  }
}

class _PostcardFront extends StatelessWidget {
  const _PostcardFront({required this.postcard});

  final TravelPostcard postcard;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.sm),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: Stack(
        fit: StackFit.expand,
        children: [
          SvgPicture.asset(postcard.artAsset, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [.45, 1],
                colors: [Colors.transparent, AppColors.textPrimary],
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.md,
            top: AppSpacing.md,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                postcard.region,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SALUDOS DESDE',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.surface,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  postcard.title,
                  style: AppTextStyles.heading.copyWith(
                    color: AppColors.surface,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PostcardBack extends StatelessWidget {
  const _PostcardBack({required this.postcard, required this.onMapRequested});

  final TravelPostcard postcard;
  final VoidCallback onMapRequested;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _PaperPainter(),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Querido viajero:',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.settingsTextMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      postcard.message,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: onMapRequested,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.surface,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                  ),
                  child: const Text(
                    'Ver en el mapa',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          CustomPaint(
            size: const Size(1, double.infinity),
            painter: _DividerPainter(),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(child: _Postage()),
                _address('Para: ti', italic: true),
                const SizedBox(height: AppSpacing.sm),
                _address(postcard.region),
                const SizedBox(height: AppSpacing.sm),
                _address('NICARAGUA'),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _address(String text, {bool italic = false}) => Container(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Text(
      text,
      style: AppTextStyles.caption.copyWith(
        color: AppColors.settingsTextMuted,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      ),
    ),
  );
}

class _Postage extends StatelessWidget {
  const _Postage();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      children: [
        Align(
          alignment: Alignment.topRight,
          child: Container(
            width: 52,
            height: 68,
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: .08),
                  blurRadius: 4,
                ),
              ],
            ),
            child: DecoratedBox(
              decoration: const BoxDecoration(color: AppColors.goldFill),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.diversity_2_outlined,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                  Text(
                    'NIC',
                    textScaler: TextScaler.noScaling,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 32,
          child: Transform.rotate(
            angle: -.15,
            child: SizedBox(
              width: math.min(120, constraints.maxWidth),
              height: 64,
              child: CustomPaint(
                painter: _PostmarkPainter(),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 64,
                    child: Text(
                      'NÍKARA\n2026',
                      textAlign: TextAlign.center,
                      textScaler: TextScaler.noScaling,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.oliveText,
                        fontSize: 10,
                        height: 1.8,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _PostmarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = AppColors.oliveText.withValues(alpha: .7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(const Offset(32, 32), 30, ink);
    canvas.drawCircle(const Offset(32, 32), 23, ink);
    for (final y in [20.0, 28.0, 36.0, 44.0]) {
      final wave = Path()..moveTo(62, y);
      for (double x = 62; x < size.width; x += 16) {
        wave.relativeQuadraticBezierTo(4, -4, 8, 0);
        wave.relativeQuadraticBezierTo(4, 4, 8, 0);
      }
      canvas.drawPath(wave, ink);
    }
  }

  @override
  bool shouldRepaint(_PostmarkPainter oldDelegate) => false;
}

class _TapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.oliveFill.withValues(alpha: .85),
    );
    final stripe = Paint()
      ..color = AppColors.surface.withValues(alpha: .3)
      ..strokeWidth = 8;
    for (double x = -size.height; x < size.width; x += 16) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        stripe,
      );
    }
  }

  @override
  bool shouldRepaint(_TapePainter oldDelegate) => false;
}

class _PaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.background);
    final grain = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: .035);
    final random = math.Random(26);
    for (var i = 0; i < size.width * size.height / 24; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        .5,
        grain,
      );
    }
  }

  @override
  bool shouldRepaint(_PaperPainter oldDelegate) => false;
}

class _DividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()..color = AppColors.border;
    for (double y = 0; y < size.height; y += 8) {
      canvas.drawLine(Offset(0, y), Offset(0, y + 4), ink);
    }
  }

  @override
  bool shouldRepaint(_DividerPainter oldDelegate) => false;
}
