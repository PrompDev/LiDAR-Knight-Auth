import 'dart:convert';

import 'package:ente_auth/models/code.dart';
import 'package:ente_auth/models/code_display.dart';
import 'package:ente_auth/services/lidar_master_key.dart';
import 'package:ente_auth/services/preference_service.dart';
import 'package:ente_auth/ui/lidar_knight/admin_vault.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Auth 4.4.31: ONE key slot, REMOVE, BROKEN keys and ACTIVATE as the primary.
// SYNTHETIC LOCAL TEST ONLY: public test secrets, never an owner's key. No
// network: every HTTPS answer comes from a scripted fake poster, and the
// vault runs on an in-memory store that applies the real policy checks.
const s1 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
const s2 = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
const s3 = 'QWERTYUIOPASDFGHJKLZXCVBNM234567';
const id1 = 'act_0123456789abcdefABCDEF';
const id2 = 'act_ZYXWVUTSRQPONMLKJIHGFE';
const id3 = 'act_abcdefghijklmnopqrstuv';

String v2File({
  String seat = 'admin2',
  String email = 'ct@example.com',
  int generation = 4,
  String activationId = id1,
  String secret = s1,
}) =>
    'LK_FORMAT=2\nISSUER=admin.lidarknight.com\nSEAT=$seat\nNAME="CT"\n'
    'EMAIL=$email\nGENERATION=$generation\nISSUED_AT=2026-10-05T12:00:00Z\n'
    'ACTIVATE_BY=2026-10-12T12:00:00Z\nACTIVATION_ID=$activationId\n'
    'TOTP_SECRET=$secret\nOTPAUTH_URI=otpauth://totp/LiDAR-Knight:CT'
    '?secret=$secret&issuer=LiDAR-Knight&algorithm=SHA1&digits=6&period=30\n';

String v1File({String seat = 'admin2', String secret = s2}) =>
    '# SYNTHETIC LOCAL TEST ONLY\nSEAT=$seat\nNAME=TEST OWNER\n'
    'TOTP_SECRET=$secret\nOTPAUTH_URI=otpauth://totp/LiDAR:TEST?secret=$secret&issuer=LiDAR&digits=6&period=30&algorithm=SHA1\n';

LidarMasterKey key2({
  String seat = 'admin2',
  int generation = 4,
  String activationId = id1,
  String secret = s1,
}) => LidarMasterKey.parse(
  utf8.encode(
    v2File(
      seat: seat,
      generation: generation,
      activationId: activationId,
      secret: secret,
    ),
  ),
);

LidarMasterKey key1({String seat = 'admin2', String secret = s2}) =>
    LidarMasterKey.parse(utf8.encode(v1File(seat: seat, secret: secret)));

/// A stored card as the database would hold it (state set directly).
Code stored(Code card, String state, {String reason = '', int? id = 7}) => Code(
  card.account,
  card.issuer,
  card.digits,
  card.period,
  card.secret,
  card.algorithm,
  card.type,
  card.counter,
  card.rawData,
  generatedID: id,
  display: card.display.lidarFormat == 2
      ? card.display.copyWith(lidarState: state, lidarReason: reason)
      : card.display,
);

LidarHttpReply active(String seat, int generation) => LidarHttpReply(200, {
  'state': 'active',
  'seat': seat,
  'name': 'CT',
  'linkedCredential': {
    'protocol': 1,
    'kind': 'enrolled',
    'generation': generation,
  },
});

LidarHttpReply refusal(int status, String reason) => LidarHttpReply(status, {
  'state': 'refused',
  'reason': reason,
  'attemptsLeft': 4,
});

/// The fake server: answers in order, records every call.
class FakeServer {
  final replies = <Object>[];
  var calls = 0;
  LidarActivation get service => LidarActivation(
    poster: (url, body) async {
      calls++;
      final next = replies.removeAt(0);
      if (next is LidarHttpReply) return next;
      throw next;
    },
    codeFor: (_) => '123456',
  );
}

Future<LidarActivationOutcome> answer(Code card, LidarHttpReply reply) =>
    (FakeServer()..replies.add(reply)).service.activate(card);

