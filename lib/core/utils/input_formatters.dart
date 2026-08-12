import 'package:flutter/services.dart';

/// Formats a Nicaraguan mobile number as the user types digits, producing
/// "XXXX-XXXX" (the "+505 " country-code prefix is shown separately via
/// the field's `prefixText`, never mixed into the editable value — that
/// keeps the formatter simple and avoids the classic "cursor jumps to the
/// wrong place" bug that comes from formatting a prefix the user can't
/// actually edit).
class NicaraguaPhoneInputFormatter extends TextInputFormatter {
  const NicaraguaPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final allDigits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final digits = allDigits.length > 8 ? allDigits.substring(0, 8) : allDigits;

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 4) buffer.write('-');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
