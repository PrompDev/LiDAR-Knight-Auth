import 'dart:convert';
import 'package:ente_auth/services/lidar_master_key.dart';
import 'package:ente_auth/services/preference_service.dart';
import 'package:ente_auth/ui/lidar_knight/admin_vault.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferenceService.instance.init();
  });
  testWidgets(
    'credential change re-hides and clipboard cleanup preserves unrelated text',
    (tester) async {
      String clipboard = '';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'];
          }
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
      final code = LidarMasterKey.parse(
        utf8.encode(
          'SEAT=admin2\nNAME=LOCAL TEST\nTOTP_SECRET=$secret\nOTPAUTH_URI=otpauth://totp/TEST?secret=$secret\n',
        ),
      ).toCode();
      Widget card(dynamic value) => MaterialApp(
        home: Scaffold(
          body: LidarFloatingCodeCard(
            key: const ValueKey('same-seat'),
            code: value,
          ),
        ),
      );
      await tester.pumpWidget(card(code));
      await tester.tap(find.text('CLICK TO REVEAL'));
      await tester.pump();
      await tester.tap(find.text('COPY CODE'));
      await tester.pump();
      expect(clipboard.length, 6);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(clipboard, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.tap(find.text('CLICK TO REVEAL'));
      await tester.pump();
      await tester.tap(find.text('COPY CODE'));
      await tester.pump();
      clipboard = 'user copied something else';
      await tester.pumpWidget(
        card(code.copyWith(display: code.display.copyWith(lidarGeneration: 1))),
      );
      await tester.pump();
      expect(find.text('CLICK TO REVEAL'), findsOneWidget);
      expect(clipboard, 'user copied something else');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'compact card hides by default, reveals on click, masks on blur and after15seconds',
    (tester) async {
      const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
      final code = LidarMasterKey.parse(
        utf8.encode(
          'SEAT=admin2\nNAME=LOCAL TEST\nTOTP_SECRET=$secret\nOTPAUTH_URI=otpauth://totp/TEST?secret=$secret\n',
        ),
      ).toCode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              child: LidarFloatingCodeCard(code: code),
            ),
          ),
        ),
      );
      expect(find.text('CLICK TO REVEAL'), findsOneWidget);
      final digits = find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^\d{6}$').hasMatch(w.data ?? ''),
      );
      expect(digits, findsNothing);
      await tester.tap(find.text('CLICK TO REVEAL'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(digits, findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(milliseconds: 400));
      expect(digits, findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.tap(find.text('CLICK TO REVEAL'));
      await tester.pump(const Duration(seconds: 16));
      await tester.pump(const Duration(milliseconds: 400));
      expect(digits, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
