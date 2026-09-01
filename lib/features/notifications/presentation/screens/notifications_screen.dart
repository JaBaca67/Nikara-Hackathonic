import 'package:flutter/material.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/presentation/screens/business_detail_screen.dart';
import 'package:nikara_app/features/eco/data/eco_service.dart';
import 'package:nikara_app/features/eco/data/organization_service.dart';
import 'package:nikara_app/features/eco/presentation/screens/eco_detail_screen.dart';
import 'package:nikara_app/features/eco/presentation/screens/organization_profile_screen.dart';
import 'package:nikara_app/features/notifications/data/notification_service.dart';
import 'package:nikara_app/features/notifications/domain/models/app_notification.dart';
import 'package:nikara_app/features/notifications/presentation/widgets/notification_tile.dart';
import 'package:nikara_app/features/notifications/presentation/widgets/notifications_states.dart';
import 'package:nikara_app/shared/widgets/circle_back_button.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Bandeja de notificaciones in-app (tabla `notifications`).
///
/// **Tier: Funcional.** Fondo [AppColors.background], superficies
/// [AppColors.surface100]/[AppColors.profileDivider] y un solo acento de
/// marca visible — el dorado del punto "sin leer", el chip de ícono y el CTA
/// de los estados vacíos. Sin oliva ni gradientes de marca.
///
/// Alcance: solo in-app. No hay push/FCM; la campana de Inicio y esta
/// pantalla leen la misma tabla.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService();

  List<AppNotification>? _notifications;
  String? _error;

  /// True mientras se resuelve el recurso de una notificación ya tocada —
  /// evita abrir dos detalles por un doble toque.
  bool _opening = false;

  bool get _isGuest => !AuthService().isLoggedIn;

  int get _unreadCount => _notifications?.where((n) => !n.isRead).length ?? 0;

  @override
  void initState() {
    super.initState();
    if (!_isGuest) _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _notifications = null;
    });
    try {
      final rows = await _service.getMine();
      if (!mounted) return;
      setState(() => _notifications = rows);
    } on NotificationServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _notifications = const [];
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Optimista: la fila se ve leída de inmediato y se revierte si el `update`
  /// falla, para que el listado no se quede mintiendo.
  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) return;
    _replace(notification.copyWith(isRead: true));
    try {
      await _service.markAsRead(notification.id);
    } on NotificationServiceException catch (e) {
      _replace(notification);
      _showMessage(e.message);
    }
  }

  Future<void> _markAllAsRead() async {
    final current = _notifications;
    if (current == null || _unreadCount == 0) return;
    setState(() {
      _notifications = current
          .map((n) => n.copyWith(isRead: true))
          .toList(growable: false);
    });
    try {
      await _service.markAllAsRead();
    } on NotificationServiceException catch (e) {
      if (!mounted) return;
      setState(() => _notifications = current);
      _showMessage(e.message);
    }
  }

  Future<void> _delete(AppNotification notification) async {
    final current = _notifications;
    if (current == null) return;
    setState(() {
      _notifications = current
          .where((n) => n.id != notification.id)
          .toList(growable: false);
    });
    try {
      await _service.delete(notification.id);
    } on NotificationServiceException catch (e) {
      if (!mounted) return;
      setState(() => _notifications = current);
      _showMessage(e.message);
    }
  }

  void _replace(AppNotification updated) {
    final current = _notifications;
    if (current == null || !mounted) return;
    setState(() {
      _notifications = [
        for (final n in current) n.id == updated.id ? updated : n,
      ];
    });
  }

  /// Tocar una notificación siempre la marca como leída; navegar es lo
  /// opcional. Un `reference_id` huérfano (el recurso se eliminó) o un tipo
  /// no navegable no es un error: se avisa y la notificación queda leída.
  Future<void> _open(AppNotification notification) async {
    if (_opening) return;
    await _markAsRead(notification);
    if (!mounted || !notification.isNavigable) return;

    setState(() => _opening = true);
    try {
      switch (notification.type.target) {
        case NotificationTarget.business:
          await _openBusiness(notification.referenceId!);
        case NotificationTarget.ecoActivity:
          await _openEcoActivity(notification.referenceId!);
        case NotificationTarget.organization:
          await _openOrganization(notification.referenceId!);
        case NotificationTarget.none:
          break;
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _openBusiness(String id) async {
    BusinessModel? business;
    try {
      // `BusinessStorageService` no expone un `getById`; el listado completo
      // es una lectura pública barata y ya está cacheada en la mayoría de los
      // casos, así que se filtra acá en vez de tocar ese servicio.
      //
      // Se buscan también los negocios propios porque el listado público solo
      // trae aprobados: la notificación de "necesita ajustes" apunta
      // justamente a uno que ya no está ahí, y sin este segundo intento
      // tocarla diría que el negocio no existe.
      final service = BusinessStorageService();
      final candidates = [
        ...await service.getBusinesses(),
        ...await service.getMyBusinesses(),
      ];
      for (final candidate in candidates) {
        if (candidate.id == id) {
          business = candidate;
          break;
        }
      }
    } on BusinessServiceException catch (e) {
      _showMessage(e.message);
      return;
    }
    if (!mounted) return;
    if (business == null) {
      _showMessage('Este negocio ya no está disponible.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BusinessDetailScreen(business: business!),
      ),
    );
  }

  Future<void> _openEcoActivity(String id) async {
    try {
      final activity = await EcoService().getActivityById(id);
      if (!mounted) return;
      if (activity == null) {
        _showMessage('Esta jornada ya no está disponible.');
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EcoDetailScreen(activity: activity)),
      );
    } on EcoServiceException catch (e) {
      _showMessage(e.message);
    }
  }

  Future<void> _openOrganization(String id) async {
    try {
      final organization = await OrganizationService().getById(id);
      if (!mounted) return;
      if (organization == null) {
        _showMessage('Esta fundación ya no está disponible.');
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OrganizationProfileScreen(organization: organization),
        ),
      );
    } on OrganizationServiceException catch (e) {
      _showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              unreadCount: _unreadCount,
              onMarkAll: _unreadCount > 0 ? _markAllAsRead : null,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isGuest) return const NotificationsGuestState();

    final error = _error;
    if (error != null) {
      return NotificationsErrorState(message: error, onRetry: _load);
    }

    final notifications = _notifications;
    if (notifications == null) return const NotificationsSkeleton();

    if (notifications.isEmpty) {
      return NotificationsEmptyState(
        onExplore: () => Navigator.of(context).maybePop(),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary500,
      backgroundColor: AppColors.surface100,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        itemCount: notifications.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return Dismissible(
            key: ValueKey(notification.id),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => _delete(notification),
            background: const _DismissBackground(),
            child: NotificationTile(
              notification: notification,
              onTap: () => _open(notification),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.unreadCount, this.onMarkAll});

  final int unreadCount;
  final VoidCallback? onMarkAll;

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (unreadCount) {
      0 => 'Estás al día',
      1 => '1 sin leer',
      _ => '$unreadCount sin leer',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          CircleBackButton(onTap: () => Navigator.of(context).maybePop()),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notificaciones',
                  style: AppTextStyles.wizardAppBarTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.wizardCaption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onMarkAll != null)
            TextButton(
              onPressed: onMarkAll,
              child: Text(
                'Marcar todas',
                style: AppTextStyles.linkSm.copyWith(
                  color: AppColors.oliveText,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fondo que aparece al deslizar una fila hacia la izquierda para eliminarla.
class _DismissBackground extends StatelessWidget {
  const _DismissBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.destructive,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Icon(
        Icons.delete_outline_rounded,
        semanticLabel: 'Eliminar notificación',
        color: AppColors.textInverted,
      ),
    );
  }
}
