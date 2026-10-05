import 'package:ente_auth/theme/ente_theme.dart';
import 'package:ente_auth/theme/lidar_knight_theme.dart';
import 'package:flutter/material.dart';

/// Compact solid-glyph title; the owner's AUTH emblem remains unchanged.
class AuthLogoWidget extends StatelessWidget {
  final double height;
  final Color? color;

  const AuthLogoWidget({super.key, this.height = 18, this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = getEnteColorScheme(context);
    final logoColor = color ?? colorScheme.textBase;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        'LiDAR KNIGHT / AUTH',
        style: TextStyle(
          fontFamily: kLkFontFamily,
          fontSize: height,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: logoColor,
        ),
      ),
    );
  }
}
