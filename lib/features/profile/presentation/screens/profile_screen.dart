import 'package:flutter/material.dart';

import 'package:nikara_app/features/home/data/mock_destinations.dart';
import 'package:nikara_app/features/home/domain/models/destination.dart';
import 'package:nikara_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:nikara_app/theme/app_theme.dart';

class _EcoBadge {
  const _EcoBadge({
    required this.icon,
    required this.title,
    required this.obtained,
    required this.tint,
  });

  final IconData icon;
  final String title;
  final bool obtained;
  final Color tint;
}

const List<_EcoBadge> _ecoBadges = [
  _EcoBadge(
    icon: Icons.forest,
    title: 'Guardián del Bosque',
    obtained: true,
    tint: AppColors.accent300,
  ),
  _EcoBadge(
    icon: Icons.water_drop,
    title: 'Protector del Lago',
    obtained: true,
    tint: Color(0xFF1B6B8A),
  ),
  _EcoBadge(
    icon: Icons.flutter_dash,
    title: 'Observador Alado',
    obtained: true,
    tint: AppColors.primary500,
  ),
  _EcoBadge(
    icon: Icons.festival,
    title: 'Cultura Viva',
    obtained: false,
    tint: AppColors.neutral500,
  ),
  _EcoBadge(
    icon: Icons.terrain,
    title: 'Escalador Eco',
    obtained: false,
    tint: AppColors.neutral500,
  ),
  _EcoBadge(
    icon: Icons.card_travel,
    title: 'Viajero Consciente',
    obtained: false,
    tint: AppColors.neutral500,
  ),
];

const List<Color> _avatarChoices = [
  AppColors.primary500,
  AppColors.accent300,
  AppColors.coral500,
  Color(0xFF1B6B8A),
  AppColors.neutral800,
];

/// Perfil screen (Figma node 259:224): profile header with a tappable
/// (mock) avatar picker, favorite places, eco badges and a level-progress
/// card. All state is local/mock — no backend wiring yet.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Color? _avatarColor;
  final Set<String> _favoriteIds = {
    'isletas-de-granada',
    'playa-maderas',
    'volcan-telica',
  };

  List<DestinationModel> get _favorites => mockDestinations
      .where((d) => _favoriteIds.contains(d.id))
      .toList(growable: false);

  void _toggleFavorite(String id) {
    setState(() {
      if (!_favoriteIds.remove(id)) _favoriteIds.add(id);
    });
  }

  Future<void> _openAvatarPicker() async {
    final chosen = await showModalBottomSheet<Color>(
      context: context,
      backgroundColor: AppColors.surface100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _AvatarPickerSheet(current: _avatarColor),
    );
    if (chosen == null || !mounted) return;
    setState(() => _avatarColor = chosen);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface100,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileHeader(
                avatarColor: _avatarColor,
                onAvatarTap: _openAvatarPicker,
                onSettingsTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
              ),
              _SectionHeader(
                title: 'Lugares Favoritos',
                trailing: 'Ver todos',
                onTrailingTap: () => _showComingSoon(context),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  children: [
                    for (final destination in _favorites) ...[
                      _FavoritePlaceCard(
                        destination: destination,
                        onFavoriteToggle: () => _toggleFavorite(destination.id),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              _SectionHeader(
                title: 'Insignias Ecológicas',
                trailing:
                    '${_ecoBadges.where((b) => b.obtained).length} / ${_ecoBadges.length}',
                pillStyle: true,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.9,
                  children: [
                    for (final badge in _ecoBadges) _EcoBadgeCard(badge: badge),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _LevelProgressCard(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Próximamente')),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.avatarColor,
    required this.onAvatarTap,
    required this.onSettingsTap,
  });

  final Color? avatarColor;
  final VoidCallback onAvatarTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.004, 0.11, 0.197, 0.413],
          colors: [
            AppColors.profileHeaderGoldPale,
            AppColors.notificationPill,
            AppColors.profileHeaderCoral,
            AppColors.surface100,
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: onAvatarTap,
                  child: Container(
                    width: 100,
                    height: 100,
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary500,
                    ),
                    child: CircleAvatar(
                      backgroundColor:
                          avatarColor ?? AppColors.surface200,
                      child: avatarColor == null
                          ? Icon(
                              Icons.camera_alt_outlined,
                              color: AppColors.neutral500,
                              size: 28,
                            )
                          : const Icon(
                              Icons.person,
                              color: AppColors.surface100,
                              size: 32,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Ixchel Galo', style: AppTextStyles.profileName),
                      const SizedBox(height: 6),
                      Text('lv 4/12', style: AppTextStyles.profileLevel),
                      const SizedBox(height: 12),
                      Text(
                        'León, Nicaragua',
                        style: AppTextStyles.profileLocation,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onSettingsTap,
            icon: const Icon(Icons.settings, color: AppColors.neutral900),
          ),
        ],
      ),
    );
  }
}

class _AvatarPickerSheet extends StatelessWidget {
  const _AvatarPickerSheet({required this.current});

  final Color? current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Elige un avatar', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 4),
            Text(
              'Selección simulada — sin subida de imágenes real.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final color in _avatarChoices)
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(color),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: color,
                      child: current == color
                          ? const Icon(
                              Icons.check,
                              color: AppColors.surface100,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.trailing,
    this.onTrailingTap,
    this.pillStyle = false,
  });

  final String title;
  final String trailing;
  final VoidCallback? onTrailingTap;
  final bool pillStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTextStyles.sectionTitle),
          if (pillStyle)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary500.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                trailing,
                style: AppTextStyles.link.copyWith(
                  color: AppColors.neutral1100,
                ),
              ),
            )
          else
            GestureDetector(
              onTap: onTrailingTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(trailing, style: AppTextStyles.link),
                  const Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: AppColors.accent300,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FavoritePlaceCard extends StatelessWidget {
  const _FavoritePlaceCard({
    required this.destination,
    required this.onFavoriteToggle,
  });

  final DestinationModel destination;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, 4),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 64,
              height: 56,
              child: destination.imageAsset != null
                  ? Image.asset(destination.imageAsset!, fit: BoxFit.cover)
                  : ColoredBox(color: destination.imagePlaceholderColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(destination.title, style: AppTextStyles.listCardTitle),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 10,
                      color: AppColors.neutral500,
                    ),
                    const SizedBox(width: 4),
                    Text(destination.location, style: AppTextStyles.listCardCaption),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${destination.formattedPrice} ',
                      style: AppTextStyles.listCardPrice,
                    ),
                    Text('/persona', style: AppTextStyles.listCardPriceSuffix),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onFavoriteToggle,
            icon: const Icon(Icons.favorite, color: Color(0xFFE8798F)),
          ),
        ],
      ),
    );
  }
}

