import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Top-of-Home header: the "Nikara" wordmark, a search field and the
/// notifications bell with an unread-count badge (Figma nodes 124:44–190:335).
class SearchHeaderWidget extends StatelessWidget {
  const SearchHeaderWidget({
    super.key,
    this.controller,
    this.onSearchChanged,
    this.notificationCount = 0,
    this.onNotificationTap,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onSearchChanged;
  final int notificationCount;
  final VoidCallback? onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: Text('Nikara', style: AppTextStyles.headingXL)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(child: _SearchField(controller: controller, onChanged: onSearchChanged)),
              const SizedBox(width: 12),
              _NotificationButton(
                count: notificationCount,
                onTap: onNotificationTap,
              ),
            ],
          ),
        ),
      ],
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
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppColors.neutral1100, width: 2),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTextStyles.caption.copyWith(color: AppColors.neutral1100),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          hintText: 'Search...',
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
