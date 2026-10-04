import 'package:ente_auth/theme/ente_theme.dart';
import 'package:ente_auth/ui/lidar_knight/dot_widgets.dart';
import 'package:flutter/material.dart';

/// The app title, drawn from square dots (LiDAR-Knight Auth fork: replaces
/// the upstream wordmark SVG).
class AuthLogoWidget extends StatelessWidget {
  final double height;
  final Color? color;

  const AuthLogoWidget({super.key, this.height = 18, this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = getEnteColorScheme(context);
    final logoColor = color ?? colorScheme.textBase;
    // Whole pixels per dot keep the dots square and crisp.
    final double rounded = (height / 7).roundToDouble();
    final double pitch = rounded < 2 ? 2 : (rounded > 8 ? 8 : rounded);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: LkDotText('LiDAR-Knight Auth', pitch: pitch, color: logoColor),
    );
  }
}
