import 'package:flutter/material.dart';

class EnteColorScheme {
  final Color backgroundBase;
  final Color backgroundElevated;
  final Color backgroundElevated2;

  final Color backdropBase;
  final Color backdropBaseMute;
  final Color backdropFaint;

  final Color textBase;
  final Color textMuted;
  final Color textFaint;

  final Color fillBase;
  final Color fillBasePressed;
  final Color fillMuted;
  final Color fillFaint;
  final Color fillFaintPressed;

  final Color strokeBase;
  final Color strokeMuted;
  final Color strokeFaint;
  final Color strokeFainter;
  final Color blurStrokeBase;
  final Color blurStrokeFaint;
  final Color blurStrokePressed;

  final Color primaryGreen;
  final Color primary700;
  final Color primary500;
  final Color primary400;
  final Color primary300;

  final Color iconButtonColor;

  final Color warning700;
  final Color warning500;
  final Color warning400;
  final Color warning800;

  final Color caution500;
  final List<Color> avatarColors;

  final Color tagChipSelectedColor;
  final Color tagChipUnselectedColor;
  final List<Color> tagChipSelectedGradient;
  final List<Color> tagChipUnselectedGradient;
  final Color tagTextUnselectedColor;
  final Color deleteTagIconColor;
  final Color deleteTagTextColor;

  final Color errorCodeProgressColor;
  final Color infoIconColor;
  final Color errorCardTextColor;
  final Color deleteCodeTextColor;
  final List<BoxShadow> pinnedCardBoxShadow;
  final Color pinnedBgColor;

  final Color gradientButtonBgColor;
  final List<Color> gradientButtonBgColors;

  bool get isLightTheme => backgroundBase == backgroundBaseLight;

  const EnteColorScheme(
    this.backgroundBase,
    this.backgroundElevated,
    this.backgroundElevated2,
    this.backdropBase,
    this.backdropBaseMute,
    this.backdropFaint,
    this.textBase,
    this.textMuted,
    this.textFaint,
    this.fillBase,
    this.fillBasePressed,
    this.fillMuted,
    this.fillFaint,
    this.fillFaintPressed,
    this.strokeBase,
    this.strokeMuted,
    this.strokeFaint,
    this.strokeFainter,
    this.blurStrokeBase,
    this.blurStrokeFaint,
    this.blurStrokePressed,
    this.avatarColors,
    this.iconButtonColor,
    this.tagChipUnselectedColor,
    this.tagChipSelectedGradient,
    this.tagChipUnselectedGradient,
    this.pinnedBgColor, {
    this.tagChipSelectedColor = _tagChipSelectedColor,
    this.tagTextUnselectedColor = _tagTextUnselectedColor,
    this.deleteTagIconColor = _deleteTagIconColor,
    this.deleteTagTextColor = _deleteTagTextColor,
    this.errorCodeProgressColor = _errorCodeProgressColor,
    this.infoIconColor = _infoIconColor,
    this.errorCardTextColor = _errorCardTextColor,
    this.deleteCodeTextColor = _deleteCodeTextColor,
    this.pinnedCardBoxShadow = _pinnedCardBoxShadow,
    this.gradientButtonBgColor = _gradientButtonBgColor,
    this.gradientButtonBgColors = _gradientButtonBgColors,
    this.primaryGreen = _primaryGreen,
    this.primary700 = _primary700,
    this.primary500 = _primary500,
    this.primary400 = _primary400,
    this.primary300 = _primary300,
    this.warning700 = _warning700,
    this.warning800 = _warning800,
    this.warning500 = _warning500,
    this.warning400 = _warning700,
    this.caution500 = _caution500,
  });
}

const EnteColorScheme lightScheme = EnteColorScheme(
  backgroundBaseLight,
  backgroundElevatedLight,
  backgroundElevated2Light,
  backdropBaseLight,
  backdropMutedLight,
  backdropFaintLight,
  textBaseLight,
  textMutedLight,
  textFaintLight,
  fillBaseLight,
  fillBasePressedLight,
  fillMutedLight,
  fillFaintLight,
  fillFaintPressedLight,
  strokeBaseLight,
  strokeMutedLight,
  strokeFaintLight,
  strokeFainterLight,
  blurStrokeBaseLight,
  blurStrokeFaintLight,
  blurStrokePressedLight,
  avatarLight,
  _iconButtonBrightColor,
  _tagChipUnselectedColorLight,
  _tagChipSelectedGradientLight,
  _tagChipUnselectedGradientLight,
  _pinnedBgColorLight,
);

