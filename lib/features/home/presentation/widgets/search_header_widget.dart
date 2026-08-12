import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

String _timeOfDayGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Buenos días';
  if (hour < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

/// Top-of-Home header: a greeting line with three real states — a signed-in
/// user with a name ("Buenos días, {nombre}"), a signed-in user with no
/// name on file ("¡A dónde vamos!"), and [isGuest] ("¡Hola, Explorador!") —
/// the "¿A dónde vamos?" heading, a search field with a filter button, and
/// the notifications bell — badge only shown once [notificationCount] is
/// actually greater than 0.
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.neutral700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text('¿A dónde vamos?', style: AppTextStyles.sectionTitle),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _NotificationButton(count: notificationCount, onTap: onNotificationTap),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _SearchField(controller: controller, onChanged: onSearchChanged)),
              const SizedBox(width: 12),
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
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(25),
        boxShadow: AppColors.cardShadow,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTextStyles.caption.copyWith(color: AppColors.neutral1100),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          hintText: 'Buscar lagunas, tours, restaurantes...',
          hintStyle: AppTextStyles.caption.copyWith(
            color: const Color(0xFF808080),
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: Color(0xFF808080),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
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
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.tune_rounded, size: 20, color: AppColors.textInk),
          ),
        ),
      ),
    );
  }
}

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
        color: AppColors.notificationPill,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 37,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  size: 18,
                  color: AppColors.neutral900,
                ),
                if (count > 0)
                  Positioned(
                    top: -4,
                    right: 4,
                    child: Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.notificationBadge,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$count',
                        style: AppTextStyles.tagPill.copyWith(fontSize: 9),
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
