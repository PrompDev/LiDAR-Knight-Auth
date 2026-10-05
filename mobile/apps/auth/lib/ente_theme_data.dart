import 'package:ente_auth/theme/colors.dart';
import 'package:ente_auth/theme/ente_theme.dart';
import 'package:ente_auth/theme/lidar_knight_theme.dart';
import 'package:ente_components/ente_components.dart' as components;
import 'package:flutter/material.dart';

// LiDAR-Knight Auth: the app is dark-only with readable military-style text. The light
// theme is the same object as the dark theme, so the system or in-app theme
// setting can never switch to Ente's light (white and purple) look.
final lightThemeData = darkThemeData;

TextStyle _lkText(double size, {FontWeight weight = FontWeight.w500}) =>
    TextStyle(
      fontFamily: kLkFontFamily,
      color: LkColors.text,
      fontSize: size,
      fontWeight: weight,
    );

final darkThemeData = ThemeData(
  fontFamily: kLkFontFamily,
  brightness: Brightness.dark,
  dividerTheme: const DividerThemeData(color: LkColors.redOutline),
  primaryColor: LkColors.red,
  primaryColorLight: LkColors.redFaint,
  iconTheme: const IconThemeData(color: LkColors.red),
  primaryIconTheme: const IconThemeData(
    color: LkColors.red,
    opacity: 1.0,
    size: 50.0,
  ),
  hintColor: LkColors.textFaint,
  buttonTheme: const ButtonThemeData().copyWith(
    buttonColor: LkColors.red,
    height: 56,
  ),
  textTheme: _buildTextTheme(LkColors.text),
  primaryTextTheme: _buildTextTheme(LkColors.text),
  outlinedButtonTheme: buildOutlinedButtonThemeData(
    bgDisabled: LkColors.redDim,
    bgEnabled: LkColors.red,
    fgDisabled: LkColors.black,
    fgEnabled: LkColors.black,
  ),
  elevatedButtonTheme: buildElevatedButtonThemeData(
    onPrimary: LkColors.black,
    primary: LkColors.red,
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: LkColors.red,
      textStyle: _lkText(14, weight: FontWeight.w600),
    ),
  ),
  // The root painter is opaque black; transparent page canvases reveal its
  // quiet LiDAR scene, never the user's desktop.
  scaffoldBackgroundColor: Colors.transparent,
  canvasColor: LkColors.dialog,
  appBarTheme: const AppBarTheme().copyWith(
    backgroundColor: Colors.transparent,
    foregroundColor: LkColors.text,
    surfaceTintColor: Colors.transparent,
    iconTheme: const IconThemeData(color: LkColors.red),
    actionsIconTheme: const IconThemeData(color: LkColors.red),
    titleTextStyle: _lkText(16, weight: FontWeight.w700),
    elevation: 0,
  ),
  drawerTheme: const DrawerThemeData(
    backgroundColor: LkColors.dialog,
    surfaceTintColor: Colors.transparent,
  ),
  cardColor: LkColors.row,
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: LkColors.dialog,
    modalBackgroundColor: LkColors.dialog,
    surfaceTintColor: Colors.transparent,
  ),
  dialogTheme: const DialogThemeData().copyWith(
    backgroundColor: LkColors.dialog,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: _lkText(20, weight: FontWeight.w700),
    contentTextStyle: _lkText(16),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      side: BorderSide(color: LkColors.redOutline),
    ),
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: LkColors.toast,
    surfaceTintColor: Colors.transparent,
    textStyle: _lkText(14),
    shape: const RoundedRectangleBorder(
      side: BorderSide(color: LkColors.redOutline),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: LkColors.red,
    foregroundColor: LkColors.black,
    shape: RoundedRectangleBorder(),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(color: LkColors.red),
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: LkColors.red,
    selectionColor: Color(0x66FF2A12),
    selectionHandleColor: LkColors.red,
  ),
  inputDecorationTheme: const InputDecorationTheme().copyWith(
    enabledBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: LkColors.redOutline),
    ),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: LkColors.red),
    ),
  ),
  checkboxTheme: CheckboxThemeData(
    side: const BorderSide(color: LkColors.red, width: 2),
    shape: const RoundedRectangleBorder(),
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return LkColors.red;
      } else {
        return LkColors.black;
      }
    }),
    checkColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return LkColors.black;
      } else {
        return LkColors.red;
      }
    }),
  ),
  radioTheme: RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith<Color?>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.disabled)) {
        return LkColors.redDim;
      }
      return LkColors.red;
    }),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith<Color?>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.disabled)) {
        return LkColors.redDim;
      }
      if (states.contains(WidgetState.selected)) {
        // One cream knob dot on a solid red track.
        return LkColors.cream;
      }
      return LkColors.red;
    }),
    trackColor: WidgetStateProperty.resolveWith<Color?>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.disabled)) {
        return LkColors.redDeep;
      }
      if (states.contains(WidgetState.selected)) {
        return LkColors.red;
      }
      return LkColors.black;
    }),
    trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((
      Set<WidgetState> states,
    ) {
      return LkColors.red;
    }),
  ),
  colorScheme:
      const ColorScheme.dark(
        primary: LkColors.red,
        onPrimary: LkColors.black,
        secondary: LkColors.red,
        onSecondary: LkColors.black,
        error: LkColors.cream,
        onError: LkColors.black,
        surface: LkColors.row,
        onSurface: LkColors.text,
      ).copyWith(
        surfaceContainerLowest: LkColors.veil,
        surfaceContainerLow: LkColors.row,
        surfaceContainer: LkColors.row,
        surfaceContainerHigh: LkColors.dialog,
        surfaceContainerHighest: LkColors.toast,
        onSurfaceVariant: LkColors.textMuted,
        outline: LkColors.redOutline,
        outlineVariant: LkColors.redSoft,
      ),
  // The shared Ente packages read these extensions before their own purple
  // defaults, so buttons, sheets, dialogs and settings follow the dot theme.
  extensions: <ThemeExtension<dynamic>>[
    lkEnteUiColorScheme,
    const components.ComponentColorTokens(lkComponentColors),
  ],
);

