import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:nikara_app/core/gamification/badges_logic.dart';
import 'package:nikara_app/core/gamification/gamification_engine.dart';
import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/favorites_service.dart';
import 'package:nikara_app/core/services/profile_face_service.dart';
import 'package:nikara_app/core/services/user_stats_service.dart';
import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/eco/data/eco_service.dart';
import 'package:nikara_app/features/home/data/mock_destinations.dart';
import 'package:nikara_app/features/home/domain/models/destination.dart';
import 'package:nikara_app/features/profile/presentation/screens/face_profile_screen.dart';
import 'package:nikara_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:nikara_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:nikara_app/shared/widgets/account_switcher_sheet.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/shared/widgets/profile_face_sheet.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Figma nodes 377:483/421:361. Todo se calcula en vivo desde Supabase/[FavoritesService]/[UserStatsService], sin datos mock de respaldo.
///
/// **Control de cambio de cara — provisional.** El nombre de la cara activa con
/// un chevron al lado, en la cabecera, abre la hoja de perfiles
/// ([showProfileFaceSheet]). Es un gesto de trabajo, decidido sin prototipo de
/// Claude Design, para que la interacción exista y se pueda probar; el pulido
/// visual viene después. El avatar **no** cambió de función: sigue sirviendo
/// para cambiar la foto de perfil, que es justo por qué el cambio de cara
/// necesitaba un control propio y no podía colgarse de él.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onExploreRequested});

  /// Null cuando esta pantalla no vive dentro de [MainLayout] (ej. tests); el botón simplemente se oculta.
  final VoidCallback? onExploreRequested;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _favoritesService = FavoritesService();
  final _userStatsService = UserStatsService();
  final _businessStorageService = BusinessStorageService();
  final _faceService = ProfileFaceService();

  bool _isLoading = true;
  String? _loadError;
  UserModel? _profile;

  /// Deshabilita el avatar mientras la foto nueva sube a Storage, para que no
  /// se disparen dos subidas en paralelo.
  bool _isSavingAvatar = false;
  List<DestinationModel> _favoriteDestinations = const [];
  List<BusinessModel> _favoriteBusinesses = const [];
  UserStats _stats = const UserStats(
    tripsCount: 0,
    savedPlacesCount: 0,
    reviewsCount: 0,
  );
  int _activeTab = 0; // 0 = Favoritos, 1 = Insignias

  @override
  void initState() {
    super.initState();
    // Mantienen la pantalla sincronizada sin refresco manual, incluso mientras Profile está inerte en el IndexedStack de MainLayout.
    _favoritesService.idsNotifier.addListener(_onDataChanged);
    BusinessStorageService.revision.addListener(_onDataChanged);
    EcoService.revision.addListener(_onDataChanged);
    ProfileFaceService.revision.addListener(_onFacesChanged);
    _loadAll();
  }

  @override
  void dispose() {
    _favoritesService.idsNotifier.removeListener(_onDataChanged);
    BusinessStorageService.revision.removeListener(_onDataChanged);
    EcoService.revision.removeListener(_onDataChanged);
    ProfileFaceService.revision.removeListener(_onFacesChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (!mounted) return;
    _loadAll();
  }

  /// Un cambio de cara no recarga favoritos ni estadísticas: solo cambia qué
  /// se dibuja arriba, así que alcanza con reconstruir.
  void _onFacesChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadAll() async {
    setState(() => _loadError = null);
    try {
      final profile = await _authService.getCurrentProfile();
      final favoriteIds = await _favoritesService.getFavoriteIds();
      final stats = await _userStatsService.getStats();
      final allBusinesses = await _businessStorageService.getBusinesses();
      if (!mounted) return;

      // Los favoritos mezclan ids de DestinationModel y de BusinessModel en el mismo set: hay que cruzar ambas fuentes o se pierden los negocios favoritos.
      final favoriteDestinations = mockDestinations
          .where((d) => favoriteIds.contains(d.id))
          .toList(growable: false);
      final favoriteBusinesses = allBusinesses
          .where((b) => favoriteIds.contains(b.id))
          .toList(growable: false);

      // Forzado: una cara nace cuando un admin aprueba la solicitud, del lado
      // del servidor, así que el cliente no se entera por ningún evento local.
      // Recargar acá es lo que hace que la cara nueva aparezca al volver al
      // perfil.
      await _faceService.load(force: true);
      if (!mounted) return;

      setState(() {
        _profile = profile;
        _favoriteDestinations = favoriteDestinations;
        _favoriteBusinesses = favoriteBusinesses;
        _stats = stats;
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

  Future<void> _toggleFavorite(String id) async {
    // Sin _loadAll() manual: togglear notifica al listener de arriba, que ya recarga la pantalla.
    try {
      await _favoritesService.toggleFavorite(id);
    } on FavoritesServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _isSavingAvatar = true);
    try {
      await _authService.updateAvatar(picked);
      await _loadAll();
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSavingAvatar = false);
    }
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  /// Control provisional de cambio de cara — ver el docstring de la pantalla.
  Future<void> _openFaceSheet() async {
    final changed = await showProfileFaceSheet(context);
    if (!mounted || !changed) return;
    await _loadAll();
  }

  Future<void> _openAccountSwitcher() async {
    await showAccountSwitcherSheet(context);
    if (!mounted) return;
    // Alternar de cuenta reconstruye la app entera, así que este recargar solo
    // cubre el caso de cerrar la hoja sin cambiar nada.
    await _loadAll();
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
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

  void _onBadgeTap(BadgeInfo badge) {
    if (badge.unlocked) {
      _showBadgeUnlocked(badge);
    } else {
      _showBadgeRequirement(badge);
    }
  }

  void _showBadgeUnlocked(BadgeInfo badge) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
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
                borderRadius: BorderRadius.circular(AppRadius.pill),
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 44,
                    color: AppColors.destructive,
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

    // Con una cara de negocio o fundación puesta, la pestaña Perfil muestra el
    // perfil de esa cara. La de turista es la única con la experiencia completa
    // —favoritos, insignias, gamificación— y por eso es la que vive acá.
    final activeFace = _faceService.activeFace;
    if (activeFace != null && !activeFace.isTurista) {
      return FaceProfileScreen(
        face: activeFace,
        onFaceTap: _openFaceSheet,
        onSettingsTap: _openSettings,
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
          // Sin esto la franja del status bar mostraría el fondo crema del Scaffold en vez de continuar el surface100 de _ProfileHeaderCard.
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
                // Espacio extra porque extendBody: true hace que la nav bar flotante se superponga al scroll en vez de reservar su propio espacio.
                padding: const EdgeInsets.only(bottom: 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ProfileHeaderShell(
                      actions: [
                        ProfileHeaderIconButton(
                          label: 'Cambiar de cuenta',
                          icon: Icons.switch_account_outlined,
                          onTap: _openAccountSwitcher,
                        ),
                        ProfileHeaderIconButton(
                          label: 'Editar perfil',
                          icon: Icons.edit_outlined,
                          onTap: _openSettings,
                        ),
                        ProfileHeaderIconButton(
                          label: 'Ajustes',
                          icon: Icons.settings_outlined,
                          onTap: _openSettings,
                        ),
                        ProfileHeaderIconButton(
                          label: 'Compartir perfil',
                          icon: Icons.ios_share,
                          onTap: _showComingSoon,
                        ),
                      ],
                      avatar: ProfileFaceAvatar(
                        imageUrl: _profile?.avatarUrl,
                        initials: initials,
                        label: 'Cambiar foto de perfil',
                        isSaving: _isSavingAvatar,
                        onTap: _pickAvatar,
                      ),
                      faceControl: FaceSelectorControl(
                        name: activeFace?.name ?? fullName,
                        kindLabel: activeFace?.kind.label,
                        onTap: _openFaceSheet,
                      ),
                      stats: [
                        ProfileStat(
                          value: '${_stats.tripsCount}',
                          label: 'Viajes',
                        ),
                        ProfileStat(
                          value: '$unlockedCount',
                          label: 'Insignias',
                        ),
                        ProfileStat(value: '$points', label: 'Puntos'),
                      ],
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
                      // Cross-fade en vez de cambio instantáneo; la key por índice es lo que hace que AnimatedSwitcher detecte el cambio de tab.
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

class _LevelProgressCard extends StatelessWidget {
  const _LevelProgressCard({required this.levelInfo});

  final LevelInfo levelInfo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardGlowSoft,
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

/// Pill continua (Figma "Barra favoritos y medallas"): un indicador deslizante, no dos botones separados; [ClipRRect] evita que el overshoot de [AnimatedAlign] se salga de las esquinas redondeadas.
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
      height: 52,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: const [
          BoxShadow(
            color: AppColors.profileCardShadow,
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
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
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
              ),
            ),
            // Positioned.fill (no un Row suelto) para centrar el contenido en todo el alto/ancho de la pill.
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
          color: selected ? AppColors.textPrimary : AppColors.neutral700,
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
                color: selected ? AppColors.textPrimary : AppColors.neutral700,
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

/// Lista única que mezcla [DestinationModel]s curados y [BusinessModel]s del usuario; ambos comparten el mismo set de [FavoritesService].
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
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
                  borderRadius: BorderRadius.circular(AppRadius.md),
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
            color: AppColors.cardGlowSoft,
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
              padding: EdgeInsets.all(AppSpacing.xs),
              child: Icon(
                Icons.favorite,
                size: 20,
                color: AppColors.favoriteActive,
                semanticLabel: 'Quitar de favoritos',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mismo lenguaje visual que [_FavoritePlaceCard], pero desde un [BusinessModel] favorito.
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
            color: AppColors.cardGlowSoft,
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
              padding: EdgeInsets.all(AppSpacing.xs),
              child: Icon(
                Icons.favorite,
                size: 20,
                color: AppColors.favoriteActive,
                semanticLabel: 'Quitar de favoritos',
              ),
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

  /// Se llama en todo tap, bloqueada o no; el padre decide el diálogo según [BadgeInfo.unlocked].
  final ValueChanged<BadgeInfo> onBadgeTap;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      // La celda de Figma medía un título de 1 línea; con títulos de 2 líneas + pill de estado, ese ratio desbordaba. 0.92 da el alto real que hace falta.
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
              // Mismo box con padding en ambos estados: alturas distintas entre "✓ Obtenida" y un Text suelto desbordaban la celda.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: unlocked
                      ? badge.tint.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
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
