import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/bookings/domain/models/booking.dart';

class BookingServiceException implements Exception {
  const BookingServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads and creates the signed-in user's real reservations in Supabase's
/// `bookings` table, joined with their owning `businesses` row (`select('*,
/// businesses(*)')`) so every card has the real business name, location,
/// photo and category without a second round-trip.
class BookingService {
  final _client = Supabase.instance.client;
  final _businessStorageService = BusinessStorageService();

  /// Fallback per-person rate for a business that has `allowsReservations`
  /// but never set [BusinessModel.price] in the wizard — keeps totals
  /// meaningful instead of charging C$0.
  static const double basePricePerPerson = 300;

  /// Bumped on every successful [createBooking] — [BookingsScreen] listens
  /// to this (same pattern as [BusinessStorageService.revision]) so a fresh
  /// reservation shows up immediately after switching to that tab, without
  /// needing a manual refresh.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static double estimateTotal(BusinessModel business, int partySize) {
    final pricePerPerson = business.price ?? basePricePerPerson;
    return pricePerPerson * partySize;
  }

  /// Empty (not an error) when nobody is signed in — callers reach this
  /// screen only from behind the auth gate, but a signed-out edge case
  /// should show "no bookings", not crash on a null user id.
  Future<List<BookingModel>> getMyBookings() async {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) return const [];

    try {
      final rows = await _client
          .from('bookings')
          .select('*, businesses(*)')
          .eq('user_id', userId)
          .order('scheduled_at', ascending: false);
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_fromRow)
          // A booking whose business join came back empty points at a data
          // integrity problem (shouldn't happen — `business_id` is a NOT
          // NULL FK with `on delete cascade`), not something to crash the
          // whole list over.
          .whereType<BookingModel>()
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw BookingServiceException(
        'No se pudieron cargar tus reservas: ${e.message}',
      );
    } catch (_) {
      throw const BookingServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Inserts a new `pendiente` booking for the signed-in user and returns
  /// it (re-fetched with its `businesses` join, so the caller gets back a
  /// fully-formed [BookingModel] — including the row's real `id` and
  /// `created_at` — without a second query).
  Future<BookingModel> createBooking({
    required BusinessModel business,
    required DateTime scheduledAt,
    required int partySize,
  }) async {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) {
      throw const BookingServiceException(
        'Debes iniciar sesión para reservar.',
      );
    }

    final totalPaid = estimateTotal(business, partySize);

    // `code` is UNIQUE in Postgres — a client-generated 4-char code could
    // in principle collide with an existing one. Vanishingly unlikely, but
    // retried instead of surfacing a cryptic unique-violation error.
    const maxAttempts = 5;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final row = await _client
            .from('bookings')
            .insert({
              'business_id': business.id,
              'user_id': userId,
              'scheduled_at': scheduledAt.toUtc().toIso8601String(),
              'party_size': partySize,
              'code': _generateCode(),
              'total_paid': totalPaid,
              'status': BookingStatus.pendiente.name,
            })
            .select('*, businesses(*)')
            .single();
        final booking = _fromRow(row);
        if (booking == null) {
          throw const BookingServiceException(
            'No se pudo confirmar la reserva. Intenta de nuevo.',
          );
        }
        revision.value++;
        return booking;
      } on PostgrestException catch (e) {
        final isDuplicateCode = e.code == '23505';
        if (isDuplicateCode && attempt < maxAttempts - 1) continue;
        throw BookingServiceException(
          'No se pudo crear la reserva: ${e.message}',
        );
      } catch (_) {
        throw const BookingServiceException(
          'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
        );
      }
    }
    // Unreachable in practice (the loop always returns or throws), but
    // keeps the method's return type sound.
    throw const BookingServiceException(
      'No se pudo generar un código único. Intenta de nuevo.',
    );
  }

  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final _codeRandom = Random();

  /// e.g. "NKR-7F2K" — 4 uppercase alphanumeric characters (ambiguous
  /// glyphs like 0/O and 1/I excluded on purpose, so a printed code is
  /// never mistaken for a different one).
  String _generateCode() {
    final chars = List.generate(
      4,
      (_) => _codeChars[_codeRandom.nextInt(_codeChars.length)],
    ).join();
    return 'NKR-$chars';
  }

  BookingModel? _fromRow(Map<String, dynamic> row) {
    final businessRow = row['businesses'] as Map<String, dynamic>?;
    if (businessRow == null) return null;
    return BookingModel(
      id: row['id'] as String,
      business: _businessStorageService.businessFromRow(businessRow),
      scheduledAt: DateTime.parse(row['scheduled_at'] as String),
      partySize: (row['party_size'] as num?)?.toInt() ?? 1,
      code: row['code'] as String? ?? '',
      totalPaid: (row['total_paid'] as num?)?.toDouble() ?? 0,
      status: bookingStatusFromString(row['status'] as String?),
    );
  }
}
