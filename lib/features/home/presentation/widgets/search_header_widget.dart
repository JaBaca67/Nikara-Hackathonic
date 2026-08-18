import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

String _timeOfDayGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Buenos días';
  if (hour < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

/// Top-of-Home header — a full-width white panel with a hairline bottom
/// border (Pantalla 2a), not a transparent strip: greeting + "¿A dónde
/// vamos?" heading on the left, the notifications bell on the right, then
/// the search field + filter button row. Three real greeting states — a
/// signed-in user with a name ("Buenos días, {nombre}"), a signed-in user
/// with no name on file ("¡A dónde vamos!"), and [isGuest]
/// ("¡Hola, Explorador!") — the badge only shows once [notificationCount]
/// is actually greater than 0 (this app has no real notifications feed
/// yet, so it stays hidden rather than showing the mock's static "3").
class SearchHeaderWidget extends StatelessWidget {
  const SearchHeaderWidget({
    super.key,
    this.userName,
    this.isGuest = false,
    this.controller,
    this.onSearchChanged,
    this.notificationCount = 0,
    this.onNotificationTap,
    this.onFilterTap,
  });

  final String? userName;
  final bool isGuest;
  final TextEditingController? controller;
  final ValueChanged<String>? onSearchChanged;
  final int notificationCount;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onFilterTap;

  @override
  Widget build(BuildContext context) {
    final name = userName?.trim();
    final greeting = isGuest
        ? '¡Hola, Explorador!'
        : (name == null || name.isEmpty)
        ? '¡A dónde vamos!'
        : '${_timeOfDayGreeting()}, $name';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface100,
        border: Border(bottom: BorderSide(color: AppColors.profileDivider)),
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
                      greeting,
                      style: AppTextStyles.homeGreeting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '¿A dónde vamos?',
                      style: AppTextStyles.homeHeading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _NotificationButton(
                count: notificationCount,
                onTap: onNotificationTap,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SearchField(
                  controller: controller,
                  onChanged: onSearchChanged,
                ),
              ),
              const SizedBox(width: 10),
              _FilterButton(onTap: onFilterTap),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({this.controller, this.onChanged});

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.settingsBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mapControlBorder),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTextStyles.homeSearchHint.copyWith(
          color: AppColors.settingsTextDark,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          hintText: 'Buscar lagunas, tours, restaurantes...',
          hintStyle: AppTextStyles.homeSearchHint,
          prefixIcon: const Icon(
            Icons.search,
            size: 16,
            color: AppColors.settingsTextMuted,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 38),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Filtros y orden',
      child: Material(
        color: AppColors.primary500,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: const SizedBox(
            width: 46,
            height: 46,
            child: Icon(
              Icons.tune_rounded,
              size: 18,
              color: AppColors.settingsTextDark,
            ),
          ),
        ),
      ),
    );
  }
}

/// 38px circle, cream fill, ink bell — Pantalla 2a's notification bell.
class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Notificaciones${count > 0 ? ', $count sin leer' : ''}',
      child: Material(
        color: AppColors.profileDivider,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  size: 17,
                  color: AppColors.settingsTextDark,
                ),
                if (count > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 17,
                      height: 17,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary500,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.surface100,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: AppTextStyles.homeMiniBadge.copyWith(
                          color: AppColors.settingsTextDark,
                          fontSize: count > 9 ? 7 : 9,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
