/// A country entry for the registration wizard's phone country-code picker
/// — dial code + flag shown in the picker and the field's prefix pill.
class CountryDialCode {
  const CountryDialCode({
    required this.iso,
    required this.name,
    required this.dialCode,
    required this.flagEmoji,
  });

  final String iso;
  final String name;
  final String dialCode;
  final String flagEmoji;
}

/// Nicaragua first (this app's home market and the phone formatter's only
/// supported mask), then the rest of Central America, then other countries
/// Níkara's tourists most commonly come from. Not an exhaustive ISO list —
/// extend as real signups show a need for a country that's missing.
const List<CountryDialCode> kCountryDialCodes = [
  CountryDialCode(
    iso: 'NI',
    name: 'Nicaragua',
    dialCode: '+505',
    flagEmoji: '🇳🇮',
  ),
  CountryDialCode(
    iso: 'CR',
    name: 'Costa Rica',
    dialCode: '+506',
    flagEmoji: '🇨🇷',
  ),
  CountryDialCode(
    iso: 'HN',
    name: 'Honduras',
    dialCode: '+504',
    flagEmoji: '🇭🇳',
  ),
  CountryDialCode(
    iso: 'SV',
    name: 'El Salvador',
    dialCode: '+503',
    flagEmoji: '🇸🇻',
  ),
  CountryDialCode(
    iso: 'GT',
    name: 'Guatemala',
    dialCode: '+502',
    flagEmoji: '🇬🇹',
  ),
  CountryDialCode(
    iso: 'PA',
    name: 'Panamá',
    dialCode: '+507',
    flagEmoji: '🇵🇦',
  ),
  CountryDialCode(
    iso: 'US',
    name: 'Estados Unidos',
    dialCode: '+1',
    flagEmoji: '🇺🇸',
  ),
  CountryDialCode(
    iso: 'MX',
    name: 'México',
    dialCode: '+52',
    flagEmoji: '🇲🇽',
  ),
  CountryDialCode(
    iso: 'CO',
    name: 'Colombia',
    dialCode: '+57',
    flagEmoji: '🇨🇴',
  ),
  CountryDialCode(
    iso: 'AR',
    name: 'Argentina',
    dialCode: '+54',
    flagEmoji: '🇦🇷',
  ),
  CountryDialCode(iso: 'CA', name: 'Canadá', dialCode: '+1', flagEmoji: '🇨🇦'),
  CountryDialCode(
    iso: 'ES',
    name: 'España',
    dialCode: '+34',
    flagEmoji: '🇪🇸',
  ),
];

/// Default selection — Nicaragua, this app's home market. A standalone
/// const (not `kCountryDialCodes.first`/`[0]`, neither of which is a valid
/// const expression in Dart) that happens to equal the list's first entry.
const CountryDialCode kDefaultCountryDialCode = CountryDialCode(
  iso: 'NI',
  name: 'Nicaragua',
  dialCode: '+505',
  flagEmoji: '🇳🇮',
);