TextTheme _buildTextTheme(Color textColor) {
  // Security information uses solid glyphs and stable contrast.
  TextStyle style(
    double size, {
    FontWeight weight = FontWeight.w500,
    double alpha = 1,
  }) => TextStyle(
    color: alpha == 1 ? textColor : textColor.withValues(alpha: alpha),
    fontSize: size,
    fontWeight: weight,
    fontFamily: kLkFontFamily,
  );

  return TextTheme(
    displayLarge: style(40, weight: FontWeight.w700),
    displayMedium: style(34, weight: FontWeight.w700),
    displaySmall: style(28, weight: FontWeight.w700),
    headlineLarge: style(26, weight: FontWeight.w700),
    headlineMedium: style(24, weight: FontWeight.w700),
    headlineSmall: style(20, weight: FontWeight.w700),
    titleLarge: style(18, weight: FontWeight.w700),
    titleMedium: style(16),
    titleSmall: style(14),
    bodyLarge: style(16),
    bodyMedium: style(14),
    bodySmall: style(12, alpha: 0.8),
    labelLarge: style(14, weight: FontWeight.w600),
    labelMedium: style(13),
    labelSmall: style(14).copyWith(decoration: TextDecoration.underline),
  );
}

extension CustomColorScheme on ColorScheme {
  Color get defaultBackgroundColor =>
      brightness == Brightness.light ? backgroundBaseLight : backgroundBaseDark;

  Color get inverseBackgroundColor =>
      brightness != Brightness.light ? backgroundBaseLight : backgroundBaseDark;

  Color get fabForegroundColor => brightness == Brightness.light
      ? const Color.fromRGBO(255, 255, 255, 1)
      : LkColors.black;

  Color get fabBackgroundColor => brightness != Brightness.light
      ? LkColors.red
      : const Color.fromRGBO(40, 40, 40, 1);

  Color get defaultTextColor =>
      brightness == Brightness.light ? textBaseLight : textBaseDark;

  Color get inverseTextColor =>
      brightness != Brightness.light ? textBaseLight : textBaseDark;

  Color get boxSelectColor => brightness == Brightness.light
      ? const Color.fromRGBO(67, 186, 108, 1)
      : LkColors.redDeeper;

  Color get boxUnSelectColor => brightness == Brightness.light
      ? const Color.fromRGBO(240, 240, 240, 1)
      : LkColors.row;

  Color get alternativeColor => LkColors.red;

  Color get dynamicFABBackgroundColor => brightness == Brightness.light
      ? const Color.fromRGBO(0, 0, 0, 1)
      : LkColors.redDeeper;

  Color get dynamicFABTextColor => LkColors.red;

  // todo: use brightness == Brightness.light for changing color for dark/light theme
  ButtonStyle? get optionalActionButtonStyle => buildElevatedButtonThemeData(
    onPrimary: LkColors.red,
    primary: LkColors.redDeep,
    elevation: 0,
  ).style;

  Color get recoveryKeyBoxColor => brightness == Brightness.light
      ? const Color.fromARGB(51, 150, 0, 220)
      : LkColors.redDeep;

  Color get frostyBlurBackdropFilterColor => brightness == Brightness.light
      ? const Color.fromRGBO(238, 238, 238, 0.5)
      : LkColors.veil;

  Color get iconColor => brightness == Brightness.light
      ? const Color.fromRGBO(0, 0, 0, 1).withValues(alpha: 0.75)
      : LkColors.text;

