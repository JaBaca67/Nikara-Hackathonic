import 'package:flutter_test/flutter_test.dart';

import 'package:nikara_app/core/utils/input_sanitizers.dart';

/// `input_sanitizers.dart` es el único punto por el que pasan **todas** las
/// escrituras de texto a Supabase (lo importan `business_storage_service`,
/// `eco_service`, `review_service` y `legal_identity_service`), y hasta hoy no
/// tenía ninguna prueba. Su lógica no es trivial: pares sustitutos de emoji,
/// prefijos telefónicos ambiguos, handles extraídos de una URL pegada y
/// partículas de nombres compuestos.
///
/// Los caracteres invisibles van siempre como escape (`\u200B`) y nunca
/// literales: pegados en el fuente son imposibles de ver al leer el test, que
/// es exactamente el problema que estas funciones existen para resolver.
///
/// Las funciones son puras y no dependen de Flutter, así que este archivo no
/// necesita el bootstrap de Supabase/SharedPreferences que sí piden los widget
/// tests del proyecto.
void main() {
  group('sanitizeText', () {
    test('recorta los costados y colapsa espacios internos', () {
      expect(sanitizeText('  Café   Luna  '), 'Café Luna');
    });

    test('colapsa saltos de línea: un nombre de una línea no los admite', () {
      expect(sanitizeText('Café\nLuna'), 'Café Luna');
      expect(sanitizeText('Café\r\nLuna'), 'Café Luna');
    });

    test('borra invisibles pegados desde WhatsApp o Word', () {
      // Zero-width space y BOM: hacen que dos nombres idénticos a la vista no
      // sean iguales para Postgres, y son imposibles de ver al depurar.
      expect(sanitizeText('\u200BCafé\uFEFF Luna'), 'Café Luna');
      expect(sanitizeText('Café\u200D\u2060Luna'), 'CaféLuna');
    });

    test('U+2028 es un salto real: separa, no pega las palabras', () {
      // Word y macOS lo insertan al pegar. Antes estaba entre los
      // invisibles a borrar y "Hola" + salto + "Mundo" quedaba "HolaMundo".
      expect(sanitizeText('Hola\u2028Mundo'), 'Hola Mundo');
      expect(sanitizeText('Hola\u2029Mundo'), 'Hola Mundo');
    });

    test('borra los controles bidireccionales', () {
      expect(sanitizeText('\u202ECafé'), 'Café');
    });

    test('reemplaza los espacios exóticos por uno normal, no los borra', () {
      expect(sanitizeText('Café\u00A0Luna'), 'Café Luna');
      expect(sanitizeText('Café\u3000Luna'), 'Café Luna');
      expect(sanitizeText('Café\tLuna'), 'Café Luna');
    });

    test('endereza las comillas curvas de iOS y Word', () {
      expect(sanitizeText('“Café”'), '"Café"');
      expect(sanitizeText('D’Angelo'), "D'Angelo");
    });

    test('deja las comillas angulares: son ortografía española válida', () {
      expect(sanitizeText('«Café Luna»'), '«Café Luna»');
    });

    test('null y vacío devuelven cadena vacía, nunca null', () {
      expect(sanitizeText(null), '');
      expect(sanitizeText('   '), '');
    });

    test('trunca al tope y recorta el espacio que quede al final', () {
      expect(sanitizeText('abcdef', maxLength: 4), 'abcd');
      expect(sanitizeText('abc def', maxLength: 4), 'abc');
    });

    test('el tope por defecto es mediumText', () {
      final largo = 'a' * (InputLimits.mediumText + 50);
      expect(sanitizeText(largo).length, InputLimits.mediumText);
    });
  });

  group('sanitizeText — pares sustitutos', () {
    test('no parte un emoji por la mitad al truncar', () {
      // Un emoji son dos code units: cortar en 5 dejaría un high surrogate
      // suelto, que es UTF-8 inválido y hace fallar el insert con un error
      // críptico de Postgres.
      final result = sanitizeText('abcd\u{1F600}', maxLength: 5);

      expect(result, 'abcd');
      expect(
        result.codeUnits.every((u) => u < 0xD800 || u > 0xDFFF),
        isTrue,
        reason: 'no debe quedar ningún surrogate huérfano',
      );
    });

    test('conserva el emoji completo cuando sí entra', () {
      expect(sanitizeText('abcd\u{1F600}', maxLength: 6), 'abcd\u{1F600}');
    });

    test('un texto de solo emojis sobrevive al recorte', () {
      final result = sanitizeText('\u{1F600}\u{1F600}\u{1F600}', maxLength: 5);

      expect(result, '\u{1F600}\u{1F600}');
      expect(() => result.runes.toList(), returnsNormally);
    });
  });

  group('sanitizeOptionalText', () {
    test('distingue "vacío" de "sin dato" para columnas nullable', () {
      expect(sanitizeOptionalText('  '), isNull);
      expect(sanitizeOptionalText(null), isNull);
      expect(sanitizeOptionalText(' Hola '), 'Hola');
    });
  });

  group('sanitizeMultilineText', () {
    test('conserva el salto de párrafo', () {
      expect(sanitizeMultilineText('Uno\n\nDos'), 'Uno\n\nDos');
    });

    test('corta la escalera de enters a un solo párrafo', () {
      expect(sanitizeMultilineText('Uno\n\n\n\n\nDos'), 'Uno\n\nDos');
    });

    test('recorta cada línea y los extremos del bloque', () {
      expect(sanitizeMultilineText('  Uno  \n   Dos   '), 'Uno\nDos');
    });

    test('la descripción con 40 enters al final deja de ser una torre', () {
      expect(sanitizeMultilineText('Hola${'\n' * 40}'), 'Hola');
    });

    test('U+2028 se conserva como salto en el texto multilinea', () {
      expect(sanitizeMultilineText('Uno\u2028Dos'), 'Uno\nDos');
    });

    test('el tope por defecto es description', () {
      final largo = 'a' * (InputLimits.description + 100);
      expect(sanitizeMultilineText(largo).length, InputLimits.description);
    });
  });

  group('sanitizeProperName', () {
    test('capitaliza lo que llega todo en minúscula del teclado móvil', () {
      expect(sanitizeProperName('juan pérez'), 'Juan Pérez');
    });

    test('no toca una palabra que ya trae mayúsculas: siglas y marcas', () {
      expect(sanitizeProperName('ONG verde'), 'ONG Verde');
      expect(sanitizeProperName('McDonald'), 'McDonald');
      expect(sanitizeProperName('iNikara'), 'iNikara');
    });

    test('deja en minúscula las partículas intermedias', () {
      expect(sanitizeProperName('juan de la cruz'), 'Juan de la Cruz');
      expect(sanitizeProperName('maría del carmen'), 'María del Carmen');
    });

    test('pero capitaliza la partícula si abre el nombre', () {
      expect(sanitizeProperName('de la cruz'), 'De la Cruz');
    });

    test('capitaliza después de guion, apóstrofo y punto', () {
      expect(sanitizeProperName('jean-luc'), 'Jean-Luc');
      expect(sanitizeProperName("d'angelo"), "D'Angelo");
    });

    test('vacío y null no explotan', () {
      expect(sanitizeProperName(null), '');
      expect(sanitizeProperName('  '), '');
    });
  });

  group('sanitizeTextList', () {
    test('descarta vacíos y duplicados sin importar mayúsculas', () {
      expect(sanitizeTextList(['Guantes', 'guantes', '  ', 'Botas']), [
        'Guantes',
        'Botas',
      ]);
    });

    test('acota el largo de la lista', () {
      final muchos = List.generate(50, (i) => 'item-$i');
      expect(sanitizeTextList(muchos, maxItems: 3), [
        'item-0',
        'item-1',
        'item-2',
      ]);
    });

    test('devuelve una lista no modificable', () {
      final result = sanitizeTextList(['Guantes']);
      expect(() => result.add('otro'), throwsUnsupportedError);
    });

    test('null y lista vacía devuelven lista vacía', () {
      expect(sanitizeTextList(null), isEmpty);
      expect(sanitizeTextList([]), isEmpty);
    });
  });

  group('sanitizeEmail', () {
    test('baja a minúsculas: si no, son dos cuentas distintas', () {
      expect(sanitizeEmail('Jose@X.com'), 'jose@x.com');
    });

    test('quita espacios y el prefijo mailto: de un enlace pegado', () {
      expect(sanitizeEmail('  mailto:jose@x.com '), 'jose@x.com');
      expect(sanitizeEmail('MAILTO:Jose@X.com'), 'jose@x.com');
      expect(sanitizeEmail('jose @ x.com'), 'jose@x.com');
    });

    test('null devuelve vacío', () {
      expect(sanitizeEmail(null), '');
    });
  });

  group('sanitizePhone', () {
    test('8 dígitos sueltos son un móvil nicaragüense agrupado', () {
      expect(sanitizePhone('88887777'), '+505 8888-7777');
      expect(sanitizePhone('8888-7777'), '+505 8888-7777');
      expect(sanitizePhone(' 8888 7777 '), '+505 8888-7777');
    });

    test('un local que empieza con 505 no se confunde con el código', () {
      // Es el caso que justifica la rama de 8 dígitos: tomar "505" como código
      // dejaría un número de 5 dígitos, que no existe.
      expect(sanitizePhone('5055-1234'), '+505 5055-1234');
    });

    test('acepta el código explícito con + y con 00', () {
      expect(sanitizePhone('+505 8888 7777'), '+505 8888-7777');
      expect(sanitizePhone('00505 8888 7777'), '+505 8888-7777');
      expect(sanitizePhone('+50588887777'), '+505 8888-7777');
    });

    test('otros países reconocidos no se agrupan con guion', () {
      expect(sanitizePhone('+506 88887777'), '+506 88887777');
      expect(sanitizePhone('+1 5551234567'), '+1 5551234567');
    });

    test(
      'un código desconocido se conserva en vez de forzarlo a Nicaragua',
      () {
        expect(sanitizePhone('+999123456'), '+999123456');
      },
    );

    test('un código de un solo dígito exige el + explícito', () {
      // Sin esto, un local con un dígito de más al tipear se guardaba como
      // teléfono de EE. UU.: '123456789' daba '+1 23456789'.
      expect(sanitizePhone('123456789'), '+505 123456789');
      expect(sanitizePhone('+1 5551234567'), '+1 5551234567');
      expect(sanitizePhone('001 5551234567'), '+1 5551234567');
    });

    test('pero un código de 3 dígitos sí se reconoce sin el +', () {
      // Pegar el número completo sin el + es un caso real y común.
      expect(sanitizePhone('50588887777'), '+505 8888-7777');
      expect(sanitizePhone('50688887777'), '+506 88887777');
    });

    test('es idempotente: sanear lo ya saneado no lo cambia', () {
      const canonico = '+505 8888-7777';
      expect(sanitizePhone(canonico), canonico);
      expect(sanitizePhone(sanitizePhone('88887777')), canonico);
    });

    test('vacío, null y texto sin dígitos devuelven vacío', () {
      expect(sanitizePhone(null), '');
      expect(sanitizePhone('   '), '');
      expect(sanitizePhone('sin número'), '');
    });
  });

  group('phoneToE164', () {
    test('deriva la forma E.164 del canónico', () {
      expect(phoneToE164('8888-7777'), '+50588887777');
      expect(phoneToE164('+506 88887777'), '+50688887777');
    });

    test('vacío queda vacío, no "+"', () {
      expect(phoneToE164(null), '');
      expect(phoneToE164('sin número'), '');
    });
  });

  group('handles de redes sociales', () {
    test('Instagram: extrae el handle de una URL pegada completa', () {
      expect(
        sanitizeInstagramHandle('https://www.instagram.com/cafe.luna/'),
        'cafe.luna',
      );
      expect(
        sanitizeInstagramHandle('instagram.com/cafe.luna?hl=es'),
        'cafe.luna',
      );
    });

    test('Instagram: quita la arroba y baja a minúsculas', () {
      expect(sanitizeInstagramHandle('@Cafe_Luna'), 'cafe_luna');
    });

    test('Facebook: conserva la capitalización y el guion de las páginas', () {
      expect(
        sanitizeFacebookHandle('facebook.com/Cafe-Las-Flores-123456'),
        'Cafe-Las-Flores-123456',
      );
    });

    test('Facebook: rescata el id numérico de un profile.php', () {
      expect(
        sanitizeFacebookHandle('https://facebook.com/profile.php?id=123456'),
        '123456',
      );
    });

    test('TikTok: minúsculas y sin arroba', () {
      expect(
        sanitizeTiktokHandle('https://tiktok.com/@Cafe.Luna'),
        'cafe.luna',
      );
    });

    test('un handle no empieza ni termina en punto', () {
      expect(sanitizeInstagramHandle('.cafe.luna.'), 'cafe.luna');
    });

    test('handle de fundación: sin puntos ni guiones bajos al inicio', () {
      expect(
        sanitizeOrganizationHandle('@_Fundacion.Verde'),
        'fundacion.verde',
      );
    });

    test('null y vacío devuelven vacío', () {
      expect(sanitizeInstagramHandle(null), '');
      expect(sanitizeFacebookHandle('   '), '');
    });
  });

  group('identidad legal', () {
    test('conserva los guiones de la cédula: son parte del formato', () {
      expect(
        sanitizeLegalDocumentNumber(' 001-201208-1009s '),
        '001-201208-1009S',
      );
    });

    test('la cédula saneada pasa su patrón', () {
      expect(
        cedulaPattern.hasMatch(sanitizeLegalDocumentNumber('001-201208-1009s')),
        isTrue,
      );
    });

    test('RUC: J + 13 dígitos, sin guiones', () {
      expect(rucPattern.hasMatch('J0310000000001'), isTrue);
      expect(
        rucPattern.hasMatch('J031000000000'),
        isFalse,
        reason: '12 dígitos',
      );
      expect(rucPattern.hasMatch('001-201208-1009S'), isFalse);
    });

    test('persona natural sin cédula: N + 13 dígitos', () {
      expect(cedulaSinDocumentoPattern.hasMatch('N0000000000019'), isTrue);
      expect(cedulaSinDocumentoPattern.hasMatch('J0000000000019'), isFalse);
    });

    test('los tres patrones son mutuamente excluyentes', () {
      const ruc = 'J0310000000001';
      const cedula = '001-201208-1009S';
      const sinDoc = 'N0000000000019';

      expect(cedulaPattern.hasMatch(ruc), isFalse);
      expect(cedulaSinDocumentoPattern.hasMatch(ruc), isFalse);
      expect(rucPattern.hasMatch(cedula), isFalse);
      expect(rucPattern.hasMatch(sinDoc), isFalse);
      expect(cedulaPattern.hasMatch(sinDoc), isFalse);
    });
  });

  group('sanitizeHttpUrl', () {
    test('acepta http y https', () {
      expect(
        sanitizeHttpUrl('https://x.supabase.co/storage/logo.png'),
        'https://x.supabase.co/storage/logo.png',
      );
      expect(sanitizeHttpUrl('http://x.com/a.png'), 'http://x.com/a.png');
    });

    test('rechaza los esquemas que terminarían en un Image.network', () {
      expect(sanitizeHttpUrl('javascript:alert(1)'), isNull);
      expect(sanitizeHttpUrl('data:text/html;base64,PHNjcmlwdD4='), isNull);
      expect(sanitizeHttpUrl('file:///etc/passwd'), isNull);
    });

    test('rechaza una URL con esquema pero sin host', () {
      expect(sanitizeHttpUrl('https://'), isNull);
      expect(sanitizeHttpUrl('https:///logo.png'), isNull);
    });

    test('rechaza una ruta sin esquema', () {
      expect(sanitizeHttpUrl('//x.com/a.png'), isNull);
      expect(sanitizeHttpUrl('x.com/a.png'), isNull);
    });

    test('null y vacío devuelven null', () {
      expect(sanitizeHttpUrl(null), isNull);
      expect(sanitizeHttpUrl('  '), isNull);
    });
  });
}
