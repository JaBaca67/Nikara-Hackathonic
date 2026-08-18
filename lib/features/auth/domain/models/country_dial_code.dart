/// A country entry for the registration wizard's phone country-code picker
/// — dial code shown in the picker and the field's prefix pill. No flag
/// artwork: the interface is emoji-free by rule, and a small ISO-code text
/// badge reads just as clearly at this size without needing per-country
/// vector flag assets.
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

/// Nicaragua first (this app's home market and the phone formatter's only
/// supported mask), then the rest of Central America, then other countries
/// Níkara's tourists most commonly come from. Not an exhaustive ISO list —
/// extend as real signups show a need for a country that's missing.
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

/// Default selection — Nicaragua, this app's home market. A standalone
/// const (not `kCountryDialCodes.first`/`[0]`, neither of which is a valid
/// const expression in Dart) that happens to equal the list's first entry.
const CountryDialCode kDefaultCountryDialCode = CountryDialCode(
  iso: 'NI',
  name: 'Nicaragua',
  dialCode: '+505',
);
