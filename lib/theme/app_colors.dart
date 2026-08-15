import 'package:flutter/material.dart';

/// Color tokens extracted from the Figma file "UI-NÍKARA" (node 157:2).
/// Names mirror the Local Variable scale defined in the Figma file.
///
/// No pure white (`#FFFFFF`) or pure black (`#000000`) token lives here —
/// [neutral1100] (primary "ink" text/icon color) and [surface100]/
/// [backgroundCream] (surfaces) are all deliberately off-white/near-black
/// for a softer, non-flat premium finish, per the design system audit.
abstract class AppColors {
  /// Variable "100" — near-white surface used for input fields.
  static const surface100 = Color(0xFFFDFDFD);

  /// Variable "300" — olive green used for links and accents.
  static const accent300 = Color(0xFF8B922A);

  /// Variable "400" — orange-red, gradient end stop.
  static const primary400 = Color(0xFFFF600F);

  /// Variable "500" — main brand gold.
  static const primary500 = Color(0xFFFDBE02);

  /// Variable "600" — muted brown-gray for secondary text and borders.
  static const neutral600 = Color(0xFF8C7373);

  /// Variable "700" — light gold, gradient end stop.
  static const primary700 = Color(0xFFFFD866);

  /// Variable "1100" — primary text/icon "ink". Originally a literal pure
  /// black (`#000000`) in the Figma file; deliberately softened to a near
  /// -black here (design system audit: no pure black/white anywhere in the
  /// app) — visually indistinguishable from black at normal text sizes,
  /// but avoids the harsh, flat look pure `#000` gives on an off-white/cream
  /// background.
  static const neutral1100 = Color(0xFF121212);

  /// Raw fill (not a bound variable in Figma) — cream card/app background.
  static const backgroundCream = Color(0xFFFFF9F0);

  // --- Home screen tokens (Figma node 124:37, "Inicio") ---
  // Same Local Variable collection as the login screen, but this frame
  // binds a wider slice of the neutral/brown scale plus its own accents.

  /// Variable "200" — light gray, used for the "Por región" divider rail.
  static const surface200 = Color(0xFFE6E5E5);

  /// Variable "400" — muted gray, status-bar time text.
  static const neutral400 = Color(0xFFB7AEAE);

  /// Variable "700" — secondary/caption text (card location, "Ver Mas").
  static const neutral700 = Color(0xFF725E5A);

  /// Variable "800" — dark brown, price text and thumbnail-selector borders.
  static const neutral800 = Color(0xFF564343);

  /// Variable "900" — near-black brown.
  static const neutral900 = Color(0xFF3A2C2C);

  /// Variable "500" (accent collection) — olive-lime ECO badge fill.
  static const ecoGreen500 = Color(0xFFC2CA5B);

  /// Variable "600" (gold collection — distinct from neutral600) — the
  /// featured-card descriptive tag pill ("Laguna Volcánica").
  static const tagGold600 = Color(0xFFFFCC33);

  /// Variable "600" (lime collection) — notification-bell pill fill.
  static const notificationPill = Color(0xFFD1D77E);

  /// Raw fill — notification badge counter circle.
  static const notificationBadge = Color(0xFF404413);

  // --- Splash/transition screen tokens (Figma node 95:2, "Precarga") ---

  /// Variable "500" (coral collection) — gradient's bottom-right stop.
  static const coral500 = Color(0xFFFF8243);

  // --- Profile screen tokens (Figma node 259:224, "Perfil") ---

  /// Variable "500" (a second, lighter neutral scale used on this screen) —
  /// muted taupe for captions ("Granada", "520 puntos").
  static const neutral500 = Color(0xFFA19191);

  /// Header gradient top stop — pale gold.
  static const profileHeaderGoldPale = Color(0xFFFFE599);

  /// Header gradient third stop — soft coral (distinct from [coral500]).
  static const profileHeaderCoral = Color(0xFFFFA375);

