import 'package:ente_auth/ente_theme_data.dart';
import 'package:ente_auth/theme/lidar_knight_theme.dart';
import 'package:ente_auth/ui/home/widgets/auth_logo_widget.dart';
import 'package:ente_auth/ui/lidar_knight/dot_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return ((a > b ? a : b) + 0.05) / ((a < b ? a : b) + 0.05);
}

void main() {
  test('security labels meet normal-text contrast across opaque panels', () {
    for (final surface in [
      LkColors.black,
      LkColors.row,
      LkColors.dialog,
      LkColors.toast,
    ]) {
      for (final text in [
        LkColors.text,
        LkColors.textMuted,
        LkColors.textFaint,
      ]) {
        expect(contrast(text, surface), greaterThanOrEqualTo(4.5));
      }
    }
    expect(contrast(LkColors.black, LkColors.red), greaterThanOrEqualTo(4.5));
  });

  testWidgets('compact readable title fits the minimum window with its scene', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: darkThemeData,
        home: LkBackdrop(
          child: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: const Center(child: AuthLogoWidget()),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('LiDAR KNIGHT / AUTH'), findsOneWidget);
    final label = tester.widget<Text>(find.text('LiDAR KNIGHT / AUTH'));
    expect(label.style?.fontFamily, 'Inter');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
