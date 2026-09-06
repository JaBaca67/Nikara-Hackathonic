/// Nombre de archivo y `Content-Type` para subir una imagen de `image_picker`
/// a Supabase Storage.
///
/// Existe porque derivar el mime type como `'image/$extension'` es un error
/// silencioso: para un `.jpg` da `image/jpg`, que **no** es un mime type real
/// (el canónico es `image/jpeg`) y que los buckets rechazan con
/// "mime type image/jpg is not supported". Y como `XFile.mimeType` viene nulo
/// en Android, ese camino roto era el habitual, no el excepcional.
///
/// Lo usan [AuthService.updateAvatar] y [EcoService.uploadActivityImage]; la
/// lista de tipos coincide con el `allowed_mime_types` de los buckets en
/// supabase/sql/014_eco_activity_image.sql y 015_profile_avatars.sql.
library;

/// Extensión de archivo -> mime type canónico. Las claves son lo que aparece
/// en un nombre de archivo; los valores, lo único que Storage acepta.
const Map<String, String> _mimeTypesByExtension = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'heic': 'image/heic',
};

/// Mime types válidos, para poder confiar en un [XFile.mimeType] que sí venga.
final Set<String> _supportedMimeTypes = _mimeTypesByExtension.values.toSet();

/// Extensión y mime type con los que subir una imagen.
class ImageUploadFormat {
  const ImageUploadFormat({required this.extension, required this.mimeType});

  /// Sin punto, ya en minúsculas ('jpg', 'png'...).
  final String extension;

  /// Siempre uno de [_supportedMimeTypes] — nunca un `image/jpg` inventado.
  final String mimeType;
}

/// Resuelve el formato de subida a partir del nombre del archivo y, si lo hay,
/// del mime type que reportó el picker.
///
/// [reportedMimeType] solo se respeta si es uno de los soportados: un picker
/// que devuelva algo raro (o el propio `image/jpg`) no debe poder producir una
/// subida que el bucket vaya a rechazar. Cualquier extensión desconocida cae a
/// JPEG, que es a lo que `image_picker` recodifica cuando se le pasa
/// `imageQuality`.
ImageUploadFormat resolveImageUploadFormat(
  String fileName, {
  String? reportedMimeType,
}) {
  final reported = reportedMimeType?.trim().toLowerCase();
  if (reported != null && _supportedMimeTypes.contains(reported)) {
    return ImageUploadFormat(
      extension: _extensionForMimeType(reported),
      mimeType: reported,
    );
  }

  final dot = fileName.lastIndexOf('.');
  final rawExtension = dot == -1 || dot == fileName.length - 1
      ? ''
      : fileName.substring(dot + 1).toLowerCase();
  final mimeType = _mimeTypesByExtension[rawExtension];
  if (mimeType == null) {
    return const ImageUploadFormat(extension: 'jpg', mimeType: 'image/jpeg');
  }
  return ImageUploadFormat(extension: rawExtension, mimeType: mimeType);
}

/// Primera extensión que mapea a [mimeType]; 'jpeg' devuelve 'jpg' porque es
/// la primera entrada del mapa, que es la forma que se quiere en el nombre.
String _extensionForMimeType(String mimeType) {
  for (final entry in _mimeTypesByExtension.entries) {
    if (entry.value == mimeType) return entry.key;
  }
  return 'jpg';
}
