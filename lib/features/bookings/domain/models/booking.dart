import 'package:nikara_app/features/business/domain/models/business_model.dart';

/// Mirrors Supabase's `public.bookings.status` enum (`booking_status`)
/// exactly — the member names below (`.name`) are sent/read as-is against
/// Postgres.
enum BookingStatus { pendiente, confirmada, completada, cancelada }

BookingStatus bookingStatusFromString(String? raw) {
  switch (raw) {
    case 'confirmada':
      return BookingStatus.confirmada;
    case 'completada':
      return BookingStatus.completada;
    case 'cancelada':
      return BookingStatus.cancelada;
    default:
      return BookingStatus.pendiente;
  }
}

/// A row from Supabase's `bookings` table, joined with its real owning
/// [business] (`select('*, businesses(*)')` in [BookingService]) — there is
/// no local/mock stand-in for either half of this data.
class BookingModel {
  const BookingModel({
    required this.id,
    required this.business,
    required this.scheduledAt,
    required this.partySize,
    required this.code,
    required this.totalPaid,
    required this.status,
  });

  final String id;
  final BusinessModel business;
  final DateTime scheduledAt;
  final int partySize;
  final String code;
  final double totalPaid;
  final BookingStatus status;

  String get formattedTotal => 'C\$${totalPaid.toStringAsFixed(0)}';

  static const _monthAbbreviations = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  /// e.g. "20 Jul 2026" — formatted by hand (no `intl` dependency) to match
  /// the rest of the app's self-contained formatting getters.
  String get formattedDate {
    final month = _monthAbbreviations[scheduledAt.month - 1];
    final capitalized = month[0].toUpperCase() + month.substring(1);
    return '${scheduledAt.day} $capitalized ${scheduledAt.year}';
  }

  /// e.g. "8:00 AM" — 12-hour clock, formatted by hand for the same reason.
  String get formattedTime {
    final hour12 = scheduledAt.hour % 12 == 0 ? 12 : scheduledAt.hour % 12;
    final period = scheduledAt.hour < 12 ? 'AM' : 'PM';
    final minute = scheduledAt.minute.toString().padLeft(2, '0');
    return '$hour12:$minute $period';
  }
}
