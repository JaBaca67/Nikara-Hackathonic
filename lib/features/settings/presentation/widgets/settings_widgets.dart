import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Esqueleto de cualquier vista de Ajustes: fondo, cabecera propia (atrás +
/// título) y contenido desplazable. La cabecera blanca llega hasta y=0 y
/// absorbe la barra de estado con su propio color — ver home_screen.dart.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.settingsBackground,
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsHeader(
              title: title,
              subtitle: subtitle,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class SettingsHeader extends StatelessWidget {
  const SettingsHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface100,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        MediaQuery.of(context).padding.top + AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          // Zona tocable de 48dp; el círculo visible sigue siendo de 36.
          Semantics(
            button: true,
            label: 'Volver',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBack,
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.profileDivider,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    size: 18,
                    color: AppColors.settingsTextDark,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.settingsTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.settingsSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta blanca con filas separadas por un filete, con una etiqueta opcional
/// encima. Las filas son [SettingsRow] / [SettingsToggleRow].
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, this.label, required this.children});

  final String? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text(
                label!.toUpperCase(),
                style: AppTextStyles.settingsSectionLabel,
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, label != null ? 6 : 0, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface100,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.detailCardGlow,
                    offset: Offset(0, 2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  children: [
                    for (var i = 0; i < children.length; i++)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: i == children.length - 1
                              ? null
                              : const Border(
                                  bottom: BorderSide(
                                    color: AppColors.cardGlowSoft,
                                    width: 0.8,
                                  ),
                                ),
                        ),
                        child: children[i],
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

/// Recuadro tintado con el ícono, compartido por filas, interruptores y botones del menú.
class SettingsIconTile extends StatelessWidget {
  const SettingsIconTile({
    super.key,
    required this.icon,
    this.tint = AppColors.settingsAccent,
    this.size = 32,
  });

  final IconData icon;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: size / 2, color: tint),
    );
  }
}

/// Fila con ícono, título y, opcionalmente, una línea de apoyo o un valor a la derecha.
///
/// El título siempre ocupa una sola línea; si hay [value] (correo, teléfono…)
/// es el valor el que se recorta con puntos suspensivos, nunca el título. Antes
/// ambos competían por el ancho y el título llegaba a partirse en tres líneas.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.caption,
    this.iconTint = AppColors.settingsAccent,
    this.titleColor = AppColors.settingsTextDark,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final String? caption;
  final Color iconTint;
  final Color titleColor;
  final VoidCallback? onTap;

  static const double _iconSize = 32;
  static const double _gap = 12;
  static const double _valueGap = 8;
  static const double _chevronSize = 16;

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTextStyles.settingsRowTitle.copyWith(
      color: titleColor,
    );
    final hasValue = value != null && value!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Al valor le toca lo que sobra después del título (a su ancho
              // natural) y del resto de la fila.
              var valueMaxWidth = 0.0;
              if (hasValue) {
                final titleWidth = _measure(context, title, titleStyle);
                valueMaxWidth =
                    (constraints.maxWidth -
                            _iconSize -
                            _gap -
                            titleWidth -
                            _valueGap * 2 -
                            _chevronSize)
                        .clamp(0.0, double.infinity);
              }
              return Row(
                children: [
                  SettingsIconTile(icon: icon, tint: iconTint),
                  const SizedBox(width: _gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: titleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (caption != null)
                          Text(
                            caption!,
                            style: AppTextStyles.settingsRowCaption,
                          ),
                      ],
                    ),
                  ),
                  if (hasValue) ...[
                    const SizedBox(width: _valueGap),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: valueMaxWidth),
                      child: Text(
                        value!,
                        style: AppTextStyles.settingsRowValue,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: _valueGap),
                  ],
                  const Icon(
                    Icons.chevron_right,
                    size: _chevronSize,
                    color: AppColors.settingsTextMuted,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static double _measure(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}

class SettingsToggleRow extends StatelessWidget {
  const SettingsToggleRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            SettingsIconTile(icon: icon),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: AppTextStyles.settingsRowTitle)),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.surface100,
              activeTrackColor: AppColors.settingsAccent,
              inactiveThumbColor: AppColors.surface100,
              inactiveTrackColor: AppColors.settingsToggleOff,
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón del menú principal de Ajustes: una categoría con ícono, título, una
/// línea de descripción y flecha. Pensado para vivir dentro de una [SettingsSection].
class SettingsMenuButton extends StatelessWidget {
  const SettingsMenuButton({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.tint = AppColors.settingsAccent,
    this.titleColor = AppColors.settingsTextDark,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Color tint;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $description',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                SettingsIconTile(icon: icon, tint: tint, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.settingsRowTitle.copyWith(
                          color: titleColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        description,
                        style: AppTextStyles.settingsRowCaption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.settingsTextMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
