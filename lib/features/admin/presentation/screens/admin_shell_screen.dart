import 'package:flutter/material.dart';

import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/permission_service.dart';
import 'package:nikara_app/features/admin/presentation/widgets/admin_metrics_view.dart';
import 'package:nikara_app/features/admin/presentation/widgets/admin_review_view.dart';
import 'package:nikara_app/features/admin/presentation/widgets/admin_users_view.dart';
import 'package:nikara_app/features/admin/presentation/widgets/admin_widgets.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Un destino del panel, con el permiso que lo habilita.
///
/// El permiso viaja **dentro** del destino y no en un `if` de la UI: agregar
/// una sección nueva es agregar una fila a [_kDestinations], y quién la ve
/// queda decidido por la misma tabla de `UserRolePermissions` que gobierna
/// todo lo demás.
class _AdminDestination {
  const _AdminDestination({
    required this.permission,
    required this.icon,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.builder,
  });

  final Permission permission;
  final IconData icon;

  /// Texto de la barra inferior del panel.
  final String label;

  /// Título del encabezado cuando este destino está activo.
  final String title;
  final String subtitle;
  final WidgetBuilder builder;
}

const _kDestinations = <_AdminDestination>[
  _AdminDestination(
    permission: Permission.reviewSubmissions,
    icon: Icons.fact_check_outlined,
    label: 'Revisión',
    title: 'Cola de revisión',
    subtitle: 'Negocios esperando tu verificación',
    builder: _buildPending,
  ),
  _AdminDestination(
    permission: Permission.reviewSubmissions,
    icon: Icons.verified_outlined,
    label: 'Aprobados',
    title: 'Negocios aprobados',
    subtitle: 'Lo que ya está publicado en la app',
    builder: _buildApproved,
  ),
  _AdminDestination(
    permission: Permission.reviewSubmissions,
    icon: Icons.gpp_maybe_outlined,
    label: 'Rechazados',
    title: 'Negocios rechazados',
    subtitle: 'Esperando que su dueño los corrija',
    builder: _buildRejected,
  ),
  _AdminDestination(
    permission: Permission.viewGlobalMetrics,
    icon: Icons.insights_outlined,
    label: 'Métricas',
    title: 'Métricas de la plataforma',
    subtitle: 'Conteos globales de Níkara',
    builder: _buildMetrics,
  ),
  _AdminDestination(
    permission: Permission.manageUsers,
    icon: Icons.people_outline,
    label: 'Usuarios',
    title: 'Usuarios de Níkara',
    subtitle: 'Perfiles registrados y su rol',
    builder: _buildUsers,
  ),
];

Widget _buildPending(BuildContext _) =>
    const AdminReviewView(status: ReviewStatus.pendiente);
Widget _buildApproved(BuildContext _) =>
    const AdminReviewView(status: ReviewStatus.aprobado);
Widget _buildRejected(BuildContext _) =>
    const AdminReviewView(status: ReviewStatus.rechazado);
Widget _buildMetrics(BuildContext _) => const AdminMetricsView();
Widget _buildUsers(BuildContext _) => const AdminUsersView();

