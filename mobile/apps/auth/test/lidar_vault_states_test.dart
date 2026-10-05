import 'dart:convert';

import 'package:ente_auth/models/code.dart';
import 'package:ente_auth/models/code_display.dart';
import 'package:ente_auth/services/lidar_master_key.dart';
import 'package:ente_auth/services/preference_service.dart';
import 'package:ente_auth/ui/lidar_knight/admin_vault.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// SYNTHETIC LOCAL TEST ONLY: the contract's example key, never an owner's.
const secret = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
const exampleFile =
    'LK_FORMAT=2\nISSUER=admin.lidarknight.com\nSEAT=admin2\nNAME="CT"\n'
    'EMAIL=ct@example.com\nGENERATION=4\nISSUED_AT=2026-10-05T12:00:00Z\n'
    'ACTIVATE_BY=2026-10-12T12:00:00Z\nACTIVATION_ID=act_0123456789abcdefABCDEF\n'
    'TOTP_SECRET=$secret\nOTPAUTH_URI=otpauth://totp/LiDAR-Knight:CT?secret=$secret'
    '&issuer=LiDAR-Knight&algorithm=SHA1&digits=6&period=30\n';
const masterFile =
    'SEAT=admin1\nNAME=LOCAL TEST\nTOTP_SECRET=$secret\nOTPAUTH_URI=otpauth://totp/TEST?secret=$secret\n';

Code card(String state, {String reason = ''}) {
  final c = LidarMasterKey.parse(utf8.encode(exampleFile)).toCode();
  return Code(
    c.account,
    c.issuer,
    c.digits,
    c.period,
    c.secret,
    c.algorithm,
    c.type,
    c.counter,
    c.rawData,
    display: c.display.copyWith(lidarState: state, lidarReason: reason),
  );
}

