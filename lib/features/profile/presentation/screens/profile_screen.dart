import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:nikara_app/core/gamification/badges_logic.dart';
import 'package:nikara_app/core/gamification/gamification_engine.dart';
import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/favorites_service.dart';
import 'package:nikara_app/core/services/local_profile_extras_service.dart';
import 'package:nikara_app/core/services/user_stats_service.dart';
import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/presentation/screens/edit_business_hub_screen.dart';
import 'package:nikara_app/features/home/data/mock_destinations.dart';
import 'package:nikara_app/features/home/domain/models/destination.dart';
import 'package:nikara_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Perfil screen (Figma nodes 377:483 "Perfil 1" and 421:361 "Perfil 2").
/// The header name comes from the real Supabase [AuthService] profile; the
/// 3 stat counters, the level/progress card, the favorites list and the
/// badge grid are computed live from [FavoritesService] and
/// [UserStatsService]. There is no mock/fallback data baked in; an empty
/// state renders instead when there's genuinely nothing to show yet.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onExploreRequested});

  /// Lets the empty-state "Explorar Nicaragua" button switch [MainLayout]
  /// back to the Home tab. Null when this screen isn't hosted there (e.g.
  /// in a test harness) — the button just hides itself in that case.
  final VoidCallback? onExploreRequested;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _extrasService = LocalProfileExtrasService();
  final _favoritesService = FavoritesService();
  final _userStatsService = UserStatsService();
  final _businessStorageService = BusinessStorageService();

  bool _isLoading = true;
  String? _loadError;
  UserModel? _profile;
  String? _avatarPath;
  List<DestinationModel> _favoriteDestinations = const [];
  List<BusinessModel> _favoriteBusinesses = const [];
  UserStats _stats = const UserStats(
    tripsCount: 0,
    savedPlacesCount: 0,
    reviewsCount: 0,
  );
  List<BusinessModel> _myBusinesses = const [];
  int _activeTab = 0; // 0 = Favoritos, 1 = Insignias

  @override
  void initState() {
    super.initState();
    // FavoritesService.idsNotifier fires whenever ANY screen
    // (BusinessDetailScreen's AppBar heart included) toggles a favorite;
    // BusinessStorageService.revision fires on every business write
    // (including a new review, which changes this screen's points total).
    // Both keep this screen in sync without a restart or manual refresh,
    // even while Profile sits inert in the background inside MainLayout's
    // IndexedStack.
    _favoritesService.idsNotifier.addListener(_onDataChanged);
    BusinessStorageService.revision.addListener(_onDataChanged);
    _loadAll();
  }

  @override
  void dispose() {
    _favoritesService.idsNotifier.removeListener(_onDataChanged);
    BusinessStorageService.revision.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (!mounted) return;
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loadError = null);
    try {
      final profile = await _authService.getCurrentProfile();
      final avatarPath = await _extrasService.getAvatarPath();
      final favoriteIds = await _favoritesService.getFavoriteIds();
      final stats = await _userStatsService.getStats();
      final allBusinesses = await _businessStorageService.getBusinesses();
      if (!mounted) return;

      // The bug: favorites can be either a mock DestinationModel id
      // ('isletas-de-granada', from Home/Map) OR a business uuid (from
      // BusinessDetailScreen's heart) — both share the same id set in
      // FavoritesService, so BOTH sources must be cross-referenced here.
      // Matching only mockDestinations (the old code) silently dropped
      // every favorited business from this tab even though it was
      // persisted fine.
      final favoriteDestinations = mockDestinations
          .where((d) => favoriteIds.contains(d.id))
          .toList(growable: false);
      final favoriteBusinesses = allBusinesses
          .where((b) => favoriteIds.contains(b.id))
          .toList(growable: false);

      final currentUserId = _authService.currentAuthUser?.id;
      final myBusinesses = currentUserId == null
          ? const <BusinessModel>[]
          : allBusinesses
                .where((b) => b.ownerId == currentUserId)
                .toList(growable: false);

      setState(() {
        _profile = profile;
        _avatarPath = avatarPath;
        _favoriteDestinations = favoriteDestinations;
        _favoriteBusinesses = favoriteBusinesses;
        _stats = stats;
        _myBusinesses = myBusinesses;
        _isLoading = false;
      });
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    } on BusinessServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _editBusiness(BusinessModel business) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditBusinessHubScreen(business: business),
      ),
    );
    await _loadAll();
  }

  Future<void> _confirmDeleteBusiness(BusinessModel business) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Eliminar negocio?'),
        content: Text(
          'Se eliminará "${business.name}" de forma permanente. Esta '
          'acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Eliminar',
              style: TextStyle(color: AppColors.settingsDanger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _businessStorageService.deleteBusiness(business.id);
    await _loadAll();
  }

  Future<void> _toggleFavorite(String id) async {
    // No manual _loadAll() here — toggling notifies every listener
    // (including the one registered above), which reloads this screen.
    await _favoritesService.toggleFavorite(id);
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
    );
    if (picked == null) return;
    await _extrasService.updateAvatar(picked.path);
    await _loadAll();
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Próximamente')));
  }

  void _showBadgeRequirement(BadgeInfo badge) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.profileMuted.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(badge.icon, size: 18, color: AppColors.profileMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                badge.title,
                style: AppTextStyles.h6.copyWith(
                  color: AppColors.settingsTextDark,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Insignia bloqueada. Para desbloquearla:\n\n${badge.requirementLabel}',
          style: AppTextStyles.bodyText2.copyWith(
            color: AppColors.settingsTextMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  /// Routes a badge-card tap to the right dialog — the gray "how to
  /// unlock" one for a still-locked badge, or [_showBadgeUnlocked] (full
  /// color, celebratory) for one the traveler already earned.
  void _onBadgeTap(BadgeInfo badge) {
    if (badge.unlocked) {
      _showBadgeUnlocked(badge);
    } else {
      _showBadgeRequirement(badge);
    }
  }

  /// Shown for an already-earned badge — same layout as the locked
  /// requirement dialog, but in the badge's real [BadgeInfo.tint] instead
  /// of gray, confirming what was achieved rather than what's missing.
  void _showBadgeUnlocked(BadgeInfo badge) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badge.tint.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(badge.icon, size: 18, color: badge.tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                badge.title,
                style: AppTextStyles.h6.copyWith(
                  color: AppColors.settingsTextDark,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: badge.tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '✓ Insignia obtenida',
                style: AppTextStyles.badgeStatusPill.copyWith(
                  color: badge.tint,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Lograste: ${badge.requirementLabel}',
              style: AppTextStyles.bodyText2.copyWith(
                color: AppColors.settingsTextMuted,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: badge.tint),
            child: const Text('¡Genial!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.settingsBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary500),
        ),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: AppColors.settingsBackground,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 44,
                    color: AppColors.settingsDanger,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No se pudo cargar tu perfil',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h6.copyWith(
                      color: AppColors.settingsTextDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyText2.copyWith(
                      color: AppColors.settingsTextMuted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() => _isLoading = true);
                      _loadAll();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      foregroundColor: AppColors.textInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final points = _userStatsService.computePoints(_stats);
    final levelInfo = GamificationEngine.calculate(points);
    final badges = BadgesLogic.build(_stats);
    final unlockedCount = badges.where((b) => b.unlocked).length;
    final fullName = _profile == null || _profile!.fullName.trim().isEmpty
        ? 'Viajero Níkara'
        : _profile!.fullName;
    final initials = _profile?.initials ?? '?';

    return Scaffold(
      backgroundColor: AppColors.settingsBackground,
      body: Column(
        children: [
          // The status-bar-safe strip SafeArea reserves at the top would
          // otherwise show the Scaffold's cream background — a hard seam
          // right where the phone's status bar sits, immediately above
          // _ProfileHeaderCard's own surface100. Painting it the same
          // surface100 here makes the two read as one continuous surface.
          Container(
            height: MediaQuery.paddingOf(context).top,
            color: AppColors.surface100,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              bottom: false,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                // Extra clearance (not just 24) because MainLayout's
                // Scaffold uses extendBody: true so the floating nav bar
                // overlaps the bottom of this scroll view instead of
                // reserving its own space — without it, "Mis Negocios"
                // gets cut off behind the nav bar.
                padding: const EdgeInsets.only(bottom: 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProfileHeaderCard(
                      fullName: fullName,
                      initials: initials,
                      avatarPath: _avatarPath,
                      tripsCount: _stats.tripsCount,
                      badgesCount: unlockedCount,
                      points: points,
                      onAvatarTap: _pickAvatar,
                      onEditTap: _openSettings,
                      onSettingsTap: _openSettings,
                      onShareTap: _showComingSoon,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _LevelProgressCard(levelInfo: levelInfo),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _ProfileTabSelector(
                        activeTab: _activeTab,
                        onChanged: (tab) => setState(() => _activeTab = tab),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      // Favoritos and Insignias are two fully independent tab
                      // bodies — AnimatedSwitcher cross-fades between them
                      // instead of an instant swap, keyed by the tab index so it
                      // actually detects the change.
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeInOutCubic,
                        switchOutCurve: Curves.easeInOutCubic,
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: _activeTab == 0
                            ? _FavoritesTab(
                                key: const ValueKey('favoritos'),
                                destinations: _favoriteDestinations,
                                businesses: _favoriteBusinesses,
                                onToggleFavorite: _toggleFavorite,
                                onExplore: widget.onExploreRequested,
                              )
                            : _BadgesTab(
                                key: const ValueKey('insignias'),
                                badges: badges,
                                onBadgeTap: _onBadgeTap,
                              ),
                      ),
                    ),
                    // "Mis Negocios" is a business-owner-only section that only
                    // makes sense under Favoritos (both are "your saved/owned
                    // places" lists) — deliberately hidden while Insignias is
                    // active instead of always showing beneath either tab, since
                    // it has nothing to do with badges/gamification. The divider
                    // + extra top gap (vs. the 12px used between the other
                    // sections) keeps it visually distinct from the tab content
                    // above it even when it IS shown.
                    if (_activeTab == 0 && _myBusinesses.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.profileDivider,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: _MyBusinessesSection(
                          businesses: _myBusinesses,
                          onEdit: _editBusiness,
                          onDelete: _confirmDeleteBusiness,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.fullName,
    required this.initials,
    required this.avatarPath,
    required this.tripsCount,
    required this.badgesCount,
    required this.points,
    required this.onAvatarTap,
    required this.onEditTap,
    required this.onSettingsTap,
    required this.onShareTap,
  });

  final String fullName;
  final String initials;
  final String? avatarPath;
  final int tripsCount;
  final int badgesCount;
  final int points;
  final VoidCallback onAvatarTap;
  final VoidCallback onEditTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onShareTap;

  @override
  Widget build(BuildContext context) {
    // AppColors.surface100 — the same soft off-white (never pure #FFFFFF)
    // every other card on this screen (level card, badge cards) already
    // uses, and what Figma node 377:483 itself specifies for this block.
    return Container(
      color: AppColors.surface100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Perfil', style: AppTextStyles.profileScreenTitle),
                Row(
                  children: [
                    _HeaderIconButton(
                      icon: Icons.edit_outlined,
                      onTap: onEditTap,
                    ),
                    const SizedBox(width: 10),
                    _HeaderIconButton(
                      icon: Icons.settings_outlined,
                      onTap: onSettingsTap,
                    ),
                    const SizedBox(width: 10),
                    _HeaderIconButton(icon: Icons.ios_share, onTap: onShareTap),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ProfileAvatar(
                  avatarPath: avatarPath,
                  initials: initials,
                  onTap: onAvatarTap,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    fullName,
                    style: AppTextStyles.profileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          _StatsRow(
            tripsCount: tripsCount,
            badgesCount: badgesCount,
            points: points,
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.profileDivider,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: AppColors.settingsTextDark),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.avatarPath,
    required this.initials,
    required this.onTap,
  });

  final String? avatarPath;
  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final path = avatarPath;
    final hasPhoto = path != null && path.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.settingsAccent, AppColors.settingsDanger],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.settingsAccent.withValues(alpha: 0.35),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(1.6),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            border: Border.fromBorderSide(
              BorderSide(color: AppColors.surface100, width: 1.6),
            ),
          ),
          child: ClipOval(
            child: hasPhoto
                ? LocalImage(path: path)
                : Container(
                    color: AppColors.profileDivider,
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: AppTextStyles.h5.copyWith(
                        color: AppColors.settingsTextDark,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.tripsCount,
    required this.badgesCount,
    required this.points,
  });

  final int tripsCount;
  final int badgesCount;
  final int points;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.profileDivider, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatColumn(
              value: '$tripsCount',
              label: 'Viajes',
              showDivider: true,
            ),
          ),
          Expanded(
            child: _StatColumn(
              value: '$badgesCount',
              label: 'Insignias',
              showDivider: true,
            ),
          ),
          Expanded(
            child: _StatColumn(
              value: '$points',
              label: 'Puntos',
              showDivider: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.value,
    required this.label,
    required this.showDivider,
  });

  final String value;
  final String label;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(
                right: BorderSide(color: AppColors.profileDivider, width: 0.8),
              ),
            )
          : null,
      child: Column(
        children: [
          Text(value, style: AppTextStyles.profileStatValue),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.profileStatLabel),
        ],
      ),
    );
  }
}

class _LevelProgressCard extends StatelessWidget {
  const _LevelProgressCard({required this.levelInfo});

  final LevelInfo levelInfo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1AF0B500),
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      levelInfo.currentLevelName,
                      style: AppTextStyles.h6.copyWith(
                        color: AppColors.settingsTextDark,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      levelInfo.isMaxLevel
                          ? 'Nivel máximo alcanzado'
                          : 'Próximo: ${levelInfo.nextLevelName}',
                      style: AppTextStyles.profileLevelNext,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(
                        value: levelInfo.progress,
                        strokeWidth: 4,
                        backgroundColor: AppColors.progressTrack,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.tagGold600,
                        ),
                      ),
                    ),
                    Text(
                      '${(levelInfo.progress * 100).round()}%',
                      style: AppTextStyles.profileProgressPercent,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: levelInfo.progress,
              minHeight: 6,
              backgroundColor: AppColors.progressTrack,
              valueColor: const AlwaysStoppedAnimation(AppColors.tagGold600),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${levelInfo.points} puntos',
                style: AppTextStyles.profileCaption10,
              ),
              Text(
                levelInfo.isMaxLevel
                    ? 'Nivel máximo'
                    : 'Meta: ${levelInfo.nextLevelMinPoints} pts',
                style: AppTextStyles.profileCaption10,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One continuous pill (Figma's "Barra favoritos y medallas") — a single
/// sliding gradient indicator behind two equal tap zones, not two
/// independently-rounded buttons with a gap between them. The slide uses a
/// real (implicit) Flutter animation — [AnimatedAlign] with an
/// overshoot curve — for a livelier feel than a flat linear cross-fade;
/// [ClipRRect] keeps that overshoot from poking past the pill's rounded
/// corners mid-bounce.
class _ProfileTabSelector extends StatelessWidget {
  const _ProfileTabSelector({required this.activeTab, required this.onChanged});

  final int activeTab;
  final ValueChanged<int> onChanged;

  static const _labels = ['Favoritos', 'Insignias'];
  static const _icons = [
    Icons.favorite_border_rounded,
    Icons.workspace_premium_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      // A touch bigger than before (52 vs 48) — a plain Stack child (the
      // Row below) shrink-wraps to its own content height and then sits
      // at the Stack's default top-start corner instead of filling it, so
      // growing this container without also fixing that would have just
      // pushed the icon/label further off-center instead of "bigger."
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 340),
                curve: Curves.easeOutBack,
                alignment: activeTab == 0
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary500, AppColors.primary700],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            // Positioned.fill (not a bare Row) so the icon+label content
            // is centered across the *entire* pill height/width, not just
            // shrink-wrapped and pinned to the top-left corner.
            Positioned.fill(
              child: Row(
                children: [
                  for (var i = 0; i < _labels.length; i++)
                    Expanded(
                      child: _ProfileTabButton(
                        icon: _icons[i],
                        label: _labels[i],
                        selected: activeTab == i,
                        onTap: () => onChanged(i),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTabButton extends StatelessWidget {
  const _ProfileTabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: AppTextStyles.buttonMd.copyWith(
          color: selected ? AppColors.neutral1100 : AppColors.neutral700,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                key: ValueKey(selected),
                size: 24,
                color: selected ? AppColors.neutral1100 : AppColors.neutral700,
              ),
            ),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// Favoritos tab — a single list merging both real sources a heart can
/// favorite: curated [DestinationModel]s (Home/Map cards) and
/// user-registered [BusinessModel]s (BusinessDetailScreen's AppBar heart).
/// Both id spaces share the same [FavoritesService] set, so both must be
/// cross-referenced for a saved business to actually show up here.
class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab({
    super.key,
    required this.destinations,
    required this.businesses,
    required this.onToggleFavorite,
    required this.onExplore,
  });

  final List<DestinationModel> destinations;
  final List<BusinessModel> businesses;
  final ValueChanged<String> onToggleFavorite;
  final VoidCallback? onExplore;

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty && businesses.isEmpty) {
      return _FavoritesEmptyState(onExplore: onExplore);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Ver todos ▼',
            style: AppTextStyles.buttonSm.copyWith(color: AppColors.neutral900),
          ),
        ),
        const SizedBox(height: 8),
        for (final destination in destinations) ...[
          _FavoritePlaceCard(
            destination: destination,
            onFavoriteToggle: () => onToggleFavorite(destination.id),
          ),
          const SizedBox(height: 10),
        ],
        for (final business in businesses) ...[
          _FavoriteBusinessCard(
            business: business,
            onFavoriteToggle: () => onToggleFavorite(business.id),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _FavoritesEmptyState extends StatelessWidget {
  const _FavoritesEmptyState({required this.onExplore});

  final VoidCallback? onExplore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary500.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border,
              size: 32,
              color: AppColors.primary500,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Aún no tienes lugares guardados',
            textAlign: TextAlign.center,
            style: AppTextStyles.h6.copyWith(color: AppColors.settingsTextDark),
          ),
          const SizedBox(height: 6),
          Text(
            'Toca el corazón en cualquier destino para guardarlo aquí.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyText2.copyWith(
              color: AppColors.settingsTextMuted,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onExplore,
              icon: const Icon(Icons.explore_outlined),
              label: const Text('Explorar Nicaragua'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: AppColors.textInk,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: AppTextStyles.buttonLg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1AF0B500),
            offset: Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 64,
              height: 58,
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
                Text(
                  destination.title,
                  style: AppTextStyles.favoriteCardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 9,
                      color: AppColors.settingsTextMuted,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        destination.location,
                        style: AppTextStyles.favoriteCardCaption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onFavoriteToggle,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.favorite, size: 20, color: Color(0xFFE8798F)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Same card language as [_FavoritePlaceCard], sourced from a favorited
/// [BusinessModel] instead of a curated [DestinationModel].
class _FavoriteBusinessCard extends StatelessWidget {
  const _FavoriteBusinessCard({
    required this.business,
    required this.onFavoriteToggle,
  });

  final BusinessModel business;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final imagePath = business.localImagePaths.isNotEmpty
        ? business.localImagePaths.first
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1AF0B500),
            offset: Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 64,
              height: 58,
              child: LocalImage(
                path: imagePath,
                fallbackIcon: Icons.storefront_outlined,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  business.name,
                  style: AppTextStyles.favoriteCardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 9,
                      color: AppColors.settingsTextMuted,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        business.city,
                        style: AppTextStyles.favoriteCardCaption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onFavoriteToggle,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.favorite, size: 20, color: Color(0xFFE8798F)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgesTab extends StatelessWidget {
  const _BadgesTab({super.key, required this.badges, required this.onBadgeTap});

  final List<BadgeInfo> badges;

  /// Called for *every* tap, locked or unlocked — the parent decides which
  /// dialog to show based on [BadgeInfo.unlocked].
  final ValueChanged<BadgeInfo> onBadgeTap;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      // Figma's 112.66×106.80 cell is a single measured instance (a
      // 1-line title), not a hard constraint — Flutter's GridView forces
      // every cell to that exact ratio, so a 2-line badge title (very
      // common here: "Guardián del Bosque", "Viajero Consciente"...) plus
      // the unlocked status pill genuinely needs more height, which is
      // exactly what was overflowing. 0.92 gives that real content room
      // instead of reproducing Figma's one sampled measurement verbatim.
      childAspectRatio: 0.92,
      children: [
        for (final badge in badges)
          _BadgeCard(badge: badge, onTap: () => onBadgeTap(badge)),
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge, required this.onTap});

  final BadgeInfo badge;

  /// Always tappable now — locked shows the gray requirement dialog,
  /// unlocked shows the full-color "insignia obtenida" one.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unlocked = badge.unlocked;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: unlocked ? 1 : 0.7,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
          decoration: BoxDecoration(
            color: unlocked ? AppColors.surface100 : AppColors.progressTrack,
            borderRadius: BorderRadius.circular(18),
            boxShadow: unlocked
                ? [
                    BoxShadow(
                      color: badge.tint.withValues(alpha: 0.14),
                      offset: const Offset(0, 4),
                      blurRadius: 8,
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
                  color: unlocked
                      ? badge.tint.withValues(alpha: 0.09)
                      : AppColors.profileMuted.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  badge.icon,
                  size: 22,
                  color: unlocked ? badge.tint : AppColors.profileMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                badge.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.badgeCardTitle.copyWith(
                  color: unlocked
                      ? AppColors.settingsTextDark
                      : AppColors.profileMuted,
                ),
              ),
              const SizedBox(height: 6),
              // Same padded box for both states (only the fill color
              // differs) — mismatched box heights between "✓ Obtenida"
              // and a bare "Bloqueada" Text was exactly what pushed
              // unlocked cards past the grid cell's height.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: unlocked
                      ? badge.tint.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  unlocked ? '✓ Obtenida' : 'Bloqueada',
                  style: AppTextStyles.badgeStatusPill.copyWith(
                    color: unlocked ? badge.tint : AppColors.profileMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Mis Negocios" — only rendered by [ProfileScreen] when the signed-in
/// account owns at least one [BusinessModel] (matched by
/// [BusinessModel.ownerId]). Each card lets the owner edit (reopens
/// [RegisterBusinessWizard] pre-filled) or delete (with confirmation) their
/// own listing.
class _MyBusinessesSection extends StatelessWidget {
  const _MyBusinessesSection({
    required this.businesses,
    required this.onEdit,
    required this.onDelete,
  });

  final List<BusinessModel> businesses;
  final ValueChanged<BusinessModel> onEdit;
  final ValueChanged<BusinessModel> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mis Negocios', style: AppTextStyles.detailSectionTitle),
        const SizedBox(height: 10),
        if (businesses.isEmpty)
          Text(
            'Aún no tienes negocios registrados.',
            style: AppTextStyles.bodyText2.copyWith(
              color: AppColors.settingsTextMuted,
            ),
          )
        else
          for (final business in businesses) ...[
            _MyBusinessCard(
              business: business,
              onEdit: () => onEdit(business),
              onDelete: () => onDelete(business),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _MyBusinessCard extends StatelessWidget {
  const _MyBusinessCard({
    required this.business,
    required this.onEdit,
    required this.onDelete,
  });

  final BusinessModel business;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final imagePath = business.localImagePaths.isNotEmpty
        ? business.localImagePaths.first
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1AF0B500),
            offset: Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 58,
                  height: 52,
                  child: LocalImage(
                    path: imagePath,
                    fallbackIcon: Icons.storefront_outlined,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      style: AppTextStyles.favoriteCardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 9,
                          color: AppColors.settingsTextMuted,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            business.city,
                            style: AppTextStyles.favoriteCardCaption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.wizardFocus,
                    side: const BorderSide(color: AppColors.warmChipBorder),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Eliminar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.settingsDanger,
                    side: BorderSide(
                      color: AppColors.settingsDanger.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
