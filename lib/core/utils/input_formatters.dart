import 'package:flutter/services.dart';

/// Mayúsculas mientras se escribe — para RUC/cédula (`legal_identities`),
/// donde un mismo documento no debería guardarse distinto según cómo lo haya
/// tipeado cada persona.
class UppercaseTextInputFormatter extends TextInputFormatter {
  const UppercaseTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// Formatea una cédula nicaragüense como "001-201208-1009S" mientras se
/// escribe (departamento/municipio 3 + fecha de nacimiento 6 + control 4 +
/// letra) — mismo criterio que `NicaraguaPhoneInputFormatter`: agrupar en
/// vivo, no solo al guardar, para que un mismo dato no se vea distinto según
/// qué formulario lo pida.
class CedulaInputFormatter extends TextInputFormatter {
  const CedulaInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    final trimmed = raw.length > 14 ? raw.substring(0, 14) : raw;

    final buffer = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      if (i == 3 || i == 9) buffer.write('-');
      buffer.write(trimmed[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

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