/// CodeStore's offline vault in memory: rows are stored and read back as
/// encrypted storage holds them, and every write runs the real policy.
class FakeVaultStore extends LidarVaultStore {
  final _rows = <int, String>{};
  var _next = 1;

  List<Code> get rows => [
    for (final e in _rows.entries)
      Code.fromOTPAuthUrl(jsonDecode(e.value))..generatedID = e.key,
  ];

  int seed(Code card) {
    final id = _next++;
    _rows[id] = card.toOTPAuthUrlFormat();
    return id;
  }

  @override
  Future<List<Code>> cards() async =>
      rows.where((c) => !c.hasError && c.display.lidarLocked).toList();

  @override
  Future<void> prepare() async {}

  @override
  Future<void> save(
    Code card, {
    LidarMasterKey? key,
    LidarResetApproval? approval,
    LidarActivationProof? activation,
  }) async {
    final all = rows;
    LidarCredentialPolicy.checkStandard(card, all);
    LidarCredentialPolicy.checkWrite(
      card,
      all,
      approval: approval,
      importKey: key,
      activation: activation,
    );
    final id = card.generatedID;
    if (id != null && _rows.containsKey(id)) {
      _rows[id] = card.toOTPAuthUrlFormat();
    } else {
      card.generatedID = seed(card);
    }
  }

  @override
  Future<void> moveSlot(
    Code previous,
    Code next, {
    required LidarMasterKey key,
    required LidarActivationProof proof,
  }) async {
    LidarCredentialPolicy.checkSlotMove(
      previous,
      next,
      rows,
      key: key,
      proof: proof,
    );
    next.generatedID = seed(next);
    _rows.remove(previous.generatedID);
  }

  @override
  Future<void> remove(Code card) async {
    final persistent = rows
        .where((c) => c.generatedID == card.generatedID)
        .firstOrNull;
    LidarCredentialPolicy.checkLidarRemove(card, persistent);
    _rows.remove(persistent!.generatedID);
  }
}

final digits = find.byWidgetPredicate(
  (w) => w is Text && RegExp(r'^\d{6}$').hasMatch(w.data ?? ''),
);
final cardFinder = find.byType(LidarFloatingCodeCard);
final activateButton = find.byKey(const ValueKey('lidar-activate'));
final importButton = find.byKey(const ValueKey('lidar-import'));
final cancelButton = find.byKey(const ValueKey('lidar-cancel'));
final removeLink = find.byKey(const ValueKey('lidar-remove'));
final removeConfirm = find.byKey(const ValueKey('lidar-remove-confirm'));
final removeKeep = find.byKey(const ValueKey('lidar-remove-cancel'));

/// The LIDAR ADMIN tab on a fake vault, server and file picker.
Future<void> pumpVault(
  WidgetTester tester,
  FakeVaultStore store, {
  FakeServer? server,
  List<String> files = const [],
}) async {
  final picks = [...files];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 520,
          child: LidarAdminVault(
            store: store,
            activation: (server ?? FakeServer()).service,
            readKeyFile: () async => utf8.encode(picks.removeAt(0)),
          ),
        ),
      ),
    ),
  );
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

