import 'package:flutter/material.dart';

import 'package:nikara_app/features/bookings/data/booking_service.dart';
import 'package:nikara_app/features/bookings/domain/models/booking.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/theme/app_theme.dart';

const List<String> _kMonthAbbreviations = [
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

/// Bottom sheet form for creating a real reservation against [business] —
/// date, time and party size, with a live total preview computed the same
/// way [BookingService.createBooking] computes it (see
/// [BookingService.estimateTotal]). Pops with the created [BookingModel] on
/// success, or nothing if the user backs out.
class BookingRequestSheet extends StatefulWidget {
  const BookingRequestSheet({super.key, required this.business});

  final BusinessModel business;

  @override
  State<BookingRequestSheet> createState() => _BookingRequestSheetState();
}

class _BookingRequestSheetState extends State<BookingRequestSheet> {
  final _bookingService = BookingService();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _partySize = 2;
  bool _isSubmitting = false;

  double get _estimatedTotal =>
      BookingService.estimateTotal(widget.business, _partySize);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today.add(const Duration(days: 1)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _changePartySize(int delta) {
    setState(() => _partySize = (_partySize + delta).clamp(1, 20));
  }

  Future<void> _confirm() async {
    final date = _selectedDate;
    final time = _selectedTime;
    if (date == null || time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una fecha y hora para tu reserva.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final scheduledAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    try {
      final booking = await _bookingService.createBooking(
        business: widget.business,
        scheduledAt: scheduledAt,
        partySize: _partySize,
      );
      if (!mounted) return;
      Navigator.of(context).pop(booking);
    } on BookingServiceException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  String _formatDate(DateTime date) {
    final month = _kMonthAbbreviations[date.month - 1];
    final capitalized = month[0].toUpperCase() + month.substring(1);
    return '${date.day} $capitalized ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Reservar en ${widget.business.name}',
                    style: AppTextStyles.detailSectionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.segmentedTrackBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.neutral900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Fecha y hora',
              style: AppTextStyles.detailRowText.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _PickerField(
                    icon: Icons.calendar_today,
                    label: _selectedDate == null
                        ? 'Elegir fecha'
                        : _formatDate(_selectedDate!),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerField(
                    icon: Icons.access_time,
                    label: _selectedTime == null
                        ? 'Elegir hora'
                        : _selectedTime!.format(context),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Cantidad de personas',
              style: AppTextStyles.detailRowText.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface200.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.neutral600.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_partySize ${_partySize == 1 ? 'persona' : 'personas'}',
                    style: AppTextStyles.detailRowText,
                  ),
                  Row(
                    children: [
                      _StepperButton(
                        icon: Icons.remove,
                        onTap: () => _changePartySize(-1),
                      ),
                      const SizedBox(width: 12),
                      _StepperButton(
                        icon: Icons.add,
                        onTap: () => _changePartySize(1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary500.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total estimado', style: AppTextStyles.detailRowText),
                  Text(
                    'C\$${_estimatedTotal.toStringAsFixed(0)}',
                    style: AppTextStyles.listCardPrice,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  disabledBackgroundColor: AppColors.primary500.withValues(
                    alpha: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(
                            AppColors.textInk,
                          ),
                        ),
                      )
                    : Text(
                        'Confirmar reserva',
                        style: AppTextStyles.buttonLg.copyWith(
                          color: AppColors.textInk,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.neutral600.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primary700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.detailRowText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.primary500,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: AppColors.textInk),
      ),
    );
  }
}