  // --- Settings screen tokens (Figma node 361:323, "Ajustes") ---
  // This frame binds a separate warm-neutral palette from the rest of the
  // app rather than the shared brown/gold scale above.

  /// Screen background.
  static const settingsBackground = Color(0xFFF7F3EC);

  /// Gold accent — row icon tint, "on" toggle fill.
  static const settingsAccent = Color(0xFFF0B500);

  /// Primary row/heading text.
  static const settingsTextDark = Color(0xFF261D0C);

  /// Secondary text — section labels, row values, captions.
  static const settingsTextMuted = Color(0xFF8A7A65);

  /// Destructive-action tint — the app's ONE canonical "danger" color.
  /// Use this (not an ad-hoc red) for every delete/cancel/log-out
  /// confirmation, per the semantic-button-color pass: destructive actions
  /// get this soft red-orange, the primary gold ([primary500]) stays
  /// reserved for the one main/confirming action in any given screen.
  static const settingsDanger = Color(0xFFCC5510);

  /// "Off" toggle track fill.
  static const settingsToggleOff = Color(0xFFC8BDB0);

  /// Variable "200" (olive collection) — generic "success/confirmed" status
  /// tint (password-strength "Fuerte" label, etc.). Named for the semantic
  /// meaning, not the screen it first appeared on — the reservations
  /// feature that originally introduced it was removed Aug 2026.
  static const statusSuccess = Color(0xFF656B1F);

  /// Raw fill — placeholder thumbnail background (also used in Perfil).
  static const placeholderTan = Color(0xFFE5DFD2);

  // --- Paleta maestra (Figma node 125:2, "Paleta de colores") ---
  // This board is a raw canvas of swatches (not a component the
  // design-context tool can traverse), so these hex values were extracted
  // by pixel-sampling the rendered board instead of reading bound variable
  // names directly. Several swatches already had a confirmed name elsewhere
  // in this file (cross-checked by exact hex match) — those are reused
  // as-is and just annotated here; only the genuinely new swatches get a
  // fresh constant. Names below are positional (left-to-right on the
  // board) since the official Figma variable numbers weren't resolvable
  // for this specific node.

  /// Primario 1/9 — palest gold.
  static const primario1 = Color(0xFFFFF2CC);
  // Primario 2/9 == profileHeaderGoldPale (#FFE599).
  // Primario 3/9 == primary700 (#FFD866).
  // Primario 4/9 == tagGold600 (#FFCC33).
  // Primario 5/9 == primary500 (#FDBE02).
  /// Primario 6/9 — muted amber.
  static const primario6 = Color(0xFFCC9900);

  /// Primario 7/9 — deep amber.
  static const primario7 = Color(0xFF997300);

  /// Primario 8/9 — dark brown-gold.
  static const primario8 = Color(0xFF664C00);

  /// Primario 9/9 — near-black gold shadow.
  static const primario9 = Color(0xFF332600);

  /// Secundario 1/9 — palest olive.
  static const secundario1 = Color(0xFFF3F5DB);

  /// Secundario 2/9 — pale olive.
  static const secundario2 = Color(0xFFEDEFCC);

  /// Secundario 3/9 — light olive.
  static const secundario3 = Color(0xFFDFE3A5);
  // Secundario 4/9 == notificationPill (#D1D77E).
  // Secundario 5/9 == ecoGreen500 (#C2CA5B).
  /// Secundario 6/9 — mid olive.
  static const secundario6 = Color(0xFFAEB738);
  // Secundario 7/9 == accent300 (#8B922A).
  // Secundario 8/9 == bookingConfirmed (#656B1F).
  // Secundario 9/9 == notificationBadge (#404413).

  /// Complementario 1/9 — palest coral.
  static const complementario1 = Color(0xFFFFEEE6);

  /// Complementario 2/9 — pale coral.
  static const complementario2 = Color(0xFFFFE7DB);