String badgeOf(WidgetTester tester) => tester
    .widget<LidarStateBadge>(
      find.descendant(of: cardFinder, matching: find.byType(LidarStateBadge)),
    )
    .label;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferenceService.instance.init();
  });

  group('REMOVE', () {
    testWidgets('two steps on the card, then the card is gone', (tester) async {
      final store = FakeVaultStore()
        ..seed(stored(key2().toCode(), 'active', id: null));
      await pumpVault(tester, store);
      expect(cardFinder, findsOneWidget);
      expect(badgeOf(tester), 'ACTIVE');
      // Step 1 only asks; CANCEL keeps everything.
      await tapAndSettle(tester, removeLink);
      expect(find.text(lidarRemoveQuestion), findsOneWidget);
      expect(
        lidarRemoveQuestion,
        'Remove this key from this device? You will need a new key from an '
        'admin to sign in again.',
      );
      expect(store.rows.length, 1);
      await tapAndSettle(tester, removeKeep);
      expect(find.text(lidarRemoveQuestion), findsNothing);
      expect(store.rows.length, 1);
      expect(cardFinder, findsOneWidget);
      // Step 2: REMOVE KEY deletes the card from this device.
      await tapAndSettle(tester, removeLink);
      await tapAndSettle(tester, removeConfirm);
      expect(store.rows, isEmpty);
      expect(cardFinder, findsNothing);
      expect(find.text('Key removed from this device.'), findsOneWidget);
      expect(find.text('Your key. Your clearance.'), findsOneWidget);
      expect(
        find.textContaining('Linked keys cannot be edited or removed'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a waiting key has no REMOVE: CANCEL drops it instead', (
      tester,
    ) async {
      final store = FakeVaultStore()
        ..seed(stored(key2().toCode(), 'active', id: null));
      await pumpVault(
        tester,
        store,
        files: [v2File(generation: 5, activationId: id2, secret: s3)],
      );
      await tapAndSettle(tester, importButton);
      expect(badgeOf(tester), 'PENDING SETUP');
      expect(removeLink, findsNothing);
      expect(cancelButton, findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    test('only the exact stored managed row may go, and only this way', () {
      for (final card in [
        stored(key2().toCode(), 'failed', reason: 'locked'),
        stored(key2().toCode(), 'active'),
        stored(key2().toCode(), 'pending'),
        stored(key1().toCode(), ''),
      ]) {
        expect(
          () => LidarCredentialPolicy.checkLidarRemove(card, card),
          returnsNormally,
        );
        // The activation state may have moved on; the key is the same.
        if (card.display.lidarFormat == 2) {
          expect(
            () => LidarCredentialPolicy.checkLidarRemove(
              card,
              stored(card, 'refused', reason: 'bad-code'),
            ),
            returnsNormally,
          );
        }
        for (final (what, shown, saved) in <(String, Code, Code?)>[
          ('no stored row', card, null),
          ('another row', card, stored(card, 'active', id: 8)),
          ('no row id', stored(card, 'active', id: null), card),
          (
            'another secret',
            card,
            card.copyWith(secret: s3)..generatedID = card.generatedID,
          ),
          (
            'another generation',
            card,
            card.copyWith(display: card.display.copyWith(lidarGeneration: 9))
              ..generatedID = card.generatedID,
          ),
          (
            'another seat',
            card,
            card.copyWith(display: card.display.copyWith(lidarSeat: 'admin3'))
              ..generatedID = card.generatedID,
          ),
          (
            'an unmanaged row',
            card,
            card.copyWith(display: CodeDisplay())
              ..generatedID = card.generatedID,
          ),
          (
            'an unmanaged caller copy',
            card.copyWith(display: CodeDisplay())
              ..generatedID = card.generatedID,
            card,
          ),
        ]) {
          expect(
            () => LidarCredentialPolicy.checkLidarRemove(shown, saved),
            throwsStateError,
            reason: what,
          );
        }
      }
      final normal = Code.fromOTPAuthUrl(
        'otpauth://totp/Example:me?secret=$s3&issuer=Example',
      )..generatedID = 3;
      expect(
        () => LidarCredentialPolicy.checkLidarRemove(normal, normal),
        throwsStateError,
        reason: 'REMOVE is for LiDAR cards only',
      );
    });

    test('ordinary delete and edit flows still refuse every managed card', () {
      for (final card in [
        stored(key2().toCode(), 'failed', reason: 'locked'),
        stored(key2().toCode(), 'expired'),
        stored(key2().toCode(), 'active'),
        stored(key2().toCode(), 'pending'),
        stored(key1().toCode(), ''),
      ]) {
        // CodeStore.removeCode (Authenticator tab, debug viewer) checks this.
        expect(
          () => LidarCredentialPolicy.checkRemove(card, card),
          throwsStateError,
        );
        expect(
          () => LidarCredentialPolicy.checkRemove(
            card.copyWith(display: CodeDisplay())
              ..generatedID = card.generatedID,
            card,
          ),
          throwsStateError,
        );
        // Trashing, unlocking or editing it through addCode.
        for (final changed in [
          card.copyWith(display: card.display.copyWith(trashed: true)),
          card.copyWith(display: card.display.copyWith(lidarLocked: false)),
          card.copyWith(account: 'Mallory'),
        ]) {
          changed.generatedID = card.generatedID;
          expect(
            () => LidarCredentialPolicy.checkWrite(changed, [card]),
            throwsStateError,
          );
        }
      }
    });
  });

  group('one key slot', () {
    testWidgets(
      'a newer key waits in the same slot; CANCEL keeps the card, ACTIVATE '
      'replaces it',
      (tester) async {
        final store = FakeVaultStore();
        final id = store.seed(stored(key2().toCode(), 'active', id: null));
        final server = FakeServer();
        final newer = v2File(generation: 5, activationId: id2, secret: s3);
        await pumpVault(tester, store, server: server, files: [newer, newer]);
        expect(badgeOf(tester), 'ACTIVE');

        await tapAndSettle(tester, importButton);
        expect(cardFinder, findsOneWidget, reason: 'never two stacked cards');
        expect(badgeOf(tester), 'PENDING SETUP');
        expect(
          find.textContaining('replaces the admin2 card only after'),
          findsOneWidget,
        );
        expect(
          find.text(
            'PENDING SETUP: press ACTIVATE. The admin2 card changes only after '
            'admin.lidarknight.com activates this key.',
          ),
          findsOneWidget,
        );
        expect(activateButton, findsOneWidget);
        expect(cancelButton, findsOneWidget);
        expect(store.rows.single.secret, s1, reason: 'nothing changed yet');

        await tapAndSettle(tester, cancelButton);
        expect(cardFinder, findsOneWidget);
        expect(badgeOf(tester), 'ACTIVE');
        expect(activateButton, findsNothing);
        expect(store.rows.single.secret, s1);
        expect(server.calls, 0);

        await tapAndSettle(tester, importButton);
        server.replies.add(active('admin2', 5));
        await tapAndSettle(tester, activateButton);
        expect(server.calls, 1);
        final card = store.rows.single;
        expect(
          [card.secret, card.generatedID, card.display.lidarGeneration],
          [s3, id, 5],
        );
        expect(card.display.lidarState, 'active');
        expect(cardFinder, findsOneWidget);
        expect(badgeOf(tester), 'ACTIVE');
        expect(activateButton, findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'another seat: refused or broken answers leave the card; only its own '
      'activation moves the slot',
      (tester) async {
        final store = FakeVaultStore()
          ..seed(stored(key2().toCode(), 'active', id: null));
        final server = FakeServer();
        final other = v2File(
          seat: 'admin3',
          generation: 1,
          activationId: id2,
          secret: s3,
        );
        await pumpVault(tester, store, server: server, files: [other, other]);

        await tapAndSettle(tester, importButton);
        expect(cardFinder, findsOneWidget);
        expect(badgeOf(tester), 'PENDING SETUP');
        expect(
          find.textContaining('replaces the admin2 card only after'),
          findsOneWidget,
        );

        server.replies.add(refusal(401, 'bad-code'));
        await tapAndSettle(tester, activateButton);
        expect(cardFinder, findsOneWidget);
        expect(badgeOf(tester), 'REFUSED (bad-code)');
        expect(
          find.text(
            'REFUSED (bad-code): this newer key was not activated. The admin2 '
            'card stays as it was.',
          ),
          findsOneWidget,
        );
        expect(activateButton, findsOneWidget, reason: 'it may try again');
        expect(store.rows.single.display.lidarSeat, 'admin2');

        server.replies.add(
          const LidarHttpReply(410, {'state': 'refused', 'reason': 'expired'}),
        );
        await tapAndSettle(tester, activateButton);
        expect(badgeOf(tester), 'BROKEN');
        expect(activateButton, findsNothing);
        expect(removeLink, findsNothing, reason: 'never stored: CANCEL');
        expect(store.rows.single.display.lidarSeat, 'admin2');
        await tapAndSettle(tester, cancelButton);
        expect(badgeOf(tester), 'ACTIVE');
        expect(store.rows.single.secret, s1);

        await tapAndSettle(tester, importButton);
        server.replies.add(active('admin3', 1));
        await tapAndSettle(tester, activateButton);
        final card = store.rows.single;
        expect(
          [card.display.lidarSeat, card.secret, card.display.lidarState],
          ['admin3', s3, 'active'],
        );
        expect(cardFinder, findsOneWidget);
        expect(badgeOf(tester), 'ACTIVE');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('a format-1 file never stacks onto another seat\'s card', (
      tester,
    ) async {
      final store = FakeVaultStore()
        ..seed(stored(key2().toCode(), 'active', id: null));
      await pumpVault(tester, store, files: [v1File(seat: 'admin3')]);
      await tapAndSettle(tester, importButton);
      expect(cardFinder, findsOneWidget);
      expect(badgeOf(tester), 'ACTIVE');
      expect(
        find.text('One key at a time: REMOVE this key first, then import.'),
        findsOneWidget,
      );
      expect(store.rows.single.display.lidarSeat, 'admin2');
      await tester.pumpWidget(const SizedBox());
    });

    test('planSlotImport: one slot for both formats', () {
      final card2 = stored(key2().toCode(), 'active');
      final master = stored(key1().toCode(), '');
      final admin3 = key2(seat: 'admin3', activationId: id2, secret: s3);
      expect(
        LidarCredentialPolicy.planSlotImport(admin3),
        LidarImportPlan.create,
      );
      expect(
        LidarCredentialPolicy.planSlotImport(admin3, slot: card2),
        LidarImportPlan.activateFirst,
      );
      // The seat's own card keeps planImport's rules.
      final same = key2(activationId: id2, secret: s3);
      expect(
        LidarCredentialPolicy.planSlotImport(
          same,
          sameSeat: card2,
          slot: card2,
        ),
        LidarCredentialPolicy.planImport(same, card2),
      );
      expect(
        LidarCredentialPolicy.planSlotImport(
          key2(),
          sameSeat: card2,
          slot: card2,
        ),
        LidarImportPlan.alreadyLinked,
      );
      // Format 1.
      expect(
        LidarCredentialPolicy.planSlotImport(key1()),
        LidarImportPlan.create,
      );
      expect(
        LidarCredentialPolicy.planSlotImport(
          key1(),
          sameSeat: master,
          slot: master,
        ),
        LidarImportPlan.alreadyLinked,
      );
      expect(
        LidarCredentialPolicy.planSlotImport(
          key1(secret: s1),
          sameSeat: master,
          slot: master,
        ),
        LidarImportPlan.activateFirst,
      );
      expect(
        LidarCredentialPolicy.planSlotImport(key1(seat: 'admin3'), slot: card2),
        LidarImportPlan.removeFirst,
      );
    });

    test('checkSlotMove: another seat takes the slot only with its own fresh '
        'active answer, as its own file', () async {
      final previous = stored(key2().toCode(), 'active');
      final newer = key2(
        seat: 'admin3',
        generation: 1,
        activationId: id2,
        secret: s3,
      );
      final setup = newer.toCode();
      final ok = await answer(setup, active('admin3', 1));
      final next = LidarActivation.withOutcome(setup, ok);
      expect(
        () => LidarCredentialPolicy.checkSlotMove(
          previous,
          next,
          [previous],
          key: newer,
          proof: ok.proof!,
        ),
        returnsNormally,
      );
      // Any previous card may be moved from (a broken or format-1 one too).
      for (final from in [
        stored(key2().toCode(), 'failed', reason: 'locked'),
        stored(key1().toCode(), ''),
      ]) {
        expect(
          () => LidarCredentialPolicy.checkSlotMove(
            from,
            next,
            [from],
            key: newer,
            proof: ok.proof!,
          ),
          returnsNormally,
        );
      }
      final refused = await answer(setup, refusal(401, 'bad-code'));
      final otherKey = key2(
        seat: 'admin3',
        generation: 2,
        activationId: id3,
        secret: s2,
      );
      final otherOk = await answer(otherKey.toCode(), active('admin3', 2));
      final sameSeat = key2(generation: 5, activationId: id2, secret: s3);
      final sameSeatOk = await answer(sameSeat.toCode(), active('admin2', 5));
      for (final (what, prev, cand, rows, key, proof)
          in <
            (
              String,
              Code,
              Code,
              List<Code>,
              LidarMasterKey,
              LidarActivationProof,
            )
          >[
            ('still pending', previous, setup, [previous], newer, ok.proof!),
            (
              'a refusal',
              previous,
              LidarActivation.withOutcome(setup, refused),
              [previous],
              newer,
              refused.proof!,
            ),
            (
              'a refusal proof',
              previous,
              next,
              [previous],
              newer,
              refused.proof!,
            ),
            (
              'another key\'s proof',
              previous,
              next,
              [previous],
              newer,
              otherOk.proof!,
            ),
            ('another file', previous, next, [previous], otherKey, ok.proof!),
            (
              'the seat already has a card',
              previous,
              next,
              [previous, stored(otherKey.toCode(), 'pending', id: 8)],
              newer,
              ok.proof!,
            ),
            ('no stored previous', previous, next, [], newer, ok.proof!),
            (
              'a stale previous',
              previous.copyWith(secret: s2)..generatedID = 7,
              next,
              [previous],
              newer,
              ok.proof!,
            ),
            (
              'a row id on the new card',
              previous,
              LidarActivation.withOutcome(setup, ok)..generatedID = 9,
              [previous],
              newer,
              ok.proof!,
            ),
            (
              'the same seat (checkWrite decides that)',
              previous,
              LidarActivation.withOutcome(sameSeat.toCode(), sameSeatOk),
              [previous],
              sameSeat,
              sameSeatOk.proof!,
            ),
          ]) {
        expect(
          () => LidarCredentialPolicy.checkSlotMove(
            prev,
            cand,
            rows,
            key: key,
            proof: proof,
          ),
          throwsStateError,
          reason: what,
        );
      }
      // And checkWrite still never lets a key land on another seat's row.
      expect(
        () => LidarCredentialPolicy.checkWrite(
          LidarActivation.withOutcome(setup, ok)
            ..generatedID = previous.generatedID,
          [previous],
          activation: ok.proof,
        ),
        throwsStateError,
      );
    });
  });

  group('BROKEN', () {
    for (final (state, reason, line) in [
      ('failed', 'locked', 'FAILED: 5 wrong activation codes.'),
      ('expired', '', 'EXPIRED: the activation deadline passed.'),
      (
        'revoked',
        '',
        'REVOKED: the seat was revoked or reset by a different admin.',
      ),
      ('reissued', '', 'REISSUED: a newer key replaced this one.'),
    ]) {
      testWidgets('$state: one red badge, one reason, code hidden, REMOVE', (
        tester,
      ) async {
        final card = stored(key2().toCode(), state, reason: reason);
        expect(lidarBroken(card.display), true);
        expect(lidarBrokenReason(card.display), line);
        var removed = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 520,
                child: ListView(
                  children: [
                    LidarFloatingCodeCard(
                      code: card,
                      onRemove: () => removed++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(find.byType(LidarStateBadge), findsOneWidget);
        final badge = tester.widget<LidarStateBadge>(
          find.byType(LidarStateBadge),
        );
        expect([badge.label, badge.broken], ['BROKEN', true]);
        expect(find.text(line), findsOneWidget);
        expect(find.text('Ask an admin for a new key.'), findsOneWidget);
        expect(find.text('LOCAL VAULT · CODE HIDDEN'), findsOneWidget);
        expect(find.text('CLICK TO REVEAL'), findsNothing);
        await tester.tap(cardFinder);
        await tester.pump(const Duration(milliseconds: 400));
        expect(digits, findsNothing, reason: 'a broken key never shows codes');
        await tester.tap(removeLink);
        await tester.pump();
        expect(removed, 0, reason: 'step 1 only asks');
        await tester.tap(removeConfirm);
        await tester.pump();
        expect(removed, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('a revealed code is hidden the moment its key breaks', (
      tester,
    ) async {
      Widget host(Code code) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            child: LidarFloatingCodeCard(key: const ValueKey('k'), code: code),
          ),
        ),
      );
      final pending = stored(key2().toCode(), 'pending');
      await tester.pumpWidget(host(pending));
      await tester.tap(find.text('CLICK TO REVEAL'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(digits, findsOneWidget);
      await tester.pumpWidget(
        host(stored(pending, 'failed', reason: 'locked')),
      );
      await tester.pump();
      expect(digits, findsNothing);
      expect(find.text('BROKEN'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the vault: no ACTIVATE, IMPORT as a link, REMOVE removes', (
      tester,
    ) async {
      final store = FakeVaultStore()
        ..seed(stored(key2().toCode(), 'failed', reason: 'locked', id: null));
      await pumpVault(tester, store);
      expect(badgeOf(tester), 'BROKEN');
      expect(activateButton, findsNothing);
      expect(tester.widget(importButton), isA<TextButton>());
      expect(find.text('Ask an admin for a new key.'), findsOneWidget);
      await tapAndSettle(tester, removeLink);
      expect(find.text(lidarRemoveQuestion), findsOneWidget);
      await tapAndSettle(tester, removeConfirm);
      expect(store.rows, isEmpty);
      expect(cardFinder, findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a broken card in the slot yields to a newer key', (
      tester,
    ) async {
      final store = FakeVaultStore()
        ..seed(stored(key2().toCode(), 'expired', id: null));
      final server = FakeServer()..replies.add(active('admin2', 5));
      await pumpVault(
        tester,
        store,
        server: server,
        files: [v2File(generation: 5, activationId: id2, secret: s3)],
      );
      await tapAndSettle(tester, importButton);
      expect(badgeOf(tester), 'PENDING SETUP');
      await tapAndSettle(tester, activateButton);
      expect(store.rows.single.secret, s3);
      expect(badgeOf(tester), 'ACTIVE');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('ACTIVATE is the primary', () {
    for (final (state, reason) in [('pending', ''), ('refused', 'bad-code')]) {
      testWidgets('$state: full width, IMPORT below it as a link', (
        tester,
      ) async {
        final store = FakeVaultStore()
          ..seed(stored(key2().toCode(), state, reason: reason, id: null));
        await pumpVault(tester, store);
        expect(activateButton, findsOneWidget);
        expect(tester.widget(activateButton), isA<OutlinedButton>());
        // The vault column is 520 wide with a 16 px gutter each side.
        expect(tester.getSize(activateButton).width, 520 - 32);
        expect(tester.widget(importButton), isA<TextButton>());
        expect(
          tester.getTopLeft(importButton).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(activateButton).dy),
        );
        expect(
          tester.getTopLeft(activateButton).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(cardFinder).dy),
        );
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('a waiting key: ACTIVATE, then CANCEL, then IMPORT', (
      tester,
    ) async {
      final store = FakeVaultStore()
        ..seed(stored(key2().toCode(), 'active', id: null));
      await pumpVault(
        tester,
        store,
        files: [v2File(generation: 5, activationId: id2, secret: s3)],
      );
      await tapAndSettle(tester, importButton);
      expect(tester.getSize(activateButton).width, 520 - 32);
      final activateBottom = tester.getBottomLeft(activateButton).dy;
      expect(
        tester.getTopLeft(cancelButton).dy,
        greaterThanOrEqualTo(activateBottom),
      );
      expect(
        tester.getTopLeft(importButton).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(cancelButton).dy),
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no ACTIVATE for an active key; IMPORT is primary only with '
        'no key', (tester) async {
      final store = FakeVaultStore()
        ..seed(stored(key2().toCode(), 'active', id: null));
      await pumpVault(tester, store);
      expect(activateButton, findsNothing);
      expect(tester.widget(importButton), isA<TextButton>());
      await tester.pumpWidget(const SizedBox());

      await pumpVault(tester, FakeVaultStore());
      expect(cardFinder, findsNothing);
      expect(tester.widget(importButton), isA<OutlinedButton>());
      expect(tester.getSize(importButton).width, 520 - 32);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