/// Experiencia propia de las cuentas `admin` y `auditor` — tier **Funcional**,
/// único acento de marca Olive.
///
/// Es un shell completo con su **propia** barra de navegación, no una pantalla
/// suelta colgada de Ajustes: el rol de moderación tiene un espacio de trabajo
/// al mismo nivel que el de un turista (mapa) o un emprendedor (registrar
/// negocio). La barra principal de la app se queda en 5 tabs y no se toca.
///
/// La diferencia auditor ↔ admin es literal y se ve en el primer segundo: el
/// auditor entra a un panel de **3 destinos** (Revisión, Aprobados,
/// Rechazados) y el admin a uno de **5** (suma Métricas y Usuarios). Sale de
/// filtrar [_kDestinations] por los permisos del rol activo, así que no hay
/// forma de que la barra y lo que el servicio permite se contradigan.
///
/// "Rechazados" no es un archivo muerto: un negocio rechazado sigue existiendo
/// y su dueño puede corregirlo y reenviarlo, así que tiene que poder mirarse
/// después de la decisión — si solo hubiera dos colas, rechazar equivaldría a
/// que el negocio desapareciera del panel.
class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key, this.onExit});

  /// Qué hace el botón "Volver a la app" del encabezado.
  ///
  /// Por defecto hace `pop` — correcto cuando el panel se abrió desde Ajustes.
  /// [AdminAwareHome] lo sobreescribe para intercambiar el shell por
  /// [MainLayout] sin pop, porque ahí el panel **es** la raíz de navegación y
  /// no habría a dónde volver.
  final VoidCallback? onExit;

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  final _permissions = PermissionService();

  UserRole? _role;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    // `force` porque el panel puede abrirse justo después de alternar de
    // cuenta: la caché podría estar resuelta para el usuario anterior.
    final role = await _permissions.load(force: true);
    if (!mounted) return;
    setState(() => _role = role);
  }

  List<_AdminDestination> _destinationsFor(UserRole role) => _kDestinations
      .where((d) => role.can(d.permission))
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final role = _role;
    if (role == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(child: AdminLoading()),
      );
    }

    final destinations = _destinationsFor(role);
    if (destinations.isEmpty) {
      // Defensa en profundidad: la entrada de Ajustes ya no se dibuja para
      // quien no tiene el permiso, pero el shell no confía en eso — si alguna
      // navegación futura empuja esta ruta, acá se corta igual.
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          title: Text(
            'Panel de Níkara',
            style: AppTextStyles.settingsTitle.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: const AdminPlaceholder(
          icon: Icons.lock_outline,
          title: 'Este panel no es para tu cuenta',
          message:
              'Solo las cuentas del equipo de Níkara (auditor o admin) '
              'pueden revisar contenido de la plataforma.',
        ),
      );
    }

    final index = _currentIndex.clamp(0, destinations.length - 1);
    final current = destinations[index];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _AdminHeader(
              role: role,
              title: current.title,
              subtitle: current.subtitle,
              onExit: widget.onExit ?? () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: IndexedStack(
                index: index,
                children: [
                  for (final destination in destinations)
                    Builder(builder: destination.builder),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _AdminNavBar(
        destinations: destinations,
        currentIndex: index,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

/// Encabezado del panel: identifica el rol desde el primer segundo.
class _AdminHeader extends StatelessWidget {
  const _AdminHeader({
    required this.role,
    required this.title,
    required this.subtitle,
    required this.onExit,
  });

  final UserRole role;
  final String title;
  final String subtitle;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.oliveFill,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 14,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      role.label,
                      style: AppTextStyles.homeMiniBadge.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // 48x48 de área táctil: el mínimo accesible que la auditoría
              // dejó marcado como incumplido en los wrappers de ícono viejos.
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  onPressed: onExit,
                  tooltip: 'Volver a la app',
                  icon: const Icon(
                    Icons.exit_to_app_rounded,
                    semanticLabel: 'Volver a la app',
                    size: 20,
                    color: AppColors.settingsTextMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: AppTextStyles.settingsTitle.copyWith(
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: AppTextStyles.settingsSubtitle.copyWith(
              color: AppColors.settingsTextMuted,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Barra inferior propia del panel.
///
/// No reusa `MainNavigationBar` a propósito: aquella tiene sus 5 destinos
/// codificados como constante de nivel superior y una píldora que interpola
/// por índice sobre ese ancho fijo. El panel tiene 2 o 4 destinos según el
/// rol, así que necesita una barra que se adapte a la cantidad.
class _AdminNavBar extends StatelessWidget {
  const _AdminNavBar({
    required this.destinations,
    required this.currentIndex,
    required this.onTap,
  });

  final List<_AdminDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: _AdminNavItem(
                  destination: destinations[i],
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AdminNavItem extends StatelessWidget {
  const _AdminNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _AdminDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.oliveText : AppColors.settingsTextMuted;
    return InkWell(
      onTap: onTap,
      child: Semantics(
        selected: selected,
        button: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(destination.icon, size: 22, color: color),
              const SizedBox(height: AppSpacing.xs),
              Text(
                destination.label,
                style: AppTextStyles.navLabel.copyWith(color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
