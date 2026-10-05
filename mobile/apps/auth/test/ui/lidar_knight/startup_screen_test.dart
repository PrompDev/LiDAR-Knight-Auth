import 'package:ente_auth/ui/lidar_knight/startup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('failure view fits the minimum desktop window', (tester) async {
    tester.view.physicalSize = const Size(200, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = ValueNotifier(
      const LkStartupState(LkStartupStage.network, failed: true),
    );
    await tester.pumpWidget(LkStartupScreen(state: state));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
  testWidgets('startup paints a themed view before secure initialization', (
    tester,
  ) async {
    final state = ValueNotifier(const LkStartupState(LkStartupStage.storage));
    await tester.pumpWidget(LkStartupScreen(state: state));
    await tester.pump();
    expect(find.text('Opening secure local storage'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets(
    'failure remains visible without exposing codes or opening home',
    (tester) async {
      final state = ValueNotifier(const LkStartupState(LkStartupStage.network));
      await tester.pumpWidget(LkStartupScreen(state: state));
      state.value = const LkStartupState(LkStartupStage.network, failed: true);
      await tester.pump();
      expect(find.text('Startup could not finish'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.textContaining('Your saved codes have not been reset'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );
}
