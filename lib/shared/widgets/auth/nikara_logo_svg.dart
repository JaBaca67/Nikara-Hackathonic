import 'package:flutter/material.dart';

/// The official Níkara logotype — used across Splash and the whole Auth
/// flow so every screen renders the exact same source asset instead of
/// separate crops per screen.
///
/// Backed by `assets/images/nikara_logo_wordmark.png`, a PNG rasterized
/// (via a headless-Chrome canvas render — 16x supersample, downsampled
/// once with high-quality smoothing to 1025x450, true alpha) from the
/// original Canva-exported SVG — not `SvgPicture` directly. Two separate
/// problems ruled that out:
/// 1. `flutter_svg`'s parser doesn't support the SVG's `filter` element
///    ("unhandled element filter"), which visibly distorted the mark's
///    edges.
/// 2. Even a clean raster shipped at a much larger size than any on-screen
///    use (an earlier pass shipped 2748x1206) still showed visible
///    moiré/aliasing on the pin icon's tightly-nested spiral curves —
///    confirmed inside the running app, not just file-preview thumbnails.
///    Runtime scaling that source down ~8x to the logo's actual ~150px
///    display height was enough to alias those closely-spaced curves
///    regardless of `filterQuality`. Shipping the asset close to its
///    actual usage size instead (1025x450 ≈ 3x the largest current
///    on-screen height, generous for retina) leaves only a gentle ~3x
///    runtime reduction, which doesn't trigger it.
///
/// Still named `...Svg` for call-site stability — every existing
/// reference already uses this name.
///
/// [color] tints the whole mark via [ColorFiltered]/[BlendMode.srcIn] when
/// set — useful for testing the mark against different backgrounds
/// without needing a second exported asset. Left `null`, it renders in its
/// own original colors.
class NikaraLogoSvg extends StatelessWidget {
  const NikaraLogoSvg({super.key, this.width, this.height, this.color});

  final double? width;
  final double? height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/nikara_logo_wordmark.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
    if (color == null) return image;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color!, BlendMode.srcIn),
      child: image,
    );
  }
}
