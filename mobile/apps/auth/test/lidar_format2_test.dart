import 'dart:convert';

import 'package:ente_auth/models/code.dart';
import 'package:ente_auth/models/code_display.dart';
import 'package:ente_auth/services/lidar_master_key.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lidar_key_file_parity_cases.dart';

// SYNTHETIC LOCAL TEST ONLY: public test secrets, never an owner's key.
const s1 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
const s2 = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
const s3 = 'QWERTYUIOPASDFGHJKLZXCVBNM234567';
const id1 = 'act_0123456789abcdefABCDEF';
const id2 = 'act_ZYXWVUTSRQPONMLKJIHGFE';

/// The canonical format-2 text (as the server's buildKeyFile writes it).
String v2File({
  String seat = 'admin2',
  String name = 'CT',
  String email = 'ct@example.com',
  int generation = 4,
  String activationId = id1,
  String secret = s1,
  String issuer = 'admin.lidarknight.com',
}) =>
    'LK_FORMAT=2\nISSUER=$issuer\nSEAT=$seat\nNAME="$name"\nEMAIL=$email\n'
    'GENERATION=$generation\nISSUED_AT=2026-10-05T12:00:00Z\n'
    'ACTIVATE_BY=2026-10-12T12:00:00Z\nACTIVATION_ID=$activationId\n'
    'TOTP_SECRET=$secret\nOTPAUTH_URI=otpauth://totp/LiDAR-Knight:'
    '${Uri.encodeComponent(name)}?secret=$secret&issuer=LiDAR-Knight'
    '&algorithm=SHA1&digits=6&period=30\n';

LidarMasterKey key2({
  String seat = 'admin2',
  String email = 'ct@example.com',
  int generation = 4,
  String activationId = id1,
  String secret = s1,
}) => LidarMasterKey.parse(
  utf8.encode(
    v2File(
      seat: seat,
      email: email,
      generation: generation,
      activationId: activationId,
      secret: secret,
    ),
  ),
);

String v1File({String seat = 'admin2', String secret = s2}) =>
    '# SYNTHETIC LOCAL TEST ONLY\nSEAT=$seat\nNAME=TEST OWNER\n'
    'TOTP_SECRET=$secret\nOTPAUTH_URI=otpauth://totp/LiDAR:TEST?secret=$secret&issuer=LiDAR&digits=6&period=30&algorithm=SHA1\n';

/// A stored card as the database would hold it (state set directly).
Code stored(Code card, String state, {String reason = '', int id = 7}) => Code(
  card.account,
  card.issuer,
  card.digits,
  card.period,
  card.secret,
  card.algorithm,
  card.type,
  card.counter,
  card.rawData,
  display: card.display.copyWith(lidarState: state, lidarReason: reason),
)..generatedID = id;

/// A fresh, real server answer through a scripted fake poster (no network).
Future<LidarActivationOutcome> answer(
  Code card,
  LidarHttpReply reply, [
  LidarHttpReply? status,
]) {
  final replies = [reply, ?status];
  return LidarActivation(
    poster: (url, body) async => replies.removeAt(0),
    codeFor: (_) => '123456',
  ).activate(card);
}

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

