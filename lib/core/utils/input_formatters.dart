import 'package:flutter/services.dart';

/// Formatea un número móvil nicaragüense como "XXXX-XXXX"; el prefijo "+505" se muestra aparte vía `prefixText` para evitar el bug clásico del cursor saltando al formatear texto no editable.
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
