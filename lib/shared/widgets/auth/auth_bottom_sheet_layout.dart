import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:nikara_app/shared/widgets/auth/nikara_logo_svg.dart';
import 'package:nikara_app/theme/app_theme.dart';
import 'package:nikara_app/widgets/aurora_background_widget.dart';

/// Estados de reposo del sheet: 0.10 es seguro porque el handle vive dentro del Scrollable; si vuelve a chocar con el gesto "swipe up" de Android, subir este valor (no reubicar el handle).
const double _kSheetHiddenSize = 0.10;
const double _kSheetOpenSize = 0.72;

/// Rango de arrastre tras [_kSheetHiddenSize] en el que el contenido se desvanece, para que quede invisible en reposo sin depender de los píxeles exactos que deja esa fracción.
const double _kContentFadeSpan = 0.08;

/// Gap fijo entre el logo y el borde superior del sheet cuando este lo alcanza.
const double _kLogoToSheetGap = 30.0;

/// Aumentado de 78 tras feedback de que se veía demasiado tímido para la marca.
const double _kLogoHeight = 150.0;

/// Shell compartido por las pantallas de Auth (Login + los 3 pasos de Register): fondo "Sunset" animado, logo, y un bottom sheet arrastrable con [child]. La altura de [child] decide el tamaño del sheet — un `AnimatedSwitcher` de contenido variable debe top-align el suyo propio.
class AuthBottomSheetLayout extends StatefulWidget {
  const AuthBottomSheetLayout({super.key, required this.child, this.onBack});

  final Widget child;

  /// Sin botón de back propio: un círculo flotante sobre el gradiente animado no se leía como tappable. Pantallas que necesitan uno lo agregan dentro de [child].
  final VoidCallback? onBack;

  @override
  State<AuthBottomSheetLayout> createState() => _AuthBottomSheetLayoutState();
}

class _AuthBottomSheetLayoutState extends State<AuthBottomSheetLayout> {
  final _sheetController = DraggableScrollableController();

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  double get _extent =>
      _sheetController.isAttached ? _sheetController.size : _kSheetOpenSize;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.onBack == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        widget.onBack?.call();
      },
      child: Scaffold(
        backgroundColor: AppColors.sunsetStart,
        resizeToAvoidBottomInset: true,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            final safeTop = MediaQuery.paddingOf(context).top;
            final baseCenterTop = (availableHeight - _kLogoHeight) / 2;

            return Stack(
              children: [
                const Positioned.fill(child: AuroraBackgroundWidget()),
                AnimatedBuilder(
                  animation: _sheetController,
                  builder: (context, _) {
                    final extent = _extent;
                    final sheetTopY = availableHeight * (1 - extent);
                    final sheetPushedTop =
                        sheetTopY - _kLogoToSheetGap - _kLogoHeight;
                    // Reposa al centro salvo que el sheet lo empuje hacia arriba, con clamp para no pasar el status bar.
                    final logoTop = math
                        .min(baseCenterTop, sheetPushedTop)
                        .clamp(safeTop + 8, availableHeight);
                    // AnimatedPositioned (no Positioned) da un pequeño rebote elástico en vez de seguir el extent del sheet 1:1.
                    return AnimatedPositioned(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutBack,
                      top: logoTop,
                      left: 0,
                      right: 0,
                      child: const Center(
                        child: NikaraLogoSvg(height: _kLogoHeight),
                      ),
                    );
                  },
                ),
                DraggableScrollableSheet(
                  controller: _sheetController,
                  initialChildSize: _kSheetOpenSize,
                  minChildSize: _kSheetHiddenSize,
                  maxChildSize: _kSheetOpenSize,
                  snap: true,
                  snapSizes: const [_kSheetHiddenSize, _kSheetOpenSize],
                  builder: (context, scrollController) {
                    // En un extremo, el drag extra se reenvía como scroll normal y ese offset no se resetea solo — forzarlo a 0 evita que el contenido abra recortado la próxima vez.
                    void resetScrollAtRest(double extent) {
                      final atOpen = extent >= _kSheetOpenSize - 0.001;
                      final atHidden = extent <= _kSheetHiddenSize + 0.001;
                      if (!atOpen && !atHidden) return;
                      if (!scrollController.hasClients) return;
                      if (scrollController.offset == 0) return;
                      scrollController.jumpTo(0);
                    }

                    return NotificationListener<
                      DraggableScrollableNotification
                    >(
                      onNotification: (notification) {
                        resetScrollAtRest(notification.extent);
                        return false;
                      },
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: AppColors.authCardBackground,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(32),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.mapControlShadowStrong,
                              offset: Offset(0, -8),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => FocusScope.of(context).unfocus(),
                            // El handle vive dentro de este mismo Scrollable a propósito: fuera de él se vería arrastrable pero no respondería al drag.
                            child: SingleChildScrollView(
                              controller: scrollController,
                              physics: const ClampingScrollPhysics(),
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 44,
                                    child: Center(
                                      child: Container(
                                        width: 52,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: AppColors.authMuted.withValues(
                                            alpha: 0.4,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  AnimatedBuilder(
                                    animation: _sheetController,
                                    builder: (context, child) {
                                      // El handle queda fuera de este fade a propósito: siempre debe leerse como agarrable.
                                      final opacity =
                                          ((_extent - _kSheetHiddenSize) /
                                                  _kContentFadeSpan)
                                              .clamp(0.0, 1.0);
                                      return Opacity(
                                        opacity: opacity,
                                        child: child,
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        22,
                                        6,
                                        22,
                                        18,
                                      ),
                                      child: widget.child,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