  Color get bgColorForQuestions => brightness == Brightness.light
      ? const Color.fromRGBO(255, 255, 255, 1)
      : LkColors.row;

  Color get greenText => LkColors.red;

  Color get cupertinoPickerTopColor => brightness == Brightness.light
      ? const Color.fromARGB(255, 238, 238, 238)
      : LkColors.redSoft;

  Color get stepProgressUnselectedColor => brightness == Brightness.light
      ? const Color.fromRGBO(196, 196, 196, 0.6)
      : LkColors.redOutline;

  Color get gNavBackgroundColor => brightness == Brightness.light
      ? const Color.fromRGBO(196, 196, 196, 0.6)
      : LkColors.row;

  Color get gNavBarActiveColor => brightness == Brightness.light
      ? const Color.fromRGBO(255, 255, 255, 0.6)
      : LkColors.red;

  Color get gNavIconColor => brightness == Brightness.light
      ? const Color.fromRGBO(0, 0, 0, 0.8)
      : LkColors.red;

  Color get gNavActiveIconColor => brightness == Brightness.light
      ? const Color.fromRGBO(0, 0, 0, 0.8)
      : const Color.fromRGBO(0, 0, 0, 0.8);

  Color get galleryThumbBackgroundColor => brightness == Brightness.light
      ? const Color.fromRGBO(240, 240, 240, 1)
      : LkColors.redDeep;

  Color get galleryThumbDrawColor => brightness == Brightness.light
      ? const Color.fromRGBO(0, 0, 0, 1).withValues(alpha: 0.8)
      : LkColors.textFaint;

  Color get backupEnabledBgColor => brightness == Brightness.light
      ? const Color.fromRGBO(230, 230, 230, 0.95)
      : LkColors.wash;

  Color get dotsIndicatorActiveColor => brightness == Brightness.light
      ? const Color.fromRGBO(0, 0, 0, 1).withValues(alpha: 0.5)
      : LkColors.red;

  Color get dotsIndicatorInactiveColor => brightness == Brightness.light
      ? const Color.fromRGBO(0, 0, 0, 1).withValues(alpha: 0.12)
      : LkColors.redDim;

  Color get toastTextColor => brightness == Brightness.light
      ? const Color.fromRGBO(255, 255, 255, 1)
      : LkColors.red;

  Color get toastBackgroundColor => brightness == Brightness.light
      ? const Color.fromRGBO(24, 24, 24, 0.95)
      : LkColors.toast;

  Color get subTextColor => brightness == Brightness.light
      ? const Color.fromRGBO(180, 180, 180, 1)
      : LkColors.textFaint;

  Color get themeSwitchInactiveIconColor => brightness == Brightness.light
      ? const Color.fromRGBO(0, 0, 0, 1).withValues(alpha: 0.5)
      : LkColors.redFaint;

  Color get searchResultsColor => brightness == Brightness.light
      ? const Color.fromRGBO(245, 245, 245, 1.0)
      : LkColors.dialog;

  Color get mutedTextColor => brightness == Brightness.light
      ? const Color.fromRGBO(80, 80, 80, 1)
      : LkColors.redFaint;

  Color get searchResultsBackgroundColor => brightness == Brightness.light
      ? Colors.black.withValues(alpha: 0.32)
      : Colors.black.withValues(alpha: 0.64);

  Color get codeCardBackgroundColor => brightness == Brightness.light
      ? const Color.fromRGBO(246, 246, 246, 1)
      : LkColors.row;

  Color get primaryColor =>
      brightness == Brightness.light ? LkColors.red : LkColors.red;

  EnteTheme get enteTheme =>
      brightness == Brightness.light ? lightTheme : darkTheme;

  EnteTheme get inverseEnteTheme =>
      brightness == Brightness.light ? darkTheme : lightTheme;
}

OutlinedButtonThemeData buildOutlinedButtonThemeData({
  required Color bgDisabled,
  required Color bgEnabled,
  required Color fgDisabled,
  required Color fgEnabled,
}) {
  return OutlinedButtonThemeData(
    style:
        OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(),
          minimumSize: const Size(0, 42),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: kLkFontFamily,
            fontSize: 14,
            letterSpacing: 0.4,
          ),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.disabled)) {
              return bgDisabled;
            }
            return bgEnabled;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.disabled)) {
              return fgDisabled;
            }
            return fgEnabled;
          }),
          alignment: Alignment.center,
        ),
  );
}

ElevatedButtonThemeData buildElevatedButtonThemeData({
  required Color onPrimary,
  required Color primary,
  double elevation = 2,
}) {
  return ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: onPrimary,
      backgroundColor: primary,
      elevation: elevation,
      alignment: Alignment.center,
      textStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontFamily: kLkFontFamily,
        fontSize: 14,
        letterSpacing: 0.4,
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      shape: const RoundedRectangleBorder(),
    ),
  );
}