const EnteColorScheme darkScheme = EnteColorScheme(
  backgroundBaseDark,
  backgroundElevatedDark,
  backgroundElevated2Dark,
  backdropBaseDark,
  backdropMutedDark,
  backdropFaintDark,
  textBaseDark,
  textMutedDark,
  textFaintDark,
  fillBaseDark,
  fillBasePressedDark,
  fillMutedDark,
  fillFaintDark,
  fillFaintPressedDark,
  strokeBaseDark,
  strokeMutedDark,
  strokeFaintDark,
  strokeFainterDark,
  blurStrokeBaseDark,
  blurStrokeFaintDark,
  blurStrokePressedDark,
  avatarDark,
  _iconButtonDarkColor,
  _tagChipUnselectedColorDark,
  _tagChipSelectedGradientDark,
  _tagChipUnselectedGradientDark,
  _pinnedBgColorDark,
);

// LiDAR-Knight Auth palette (see lib/theme/lidar_knight_theme.dart):
// red #FF2A12 for every informative dot, cream #FFD8CC for rare highlights
// and warnings, translucent black surfaces. Only the dark scheme is used.
const accentColor = Color(0xFFFF2A12);

const Color qrBoxColor = Color.fromRGBO(245, 245, 247, 1);

const Color backgroundBaseLight = Color.fromRGBO(255, 255, 255, 1);
const Color backgroundElevatedLight = Color.fromRGBO(255, 255, 255, 1);
const Color backgroundElevated2Light = Color.fromRGBO(251, 251, 251, 1);

const Color backgroundBaseDark = Color(0x8C000000);
const Color backgroundElevatedDark = Color(0xC7000000);
const Color backgroundElevated2Dark = Color(0xDB000000);

const Color backdropBaseLight = Color.fromRGBO(255, 255, 255, 0.92);
const Color backdropMutedLight = Color.fromRGBO(255, 255, 255, 0.75);
const Color backdropFaintLight = Color.fromRGBO(255, 255, 255, 0.30);

const Color backdropBaseDark = Color.fromRGBO(0, 0, 0, 0.90);
const Color backdropMutedDark = Color.fromRGBO(0, 0, 0, 0.65);
const Color backdropFaintDark = Color.fromRGBO(0, 0, 0, 0.20);

const Color textBaseLight = Color.fromRGBO(0, 0, 0, 1);
const Color textMutedLight = Color.fromRGBO(0, 0, 0, 0.6);
const Color textFaintLight = Color.fromRGBO(0, 0, 0, 0.5);

const Color textBaseDark = Color(0xFFFF2A12);
const Color textMutedDark = Color(0xD9FF2A12);
const Color textFaintDark = Color(0xB3FF2A12);

const Color fillBaseLight = Color.fromRGBO(0, 0, 0, 1);
const Color fillBasePressedLight = Color.fromRGBO(0, 0, 0, 0.87);
const Color fillMutedLight = Color.fromRGBO(0, 0, 0, 0.12);
const Color fillFaintLight = Color.fromRGBO(0, 0, 0, 0.04);
const Color fillFaintPressedLight = Color.fromRGBO(0, 0, 0, 0.08);

const Color fillBaseDark = Color(0xFFFF2A12);
const Color fillBasePressedDark = Color(0xFFD92410);
const Color fillMutedDark = Color(0x29FF2A12);
const Color fillFaintDark = Color(0x1FFF2A12);
const Color fillFaintPressedDark = Color(0x14FF2A12);

const Color strokeBaseLight = Color.fromRGBO(0, 0, 0, 1);
const Color strokeMutedLight = Color.fromRGBO(0, 0, 0, 0.24);
const Color strokeFaintLight = Color.fromRGBO(0, 0, 0, 0.04);
const Color strokeFainterLight = Color.fromRGBO(0, 0, 0, 0.06);
const Color blurStrokeBaseLight = Color.fromRGBO(0, 0, 0, 0.65);
const Color blurStrokeFaintLight = Color.fromRGBO(0, 0, 0, 0.08);
const Color blurStrokePressedLight = Color.fromRGBO(0, 0, 0, 0.50);

