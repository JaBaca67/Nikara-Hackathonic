import 'package:flutter/material.dart';

import 'package:nikara_app/features/auth/domain/models/country_dial_code.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Badge de código ISO en vez de bandera: la interfaz es libre de emojis por regla, y evita necesitar assets vectoriales por país.
class _IsoBadge extends StatelessWidget {
  const _IsoBadge({required this.iso});

  final String iso;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.authMuted.withValues(alpha: 0.3)),
      ),
      child: Text(
        iso,
        style: AppTextStyles.authFieldLabel.copyWith(
          fontSize: 9,
          letterSpacing: 0,
          color: AppColors.authInk,
        ),
      ),
    );
  }
}

/// Prefijo tappable dentro del [AuthTextField] de teléfono.
class CountryPrefixBadge extends StatelessWidget {
  const CountryPrefixBadge({
    super.key,
    required this.country,
    required this.onTap,
  });

  final CountryDialCode country;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IsoBadge(iso: country.iso),
          const SizedBox(width: 6),
          Text(
            country.dialCode,
            style: AppTextStyles.inputText.copyWith(
              color: AppColors.authInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.expand_more, size: 16, color: AppColors.authMuted),
          const SizedBox(width: 10),
          Container(
            width: 1,
            height: 20,
            color: AppColors.authMuted.withValues(alpha: 0.25),
          ),
        ],
      ),
    );
  }
}

/// Devuelve el país elegido, o null si se cierra sin seleccionar.
Future<CountryDialCode?> showCountryDialCodePicker(BuildContext context) {
  return showModalBottomSheet<CountryDialCode>(
    context: context,
    backgroundColor: AppColors.surface100,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('Selecciona tu país', style: AppTextStyles.detailSectionTitle),
            const SizedBox(height: 4),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: kCountryDialCodes.length,
                itemBuilder: (context, index) {
                  final country = kCountryDialCodes[index];
                  return ListTile(
                    leading: _IsoBadge(iso: country.iso),
                    title: Text(country.name, style: AppTextStyles.inputText),
                    trailing: Text(
                      country.dialCode,
                      style: AppTextStyles.authFieldLabel.copyWith(
                        letterSpacing: 0,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(country),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
