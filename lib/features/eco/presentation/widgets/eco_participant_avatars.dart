import 'package:flutter/material.dart';

import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/profile/presentation/screens/public_user_profile_screen.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Pila de avatares de los inscritos. Muestra la foto real de cada persona
/// (`profiles.avatar_url` vía el embed de [EcoService]) y cae a sus iniciales
/// sobre un color de [AppColors.ecoAvatarStack] cuando no tiene foto.
///
/// Tocar la pila abre el perfil público del primer inscrito; para elegir a
/// cualquiera está la pestaña "Participantes" del detalle, donde cada fila es
/// su propio enlace.
class EcoParticipantAvatars extends StatelessWidget {
  const EcoParticipantAvatars({
    super.key,
    required this.count,
    this.participants = const [],
    this.size = 32,
    this.maxShown = 4,
    this.borderColor = AppColors.surface100,
    this.enableProfileTap = true,
  });

  final int count;

  /// Vacía si la consulta corrió sin el embed de `profiles`: entonces se
  /// dibujan los rellenos neutros de siempre, sin inventar identidades.
  final List<EcoParticipant> participants;

  final double size;
  final int maxShown;
  final Color borderColor;
  final bool enableProfileTap;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final shown = count < maxShown ? count : maxShown;
    final overlap = size * 0.62;
    final first = participants.isEmpty ? null : participants.first;

    final stack = SizedBox(
      height: size,
      width: overlap * (shown - 1) + size,
      child: Stack(
        children: [
          for (var i = shown - 1; i >= 0; i--)
            Positioned(
              left: i * overlap,
              child: _Avatar(
                participant: i < participants.length ? participants[i] : null,
                fallbackColor: AppColors
                    .ecoAvatarStack[i % AppColors.ecoAvatarStack.length],
                size: size,
                borderColor: borderColor,
              ),
            ),
        ],
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (enableProfileTap && first != null)
          GestureDetector(
            onTap: () => openParticipantProfile(context, first),
            child: stack,
          )
        else
          stack,
        const SizedBox(width: 8),
        Text(
          '+$count',
          style: AppTextStyles.mapRowTitle.copyWith(
            fontSize: 12,
            color: AppColors.settingsTextMuted,
          ),
        ),
      ],
    );
  }
}

/// Abre el perfil público de un inscrito, con su nombre ya conocido como
/// respaldo mientras `profiles` carga.
Future<void> openParticipantProfile(
  BuildContext context,
  EcoParticipant participant,
) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PublicUserProfileScreen(
        userId: participant.userId,
        fallbackName: participant.fullName,
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.participant,
    required this.fallbackColor,
    required this.size,
    required this.borderColor,
  });

  final EcoParticipant? participant;
  final Color fallbackColor;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final person = participant;
    final avatarUrl = person?.avatarUrl;
    final hasPhoto = avatarUrl != null && avatarUrl.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fallbackColor,
        border: Border.all(color: borderColor, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? LocalImage(path: avatarUrl, fallbackIcon: Icons.person)
          : (person == null
                ? null
                : Center(
                    child: Text(
                      person.initials,
                      style: AppTextStyles.mapRowTitle.copyWith(
                        fontSize: size * 0.36,
                        color: AppColors.surface100,
                      ),
                    ),
                  )),
    );
  }
}
