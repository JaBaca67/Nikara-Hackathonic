import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_spacing.dart';

/// Controles y panel comparten flujo vertical para que sus alturas reales,
/// junto al espacio de la barra inferior, determinen su posición.
class MapBottomDock extends StatelessWidget {
  const MapBottomDock({
    super.key,
    this.leading,
    this.recommendationLabel,
    this.locationControl,
    this.assistantControl,
    this.panel,
  });

  final Widget? leading;
  final Widget? recommendationLabel;
  final Widget? locationControl;
  final Widget? assistantControl;
  final Widget? panel;

  @override
  Widget build(BuildContext context) {
    final hasControls =
        leading != null || locationControl != null || assistantControl != null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasControls)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (recommendationLabel != null)
                      Expanded(child: recommendationLabel!),
                    ?leading,
                    if (leading != null) const SizedBox(width: AppSpacing.md),
                    if (recommendationLabel == null) const Spacer(),
                    if (recommendationLabel != null)
                      const SizedBox(width: AppSpacing.sm),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.65,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ?locationControl,
                          if (locationControl != null &&
                              assistantControl != null)
                            const SizedBox(height: AppSpacing.sm),
                          ?assistantControl,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (hasControls && panel != null && recommendationLabel == null)
              const SizedBox(height: AppSpacing.md),
            ?panel,
          ],
        ),
      ),
    );
  }
}