Widget host(Widget child) => MaterialApp(
  home: Scaffold(
    body: SizedBox(width: 520, child: ListView(children: [child])),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferenceService.instance.init();
  });

  test('state labels use the contract names; a refusal shows its reason', () {
    final labels = {
      for (final s in [
        'pending',
        'active',
        'expired',
        'failed',
        'reissued',
        'revoked',
      ])
        s: lidarStateLabel(card(s).display),
    };
    expect(labels, {
      'pending': 'PENDING',
      'active': 'ACTIVE',
      'expired': 'EXPIRED',
      'failed': 'FAILED',
      'reissued': 'REISSUED',
      'revoked': 'REVOKED',
    });
    for (final reason in LidarKeyContract.reasons) {
      expect(
        lidarStateLabel(card('refused', reason: reason).display),
        'REFUSED ($reason)',
      );
    }
    expect(
      lidarStateLabel(card('pending').display, setup: true),
      'PENDING SETUP',
    );
    final master = LidarMasterKey.parse(utf8.encode(masterFile)).toCode();
    expect(lidarStateLabel(master.display), isNull);
    expect(lidarStateLabel(CodeDisplay()), isNull);
  });

  testWidgets('a pending card shows PENDING codes, never a sign-in', (
    tester,
  ) async {
    await tester.pumpWidget(host(LidarFloatingCodeCard(code: card('pending'))));
    expect(find.text('PENDING'), findsOneWidget);
    expect(find.text('NOT ACTIVATED · LOCAL VAULT'), findsOneWidget);
    expect(find.text('PRIVATE · LOCAL VAULT'), findsNothing);
    await tester.tap(find.text('CLICK TO REVEAL'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^\d{6}$').hasMatch(w.data ?? ''),
      ),
      findsOneWidget,
      reason: 'the code is needed to activate',
    );
    expect(
      find.textContaining(RegExp(r'^PENDING CODE · REFRESHES IN \d+ SEC$')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'badges for every state; format-1 and active cards look as before',
    (tester) async {
      for (final (code, badge) in [
        (
          card('refused', reason: 'wrong-recipient'),
          'REFUSED (wrong-recipient)',
        ),
        (card('expired'), 'EXPIRED'),
        (card('failed', reason: 'locked'), 'FAILED'),
        (card('reissued'), 'REISSUED'),
        (card('revoked'), 'REVOKED'),
      ]) {
        await tester.pumpWidget(host(LidarFloatingCodeCard(code: code)));
        expect(find.text(badge), findsOneWidget);
        expect(find.text('NOT ACTIVATED · LOCAL VAULT'), findsOneWidget);
      }
      await tester.pumpWidget(
        host(LidarFloatingCodeCard(code: card('active'))),
      );
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('PRIVATE · LOCAL VAULT'), findsOneWidget);
      await tester.pumpWidget(
        host(LidarFloatingCodeCard(code: card('pending'), setup: true)),
      );
      expect(find.text('PENDING SETUP'), findsOneWidget);
      final master = LidarMasterKey.parse(utf8.encode(masterFile)).toCode();
      await tester.pumpWidget(host(LidarFloatingCodeCard(code: master)));
      expect(find.text('PRIVATE · LOCAL VAULT'), findsOneWidget);
      expect(find.byType(LidarStateBadge), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('ACTIVATE on pending and refused cards only', (tester) async {
    for (final state in ['pending', 'refused']) {
      var taps = 0;
      await tester.pumpWidget(
        host(
          LidarKeyStatus(
            code: card(state, reason: state == 'refused' ? 'bad-code' : ''),
            onActivate: () => taps++,
          ),
        ),
      );
      await tester.tap(find.text('ACTIVATE'));
      expect(taps, 1, reason: state);
      expect(find.text('CANCEL'), findsNothing);
    }
    expect(
      find.text(
        'REFUSED (bad-code): the last activation was refused. The card stays as it was.',
      ),
      findsOneWidget,
    );
    for (final state in [
      'active',
      'expired',
      'failed',
      'reissued',
      'revoked',
    ]) {
      await tester.pumpWidget(
        host(LidarKeyStatus(code: card(state), onActivate: () {})),
      );
      expect(find.text('ACTIVATE'), findsNothing, reason: state);
    }
    await tester.pumpWidget(
      host(
        LidarKeyStatus(code: card('pending'), busy: true, onActivate: () {}),
      ),
    );
    expect(find.text('ACTIVATING…'), findsOneWidget);
    final master = LidarMasterKey.parse(utf8.encode(masterFile)).toCode();
    await tester.pumpWidget(host(LidarKeyStatus(code: master)));
    expect(find.byType(Text), findsNothing, reason: 'format 1: no panel');
  });

  testWidgets('after ACTIVE: the delete-the-file guidance', (tester) async {
    await tester.pumpWidget(host(LidarKeyStatus(code: card('active'))));
    expect(
      find.text(
        'Delete the downloaded file and the email: the app keeps your key.',
      ),
      findsOneWidget,
    );
    expect(find.text('Empty Trash or Deleted Items too.'), findsOneWidget);
  });

  testWidgets('pending setup: ACTIVATE and CANCEL; the old card is named', (
    tester,
  ) async {
    var activated = 0;
    var cancelled = 0;
    await tester.pumpWidget(
      host(
        LidarKeyStatus(
          code: card('pending'),
          setup: true,
          onActivate: () => activated++,
          onCancel: () => cancelled++,
        ),
      ),
    );
    expect(
      find.textContaining('replaces the admin2 card only after'),
      findsOneWidget,
    );
    await tester.tap(find.text('ACTIVATE'));
    await tester.tap(find.text('CANCEL'));
    expect([activated, cancelled], [1, 1]);
  });

  test('notices after ACTIVATE: plain words, never a code, secret or id', () async {
    Future<String> notice(Object reply, [String state = 'pending']) async {
      final outcome = await LidarActivation(
        poster: (url, body) async {
          if (reply is LidarHttpReply) return reply;
          throw reply;
        },
        codeFor: (_) => '654321',
      ).activate(card(state));
      return lidarOutcomeNotice(outcome);
    }

    final texts = [
      await notice(
        const LidarHttpReply(200, {
          'state': 'active',
          'seat': 'admin2',
          'name': 'CT',
          'linkedCredential': {
            'protocol': 1,
            'kind': 'enrolled',
            'generation': 4,
          },
        }),
      ),
      await notice(
        const LidarHttpReply(401, {
          'state': 'refused',
          'reason': 'bad-code',
          'attemptsLeft': 3,
        }),
      ),
      await notice(
        const LidarHttpReply(429, {
          'state': 'refused',
          'reason': 'locked',
          'retryAfter': 10,
        }),
      ),
      await notice(const LidarHttpReply(503, null)),
      await notice(StateError('synthetic offline')),
      await notice(const LidarHttpReply(200, null), 'active'),
    ];
    expect(texts[0], startsWith('ACTIVE: admin.lidarknight.com activated'));
    expect(
      texts[1],
      'Activation refused (bad-code). 3 attempts left. The card stays as it was.',
    );
    expect(
      texts[2],
      'Activation refused (locked). Try again in 10 s. The card stays as it was.',
    );
    expect(texts[3], contains('Nothing changed'));
    expect(texts[4], contains('Could not reach admin.lidarknight.com'));
    expect(texts[5], 'This key is not waiting for activation.');
    for (final text in texts) {
      for (final private in [secret, '654321', 'act_', 'ct@example.com']) {
        expect(text, isNot(contains(private)));
      }
    }
  });

  test('state messages and notices: contract meanings, nothing secret', () {
    expect(
      lidarStateMessage(card('pending').display),
      contains('Activate by 2026-10-12 12:00 UTC.'),
    );
    expect(
      lidarStateMessage(card('pending').display),
      contains('not signed in'),
    );
    expect(lidarStateMessage(card('expired').display), contains('reissue'));
    expect(lidarStateMessage(card('failed').display), contains('5 wrong'));
    expect(lidarStateMessage(card('reissued').display), contains('newer file'));
    expect(
      lidarStateMessage(card('revoked').display),
      contains('different admin'),
    );
    for (final state in LidarKeyContract.states) {
      final text = lidarStateMessage(card(state, reason: 'bad-code').display);
      expect(text, isNot(contains(secret)));
      expect(text, isNot(contains('act_')));
      expect(text, isNot(contains('ct@example.com')));
    }
  });
}
