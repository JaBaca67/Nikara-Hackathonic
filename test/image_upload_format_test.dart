import 'package:flutter_test/flutter_test.dart';

import 'package:nikara_app/core/utils/image_upload.dart';

/// Regresión de "mime type image/jpg is not supported".
///
/// El mime type se derivaba como `'image/$extension'`, que para un `.jpg` da
/// `image/jpg` — un tipo que no existe (el canónico es `image/jpeg`) y que los
/// buckets rechazan. Como `XFile.mimeType` viene nulo en Android, ese camino
/// era el habitual, así que fallaba toda subida desde el teléfono.
///
/// El invariante que estos tests protegen: [resolveImageUploadFormat] nunca
/// puede devolver un mime type fuera del `allowed_mime_types` de los buckets
/// (supabase/sql/014 y 015), pase lo que pase por entrada.
void main() {
  /// Tal cual está en `allowed_mime_types` de ambos buckets.
  const bucketAllowed = {'image/jpeg', 'image/png', 'image/webp', 'image/heic'};

  group('mime type canónico', () {
    test('.jpg produce image/jpeg, no image/jpg', () {
      final format = resolveImageUploadFormat('foto.jpg');
      expect(format.mimeType, 'image/jpeg');
      expect(format.extension, 'jpg');
    });

    test('.jpeg produce image/jpeg', () {
      expect(resolveImageUploadFormat('foto.jpeg').mimeType, 'image/jpeg');
    });

    test('.png / .webp / .heic mantienen su tipo', () {
      expect(resolveImageUploadFormat('a.png').mimeType, 'image/png');
      expect(resolveImageUploadFormat('a.webp').mimeType, 'image/webp');
      expect(resolveImageUploadFormat('a.heic').mimeType, 'image/heic');
    });

    test('mayúsculas en la extensión no rompen el mapeo', () {
      final format = resolveImageUploadFormat('IMG_0042.JPG');
      expect(format.mimeType, 'image/jpeg');
      expect(format.extension, 'jpg');
    });
  });

  group('entradas degeneradas caen a JPEG', () {
    test('sin extensión', () {
      final format = resolveImageUploadFormat('image_picker_ABC123');
      expect(format.mimeType, 'image/jpeg');
      expect(format.extension, 'jpg');
    });

    test('punto final sin extensión', () {
      expect(resolveImageUploadFormat('foto.').mimeType, 'image/jpeg');
    });

    test('extensión desconocida', () {
      // image_picker recodifica a JPEG cuando se le pasa imageQuality, así que
      // JPEG es el fallback correcto y no una suposición arbitraria.
      expect(resolveImageUploadFormat('foto.raw').mimeType, 'image/jpeg');
      expect(resolveImageUploadFormat('foto.gif').mimeType, 'image/jpeg');
    });

    test('nombre vacío', () {
      expect(resolveImageUploadFormat('').mimeType, 'image/jpeg');
    });
  });

  group('mimeType reportado por el picker', () {
    test('se respeta cuando es válido, aunque el nombre diga otra cosa', () {
      final format = resolveImageUploadFormat(
        'captura.jpg',
        reportedMimeType: 'image/png',
      );
      expect(format.mimeType, 'image/png');
      expect(format.extension, 'png');
    });

    test('un image/jpg reportado se normaliza a image/jpeg', () {
      // El propio bug, pero llegando desde el picker en vez de construido acá.
      final format = resolveImageUploadFormat(
        'foto.jpg',
        reportedMimeType: 'image/jpg',
      );
      expect(format.mimeType, 'image/jpeg');
    });

    test('un tipo no soportado se ignora y manda el nombre', () {
      final format = resolveImageUploadFormat(
        'foto.png',
        reportedMimeType: 'application/octet-stream',
      );
      expect(format.mimeType, 'image/png');
    });

    test('nulo o vacío no rompe', () {
      expect(
        resolveImageUploadFormat('foto.png', reportedMimeType: null).mimeType,
        'image/png',
      );
      expect(
        resolveImageUploadFormat('foto.png', reportedMimeType: '  ').mimeType,
        'image/png',
      );
    });
  });

  test('ninguna entrada puede producir un tipo que el bucket rechace', () {
    const names = [
      'foto.jpg',
      'foto.JPEG',
      'foto.png',
      'foto.webp',
      'foto.heic',
      'foto.gif',
      'foto.raw',
      'foto.',
      'foto',
      '',
      'sin.punto.varias.partes.tiff',
    ];
    const reported = [
      null,
      'image/jpg',
      'image/png',
      'IMAGE/JPEG',
      'application/octet-stream',
      '',
      'texto cualquiera',
    ];

    for (final name in names) {
      for (final mime in reported) {
        final format = resolveImageUploadFormat(name, reportedMimeType: mime);
        expect(
          bucketAllowed,
          contains(format.mimeType),
          reason: 'name="$name" reportedMimeType=$mime',
        );
        expect(format.extension, isNotEmpty);
        expect(format.extension, isNot(contains('.')));
      }
    }
  });
}