class _EcoBadgeCard extends StatelessWidget {
  const _EcoBadgeCard({required this.badge});

  final _EcoBadge badge;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: badge.obtained ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: badge.obtained ? AppColors.surface100 : const Color(0xFFF4EDE8),
          borderRadius: BorderRadius.circular(16),
          boxShadow: badge.obtained
              ? const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    offset: Offset(0, 4),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badge.tint.withValues(alpha: 0.09),
                shape: BoxShape.circle,
              ),
              child: Icon(badge.icon, size: 22, color: badge.tint),
            ),
            const SizedBox(height: 8),
            Text(
              badge.title,
              textAlign: TextAlign.center,
              style: AppTextStyles.badgeTitle,
            ),
            const SizedBox(height: 2),
            Text(
              badge.obtained ? 'Obtenida' : 'Bloqueada',
              style: AppTextStyles.badgeStatus.copyWith(
                color: badge.obtained ? badge.tint : AppColors.neutral500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelProgressCard extends StatelessWidget {
  const _LevelProgressCard();

  @override
  Widget build(BuildContext context) {
    const current = 520;
    const goal = 1000;
    const progress = current / goal;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary500.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary500.withValues(alpha: 0.12),
            AppColors.accent300.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nivel: Exploradora Eco', style: AppTextStyles.badgeTitle.copyWith(fontSize: 12, height: 16 / 12)),
                    const SizedBox(height: 2),
                    Text(
                      'Siguiente: Guardiana del Territorio',
                      style: AppTextStyles.listCardCaption,
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary500.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.eco, size: 18, color: AppColors.accent300),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.primary500.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary500),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$current puntos', style: AppTextStyles.sectionSubLabel),
              Text('Meta: $goal pts', style: AppTextStyles.sectionSubLabel),
            ],
          ),
        ],
      ),
    );
  }
}