  /// Complementario 3/9 — light coral.
  static const complementario3 = Color(0xFFFFC5A8);
  // Complementario 4/9 == profileHeaderCoral (#FFA375).
  // Complementario 5/9 == coral500 (#FF8243).
  // Complementario 6/9 == primary400 (#FF600F).
  // Complementario 7/9 == bookingPending (#DB4900).
  /// Complementario 8/9 — deep rust.
  static const complementario8 = Color(0xFFA83800);

  /// Complementario 9/9 — near-black rust shadow.
  static const complementario9 = Color(0xFF752700);

  /// Neutro 100 — off-white (originally a literal pure `#FFFFFF` in the
  /// Figma file; softened for the same reason as [neutral1100]). Not
  /// actually drawn anywhere today ([surface100]/[backgroundCream] are the
  /// app's real surface tokens), kept for palette completeness.
  static const neutral100 = Color(0xFFF8F9FA);
  // Neutro 200 == surface200 (#E6E5E5).
  /// Neutro 300 — light warm gray.
  static const neutral300 = Color(0xFFCECACA);
  // Neutro 400..900 and 1100 == neutral400..neutral900 and neutral1100
  // above, confirmed by exact hex match at their expected board position.
  /// Neutro 1000 — near-black warm gray.
  static const neutral1000 = Color(0xFF1E1515);
  // Neutro 1100 == neutral1100 (near-black — see its own doc comment).

  // --- Business detail screen tokens (Figma nodes 284:2256, 233:437) ---

  /// Forest green — eco activity icons/tags and review-avatar fill. Distinct
  /// from the brand's [ecoGreen500] (olive), this is a separate accent used
  /// only on this screen.
  static const ecoForest = Color(0xFF3A7D3A);

  /// Segmented-control track background ("Información" / "Reseñas & Fotos") —
  /// per Claude Design's turn 3 ("Perfil del negocio / lugar — unificación
  /// prototipo + Figma"), Pantalla 3a: exact hex, supersedes the earlier
  /// Figma-only value.
  static const segmentedTrackBg = Color(0xFFEDE9E1);

  /// Solid near-black ink used for text on gold buttons/pills throughout
  /// the app (previously inlined as a literal hex in several screens).
  static const textInk = Color(0xFF1A1510);

  /// Inline form-field validation-error text (Login/Register). Distinct
  /// from [settingsDanger], which is the destructive-*action* tint
  /// (delete/cancel/log-out) — this is purely "this field is invalid".
  /// Previously inlined as a literal hex in three separate Auth screens.
  static const formError = Color(0xFFD64545);

  // --- Profile screen full redesign (Figma nodes 377:483, 421:361) ---

  /// Muted taupe — "9:41" mock status text, location caption, locked-badge
  /// title/status text. Distinct from [neutral500] (#A19191).
  static const profileMuted = Color(0xFFB8AA98);

  /// Hairline dividers and the edit/settings/share button fill.
  static const profileDivider = Color(0xFFF2EBE0);

  /// Level progress bar track + locked-badge card fill.
  static const progressTrack = Color(0xFFEDE6D8);

  /// "Guardián del Bosque" badge tint.
  static const badgeForest = Color(0xFF7A8C28);

  /// "Protector del Lago" badge tint.
  static const badgeLake = Color(0xFF5A6B1A);

  // --- Business detail: warm amenities/actividades palette (replaces the
  // earlier green ecoForest/primary500 chip styling) ---

  /// Comodidades chip fill.
  static const warmChipBackground = Color(0xFFFFF8E1);

  /// Actividades chip fill — a shade warmer than [warmChipBackground] so
  /// the two chip sections stay visually distinct.
  static const warmChipBackgroundAlt = Color(0xFFFFF3E0);

  /// Chip border for both Comodidades and Actividades.
  static const warmChipBorder = Color(0xFFFDE68A);

  /// Comodidades/Actividades chip icon + text color — solid dark, replacing
  /// the earlier amber/deep-orange tinted text for legibility.
  static const chipContentDark = Color(0xFF111827);

