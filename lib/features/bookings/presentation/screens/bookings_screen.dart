import 'package:flutter/material.dart';

import 'package:nikara_app/features/bookings/data/booking_service.dart';
import 'package:nikara_app/features/bookings/domain/models/booking.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// (status, label) pairs for the horizontal filter row — `null` means
/// "Todas" (no filter). Order matches the Figma reference exactly.
const List<(BookingStatus?, String)> _kFilterOptions = [
  (null, 'Todas'),
  (BookingStatus.confirmada, 'Confirmada'),
  (BookingStatus.pendiente, 'Pendiente'),
  (BookingStatus.completada, 'Completada'),
];

/// Reservas screen (Figma node 170:23) — real reservations read from
/// Supabase's `bookings` table (joined with their owning `businesses` row),
/// filtered in memory by a horizontal chip row instead of the earlier
/// mock-data TabBar split.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key, this.onExploreMapRequested});

  /// Wired by [MainLayout] to switch to the Mapa tab — the empty state's
  /// "Explorar en el mapa" shortcut uses this instead of pushing a new
  /// route, so the bottom nav bar stays put.
  final VoidCallback? onExploreMapRequested;

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final _bookingService = BookingService();

  bool _isLoading = true;
  String? _loadError;
  List<BookingModel> _bookings = const [];
  BookingStatus? _selectedFilter;

  @override
  void initState() {
    super.initState();
    // Fires on every successful booking creation, even from a screen this
    // one never rebuilt directly (BusinessDetailScreen) — keeps "Mis
    // Reservas" in sync without a manual refresh while it sits inert in
    // the background inside MainLayout's IndexedStack.
    BookingService.revision.addListener(_onDataChanged);
    _loadBookings();
  }

  @override
  void dispose() {
    BookingService.revision.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (!mounted) return;
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final bookings = await _bookingService.getMyBookings();
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } on BookingServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    }
  }

  List<BookingModel> get _filteredBookings {
    if (_selectedFilter == null) return _bookings;
    return _bookings.where((b) => b.status == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    // The summary pills always reflect the FULL set, independent of the
    // active chip filter — matches the Figma reference (the counts don't
    // change as "Todas"/"Confirmada"/etc. are tapped).
    final confirmed = _bookings
        .where((b) => b.status == BookingStatus.confirmada)
        .length;
    final pending = _bookings
        .where((b) => b.status == BookingStatus.pendiente)
        .length;
    final completed = _bookings
        .where((b) => b.status == BookingStatus.completada)
        .length;

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _BookingsHeader(
              total: _bookings.length,
              confirmed: confirmed,
              pending: pending,
              completed: completed,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _FilterChips(
                selected: _selectedFilter,
                onSelected: (status) =>
                    setState(() => _selectedFilter = status),
              ),
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (_isLoading) return const _BookingListSkeleton();
                  if (_loadError != null) {
                    return _BookingsErrorState(
                      message: _loadError!,
                      onRetry: _loadBookings,
                    );
                  }
                  if (_bookings.isEmpty) {
                    return _EmptyBookingsState(
                      onExploreMap: widget.onExploreMapRequested,
                    );
                  }
                  final filtered = _filteredBookings;
                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Ninguna reserva coincide con este filtro.',
                          style: AppTextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _BookingCard(booking: filtered[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingsHeader extends StatelessWidget {
  const _BookingsHeader({
    required this.total,
    required this.confirmed,
    required this.pending,
    required this.completed,
  });

  final int total;
  final int confirmed;
  final int pending;
  final int completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.55, -0.8),
          end: Alignment(0.55, 0.8),
          colors: [AppColors.primary700, AppColors.secundario6],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_month,
                  size: 18,
                  color: AppColors.neutral1100,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mis Reservas',
                      style: AppTextStyles.bookingHeaderTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$total ${total == 1 ? 'reserva' : 'reservas'} en total',
                      style: AppTextStyles.bookingMeta.copyWith(
                        color: const Color(0x991A1510),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                icon: Icons.check_circle,
                label: '$confirmed Confirmadas',
              ),
              _StatusPill(
                icon: Icons.access_time,
                label: '$pending Pendientes',
              ),
              _StatusPill(icon: Icons.folder, label: '$completed Completadas'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.neutral1100),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.bookingPillCount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final BookingStatus? selected;
  final ValueChanged<BookingStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Row(
        children: [
          for (final (status, label) in _kFilterOptions) ...[
            _FilterChip(
              label: label,
              isSelected: selected == status,
              onTap: () => onSelected(status),
            ),
            if (status != _kFilterOptions.last.$1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.neutral800 : AppColors.surface100,
      borderRadius: BorderRadius.circular(999),
      elevation: isSelected ? 0 : 1.5,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: AppTextStyles.bookingActionLabel.copyWith(
              color: isSelected ? Colors.white : AppColors.neutral800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x21FDBE02),
            offset: Offset(0, 4),
            blurRadius: 20,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHero(booking: booking),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 13,
                            color: AppColors.neutral800,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              booking.formattedDate,
                              style: AppTextStyles.bookingMeta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.access_time,
                            size: 13,
                            color: AppColors.neutral800,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              booking.formattedTime,
                              style: AppTextStyles.bookingMeta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${booking.partySize} ${booking.partySize == 1 ? 'persona' : 'personas'}',
                      style: AppTextStyles.bookingMeta.copyWith(
                        color: AppColors.neutral800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0x26FDBE02), height: 1),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CÓDIGO', style: AppTextStyles.bookingLabel),
                          Text(
                            booking.code,
                            style: AppTextStyles.bookingCode,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'TOTAL PAGADO',
                          style: AppTextStyles.bookingLabel,
                        ),
                        Text(
                          booking.formattedTotal,
                          style: AppTextStyles.bookingTotal,
                        ),
                      ],
                    ),
                  ],
                ),
                if (booking.status != BookingStatus.cancelada) ...[
                  const SizedBox(height: 12),
                  _buildAction(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context) {
    void showComingSoon() => ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Próximamente')),
    );

    switch (booking.status) {
      case BookingStatus.confirmada:
      case BookingStatus.pendiente:
        return _ActionButton(
          label: 'Ver detalles del itinerario',
          background: AppColors.primary500.withValues(alpha: 0.15),
          textColor: AppColors.neutral1100,
          onTap: showComingSoon,
        );
      case BookingStatus.completada:
        return _ActionButton(
          label: 'Dejar una reseña ★',
          background: AppColors.ecoForest.withValues(alpha: 0.1),
          textColor: AppColors.bookingConfirmed,
          onTap: showComingSoon,
        );
      case BookingStatus.cancelada:
        return const SizedBox.shrink();
    }
  }
}

class _CardHero extends StatelessWidget {
  const _CardHero({required this.booking});

  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final business = booking.business;
    final photoPath = business.localImagePaths.isNotEmpty
        ? business.localImagePaths.first
        : null;

    return SizedBox(
      height: 96,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LocalImage(path: photoPath, fallbackIcon: Icons.storefront_outlined),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0x991A1510), Colors.transparent],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        business.name,
                        style: AppTextStyles.bookingCardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${business.city}, Nicaragua',
                        style: AppTextStyles.heroLocation.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: booking.status),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color textColor;
    late final BoxDecoration decoration;

    switch (status) {
      case BookingStatus.confirmada:
        label = 'Confirmada';
        textColor = Colors.white;
        decoration = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.bookingConfirmed.withValues(alpha: 0.8),
              AppColors.secundario6.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(999),
        );
      case BookingStatus.pendiente:
        label = 'Pendiente';
        textColor = AppColors.bookingPending;
        decoration = BoxDecoration(
          color: AppColors.primary500.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(999),
        );
      case BookingStatus.completada:
        label = 'Completada';
        textColor = AppColors.neutral1100;
        decoration = BoxDecoration(
          color: AppColors.neutral500.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(999),
        );
      case BookingStatus.cancelada:
        label = 'Cancelada';
        textColor = Colors.white;
        decoration = BoxDecoration(
          color: AppColors.bookingPending.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(999),
        );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: decoration,
      child: Text(
        label,
        style: AppTextStyles.bookingStatusChip.copyWith(color: textColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.background,
    required this.textColor,
    this.onTap,
  });

  final String label;
  final Color background;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                label,
                style: AppTextStyles.bookingActionLabel.copyWith(
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingsErrorState extends StatelessWidget {
  const _BookingsErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: AppColors.settingsDanger,
            ),
            const SizedBox(height: 12),
            Text(
              'No se pudieron cargar tus reservas',
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reintentar'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: AppColors.textInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBookingsState extends StatelessWidget {
  const _EmptyBookingsState({this.onExploreMap});

  final VoidCallback? onExploreMap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary500.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_outlined,
                size: 32,
                color: AppColors.primary700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aún no tienes reservas',
              style: AppTextStyles.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Explora negocios reales en el mapa y reserva tu próxima aventura.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (onExploreMap != null)
              FilledButton.icon(
                onPressed: onExploreMap,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Explorar en el mapa'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: AppColors.textInk,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loading state — content-shaped placeholder cards that pulse in
/// and out (a lightweight, dependency-free stand-in for a `shimmer`
/// package) instead of a bare spinner.
class _BookingListSkeleton extends StatelessWidget {
  const _BookingListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => const _BookingCardSkeleton(),
    );
  }
}

class _BookingCardSkeleton extends StatelessWidget {
  const _BookingCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ShimmerBox(height: 96, borderRadius: BorderRadius.zero),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ShimmerBox(height: 12, width: 160),
                const SizedBox(height: 16),
                const _ShimmerBox(height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    _ShimmerBox(height: 28, width: 90),
                    _ShimmerBox(height: 28, width: 70),
                  ],
                ),
                const SizedBox(height: 16),
                const _ShimmerBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({
    required this.height,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  final double height;
  final double? width;
  final BorderRadius borderRadius;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller.drive(Tween(begin: 0.35, end: 0.85)),
      child: Container(
        width: widget.width ?? double.infinity,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.surface200,
          borderRadius: widget.borderRadius,
        ),
      ),
    );
  }
}