const Color strokeBaseDark = Color(0xFFFF2A12);
const Color strokeMutedDark = Color(0x59FF2A12);
const Color strokeFaintDark = Color(0x29FF2A12);
const Color strokeFainterDark = Color(0x14FF2A12);
const Color blurStrokeBaseDark = Color(0xE6FF2A12);
const Color blurStrokeFaintDark = Color(0x0FFF2A12);
const Color blurStrokePressedDark = Color(0x80FF2A12);

const Color _primaryGreen = Color(0xFFFF2A12);

const Color _primary700 = Color(0xFFFF2A12);
const Color _primary500 = accentColor;
const Color _primary400 = Color(0xFFFF2A12);
const Color _primary300 = Color(0xFFFF5A2A);

const Color _iconButtonBrightColor = Color.fromRGBO(130, 50, 225, 1);
const Color _iconButtonDarkColor = Color(0xFFFF2A12);

const Color _warning700 = Color(0xFFFFD8CC);
const Color _warning500 = Color(0xFFFFD8CC);
const Color _warning800 = Color(0xFFFFD8CC);
const Color warning500 = Color(0xFFFFD8CC);
// ignore: unused_element
const Color _warning400 = Color(0xFFFFD8CC);

const Color _caution500 = Color(0xFFFFD8CC);

const List<Color> avatarLight = [
  Color.fromRGBO(118, 84, 154, 1),
  Color.fromRGBO(223, 120, 97, 1),
  Color.fromRGBO(148, 180, 159, 1),
  Color.fromRGBO(135, 162, 251, 1),
  Color.fromRGBO(198, 137, 198, 1),
  Color.fromRGBO(198, 137, 198, 1),
  Color.fromRGBO(50, 82, 136, 1),
  Color.fromRGBO(133, 180, 224, 1),
  Color.fromRGBO(193, 163, 163, 1),
  Color.fromRGBO(193, 163, 163, 1),
  Color.fromRGBO(66, 97, 101, 1),
  Color.fromRGBO(66, 97, 101, 1),
  Color.fromRGBO(66, 97, 101, 1),
  Color.fromRGBO(221, 157, 226, 1),
  Color.fromRGBO(130, 171, 139, 1),
  Color.fromRGBO(155, 187, 232, 1),
  Color.fromRGBO(143, 190, 190, 1),
  Color.fromRGBO(138, 195, 161, 1),
  Color.fromRGBO(168, 176, 242, 1),
  Color.fromRGBO(176, 198, 149, 1),
  Color.fromRGBO(233, 154, 173, 1),
  Color.fromRGBO(209, 132, 132, 1),
  Color.fromRGBO(120, 181, 167, 1),
];

const List<Color> avatarDark = [
  Color(0xFFFF2A12),
  Color(0xFFFF5A2A),
  Color(0xFFD92410),
  Color(0xFFB01E0D),
  Color(0xFF7A1A10),
];

const Color _tagChipUnselectedColorLight = Color(0xFFFCF5FF);
const Color _tagChipUnselectedColorDark = Color(0xC7000000);
const List<Color> _tagChipUnselectedGradientLight = [
  Color(0x33AD00FF),
  Color(0x338609C2),
];
const List<Color> _tagChipUnselectedGradientDark = [
  Color(0xFFFF2A12),
  Color(0xFF7A1A10),
];
const Color _tagChipSelectedColor = Color(0xFFFF2A12);
const List<Color> _tagChipSelectedGradientLight = [
  Color(0xFFB37FEB),
  Color(0xFFAE40E3),
];
const List<Color> _tagChipSelectedGradientDark = [
  Color(0xFFFF5A2A),
  Color(0xFFFF2A12),
];
const Color _tagTextUnselectedColor = Color(0xFFFF2A12);
const Color _deleteTagIconColor = Color(0xFFFFD8CC);
const Color _deleteTagTextColor = Color(0xFFFFD8CC);

const Color _pinnedBgColorLight = Color(0xFFF9ECFF);
const Color _pinnedBgColorDark = Color(0xFF3A160A);
const Color _errorCodeProgressColor = Color(0xFFFFD8CC);
const Color _infoIconColor = Color(0xFFFFD8CC);
const Color _errorCardTextColor = Color(0xFFFFD8CC);
const Color _deleteCodeTextColor = Color(0xFFFFD8CC);
// No soft shadows in the dot theme: blur has no place on a pixel grid.
const List<BoxShadow> _pinnedCardBoxShadow = [];

const Color _gradientButtonBgColor = Color(0xFFFF2A12);
const List<Color> _gradientButtonBgColors = [
  Color(0xFFFF2A12),
  Color(0xFFB01E0D),
];
