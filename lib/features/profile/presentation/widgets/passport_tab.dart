import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:nikara_app/features/business/utils/business_icons.dart';
import 'package:nikara_app/features/profile/domain/models/travel_postcard.dart';
import 'package:nikara_app/features/profile/domain/models/postcard_search.dart';
import 'package:nikara_app/features/profile/presentation/widgets/postcard_category_style.dart';
import 'package:nikara_app/shared/services/map_focus_controller.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_motion.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Only earned postcards enter the collection; previews never count as visits.
class PassportTab extends StatelessWidget {
  const PassportTab({super.key, this.postcards = const [], this.onViewAll});

  final List<TravelPostcard> postcards;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final earned = searchPostcards(postcards);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tu pasaporte', style: AppTextStyles.heading),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Cada viaje completado, una historia para llevar contigo.',
          style: AppTextStyles.body.copyWith(
            color: AppColors.settingsTextMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (earned.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.menu_book_outlined,
                  color: AppColors.oliveText,
                  size: 32,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Tu primera postal te espera',
                  style: AppTextStyles.sectionTitle,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Inicia un viaje hacia un negocio y llega a su ubicación. '
                  'Al completar el viaje recibirás su postal con el sello Níkara, '
                  'la fecha y la hora de llegada.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.settingsTextMuted,
                  ),
                ),
              ],
            ),
          ),
        if (earned.isNotEmpty) ...[
          Text(
            '${earned.length} ${earned.length == 1 ? 'postal coleccionada' : 'postales coleccionadas'}',
            style: AppTextStyles.body.copyWith(
              color: AppColors.settingsTextMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PostcardGrid(
            postcards: earned.take(3).toList(),
            shrinkWrap: true,
            onSelected: (postcard) => showTravelPostcard(context, postcard),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (onViewAll != null)
            OutlinedButton.icon(
              onPressed: onViewAll,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                minimumSize: const Size(0, 48),
              ),
              icon: const Icon(Icons.collections_bookmark_outlined),
              label: Text('Ver todas las postales (${earned.length})'),
            ),
        ],
      ],
    );
  }
}

void focusPostcardOnMap(TravelPostcard postcard) {
  MapFocusController().focusOnBusiness(
    MapFocusRequest(
      businessId: postcard.id,
      name: postcard.title,
      latitude: postcard.latitude!,
      longitude: postcard.longitude!,
    ),
  );
}

Future<void> showTravelPostcard(
  BuildContext context,
  TravelPostcard postcard, {
  VoidCallback? onMapRequested,
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    builder: (sheetContext) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .82,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(postcard.title, style: AppTextStyles.heading),
              const SizedBox(height: AppSpacing.sm),
              Text(
                PostcardCategoryStyle.forCategory(postcard.category).label,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.settingsTextMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TravelPostcardCard(
                postcard: postcard,
                onMapRequested: !postcard.hasCoordinates
                    ? null
                    : () {
                        Navigator.of(sheetContext).pop();
                        if (onMapRequested != null) {
                          onMapRequested();
                        } else {
                          focusPostcardOnMap(postcard);
                        }
                      },
              ),
              Text(
                'Sellada el ${postcard.sealDateLabel} a las ${postcard.sealTimeLabel}',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
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

/// Both grids build postcards lazily; only the three-item profile preview shrinks.
class PostcardGrid extends StatelessWidget {
  const PostcardGrid({
    super.key,
    required this.postcards,
    required this.onSelected,
    this.shrinkWrap = false,
  });
  final List<TravelPostcard> postcards;
  final ValueChanged<TravelPostcard> onSelected;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = scale > 1.3 || constraints.maxWidth < 300
          ? 1
          : math.max(2, (constraints.maxWidth / 220).floor());
      final width =
          (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;
      return GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          mainAxisExtent: width * .95 + 92 * scale,
        ),
        itemCount: postcards.length,
        itemBuilder: (context, index) => PostcardThumbnail(
          key: ValueKey(postcards[index].id),
          postcard: postcards[index],
          onTap: () => onSelected(postcards[index]),
        ),
      );
    },
  );
}

class PostcardSliverGrid extends StatelessWidget {
  const PostcardSliverGrid({
    super.key,
    required this.postcards,
    required this.onSelected,
  });
  final List<TravelPostcard> postcards;
  final ValueChanged<TravelPostcard> onSelected;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final availableWidth = constraints.crossAxisExtent;
      final columns = scale > 1.3 || availableWidth < 300
          ? 1
          : math.max(2, (availableWidth / 220).floor());
      final width = (availableWidth - AppSpacing.md * (columns - 1)) / columns;
      return SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          mainAxisExtent: width * .95 + 92 * scale,
        ),
        itemCount: postcards.length,
        itemBuilder: (context, index) => PostcardThumbnail(
          key: ValueKey(postcards[index].id),
          postcard: postcards[index],
          onTap: () => onSelected(postcards[index]),
        ),
      );
    },
  );
}

class PostcardThumbnail extends StatelessWidget {
  const PostcardThumbnail({
    super.key,
    required this.postcard,
    required this.onTap,
  });
  final TravelPostcard postcard;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Abrir postal de ${postcard.title}',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  top: AppSpacing.md,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.textPrimary.withValues(alpha: .08),
                          offset: const Offset(0, 4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: _PostcardFront(postcard: postcard, compact: true),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: PostcardTape(
                    category: postcard.category,
                    width: 60,
                    height: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            PostcardCategoryStyle.forCategory(postcard.category).label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${postcard.sealDateLabel} · ${postcard.sealTimeLabel}',
            maxLines: 2,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.settingsTextMuted,
            ),
          ),
        ],
      ),
    ),
  );
}

