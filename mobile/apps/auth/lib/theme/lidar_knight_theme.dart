// LiDAR-Knight Auth: red-dot palette and the theme overrides for the shared
// Ente packages (ente_ui and ente_components).
//
// Modified work notice (AGPL-3.0 section 5a): this file was added by the
// LiDAR-Knight Auth fork of Ente Auth in 2026. See CHANGES-LIDAR-KNIGHT.md.

import 'package:ente_components/ente_components.dart' as components;
import 'package:ente_ui/theme/colors.dart' as ui;
import 'package:flutter/material.dart';

/// The dot-matrix font bundled with the app (Doto, SIL OFL 1.1).
///
/// Its default instance is square dots (ROND 0) at the heaviest weight
/// (wght 900), so no font variations are needed for the red-dot look.
const String kLkFontFamily = 'Doto';

/// LiDAR-Knight Auth palette: hot red dots on black, rare cream highlights.
class LkColors {
  LkColors._();

  /// Every dot that carries information: text, digits, outlines.
  static const Color red = Color(0xFFFF2A12);

  /// Highlight dots only (next code, last seconds, copy flash, errors).
  static const Color cream = Color(0xFFFFD8CC);

  /// Haze and disabled states only. Never used for text.
  static const Color redDim = Color(0xFF7A1A10);

  /// Pressed and selected fills.
  static const Color redDeep = Color(0xFF2A140E);
  static const Color redDeeper = Color(0xFF3A160A);

  /// Hover glow, used sparingly.
  static const Color hot = Color(0xFFFF5A2A);

  static const Color redDark = Color(0xFFD92410);
  static const Color redDarker = Color(0xFFB01E0D);

  static const Color black = Color(0xFF000000);

  /// Translucent black surfaces, from the most to the least see-through.
  static const Color veil = Color(0x8C000000); // .55
  static const Color row = Color(0xC7000000); // .78
  static const Color dialog = Color(0xDB000000); // .86
  static const Color toast = Color(0xE6000000); // .90

  /// A faint red wash for selected rows.
  static const Color wash = Color(0x14FF2A12);

  static const Color redMuted = Color(0xD9FF2A12); // .85
  static const Color redFaint = Color(0xB3FF2A12); // .70
  static const Color redOutline = Color(0x59FF2A12); // .35
  static const Color redSoft = Color(0x29FF2A12); // .16
}

/// ente_ui colour scheme (buttons, dialogs, lock screen, account pages).
///
/// Registered as a ThemeExtension, which ente_ui reads before its own
/// purple fallback, so the shared package itself is not edited.
final ui.EnteColorScheme lkEnteUiColorScheme =
    ui.EnteColorScheme.dark(
      primary700: LkColors.red,
      primary500: LkColors.red,
      primary400: LkColors.red,
      primary300: LkColors.hot,
      iconButtonColor: LkColors.red,
      gradientButtonBgColor: LkColors.red,
      gradientButtonBgColors: const [LkColors.red, LkColors.redDarker],
      warning700: LkColors.cream,
      warning500: LkColors.cream,
      warning400: LkColors.cream,
      warning800: LkColors.cream,
      caution500: LkColors.cream,
    ).copyWith(
      backgroundBase: LkColors.veil,
      backgroundElevated: LkColors.row,
      backgroundElevated2: LkColors.dialog,
      textBase: LkColors.red,
      textMuted: LkColors.redMuted,
      textFaint: LkColors.redFaint,
      fillBase: LkColors.red,
      fillBasePressed: LkColors.redDark,
      fillMuted: LkColors.redSoft,
      fillFaint: const Color(0x1FFF2A12),
      fillFaintPressed: LkColors.wash,
      strokeBase: LkColors.red,
      strokeMuted: LkColors.redOutline,
      strokeFaint: LkColors.redSoft,
      strokeFainter: LkColors.wash,
      blurStrokeBase: LkColors.redMuted,
      blurStrokeFaint: const Color(0x0FFF2A12),
      blurStrokePressed: const Color(0x80FF2A12),
      fabForegroundColor: LkColors.black,
      fabBackgroundColor: LkColors.red,
      boxSelectColor: LkColors.redDeeper,
      boxUnSelectColor: LkColors.row,
      alternativeColor: LkColors.red,
      dynamicFABBackgroundColor: LkColors.redDeeper,
      dynamicFABTextColor: LkColors.red,
      recoveryKeyBoxColor: LkColors.redDeep,
      frostyBlurBackdropFilterColor: LkColors.veil,
      iconColor: LkColors.red,
      bgColorForQuestions: LkColors.row,
      greenText: LkColors.red,
      cupertinoPickerTopColor: LkColors.redSoft,
      stepProgressUnselectedColor: LkColors.redOutline,
      gNavBackgroundColor: LkColors.row,
      gNavBarActiveColor: LkColors.red,
      gNavIconColor: LkColors.red,
      gNavActiveIconColor: LkColors.black,
      galleryThumbBackgroundColor: LkColors.redDeep,
      galleryThumbDrawColor: LkColors.redFaint,
      backupEnabledBgColor: LkColors.wash,
      dotsIndicatorActiveColor: LkColors.red,
      dotsIndicatorInactiveColor: LkColors.redDim,
      toastTextColor: LkColors.red,
      toastBackgroundColor: LkColors.toast,
      subTextColor: LkColors.redFaint,
      themeSwitchInactiveIconColor: LkColors.redFaint,
      searchResultsColor: LkColors.dialog,
      mutedTextColor: LkColors.redFaint,
      searchResultsBackgroundColor: const Color(0xA3000000),
      codeCardBackgroundColor: LkColors.row,
      primaryColor: LkColors.red,
      avatarColors: const [
        LkColors.red,
        LkColors.hot,
        LkColors.redDark,
        LkColors.redDarker,
        LkColors.redDim,
      ],
    );