void main() {
  group('parser parity with the server reference (key-file.js)', () {
    test('every synthetic file gets the reference verdict and fields', () {
      expect(parityCases.length, greaterThan(150));
      for (final c in parityCases) {
        final bytes = base64.decode(c.b64);
        if (c.format == 0) {
          try {
            LidarMasterKey.parse(bytes);
            fail('${c.id}: the reference refuses it');
          } on FormatException catch (error) {
            expect(error.message, c.error, reason: c.id);
            expect(error.source, isNull, reason: c.id);
            for (final secret in [s1, s2, 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP']) {
              expect(error.toString(), isNot(contains(secret)), reason: c.id);
            }
            expect(error.toString(), isNot(contains('@')), reason: c.id);
          }
          continue;
        }
        final LidarMasterKey key;
        try {
          key = LidarMasterKey.parse(bytes);
        } on FormatException catch (error) {
          fail('${c.id}: the reference accepts it, Dart said ${error.message}');
        }
        expect(key.format, c.format, reason: c.id);
        expect(key.seat, c.seat, reason: c.id);
        expect(key.name, c.name, reason: c.id);
        final code = key.toCode();
        expect(code.secret, c.secret, reason: c.id);
        expect(code.account, c.name, reason: c.id);
        expect(key.toString(), isNot(contains(c.secret)), reason: c.id);
        if (c.format == 2) {
          expect(key.issuer, c.issuer, reason: c.id);
          expect(key.email, c.email, reason: c.id);
          expect(key.generation, c.generation, reason: c.id);
          expect(key.issuedAt, c.issuedAt, reason: c.id);
          expect(key.activateBy, c.activateBy, reason: c.id);
          expect(code.display.lidarActivationId, c.activationId, reason: c.id);
        }
      }
    });

    test('the table covers both formats, every error text and the issuer', () {
      final errors = parityCases.map((c) => c.error).toSet();
      expect(errors, {
        '',
        'Choose one individual LiDAR owner ENV file.',
        'The owner file must be UTF-8 text.',
        'Invalid owner file format.',
        'Choose an individual owner file, not a provider ENV.',
        'The individual owner file is incomplete.',
        'Invalid LiDAR owner credential.',
        'This admin key belongs to another server.',
      });
      expect(parityCases.where((c) => c.format == 1).length, greaterThan(10));
      expect(parityCases.where((c) => c.format == 2).length, greaterThan(30));
    });
  });

  group('format 2 import card', () {
    test('a format-2 file becomes a locked PENDING card with its fields', () {
      final key = key2();
      final code = key.toCode();
      final d = code.display;
      expect(
        [d.lidarLocked, d.pinned, d.lidarSeat, d.lidarFormat],
        [true, true, 'admin2', 2],
      );
      expect(
        [d.lidarIssuer, d.lidarEmail, d.lidarActivationId, d.lidarState],
        ['admin.lidarknight.com', 'ct@example.com', id1, 'pending'],
      );
      expect(
        [d.lidarGeneration, d.lidarReason, d.lidarActivateBy],
        [4, '', '2026-10-12T12:00:00Z'],
      );
      expect(
        [code.issuer, code.account, code.digits, code.period],
        ['LiDAR-Knight', 'CT', 6, 30],
      );
      expect(code.type, Type.totp);
      expect(code.algorithm, Algorithm.sha1);
    });

    test('format 1 still makes the 4.4.29 card, byte for byte', () {
      final code = LidarMasterKey.parse(utf8.encode(v1File())).toCode();
      expect(LidarMasterKey.parse(utf8.encode(v1File())).format, 1);
      // The exact display JSON Auth 4.4.29 stored for a master card.
      expect(
        jsonEncode(code.display.toJson()),
        '{"pinned":true,"trashed":false,"lastUsedAt":0,"tapCount":0,'
        '"tags":[],"note":"","position":0,"iconSrc":"","iconID":"",'
        '"lidarSeat":"admin2","lidarLocked":true,"lidarGeneration":0}',
      );
      expect(code.toOTPAuthUrlFormat(), isNot(contains('lidarFormat')));
    });

    test('planImport refuses a format-1 key (format 1 keeps its own flow)', () {
      expect(
        () => LidarCredentialPolicy.planImport(
          LidarMasterKey.parse(utf8.encode(v1File())),
          null,
        ),
        throwsArgumentError,
      );
    });
  });

  group('model: JSON round trip and backwards compatibility', () {
    test('a format-2 card survives encrypted-storage serialization', () {
      for (final (name, email) in [
        ('CT', 'ct@example.com'),
        ('Q?#&=+ /', 'x%2cy@example.test'),
        ('Zoë 🚀', "o'neil+lk=1@example.test"),
      ]) {
        final text = v2File(name: name, email: email);
        final card = stored(
          LidarMasterKey.parse(utf8.encode(text)).toCode(),
          'refused',
          reason: 'bad-code',
        );
        final restored = Code.fromOTPAuthUrl(
          jsonDecode(card.toOTPAuthUrlFormat()),
        );
        expect(restored.display, card.display, reason: name);
        expect(restored.account, name);
        expect(restored.secret, s1);
        expect(restored.display.lidarEmail, email);
        final viaExport = Code.fromExportJson({
          'rawData': card.rawData,
          'display': card.display.toJson(),
        });
        expect(viaExport.display, card.display);
      }
    });

    test('an old 4.4.29 row loads unchanged as a format-1 master card', () {
      final legacy = CodeDisplay.fromJson({
        'pinned': true,
        'trashed': false,
        'lastUsedAt': 0,
        'tapCount': 0,
        'tags': [],
        'note': '',
        'position': 2,
        'iconSrc': '',
        'iconID': '',
        'lidarSeat': 'admin1',
        'lidarLocked': true,
        'lidarGeneration': 0,
      });
      expect(
        [legacy.lidarFormat, legacy.lidarState, legacy.lidarEmail],
        [1, '', ''],
      );
      expect(legacy.toJson().containsKey('lidarFormat'), false);
      expect(legacy.toJson().length, 12);
      expect(CodeDisplay.fromJson(legacy.toJson()), legacy);
      expect(CodeDisplay.fromJson({'note': 'normal'}).lidarFormat, 1);
    });

    test('format-2 keys are ignored unless the row says format 2', () {
      final d = CodeDisplay.fromJson({
        'lidarLocked': true,
        'lidarSeat': 'admin2',
        'lidarEmail': 'mallory@example.com',
        'lidarState': 'active',
        'lidarFormat': 3,
      });
      expect([d.lidarFormat, d.lidarEmail, d.lidarState], [1, '', '']);
      final typed = CodeDisplay.fromJson({
        'lidarFormat': 2,
        'lidarEmail': 7,
        'lidarState': ['active'],
      });
      expect(
        [typed.lidarFormat, typed.lidarEmail, typed.lidarState],
        [2, '', ''],
      );
    });

    test('copyWith and equality cover every format-2 field', () {
      final d = key2().toCode().display;
      for (final changed in [
        d.copyWith(lidarFormat: 1),
        d.copyWith(lidarIssuer: 'x'),
        d.copyWith(lidarEmail: 'x@y.z'),
        d.copyWith(lidarActivationId: id2),
        d.copyWith(lidarState: 'active'),
        d.copyWith(lidarReason: 'bad-code'),
        d.copyWith(lidarActivateBy: '2026-10-13T12:00:00Z'),
      ]) {
        expect(changed == d, false);
      }
      expect(d.copyWith(note: 'x').lidarActivationId, id1);
    });
  });

  group('policy: creation, state changes and locks', () {
    test('a PENDING card is created only from its own parsed file', () {
      final key = key2();
      final card = key.toCode();
      expect(
        () => LidarCredentialPolicy.checkWrite(card, [], importKey: key),
        returnsNormally,
      );
      expect(
        () => LidarCredentialPolicy.checkWrite(card, []),
        throwsStateError,
      );
      for (final forged in [
        card.copyWith(display: card.display.copyWith(lidarState: 'active')),
        card.copyWith(display: card.display.copyWith(lidarEmail: 'm@x.io')),
        card.copyWith(display: card.display.copyWith(lidarGeneration: 9)),
        card.copyWith(display: card.display.copyWith(lidarActivationId: id2)),
        card.copyWith(display: card.display.copyWith(lidarFormat: 1)),
      ]) {
        expect(
          () => LidarCredentialPolicy.checkWrite(forged, [], importKey: key),
          throwsStateError,
        );
      }
      // A format-1 key can never mint a card carrying format-2 metadata.
      final v1 = LidarMasterKey.parse(utf8.encode(v1File()));
      final v1Card = v1.toCode();
      expect(
        () => LidarCredentialPolicy.checkWrite(
          v1Card.copyWith(
            display: v1Card.display.copyWith(lidarEmail: 'x@y.io'),
          ),
          [],
          importKey: v1,
        ),
        throwsStateError,
      );
    });

    test(
      'the state changes only with a fresh server answer for that key',
      () async {
        final pending = stored(key2().toCode(), 'pending');
        final unproven = LidarActivation.withOutcome(
          pending,
          await answer(pending, active('admin2', 4)),
        );
        expect(unproven.display.lidarState, 'active');
        expect(
          () => LidarCredentialPolicy.checkWrite(unproven, [pending]),
          throwsStateError,
          reason: 'no answer, no ACTIVE',
        );
        final ok = await answer(pending, active('admin2', 4));
        expect(
          () => LidarCredentialPolicy.checkWrite(
            LidarActivation.withOutcome(pending, ok),
            [pending],
            activation: ok.proof,
          ),
          returnsNormally,
        );
        // The proof records exactly its own answer, on its own card.
        expect(
          () => LidarCredentialPolicy.checkWrite(
            stored(pending, 'refused', reason: 'bad-code'),
            [pending],
            activation: ok.proof,
          ),
          throwsStateError,
        );
        final other = stored(
          key2(activationId: id2, secret: s3).toCode(),
          'pending',
        );
        expect(
          () => LidarCredentialPolicy.checkWrite(stored(other, 'active'), [
            other,
          ], activation: ok.proof),
          throwsStateError,
        );
        // An ACTIVE card never moves back, even with a real refusal answer.
        final refusal = await answer(
          pending,
          const LidarHttpReply(401, {
            'state': 'refused',
            'reason': 'bad-code',
            'attemptsLeft': 4,
          }),
        );
        expect(
          () => LidarCredentialPolicy.checkWrite(
            stored(pending, 'refused', reason: 'bad-code'),
            [stored(pending, 'active')],
            activation: refusal.proof,
          ),
          throwsStateError,
        );
      },
    );

    test('no delete, no unlock, no edit of a format-2 card', () {
      final card = stored(key2().toCode(), 'active');
      for (final changed in [
        card.copyWith(display: card.display.copyWith(lidarLocked: false)),
        card.copyWith(display: card.display.copyWith(trashed: true)),
        card.copyWith(display: card.display.copyWith(lidarSeat: 'admin3')),
        card.copyWith(display: card.display.copyWith(lidarEmail: 'a@b.io')),
        card.copyWith(display: card.display.copyWith(lidarState: 'pending')),
        card.copyWith(secret: s3),
      ]) {
        changed.generatedID = 7;
        expect(
          () => LidarCredentialPolicy.checkWrite(changed, [card]),
          throwsStateError,
        );
      }
      expect(
        () => LidarCredentialPolicy.checkWrite(
          card.copyWith(display: card.display.copyWith(position: 3))
            ..generatedID = 7,
          [card],
        ),
        returnsNormally,
      );
      expect(
        () => LidarCredentialPolicy.checkRemove(card, card),
        throwsStateError,
      );
    });

    test('standard accounts cannot carry format-2 metadata or its secret', () {
      final card = key2().toCode();
      final standard = Code.fromOTPAuthUrl(
        'otpauth://totp/Example:me?secret=$s3&issuer=Example',
      );
      expect(
        () => LidarCredentialPolicy.checkStandard(standard, [card]),
        returnsNormally,
      );
      expect(
        () => LidarCredentialPolicy.checkStandard(
          standard.copyWith(
            display: CodeDisplay(lidarFormat: 2, lidarEmail: 'a@b.io'),
          ),
          [],
        ),
        throwsStateError,
      );
      expect(
        () => LidarCredentialPolicy.checkStandard(
          Code.fromOTPAuthUrl(
            'otpauth://totp/Example:me?secret=$s1&issuer=Example',
          ),
          [card],
        ),
        throwsStateError,
      );
    });
  });

  group('replacement rule (contract 5 + v2.3)', () {
    final old = key2(); // admin2, ct@example.com, generation 4, secret s1

    Future<void> expectReplace(
      Code previous,
      LidarMasterKey next, {
      required bool allowed,
    }) async {
      final setup = next.toCode();
      final outcome = await answer(setup, active(next.seat, next.generation));
      expect(outcome.isActive, true);
      final candidate = LidarActivation.withOutcome(setup, outcome)
        ..generatedID = previous.generatedID;
      expect(
        () => LidarCredentialPolicy.checkWrite(candidate, [
          previous,
        ], activation: outcome.proof),
        allowed ? returnsNormally : throwsStateError,
      );
    }

    for (final state in [
      'pending',
      'refused',
      'expired',
      'failed',
      'reissued',
      'revoked',
    ]) {
      test(
        'a $state card: same seat, same email, higher generation, after 200',
        () async {
          final previous = stored(
            old.toCode(),
            state,
            reason: state == 'refused' ? 'wrong-recipient' : '',
          );
          final newer = key2(generation: 5, activationId: id2, secret: s3);
          expect(
            LidarCredentialPolicy.planImport(newer, previous),
            LidarImportPlan.activateFirst,
          );
          // Until the newer key activates, the old card stays untouched.
          final setup = newer.toCode()..generatedID = previous.generatedID;
          expect(
            () => LidarCredentialPolicy.checkWrite(setup, [previous]),
            throwsStateError,
          );
          final refused = await answer(
            setup,
            const LidarHttpReply(401, {
              'state': 'refused',
              'reason': 'bad-code',
              'attemptsLeft': 4,
            }),
          );
          expect(
            () => LidarCredentialPolicy.checkWrite(
              LidarActivation.withOutcome(setup, refused),
              [previous],
              activation: refused.proof,
            ),
            throwsStateError,
          );
          await expectReplace(previous, newer, allowed: true);
          // Same generation, lower generation or another email: refused.
          for (final bad in [
            key2(generation: 4, activationId: id2, secret: s3),
            key2(generation: 3, activationId: id2, secret: s3),
            key2(
              generation: 5,
              activationId: id2,
              secret: s3,
              email: 'other@example.com',
            ),
          ]) {
            expect(
              LidarCredentialPolicy.planImport(bad, previous),
              LidarImportPlan.refusedNotNewer,
            );
            await expectReplace(previous, bad, allowed: false);
          }
        },
      );
    }

    test(
      'an ACTIVE card: only the linked-credential rule (higher generation)',
      () async {
        final previous = stored(old.toCode(), 'active');
        final newer = key2(
          generation: 6,
          activationId: id2,
          secret: s3,
          email: 'new@example.com',
        );
        expect(
          LidarCredentialPolicy.planImport(newer, previous),
          LidarImportPlan.activateFirst,
        );
        await expectReplace(previous, newer, allowed: true);
        final same = key2(generation: 4, activationId: id2, secret: s3);
        expect(
          LidarCredentialPolicy.planImport(same, previous),
          LidarImportPlan.refusedLocked,
        );
        await expectReplace(previous, same, allowed: false);
      },
    );

    test(
      'a format-1 master card keeps its lock; a newer activated key may follow it',
      () async {
        final master = LidarMasterKey.parse(
          utf8.encode(v1File(secret: s2)),
        ).toCode()..generatedID = 7;
        final newer = key2(generation: 1, activationId: id2, secret: s3);
        expect(
          LidarCredentialPolicy.planImport(newer, master),
          LidarImportPlan.activateFirst,
        );
        final pendingOverMaster = newer.toCode()..generatedID = 7;
        expect(
          () => LidarCredentialPolicy.checkWrite(pendingOverMaster, [master]),
          throwsStateError,
          reason: 'never without the activation answer',
        );
        await expectReplace(master, newer, allowed: true);
        // The seat's own master secret is the same key.
        expect(
          LidarCredentialPolicy.planImport(key2(secret: s2), master),
          LidarImportPlan.alreadyLinked,
        );
      },
    );

    test('the same file again, and a new seat', () {
      expect(
        LidarCredentialPolicy.planImport(old, stored(old.toCode(), 'pending')),
        LidarImportPlan.alreadyLinked,
      );
      expect(
        LidarCredentialPolicy.planImport(old, null),
        LidarImportPlan.create,
      );
    });

    test(
      'a replacement never lands on another seat or as a new card',
      () async {
        final previous = stored(old.toCode(), 'expired');
        final otherSeat = key2(
          seat: 'admin3',
          generation: 5,
          activationId: id2,
          secret: s3,
        );
        await expectReplace(previous, otherSeat, allowed: false);
        final setup = key2(
          generation: 5,
          activationId: id2,
          secret: s3,
        ).toCode();
        final outcome = await answer(setup, active('admin2', 5));
        expect(
          () => LidarCredentialPolicy.checkWrite(
            LidarActivation.withOutcome(setup, outcome),
            [previous],
            activation: outcome.proof,
          ),
          throwsStateError,
          reason: 'no generatedID: a second card for the seat',
        );
      },
    );
  });
}