  /// Registration wizard's focus/accent color (inputs, stepper, primary
  /// actions) — warmer than the brand's [primary500] gold, per the
  /// Perfil-matching redesign.
  static const wizardFocus = Color(0xFFF59E0B);

  // --- Depth system (UI/UX audit pass) ---
  // Flat cards/sheets throughout the app used to rely on color contrast
  // alone; these two tokens are the standard "give it depth" pairing —
  // a hairline border plus a soft, low-opacity shadow — used together
  // wherever a surface needs to read as raised instead of flat.

  /// Subtle 1px card/input border — barely visible, just enough to define
  /// an edge against a same-toned background.
  static const cardBorder = Color(0x1F000000); // black @ ~12% alpha

  /// Soft ambient shadow color for [cardShadow] — near-black at very low
  /// opacity, warmer than a default Material shadow so it reads as part of
  /// the brand's warm palette instead of a generic gray drop shadow.
  static const shadowAmbient = Color(0x14261D0C); // settingsTextDark @ ~8%

  /// Standard soft card elevation — pair with a rounded [BoxDecoration] for
  /// any surface that should read as "raised" (cards, sheets, buttons)
  /// instead of flat-against-background.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: shadowAmbient, offset: Offset(0, 4), blurRadius: 10),
  ];

  // --- Map screen redesign (Claude Design project "Rediseño de Níkara
  // Home y Mapa", Pantalla 2b) ---
  // This screen layers many soft ink-tinted (not pure black) hairline
  // borders/shadows directly over the map instead of the black-based
  // [cardBorder]/[shadowAmbient] pair above — kept as their own small scale
  // (all derived from [settingsTextDark] at the exact alpha the design
  // uses) rather than overloading those general-purpose tokens.

  /// Hairline border on every floating map control (search bar, filter
  /// button, category chips, recenter button) — settingsTextDark @ 6%.
  static const mapControlBorder = Color(0x0F261D0C);

  /// Shadow under the search bar and filter button — settingsTextDark @ 12%.
  static const mapControlShadow = Color(0x1F261D0C);

  /// Stronger shadow for the active category chip and the recenter button —
  /// settingsTextDark @ 14%.
  static const mapControlShadowStrong = Color(0x24261D0C);

  /// Lighter shadow for inactive category chips — settingsTextDark @ 10%.
  static const mapControlShadowSoft = Color(0x1A261D0C);

  /// Shadow under the floating business-preview card — settingsTextDark @ 16%.
  static const mapCardShadow = Color(0x29261D0C);

  /// Drop shadow under an active (selected) map pin — black @ 22%.
  static const mapPinShadowActive = Color(0x38000000);

  /// Drop shadow under an inactive map pin — black @ 18%.
  static const mapPinShadowInactive = Color(0x2E000000);

  /// Favorite-heart fill on the map preview card — a pink distinct from
  /// [primary400]/[coral500], called out by exact hex in the Map redesign.
  static const favoriteActive = Color(0xFFE8798F);

  // --- Business detail redesign (Claude Design turn 3, "Perfil del
  // negocio / lugar — unificación prototipo + Figma", Pantalla 3a) ---

  /// Actividad row icon-chip background — pale olive, distinct from
  /// [warmChipBackground]'s amber tone.
  static const detailActivityIconBg = Color(0xFFEFF2DF);

  /// Warm dark-brown body copy — description paragraph, address line,
  /// contact-pill label. Distinct from [neutral900]/[settingsTextDark].
  static const detailBodyBrown = Color(0xFF4A3D2A);

  /// Muted secondary row text (non-today schedule rows, map caption).
  static const detailMutedRow = Color(0xFF6B5B45);

  /// WhatsApp contact row — icon-circle fill.
  static const detailWhatsappIconBg = Color(0xFFE7F0E4);

  /// WhatsApp contact row — icon tint.
  static const detailWhatsappIcon = Color(0xFF4E8A50);

  /// Instagram contact row — icon-circle fill ([favoriteActive] is the icon
  /// tint itself, reused as-is since it's an exact hex match).
  static const detailInstagramIconBg = Color(0xFFFBECEF);

  /// "Cómo llegar" mini-map illustration — base fill, road stripe, green
  /// area, in that layering order.
  static const detailMapBg = Color(0xFFE9E5DC);
  static const detailMapRoad = Color(0xFFDCD6C8);
  static const detailMapGreen = Color(0xFFDDE7DC);

  // --- Wizard redesign (Claude Design turn 4, "Creación y edición de
  // negocio local — flujo en 4 pasos", Pantallas 4a-4e) ---

  /// Un-reached step-circle ring in the progress stepper.
  static const wizardStepInactiveBorder = Color(0xFFF0DFAE);

  /// "REVISIÓN" pill / incomplete-gallery warning row — fill and text.
  static const wizardReviewBadgeBg = Color(0xFFFFF6DC);
  static const wizardReviewBadgeText = Color(0xFF8A6A00);

  /// Facebook contact row — icon-circle fill and icon tint.
  static const wizardFacebookIconBg = Color(0xFFE7EDF7);
  static const wizardFacebookIcon = Color(0xFF5B7FB5);

  /// Dashed cover-photo drop zone fill.
  static const wizardUploadZoneBg = Color(0xFFFFFBEF);

  /// "Eliminar este negocio" link — distinct from [settingsDanger], exact
  /// hex from Pantalla 4e.
  static const wizardDangerLink = Color(0xFFC4756A);

  /// Verification/pin-confirm icon amber — the solid-color sibling of the
  /// `rgba(240,181,0,…)` shadow tint already inlined elsewhere in this app.
  static const wizardAmber = Color(0xFFF0B500);

  // --- Auth flow redesign (Claude Design canvas "Nikara Inicio y Mapa",
  // turns 9/10 — Login v3 + Registro en 3 pasos) ---

  /// Sunset gradient, stop 1/4 — top.
  static const sunsetStart = Color(0xFFFFD028);

  /// Sunset gradient, stop 2/4.
  static const sunsetMid1 = Color(0xFFFDB828);

  /// Sunset gradient, stop 3/4.
  static const sunsetMid2 = Color(0xFFFF8A35);

  /// Sunset gradient, stop 4/4 — bottom.
  static const sunsetEnd = Color(0xFFF97316);

  /// Auth card fill — the warm off-white behind every Login/Register form,
  /// distinct from [backgroundCream] (this is warmer/lighter).
  static const authCardBackground = Color(0xFFFFFDF8);

  /// Deep olive used for every text link in the Auth flow ("Inicia
  /// sesión", "Regístrate aquí", the guest-CTA icon/text) — distinct from
  /// [accent300], a lighter olive used elsewhere in the app.
  static const authLink = Color(0xFF6E7522);

  /// "Explorar como invitado" pill — gradient fill and icon-circle tint,
  /// a muted sibling of [authLink].
  static const authGuestPillStart = Color(0xFFEFF2DF);
  static const authGuestPillEnd = Color(0xFFE4EAC0);
  static const authGuestIconText = Color(0xFF4C5218);

  /// Password-strength "Débil" (weak) label/bar tint.
  static const strengthWeak = Color(0xFFD2691E);

  /// Auth flow's "ink" — headings, primary-button text, primary icons
  /// (mail/lock/arrow_back). Distinct from [textInk]: this redesign turn's
  /// source gave an explicit, lighter warm-brown value, not the app's
  /// older near-black ink.
  static const authInk = Color(0xFF3D2110);

  /// Auth field labels ("CORREO ELECTRÓNICO"), muted trailing icons
  /// (`visibility_off`), and — at 35% alpha — every field's inset border.
  static const authMuted = Color(0xFF9A8A82);

  /// Auth subtitle/body copy under a heading ("Empecemos con lo básico").
  static const authBodyMuted = Color(0xFF6B5B45);

  /// Auth field placeholder text.
  static const authPlaceholder = Color(0xFFB7A9A0);
}