/// ente_components colour tokens (settings, sheets, buttons, chips).
///
/// Every colour family maps to the red-dot palette: Ente's purple, green and
/// blue become red, warnings and cautions become cream.
const components.ColorTokens lkComponentColors = components.ColorTokens(
  primaryLight: LkColors.redDeep,
  primaryLightHover: LkColors.redDeeper,
  primaryLightPressed: Color(0xFF4A1A0C),
  primaryStroke: LkColors.redDim,
  primary: LkColors.red,
  primaryDark: LkColors.redDark,
  primaryDarker: LkColors.redDarker,
  greenLight: LkColors.redDeep,
  greenLightHover: LkColors.redDeeper,
  greenLightPressed: Color(0xFF4A1A0C),
  greenStroke: LkColors.redDim,
  green: LkColors.red,
  greenDark: LkColors.redDark,
  greenDarker: LkColors.redDarker,
  blueLight: LkColors.redDeep,
  blueLightHover: LkColors.redDeeper,
  blueLightPressed: Color(0xFF4A1A0C),
  blueStroke: LkColors.redDim,
  blue: LkColors.red,
  blueDark: LkColors.redDark,
  blueDarker: LkColors.redDarker,
  purpleLight: LkColors.redDeep,
  purpleLightHover: LkColors.redDeeper,
  purpleLightPressed: Color(0xFF4A1A0C),
  purpleStroke: LkColors.redDim,
  purple: LkColors.red,
  purpleDark: LkColors.redDark,
  purpleDarker: LkColors.redDarker,
  warningLight: LkColors.redDeep,
  warning: LkColors.cream,
  warningDark: Color(0xFFE8BFB2),
  warningDarker: Color(0xFFD1A698),
  cautionLight: LkColors.redDeep,
  caution: LkColors.cream,
  textLight: LkColors.redFaint,
  textBase: LkColors.red,
  textDark: LkColors.red,
  textDarker: LkColors.redMuted,
  textLighter: LkColors.redFaint,
  textLightest: LkColors.redDim,
  textReverse: LkColors.black,
  iconColor: LkColors.red,
  backgroundBase: LkColors.dialog,
  fillLight: Color(0xE6140705),
  fillBase: LkColors.red,
  fillDark: Color(0xFF0A0303),
  fillDarker: Color(0xFF140605),
  fillDarkest: LkColors.redDeep,
  strokeDark: LkColors.redDim,
  strokeFaint: LkColors.redDeeper,
  accentOrangeLight: LkColors.redDeep,
  accentPinkLight: LkColors.redDeep,
  accentTealLight: LkColors.redDeep,
  accentOrange: LkColors.hot,
  accentPink: LkColors.red,
  accentTeal: LkColors.cream,
  specialContentReverse: LkColors.black,
  specialScrim: Color(0x99000000),
  // Text and knobs drawn on top of red fills: black reads best on red.
  specialWhite: LkColors.black,
  specialWhiteOverlay: LkColors.redSoft,
);
