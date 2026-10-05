import 'package:ente_auth/ente_theme_data.dart';
import 'package:ente_auth/ui/home/home_empty_state.dart';
import 'package:ente_strings/ente_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'standard account actions fit a 280-pixel client and still work',
    (tester) async {
      tester.view.physicalSize = const Size(440, 280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var imported = 0;
      var manual = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: darkThemeData,
          localizationsDelegates: StringsLocalizations.localizationsDelegates,
          supportedLocales: StringsLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: HomeEmptyStateWidget(
              onScanTap: () {},
              onImportImageTap: () => imported++,
              onManuallySetupTap: () => manual++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ListView), findsOneWidget);
      final gallery = find.byType(ElevatedButton);
      final setup = find.byType(OutlinedButton);
      expect(tester.getRect(gallery).bottom, lessThanOrEqualTo(280));
      expect(tester.getRect(setup).bottom, lessThanOrEqualTo(280));
      await tester.tap(gallery);
      await tester.tap(setup);
      expect(imported, 1);
      expect(manual, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
