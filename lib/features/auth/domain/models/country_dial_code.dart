/// Entrada del selector de código de país del wizard de registro. Sin
/// banderas: la interfaz no usa emojis por regla, y el badge de texto ISO
/// se lee igual de claro sin assets vectoriales por país.
class CountryDialCode {
  const CountryDialCode({
    required this.iso,
    required this.name,
    required this.dialCode,
  });

  final String iso;
  final String name;
  final String dialCode;
}

/// Nicaragua primero (mercado local y única máscara que soporta el
/// formateador telefónico), luego Centroamérica y los países de origen más
/// comunes de los turistas. Lista no exhaustiva — se extiende según haga falta.
const List<CountryDialCode> kCountryDialCodes = [
  CountryDialCode(iso: 'NI', name: 'Nicaragua', dialCode: '+505'),
  CountryDialCode(iso: 'CR', name: 'Costa Rica', dialCode: '+506'),
  CountryDialCode(iso: 'HN', name: 'Honduras', dialCode: '+504'),
  CountryDialCode(iso: 'SV', name: 'El Salvador', dialCode: '+503'),
  CountryDialCode(iso: 'GT', name: 'Guatemala', dialCode: '+502'),
  CountryDialCode(iso: 'PA', name: 'Panamá', dialCode: '+507'),
  CountryDialCode(iso: 'US', name: 'Estados Unidos', dialCode: '+1'),
  CountryDialCode(iso: 'MX', name: 'México', dialCode: '+52'),
  CountryDialCode(iso: 'CO', name: 'Colombia', dialCode: '+57'),
  CountryDialCode(iso: 'AR', name: 'Argentina', dialCode: '+54'),
  CountryDialCode(iso: 'CA', name: 'Canadá', dialCode: '+1'),
  CountryDialCode(iso: 'ES', name: 'España', dialCode: '+34'),
];

/// Selección por defecto. Const aparte (no `kCountryDialCodes.first`, que
/// no es una expresión const válida en Dart) que coincide con el primer
/// elemento de la lista.
const CountryDialCode kDefaultCountryDialCode = CountryDialCode(
  iso: 'NI',
  name: 'Nicaragua',
  dialCode: '+505',
);
