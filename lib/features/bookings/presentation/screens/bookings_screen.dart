import 'package:flutter/material.dart';

import 'package:nikara_app/features/bookings/domain/models/booking.dart';
import 'package:nikara_app/features/home/data/mock_destinations.dart';
import 'package:nikara_app/features/home/domain/models/destination.dart';
import 'package:nikara_app/theme/app_theme.dart';

const _tabs = ['Activas', 'Completadas', 'Canceladas'];

/// Reservas screen (Figma node 170:23). [TabController]-driven Activas /
/// Completadas / Canceladas split — cancelling an active booking just moves
/// it between local lists via `setState`, no backend involved.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: _tabs.length,
    vsync: this,
  );
  List<Booking> _bookings = List.of(mockBookings);

  List<Booking> get _active => _bookings
      .where(
        (b) =>
            b.status == BookingStatus.confirmada ||
            b.status == BookingStatus.pendiente,
      )
      .toList();

  List<Booking> get _completed =>
      _bookings.where((b) => b.status == BookingStatus.completada).toList();

  List<Booking> get _cancelled =>
      _bookings.where((b) => b.status == BookingStatus.cancelada).toList();

  Future<void> _cancelBooking(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancelar reserva'),
        content: const Text('¿Seguro que quieres cancelar esta reserva?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Cancelar reserva',
              style: TextStyle(color: AppColors.bookingPending),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _bookings = [
        for (final b in _bookings)
          if (b.id == booking.id)
            b.copyWith(status: BookingStatus.cancelada)
          else
            b,
      ];
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _BookingsHeader(
              total: _bookings.length,
              confirmed: _bookings
                  .where((b) => b.status == BookingStatus.confirmada)
                  .length,
              pending: _bookings
                  .where((b) => b.status == BookingStatus.pendiente)
                  .length,
              completed: _completed.length,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _PillTabBar(controller: _tabController),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _BookingList(
                    bookings: _active,
                    emptyMessage: 'No tienes reservas activas',
                    onCancel: _cancelBooking,
                  ),
                  _BookingList(
                    bookings: _completed,
                    emptyMessage: 'Aún no completas ninguna reserva',
                  ),
                  _BookingList(
                    bookings: _cancelled,
                    emptyMessage: 'No tienes reservas canceladas',
                  ),
                ],
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
          colors: [AppColors.primary700, AppColors.primary500],
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mis Reservas', style: AppTextStyles.bookingHeaderTitle),
                  Text(
                    '$total reservas en total',
                    style: AppTextStyles.bookingMeta.copyWith(
                      color: const Color(0x991A1510),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(color: AppColors.bookingConfirmed, label: '$confirmed Confirmadas'),
              _StatusPill(color: AppColors.bookingPending, label: '$pending Pendientes'),
              _StatusPill(color: AppColors.neutral800, label: '$completed Completadas'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.color, required this.label});

  final Color color;
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
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.bookingPillCount),
        ],
      ),
    );
  }
}

class _PillTabBar extends StatelessWidget {
  const _PillTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      isScrollable: false,
      padding: EdgeInsets.zero,
      labelPadding: EdgeInsets.zero,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      indicator: BoxDecoration(
        color: AppColors.neutral800,
        borderRadius: BorderRadius.circular(999),
      ),
      labelColor: AppColors.primary500,
      unselectedLabelColor: AppColors.neutral800,
      labelStyle: AppTextStyles.bookingActionLabel.copyWith(fontSize: 12),
      unselectedLabelStyle: AppTextStyles.bookingActionLabel.copyWith(fontSize: 12),
      tabs: [for (final label in _tabs) Tab(text: label)],
    );
  }
}

class _BookingList extends StatelessWidget {
  const _BookingList({
    required this.bookings,
    required this.emptyMessage,
    this.onCancel,
  });

  final List<Booking> bookings;
  final String emptyMessage;
  final ValueChanged<Booking>? onCancel;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: bookings.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final destination = mockDestinations.firstWhere(
          (d) => d.id == booking.destinationId,
          orElse: () => mockDestinations.first,
        );
        return _BookingCard(
          booking: booking,
          destination: destination,
          onCancel: onCancel == null ? null : () => onCancel!(booking),
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.destination,
    this.onCancel,
  });

  final Booking booking;
  final DestinationModel destination;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          _CardHero(booking: booking, destination: destination),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 13, color: AppColors.neutral800),
                        const SizedBox(width: 6),
                        Text(booking.date, style: AppTextStyles.bookingMeta),
                        const SizedBox(width: 12),
                        const Icon(Icons.access_time, size: 13, color: AppColors.neutral800),
                        const SizedBox(width: 6),
                        Text(booking.time, style: AppTextStyles.bookingMeta),
                      ],
                    ),
                    Text(
                      '${booking.partySize} personas',
                      style: AppTextStyles.bookingMeta.copyWith(color: AppColors.neutral800),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0x26FDBE02), height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CÓDIGO', style: AppTextStyles.bookingLabel),
                        Text(booking.code, style: AppTextStyles.bookingCode),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('TOTAL PAGADO', style: AppTextStyles.bookingLabel),
                        Text(booking.formattedTotal, style: AppTextStyles.bookingTotal),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._buildActions(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    void showComingSoon() => ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Próximamente')),
    );

    switch (booking.status) {
      case BookingStatus.confirmada:
      case BookingStatus.pendiente:
        return [
          _ActionButton(
            label: 'Ver detalles del itinerario',
            background: AppColors.primary500.withValues(alpha: 0.15),
            textColor: AppColors.neutral1100,
            onTap: showComingSoon,
          ),
          if (onCancel != null) ...[
            const SizedBox(height: 8),
            _ActionButton(
              label: 'Cancelar reserva',
              background: AppColors.bookingPending.withValues(alpha: 0.1),
              textColor: AppColors.bookingPending,
              onTap: onCancel,
            ),
          ],
        ];
      case BookingStatus.completada:
        return [
          _ActionButton(
            label: 'Dejar una reseña ★',
            background: AppColors.accent300.withValues(alpha: 0.1),
            textColor: AppColors.bookingConfirmed,
            onTap: showComingSoon,
          ),
        ];
      case BookingStatus.cancelada:
        return [];
    }
  }
}

class _CardHero extends StatelessWidget {
  const _CardHero({required this.booking, required this.destination});

  final Booking booking;
  final DestinationModel destination;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: Stack(
        fit: StackFit.expand,
        children: [
          destination.imageAsset != null
              ? Image.asset(destination.imageAsset!, fit: BoxFit.cover)
              : ColoredBox(color: destination.imagePlaceholderColor),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.neutral900.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
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
                        destination.title,
                        style: AppTextStyles.bookingCardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${destination.location}, Nicaragua',
                        style: AppTextStyles.heroLocation.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
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
    final (label, color) = switch (status) {
      BookingStatus.confirmada => ('Confirmada', AppColors.bookingConfirmed),
      BookingStatus.pendiente => ('Pendiente', AppColors.bookingPending),
      BookingStatus.completada => ('Completada', AppColors.neutral800),
      BookingStatus.cancelada => ('Cancelada', AppColors.bookingPending),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: AppTextStyles.bookingStatusChip.copyWith(color: color)),
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
                style: AppTextStyles.bookingActionLabel.copyWith(color: textColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
