import 'package:flutter/material.dart';

import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/features/admin/data/admin_service.dart';
import 'package:nikara_app/features/admin/domain/models/admin_user_summary.dart';
import 'package:nikara_app/features/admin/presentation/widgets/admin_widgets.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Listado de perfiles y su rol — **solo admin**.
///
/// Es lectura, no gestión: cambiar el rol de otra persona desde el cliente es
/// exactamente lo que `001_profiles_trigger_and_rls.sql` bloqueó a propósito
/// (`revoke update on profiles` + `promote_to_emprendedor()` como único
/// camino). Habilitarlo requiere un RPC nuevo, no un `update` desde acá.
class AdminUsersView extends StatefulWidget {
  const AdminUsersView({super.key, this.active = true, this.refreshToken = 0});

  /// Ver `AdminReviewView.active`: mismo `IndexedStack`, mismo bug de
  /// snapshot viejo (ej. el rol recién promovido a "Emprendedor" no se veía
  /// hasta un pull-to-refresh manual).
  final bool active;

  /// Ver `AdminReviewView.refreshToken`.
  final int refreshToken;

  @override
  State<AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends State<AdminUsersView> {
  final _service = AdminService();

  List<AdminUserSummary>? _users;
  String? _error;
  UserRole? _roleFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AdminUsersView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final justActivated = widget.active && !oldWidget.active;
    final refreshed =
        widget.active && widget.refreshToken != oldWidget.refreshToken;
    if (justActivated || refreshed) _load();
  }

  Future<void> _load() async {
    setState(() {
      _users = null;
      _error = null;
    });
    try {
      final users = await _service.getUsers();
      if (!mounted) return;
      setState(() => _users = users);
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return AdminPlaceholder(
        icon: Icons.people_outline,
        title: 'No se pudo cargar el listado',
        message: _error!,
        onRetry: _load,
      );
    }
    final users = _users;
    if (users == null) return const AdminLoading();

    final filtered = _roleFilter == null
        ? users
        : users.where((u) => u.role == _roleFilter).toList(growable: false);

    return Column(
      children: [
        _RoleFilterBar(
          selected: _roleFilter,
          counts: {
            for (final role in UserRole.values)
              role: users.where((u) => u.role == role).length,
          },
          onSelected: (role) => setState(() => _roleFilter = role),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const AdminPlaceholder(
                  icon: Icons.person_search_outlined,
                  title: 'Ningún usuario con ese rol',
                  message: 'Prueba con otro filtro.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.oliveText,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.xxxl,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) =>
                        _UserRow(user: filtered[index]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _RoleFilterBar extends StatelessWidget {
  const _RoleFilterBar({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final UserRole? selected;
  final Map<UserRole, int> counts;
  final ValueChanged<UserRole?> onSelected;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold<int>(0, (sum, c) => sum + c);
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          _FilterChip(
            label: 'Todos ($total)',
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final role in UserRole.values)
            _FilterChip(
              label: '${role.label} (${counts[role] ?? 0})',
              selected: selected == role,
              onTap: () => onSelected(role),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm, top: AppSpacing.md),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.oliveFill : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.oliveFill : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.settingsRowCaption.copyWith(
              color: selected
                  ? AppColors.textPrimary
                  : AppColors.settingsTextMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user});

  final AdminUserSummary user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.profileDivider,
              shape: BoxShape.circle,
            ),
            child: Text(
              user.initials,
              style: AppTextStyles.settingsRowTitle.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.displayName,
                  style: AppTextStyles.settingsRowTitle.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  user.email.isEmpty ? 'Sin correo' : user.email,
                  style: AppTextStyles.settingsRowCaption.copyWith(
                    color: AppColors.settingsTextMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _RoleTag(role: user.role),
        ],
      ),
    );
  }
}

/// Etiqueta de rol.
///
/// Solo el rol con privilegios de moderación se pinta con el acento Olive;
/// turista y emprendedor van en neutro. Así el listado se escanea buscando
/// justo lo que un admin necesita auditar: quién tiene poder.
class _RoleTag extends StatelessWidget {
  const _RoleTag({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final privileged = role == UserRole.admin;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: privileged ? AppColors.oliveFill : AppColors.profileDivider,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        role.label,
        style: AppTextStyles.homeMiniBadge.copyWith(
          color: privileged
              ? AppColors.textPrimary
              : AppColors.settingsTextMuted,
        ),
      ),
    );
  }
}
