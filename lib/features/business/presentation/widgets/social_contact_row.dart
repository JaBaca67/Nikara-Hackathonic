import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Strips everything but digits — turns "+505 8123 4567" into "50581234567",
/// suitable for both a `wa.me` deep link and a `tel:` URI.
String digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

/// Opens WhatsApp with [phone] pre-filled with [message], falling back to a
/// SnackBar if no app/browser on the device can handle the deep link.
Future<void> launchWhatsApp(
  BuildContext context,
  String phone, {
  String? message,
}) async {
  final digits = digitsOnly(phone);
  if (digits.isEmpty) return;
  final query = message == null ? '' : '?text=${Uri.encodeComponent(message)}';
  await _launch(context, Uri.parse('https://wa.me/$digits$query'));
}

Future<void> _launch(BuildContext context, Uri uri) async {
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('No se pudo abrir $uri')));
  }
}

/// One chip in [SocialContactRow] — an icon, a label, and the link it opens.
class SocialContact {
  const SocialContact({
    required this.icon,
    required this.label,
    required this.tint,
    required this.uri,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final Uri uri;

  /// WhatsApp chat pre-filled with [message].
  factory SocialContact.whatsapp(String phone, {String? message}) {
    final digits = digitsOnly(phone);
    final query = message == null
        ? ''
        : '?text=${Uri.encodeComponent(message)}';
    return SocialContact(
      icon: Icons.chat,
      label: 'WhatsApp',
      tint: const Color(0xFF25D366),
      uri: Uri.parse('https://wa.me/$digits$query'),
    );
  }

  factory SocialContact.phone(String phone) {
    return SocialContact(
      icon: Icons.call_rounded,
      label: 'Llamar',
      tint: AppColors.accent300,
      uri: Uri.parse('tel:${digitsOnly(phone)}'),
    );
  }

  factory SocialContact.instagram(String link) => SocialContact(
    icon: Icons.camera_alt_outlined,
    label: 'Instagram',
    tint: const Color(0xFFE1306C),
    uri: Uri.parse(link),
  );

  factory SocialContact.facebook(String link) => SocialContact(
    icon: Icons.facebook,
    label: 'Facebook',
    tint: const Color(0xFF1877F2),
    uri: Uri.parse(link),
  );

  factory SocialContact.tiktok(String link) => SocialContact(
    icon: Icons.music_note_rounded,
    label: 'TikTok',
    tint: AppColors.neutral900,
    uri: Uri.parse(link),
  );

  factory SocialContact.link(String link) => SocialContact(
    icon: Icons.link_rounded,
    label: 'Enlace',
    tint: AppColors.neutral600,
    uri: Uri.parse(link),
  );
}

/// Horizontal row of clean, subtly-bordered contact chips (WhatsApp, phone,
/// Instagram, Facebook, TikTok...) — only the ones a business actually has
/// data for are rendered. Tapping one opens its link via `url_launcher`.
class SocialContactRow extends StatelessWidget {
  const SocialContactRow({super.key, required this.contacts});

  final List<SocialContact> contacts;

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final contact in contacts)
          _SocialContactChip(
            contact: contact,
            onTap: () => _launch(context, contact.uri),
          ),
      ],
    );
  }
}

class _SocialContactChip extends StatelessWidget {
  const _SocialContactChip({required this.contact, required this.onTap});

  final SocialContact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(contact.icon, size: 16, color: contact.tint),
              const SizedBox(width: 6),
              Text(
                contact.label,
                style: AppTextStyles.detailRowText.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
