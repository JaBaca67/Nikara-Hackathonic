import 'package:flutter_test/flutter_test.dart';

import 'package:nikara_app/core/utils/validators.dart';

/// Contraparte de `test/input_sanitizers_test.dart`: estos validadores son los
/// que las pantallas pasan al `validator:` de un `TextFormField`, y desde el
/// 2026-10-03 están cableados en `register_screen`, `login_screen` y
/// `settings_screen` en vez de la lambda inline que cada una tenía.
///
/// Un validador devuelve `null` cuando el valor sirve, así que `isNull` se lee
/// como "válido" en todo el archivo.
void main() {
  group('validateEmail', () {
    test('acepta dominios con más de un punto', () {
      // El validador inline que esto reemplazó exigía
      // `[\w-]+\.[A-Za-z]{2,}$`, o sea un único punto en el dominio: rechazaba
      // todo correo institucional (`@uamv.edu.ni`) y todo `.co.uk`. Estaba
      // duplicado byte a byte en tres pantallas.
      expect(validateEmail('jabaca@uamv.edu.ni'), isNull);
      expect(validateEmail('jose@mail.co.uk'), isNull);
      expect(validateEmail('jose@x.com'), isNull);
    });

    test('valida sobre el valor saneado, no el crudo', () {
      // El campo rechazaría algo que el servicio habría aceptado si no
      // compartieran el saneo.
      expect(validateEmail('  JOSE@X.COM  '), isNull);
      expect(validateEmail('mailto:jose@x.com'), isNull);
    });

    test('rechaza lo que de verdad no es un correo', () {
      expect(validateEmail('jose'), isNotNull);
      expect(validateEmail('jose@'), isNotNull);
      expect(validateEmail('jose@x'), isNotNull);
      expect(validateEmail('@x.com'), isNotNull);
      expect(validateEmail('jose@@x.com'), isNotNull);
    });

    test('vacío y null piden el correo', () {
      expect(validateEmail(null), 'Escribe tu correo electrónico.');
      expect(validateEmail('   '), 'Escribe tu correo electrónico.');
    });
  });

  group('validatePhone', () {
    test('acepta un móvil nicaragüense escrito de cualquier forma', () {
      expect(validatePhone('88887777'), isNull);
      expect(validatePhone('8888-7777'), isNull);
      expect(validatePhone('+505 8888-7777'), isNull);
      expect(validatePhone('0050588887777'), isNull);
    });

    test('un número nicaragüense con otra cantidad de dígitos no pasa', () {
      expect(
        validatePhone('8888777'),
        'Un número de Nicaragua tiene 8 dígitos.',
      );
      expect(
        validatePhone('888877771'),
        'Un número de Nicaragua tiene 8 dígitos.',
      );
    });

    test('required en false acepta el campo vacío', () {
      expect(validatePhone('', required: false), isNull);
      expect(validatePhone(null, required: false), isNull);
    });

    test('pero vacío con required sí pide el número', () {
      expect(validatePhone(''), 'Escribe un número de teléfono.');
    });

    test('texto sin dígitos no pasa', () {
      expect(validatePhone('no tengo'), isNotNull);
    });
  });

  group('validatePhone — dialCode de un selector aparte', () {
    test('un número de 10 dígitos marcado como de EE. UU. es válido', () {
      // Sin dialCode se leería como nicaragüense y el error hablaría de
      // Nicaragua a alguien que eligió otro país en el selector.
      expect(validatePhone('5551234567', dialCode: '+1'), isNull);
      expect(validatePhone('5551234567', dialCode: '1'), isNull);
    });

    test('ese mismo número sin dialCode falla hablando de Nicaragua', () {
      expect(
        validatePhone('5551234567'),
        'Un número de Nicaragua tiene 8 dígitos.',
      );
    });

    test('con dialCode de Nicaragua sigue exigiendo los 8 dígitos', () {
      expect(validatePhone('88887777', dialCode: '+505'), isNull);
      expect(
        validatePhone('888877', dialCode: '+505'),
        'Un número de Nicaragua tiene 8 dígitos.',
      );
    });

    test('un dialCode vacío se comporta como no pasarlo', () {
      expect(validatePhone('88887777', dialCode: ''), isNull);
      expect(validatePhone('88887777', dialCode: '   '), isNull);
    });

    test('el campo vacío pide el número en vez de hablar de dígitos', () {
      // Con el código del selector adelante, un campo vacío llegaría al
      // sanitizador como "+505" y el mensaje sería el equivocado.
      expect(
        validatePhone('', dialCode: '+505'),
        'Escribe un número de teléfono.',
      );
    });
  });

  group('validatePassword', () {
    test('exige 8 caracteres, no 6', () {
      // Las pantallas pedían 6 por su cuenta. 8 es el mínimo que este
      // proyecto adelanta para no gastar un viaje de red en que Supabase
      // diga lo mismo.
      expect(validatePassword('1234567'), isNotNull);
      expect(validatePassword('12345678'), isNull);
    });

    test('rechaza espacios al principio o al final', () {
      expect(validatePassword(' contrasena'), isNotNull);
      expect(validatePassword('contrasena '), isNotNull);
      expect(validatePassword('con trasena'), isNull);
    });

    test('vacío y null piden una contraseña', () {
      expect(validatePassword(''), 'Escribe una contraseña.');
      expect(validatePassword(null), 'Escribe una contraseña.');
    });
  });

  group('validateLoginPassword', () {
    test('al iniciar sesión solo exige que haya algo escrito', () {
      // La contraseña correcta es la que la cuenta ya tiene: medir fuerza
      // acá solo puede rechazar a alguien legítimo.
      expect(validateLoginPassword('123456'), isNull);
      expect(validateLoginPassword('abc'), isNull);
      expect(validateLoginPassword('  '), isNull);
    });

    test('vacío y null piden la contraseña', () {
      expect(validateLoginPassword(''), 'Escribe tu contraseña.');
      expect(validateLoginPassword(null), 'Escribe tu contraseña.');
    });

    test('es más permisivo que el de registro, a propósito', () {
      const debil = '123456';
      expect(validateLoginPassword(debil), isNull);
      expect(validatePassword(debil), isNotNull);
    });
  });

  group('validatePasswordConfirmation', () {
    test('compara exacto, sin sanear', () {
      expect(validatePasswordConfirmation('abc12345', 'abc12345'), isNull);
      expect(
        validatePasswordConfirmation('abc12345', 'abc12346'),
        'Las contraseñas no coinciden.',
      );
    });

    test('vacío pide repetirla', () {
      expect(
        validatePasswordConfirmation('', 'abc12345'),
        'Repite la contraseña.',
      );
    });
  });

  group('validateUsername', () {
    test('acepta letras, dígitos, punto y guion bajo', () {
      expect(validateUsername('samy.ixchel'), isNull);
      expect(validateUsername('jose_2026'), isNull);
    });

    test('exige al menos 3 caracteres', () {
      expect(
        validateUsername('ab'),
        'El nombre de usuario debe tener al menos 3 caracteres.',
      );
    });

    test(
      'rechaza acentos y eñes: dos usuarios no deben verse casi iguales',
      () {
        expect(
          validateUsername('josé'),
          'Solo letras, números, puntos y guiones bajos.',
        );
        expect(
          validateUsername('niño'),
          'Solo letras, números, puntos y guiones bajos.',
        );
      },
    );

    test('rechaza espacios y símbolos', () {
      expect(validateUsername('samy ixchel'), isNotNull);
      expect(validateUsername('samy@ixchel'), isNotNull);
    });

    test('vacío y null piden elegir uno', () {
      expect(validateUsername(null), 'Elige un nombre de usuario.');
      expect(validateUsername('  '), 'Elige un nombre de usuario.');
    });
  });

  group('validateFullName', () {
    test('acepta un nombre normal, ya saneado', () {
      expect(validateFullName('  juan   pérez '), isNull);
    });

    test('exige al menos una letra', () {
      expect(
        validateFullName('123'),
        'El nombre debe tener al menos una letra.',
      );
      expect(validateFullName('...'), isNotNull);
    });

    test('vacío pide el nombre', () {
      expect(validateFullName(''), 'Escribe tu nombre completo.');
    });
  });

  group('validateRequiredText', () {
    test('nombra el campo en el mensaje', () {
      expect(
        validateRequiredText('', label: 'tu nombre'),
        'Completa tu nombre.',
      );
    });

    test('aplica el mínimo pedido', () {
      expect(validateRequiredText('a', label: 'tu nombre'), isNotNull);
      expect(validateRequiredText('Ab', label: 'tu nombre'), isNull);
    });

    test('un valor de solo espacios cuenta como vacío', () {
      expect(
        validateRequiredText('   ', label: 'la ciudad'),
        'Completa la ciudad.',
      );
    });
  });

  group('validateEntityName y validateTitle', () {
    test('exigen 3 caracteres y una letra', () {
      expect(validateEntityName('Ca'), isNotNull);
      expect(validateEntityName('Café Luna'), isNull);
      expect(validateEntityName('123'), isNotNull);
    });

    test('el label aparece en el mensaje', () {
      expect(
        validateEntityName('', label: 'nombre del negocio'),
        'Escribe el nombre del negocio.',
      );
      expect(validateTitle(''), 'Escribe el título.');
    });
  });

  group('validateCapacity', () {
    test('vacío es válido: significa sin tope', () {
      expect(validateCapacity(''), isNull);
      expect(validateCapacity(null), isNull);
    });

    test('rechaza lo que no es un número positivo razonable', () {
      expect(validateCapacity('abc'), 'El cupo debe ser un número.');
      expect(validateCapacity('0'), 'El cupo debe ser mayor que cero.');
      expect(validateCapacity('-5'), 'El cupo debe ser mayor que cero.');
      expect(validateCapacity('100001'), 'Ese cupo es demasiado grande.');
    });

    test('acepta un cupo normal', () {
      expect(validateCapacity('30'), isNull);
    });
  });

  group('validateRouteDays', () {
    test('acepta el rango que admite la columna (1..30)', () {
      expect(validateRouteDays('1'), isNull);
      expect(validateRouteDays('30'), isNull);
    });

    test('rechaza fuera de rango y no numérico', () {
      expect(validateRouteDays('0'), isNotNull);
      expect(validateRouteDays('31'), isNotNull);
      expect(validateRouteDays('dos'), 'Los días deben ser un número.');
    });

    test('vacío pide el dato', () {
      expect(validateRouteDays(''), 'Indica cuántos días dura la ruta.');
    });
  });

  group('validateFutureDateTime', () {
    test('rechaza el pasado y acepta el futuro', () {
      expect(
        validateFutureDateTime(
          DateTime.now().subtract(const Duration(days: 1)),
        ),
        'La fecha debe ser posterior a este momento.',
      );
      expect(
        validateFutureDateTime(DateTime.now().add(const Duration(days: 1))),
        isNull,
      );
    });

    test('null pide elegirla', () {
      expect(validateFutureDateTime(null), 'Elige la fecha y la hora.');
    });
  });

  group('validateCoordinates', () {
    test('exige un punto marcado en el mapa', () {
      expect(
        validateCoordinates(null, null),
        'Marca la ubicación del lugar en el mapa.',
      );
      expect(validateCoordinates(12.1, null), isNotNull);
    });

    test('acepta una coordenada de Nicaragua', () {
      expect(validateCoordinates(12.1364, -86.2514), isNull);
    });

    test('rechaza una coordenada fuera de rango', () {
      expect(validateCoordinates(91, 0), isNotNull);
      expect(validateCoordinates(0, 181), isNotNull);
    });
  });

  group('handles opcionales', () {
    test('Instagram y Facebook vacíos son válidos: son campos opcionales', () {
      expect(validateInstagramHandle(''), isNull);
      expect(validateFacebookHandle(null), isNull);
    });

    test('Instagram acepta una URL o el usuario con arroba', () {
      expect(
        validateInstagramHandle('https://instagram.com/cafe.luna'),
        isNull,
      );
      expect(validateInstagramHandle('@cafe.luna'), isNull);
    });

    test('un valor que no deja nada utilizable al normalizar no pasa', () {
      expect(validateInstagramHandle('!!!'), isNotNull);
    });

    test('el handle de fundación sí es obligatorio', () {
      expect(validateOrganizationHandle(''), isNotNull);
      expect(validateOrganizationHandle('ab'), isNotNull);
      expect(validateOrganizationHandle('fundacion.verde'), isNull);
    });
  });

  group('validateAll', () {
    test('devuelve el primer error y no sigue evaluando', () {
      var evaluados = 0;
      final error = validateAll([
        () {
          evaluados++;
          return null;
        },
        () {
          evaluados++;
          return 'segundo';
        },
        () {
          evaluados++;
          return 'tercero';
        },
      ]);

      expect(error, 'segundo');
      expect(evaluados, 2, reason: 'el tercero no debería evaluarse');
    });

    test('null si todos pasan', () {
      expect(validateAll([() => null, () => null]), isNull);
    });
  });
}
