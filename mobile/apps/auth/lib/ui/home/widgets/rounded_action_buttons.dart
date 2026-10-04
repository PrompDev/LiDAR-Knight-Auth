import 'package:ente_auth/theme/ente_theme.dart';
import 'package:ente_auth/theme/lidar_knight_theme.dart';
import 'package:flutter/material.dart';

enum RoundedButtonType { primary, secondary, primaryInverse, secondaryInverse }

/// Action button. LiDAR-Knight Auth: square blocks in the red-dot palette
/// (solid red with black text, or a translucent black block with a red rule).
class RoundedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double? width;
  final RoundedButtonType type;

  const RoundedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.width,
    this.type = RoundedButtonType.primary,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = getEnteTextTheme(context);

    final (backgroundColor, textColor, borderColor) = switch (type) {
      RoundedButtonType.primary => (LkColors.red, LkColors.black, LkColors.red),
      RoundedButtonType.secondary => (
        LkColors.wash,
        LkColors.red,
        LkColors.redOutline,
      ),
      RoundedButtonType.primaryInverse => (
        LkColors.red,
        LkColors.black,
        LkColors.red,
      ),
      RoundedButtonType.secondaryInverse => (
        LkColors.row,
        LkColors.red,
        LkColors.red,
      ),
    };

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: width,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
        decoration: ShapeDecoration(
          color: backgroundColor,
          shape: RoundedRectangleBorder(side: BorderSide(color: borderColor)),
        ),
        child: Center(
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.small.copyWith(
              color: textColor,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
