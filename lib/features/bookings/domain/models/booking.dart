enum BookingStatus { confirmada, pendiente, completada, cancelada }

class Booking {
  const Booking({
    required this.id,
    required this.destinationId,
    required this.date,
    required this.time,
    required this.partySize,
    required this.code,
    required this.totalPaid,
    required this.status,
  });

  final String id;
  final String destinationId;
  final String date;
  final String time;
  final int partySize;
  final String code;
  final double totalPaid;
  final BookingStatus status;

  String get formattedTotal => 'C\$${totalPaid.toStringAsFixed(0)}';

  Booking copyWith({BookingStatus? status}) => Booking(
    id: id,
    destinationId: destinationId,
    date: date,
    time: time,
    partySize: partySize,
    code: code,
    totalPaid: totalPaid,
    status: status ?? this.status,
  );
}

const List<Booking> mockBookings = [
  Booking(
    id: 'b1',
    destinationId: 'laguna-de-apoyo',
    date: '20 Jul 2026',
    time: '8:00 AM',
    partySize: 2,
    code: 'NKR-2847',
    totalPaid: 725,
    status: BookingStatus.confirmada,
  ),
  Booking(
    id: 'b2',
    destinationId: 'isletas-de-granada',
    date: '5 Ago 2026',
    time: '9:30 AM',
    partySize: 3,
    code: 'NKR-2831',
    totalPaid: 1455,
    status: BookingStatus.pendiente,
  ),
  Booking(
    id: 'b3',
    destinationId: 'playa-maderas',
    date: '12 Jun 2026',
    time: '7:00 AM',
    partySize: 2,
    code: 'NKR-2719',
    totalPaid: 605,
    status: BookingStatus.completada,
  ),
  Booking(
    id: 'b4',
    destinationId: 'volcan-telica',
    date: '3 May 2026',
    time: '6:00 AM',
    partySize: 4,
    code: 'NKR-2680',
    totalPaid: 1680,
    status: BookingStatus.completada,
  ),
];
