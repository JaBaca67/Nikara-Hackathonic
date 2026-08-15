import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:nikara_app/shared/widgets/auth/nikara_logo_svg.dart';
import 'package:nikara_app/theme/app_theme.dart';
import 'package:nikara_app/widgets/aurora_background_widget.dart';

/// The sheet's two resting states — "open" (default) and "hidden" (dragged
/// down, revealing almost the entire gradient — just the drag handle
/// stays on screen). Trying this back at a thin value is safe now that
/// the handle actually lives inside the [scrollController]'s Scrollable
/// (see the sheet `builder` below) — the earlier bump to 0.16 was working
/// around the visual handle and the real drag hit-area not lining up, not
/// around this fraction itself. If a sliver-thin hitbox here ever proves
/// too easy to collide with Android's "swipe up to exit" gesture strip
/// again, raise this back up — the fix that matters is the handle's
/// placement, not this number. The card's own content still reads as
/// fully hidden at this size — see [_kContentFadeSpan] — height, not
/// content visibility, is what's traded off here. The same numbers drive
/// every Auth screen (Login + all 3 Register steps) via this one shared
/// component, so the card reads as one consistent, predictable object
/// across the whole flow.
const double _kSheetHiddenSize = 0.10;
const double _kSheetOpenSize = 0.72;

/// How much further past [_kSheetHiddenSize] the sheet has to be dragged
/// before its content is fully opaque again — content fades out over this
/// span as the sheet approaches hidden, so it's fully invisible at rest
/// there regardless of exactly how much pixel height that fraction leaves
/// (decouples "hide the text" from "how big the drag handle is").
const double _kContentFadeSpan = 0.08;

/// Fixed gap kept between the logo's bottom edge and the sheet's current
/// top edge whenever the sheet is high enough to touch it — "medium" per
/// the design note, not edge-to-edge and not floaty.
const double _kLogoToSheetGap = 30.0;

/// Bold per feedback that the original size (78) read as too small/timid
/// for the brand's home screen presence.
const double _kLogoHeight = 150.0;

/// Shared shell for every Auth screen (Login, Register x3) — animated
/// "Sunset" gradient (via [AuroraBackgroundWidget]) with [NikaraLogoSvg],
/// and a real, draggable bottom sheet ([DraggableScrollableSheet]) holding
/// [child] in a warm off-white card. Per the Claude Design canvas "Nikara
/// Inicio y Mapa" (turns 9/10).
///
/// The sheet drags between [_kSheetOpenSize] and [_kSheetHiddenSize] (snaps
/// to whichever it's closer to on release) — it can be pulled almost
/// completely out of the way, not just resized within a narrow band.
///
/// The logo's *base* resting spot is the vertical center of the screen —
/// where it sits whenever the sheet is low enough not to reach it (e.g.
/// dragged down to [_kSheetHiddenSize]). As the sheet rises, its top edge
/// eventually reaches the logo's centered position; from that point on the
/// logo gets pushed upward, riding [_kLogoToSheetGap] above the sheet, all
/// the way up to a safe minimum near the status bar. It's never pinned to
/// a fixed spot — always either resting at center or actively being
/// pushed by the sheet.
///
/// [child]'s own content decides how tall it is — no forced `minHeight`.
/// Callers that switch between step contents (the Register wizard) should
/// still pin their own `AnimatedSwitcher.layoutBuilder` to top-align —
/// [AnimatedSwitcher]'s default centers, which would float short content
/// in the middle of whatever height the sheet currently is.
class AuthBottomSheetLayout extends StatefulWidget {
  const AuthBottomSheetLayout({super.key, required this.child, this.onBack});

  /// The card's scrollable content — typically an [AuthHeader], fields,
  /// and a primary button, in a `Column`.
  final Widget child;

  /// Called when the hardware/gesture back action fires. Purely a hook —
  /// this widget renders no back button of its own; a floating circle
  /// over the busy animated gradient competed visually with the much
  /// bigger logo and didn't read as clearly tappable. Screens that need a
  /// visible back affordance (the Register wizard) put one inside their
  /// own [child], styled to match the card's own type system instead.
  /// Null means "nothing to go back to" — the system back action pops the
  /// route normally.
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
                // Continuous, deliberately bold motion — not a static
                // gradient — per the "que se sienta vivo, como un video"
                // note. Already painted with the Sunset palette via
                // [AppGradients].
                const Positioned.fill(child: AuroraBackgroundWidget()),
                AnimatedBuilder(
                  animation: _sheetController,
                  builder: (context, _) {
                    final extent = _extent;
                    final sheetTopY = availableHeight * (1 - extent);
                    final sheetPushedTop =
                        sheetTopY - _kLogoToSheetGap - _kLogoHeight;
                    // Rest at center unless the sheet's edge has risen high
                    // enough to need pushing the logo above it — then
                    // follow the sheet, clamped so it can never be pushed
                    // above the status bar.
                    final logoTop = math
                        .min(baseCenterTop, sheetPushedTop)
                        .clamp(safeTop + 8, availableHeight);
                    // AnimatedPositioned (not a plain Positioned) is what
                    // gives the logo its "pushed" feel a small bounce
                    // instead of tracking the sheet's raw extent 1:1 every
                    // frame — a little elastic lag reads as the sheet
                    // actually *moving* something, per the "que se sienta
                    // como si lo estuviera moviendo, pero fluido" note.
                    // `logoTop` keeps changing every tick while dragging;
                    // an implicit animation like this one just keeps
                    // smoothly re-targeting instead of restarting, so it
                    // stays fluid through a whole drag gesture, not just
                    // at the end of one.
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
                    // Once the sheet is dragged all the way to either
                    // resting extent, any further drag has nowhere left to
                    // resize into — it gets forwarded to this same
                    // [scrollController] as ordinary scrolling instead,
                    // and (unlike the sheet's own extent) that offset
                    // doesn't reset itself on release. Left alone, the
                    // next time the sheet opens its content starts
                    // scrolled past the top, clipping the heading. Snap
                    // back to offset 0 whenever a drag settles at either
                    // extreme.
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
                              color: Color(0x24261D0C),
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
                            // The drag handle lives *inside* this same
                            // [SingleChildScrollView] — the one attached to
                            // [scrollController] — on purpose. Drag-to-resize
                            // only works where a touch lands on the
                            // Scrollable itself; a decorative bar drawn as a
                            // sibling next to it (outside the scrollable)
                            // looks like a grab handle but doesn't actually
                            // respond to drag, which is exactly the mismatch
                            // this fixes: what you see lined up with what
                            // you can grab.
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
                                      // Fades to fully invisible as the
                                      // sheet approaches [_kSheetHiddenSize]
                                      // — guarantees the header/fields never
                                      // peek through at rest, independent
                                      // of exactly how many pixels that
                                      // fraction leaves on a given device.
                                      // The handle above is deliberately
                                      // outside this fade — it should
                                      // always read as grabbable.
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