class PostcardTape extends StatelessWidget {
  const PostcardTape({
    super.key,
    required this.category,
    this.width = 88,
    this.height = 24,
  });
  final String category;
  final double width;
  final double height;
  Color get color => PostcardCategoryStyle.forCategory(category).tapeColor;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Transform.rotate(
      angle: -.06,
      child: CustomPaint(
        size: Size(width, height),
        painter: _TapePainter(color),
      ),
    ),
  );
}

class TravelPostcardCard extends StatefulWidget {
  const TravelPostcardCard({
    super.key,
    required this.postcard,
    required this.onMapRequested,
  });

  final TravelPostcard postcard;
  final VoidCallback? onMapRequested;

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
            height:
                math.max(
                  constraints.maxWidth / 1.5,
                  (widget.postcard.address.isEmpty ? 232 : 320) * textScale,
                ) +
                12,
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
                        child: PostcardTape(category: widget.postcard.category),
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
          label: Text(
            _showBack
                ? (widget.postcard.artAsset != null
                      ? 'Ver paisaje'
                      : 'Ver foto')
                : 'Leer postal',
          ),
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
  const _PostcardFront({required this.postcard, this.compact = false});

  final TravelPostcard postcard;
  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.sm),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (postcard.artAsset != null)
            SvgPicture.asset(postcard.artAsset!, fit: BoxFit.cover)
          else
            LocalImage(
              path: postcard.imagePath,
              fallbackIcon: businessCategoryIcon(postcard.category),
              fallbackIconSize: 48,
            ),
          if (postcard.isStamped)
            Positioned(
              right: AppSpacing.md,
              top: AppSpacing.md,
              child: Container(
                width: compact ? 48 : 80,
                height: compact ? 48 : 80,
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: .85),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: FittedBox(
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: PostcardSeal(postcard: postcard, showWaves: false),
                    ),
                  ),
                ),
              ),
            ),
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
          if (postcard.region.isNotEmpty)
            Positioned(
              left: AppSpacing.md,
              right: compact ? 68 : 100,
              top: AppSpacing.md,
              child: Align(
                alignment: Alignment.centerLeft,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                    ),
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
                if (!compact)
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
                  maxLines: compact ? 3 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: AppTextStyles.heading.copyWith(
                    color: AppColors.surface,
                    height: 1.1,
                    fontSize: compact ? 15 : null,
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
  final VoidCallback? onMapRequested;

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          postcard.message.isEmpty
                              ? 'Este negocio aún no ha agregado una descripción.'
                              : postcard.message,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        if (postcard.schedules.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Horario',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            postcard.schedules,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.settingsTextMuted,
                            ),
                          ),
                        ],
                      ],
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
                  child: Text(
                    onMapRequested == null
                        ? 'Ubicación pendiente'
                        : 'Ver en el mapa',
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
                SizedBox(
                  height: 96,
                  child: _Postage(
                    postcard: postcard,
                    icon: postcard.category.isEmpty
                        ? Icons.diversity_2_outlined
                        : businessCategoryIcon(postcard.category),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _address('Para: ti', italic: true),
                            const SizedBox(height: AppSpacing.sm),
                            _address(
                              postcard.region.isEmpty
                                  ? 'Nicaragua'
                                  : postcard.region,
                            ),
                            if (postcard.address.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              _address(postcard.address),
                            ],
                            const SizedBox(height: AppSpacing.sm),
                            _address('NICARAGUA'),
                          ],
                        ),
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
  const _Postage({required this.icon, required this.postcard});

  final IconData icon;
  final TravelPostcard postcard;

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
                  Icon(icon, color: AppColors.textPrimary, size: 24),
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
              child: PostcardSeal(postcard: postcard),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Decorative seal has fixed type sizes; the full timestamp remains readable
/// below the postcard and available to assistive technology.
class PostcardSeal extends StatelessWidget {
  const PostcardSeal({
    super.key,
    required this.postcard,
    this.showWaves = true,
  });
  final TravelPostcard postcard;
  final bool showWaves;

  @override
  Widget build(BuildContext context) => Semantics(
    label: postcard.isStamped
        ? 'Sello Níkara. ${postcard.sealDateLabel}, ${postcard.sealTimeLabel}'
        : 'Sello Níkara',
    child: CustomPaint(
      painter: _PostmarkPainter(showWaves: showWaves),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'N',
                textScaler: TextScaler.noScaling,
                style: AppTextStyles.heading.copyWith(
                  color: AppColors.oliveText,
                  fontSize: 18,
                  height: 1,
                ),
              ),
              Text(
                'NÍKARA',
                textScaler: TextScaler.noScaling,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.oliveText,
                  fontSize: 7,
                  height: 1.1,
                ),
              ),
              if (postcard.isStamped) ...[
                Text(
                  postcard.sealDateLabel,
                  textScaler: TextScaler.noScaling,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.oliveText,
                    fontSize: 7,
                    height: 1.4,
                  ),
                ),
                Text(
                  postcard.sealTimeLabel,
                  textScaler: TextScaler.noScaling,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.oliveText,
                    fontSize: 9,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _PostmarkPainter extends CustomPainter {
  const _PostmarkPainter({required this.showWaves});
  final bool showWaves;
  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = AppColors.oliveText.withValues(alpha: .7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(const Offset(32, 32), 30, ink);
    canvas.drawCircle(const Offset(32, 32), 23, ink);
    if (!showWaves) return;
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
  bool shouldRepaint(_PostmarkPainter oldDelegate) =>
      oldDelegate.showWaves != showWaves;
}

class _TapePainter extends CustomPainter {
  const _TapePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = color.withValues(alpha: .85),
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
  bool shouldRepaint(_TapePainter oldDelegate) => oldDelegate.color != color;
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
