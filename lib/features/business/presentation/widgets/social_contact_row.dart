import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nikara_app/theme/app_theme.dart';

String digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

/// Tolera handle bare, con "@" o URL completa (dato de antes de simplificar el campo a solo handle).
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

class SocialContact {
  const SocialContact({
    required this.icon,
    required this.label,
    required this.handle,
    required this.tint,
    required this.iconBackground,
    required this.uri,
  });

  final IconData icon;

  final String label;

  /// Vacío cuando no hay nada significativo que mostrar (ej. un "Llamar" sin número visible).
  final String handle;
  final Color tint;

  /// Tinte pálido distintivo por canal, no simplemente [tint] con alpha bajo.
  final Color iconBackground;
  final Uri uri;

  factory SocialContact.whatsapp(String phone, {String? message}) {
    final digits = digitsOnly(phone);
    final query = message == null
        ? ''
        : '?text=${Uri.encodeComponent(message)}';
    return SocialContact(
      icon: Icons.chat,
      label: 'WhatsApp',
      handle: phone.trim(),
      tint: AppColors.detailWhatsappIcon,
      iconBackground: AppColors.detailWhatsappIconBg,
      uri: Uri.parse('https://wa.me/$digits$query'),
    );
  }

  factory SocialContact.phone(String phone) {
    return SocialContact(
      icon: Icons.call_rounded,
      label: 'Llamar',
      handle: phone.trim(),
      tint: AppColors.settingsTextMuted,
      iconBackground: AppColors.profileDivider,
      uri: Uri.parse('tel:${digitsOnly(phone)}'),
    );
  }

  factory SocialContact.instagram(String handleOrLink) {
    final handle = _extractHandle(handleOrLink, hostFragment: 'instagram.com');
    return SocialContact(
      icon: Icons.photo_camera,
      label: 'Instagram',
      handle: handle.isEmpty ? '' : '@$handle',
      tint: AppColors.favoriteActive,
      iconBackground: AppColors.detailInstagramIconBg,
      uri: Uri.parse('https://instagram.com/$handle'),
    );
  }

  factory SocialContact.facebook(String handleOrLink) {
    final handle = _extractHandle(handleOrLink, hostFragment: 'facebook.com');
    return SocialContact(
      icon: Icons.thumb_up,
      label: 'Facebook',
      handle: '',
      tint: AppColors.wizardFacebookIcon,
      iconBackground: AppColors.wizardFacebookIconBg,
      uri: Uri.parse('https://facebook.com/$handle'),
    );
  }

  factory SocialContact.tiktok(String handleOrLink) {
    final handle = _extractHandle(handleOrLink, hostFragment: 'tiktok.com');
    return SocialContact(
      icon: Icons.music_note_rounded,
      label: 'TikTok',
      handle: handle.isEmpty ? '' : '@$handle',
      tint: AppColors.neutral900,
      iconBackground: AppColors.neutral900.withValues(alpha: 0.1),
      uri: Uri.parse('https://www.tiktok.com/@$handle'),
    );
  }

  factory SocialContact.link(String link) => SocialContact(
    icon: Icons.link_rounded,
    label: 'Enlace',
    handle: '',
    tint: AppColors.neutral600,
    iconBackground: AppColors.neutral600.withValues(alpha: 0.1),
    uri: Uri.parse(link),
  );
}

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
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.mapControlBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: contact.iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(contact.icon, color: contact.tint, size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.label,
                      style: AppTextStyles.quickInfoValue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (contact.handle.isNotEmpty)
                      Text(
                        contact.handle,
                        style: AppTextStyles.settingsSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.settingsBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('Abrir', style: AppTextStyles.detailPillAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
