import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Strips everything but digits — turns "+505 8123 4567" into "50581234567",
/// suitable for both a `wa.me` deep link and a `tel:` URI.
String digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

/// Normalizes a wizard-collected value down to a bare handle — works
/// whether the stored value is already a bare handle ("lagunadeapoyo"), has
/// a leading "@" ("@lagunadeapoyo"), or (for data saved before the wizard
/// simplified these fields to handles-only) a full profile URL.
String _extractHandle(String raw, {required String hostFragment}) {
  var value = raw.trim();
  if (value.isEmpty) return '';
  value = value.replaceFirst(RegExp(r'^https?://'), '');
  value = value.replaceFirst(RegExp(r'^www\.'), '');
  value = value.replaceFirst(RegExp('^$hostFragment/?'), '');
  value = value.replaceFirst('@', '');
  value = value.split('/').first;
  value = value.split('?').first;
  return value.trim();
}

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

/// One card in [SocialHub] — an icon, the platform/action name, the
/// handle or number shown under it (may be empty), and the link it opens.
class SocialContact {
  const SocialContact({
    required this.icon,
    required this.label,
    required this.handle,
    required this.tint,
    required this.uri,
  });

  final IconData icon;

  /// Platform/action name — "WhatsApp", "Instagram", "TikTok", "Llamar".
  final String label;

  /// What's shown under [label] — "@lagunadeapoyo", a phone number, or ''
  /// when there's nothing meaningful to show (e.g. a bare "Llamar" action).
  final String handle;
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
      handle: phone.trim(),
      tint: const Color(0xFF25D366),
      uri: Uri.parse('https://wa.me/$digits$query'),
    );
  }

  factory SocialContact.phone(String phone) {
    return SocialContact(
      icon: Icons.call_rounded,
      label: 'Llamar',
      handle: phone.trim(),
      tint: AppColors.accent300,
      uri: Uri.parse('tel:${digitsOnly(phone)}'),
    );
  }

  /// [handleOrLink] is whatever the wizard's "Instagram" field holds — just
  /// the bare handle since the redesign, but this also tolerates a legacy
  /// full URL from before that change.
  factory SocialContact.instagram(String handleOrLink) {
    final handle = _extractHandle(handleOrLink, hostFragment: 'instagram.com');
    return SocialContact(
      icon: Icons.camera_alt_outlined,
      label: 'Instagram',
      handle: handle.isEmpty ? '' : '@$handle',
      tint: const Color(0xFFE1306C),
      uri: Uri.parse('https://instagram.com/$handle'),
    );
  }

  factory SocialContact.facebook(String link) => SocialContact(
    icon: Icons.facebook,
    label: 'Facebook',
    handle: '',
    tint: const Color(0xFF1877F2),
    uri: Uri.parse(link),
  );

  /// Same handle-first tolerance as [SocialContact.instagram] — TikTok
  /// profile URLs keep the "@" in their path (`tiktok.com/@handle`).
  factory SocialContact.tiktok(String handleOrLink) {
    final handle = _extractHandle(handleOrLink, hostFragment: 'tiktok.com');
    return SocialContact(
      icon: Icons.music_note_rounded,
      label: 'TikTok',
      handle: handle.isEmpty ? '' : '@$handle',
      tint: AppColors.neutral900,
      uri: Uri.parse('https://www.tiktok.com/@$handle'),
    );
  }

  factory SocialContact.link(String link) => SocialContact(
    icon: Icons.link_rounded,
    label: 'Enlace',
    handle: '',
    tint: AppColors.neutral600,
    uri: Uri.parse(link),
  );
}

/// The business detail screen's "Contacto y redes" — a vertical stack of
/// premium micro-cards (soft shadow, brand-tinted icon, handle, "Abrir"
/// action), one per contact channel the business actually has data for.
/// Replaces the earlier compact pill-chip row for better legibility and a
/// more deliberate tap target per channel.
class SocialHub extends StatelessWidget {
  const SocialHub({super.key, required this.contacts});

  final List<SocialContact> contacts;

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final contact in contacts) ...[
          _SocialHubCard(
            contact: contact,
            onTap: () => _launch(context, contact.uri),
          ),
          if (contact != contacts.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SocialHubCard extends StatelessWidget {
  const _SocialHubCard({required this.contact, required this.onTap});

  final SocialContact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface100,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: contact.tint.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(contact.icon, color: contact.tint, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.label,
                      style: AppTextStyles.detailRowText.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (contact.handle.isNotEmpty)
                      Text(
                        contact.handle,
                        style: AppTextStyles.reviewMeta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: contact.tint.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Abrir',
                      style: AppTextStyles.reviewMeta.copyWith(
                        color: contact.tint,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 12,
                      color: contact.tint,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
