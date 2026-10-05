import 'dart:convert';

import 'package:ente_auth/models/code.dart';
import 'package:ente_auth/models/code_display.dart';
import 'package:ente_auth/services/lidar_master_key.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lidar_key_file_parity_cases.dart';
import 'lidar_key_file_parity_extra.dart';

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

/// Every row must get the reference verdict, error text and fields.
void expectParity(List<ParityCase> cases) {
  for (final c in cases) {
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
      // The card the file makes can be created from it (its label is NAME).
      expect(
        () => LidarCredentialPolicy.checkWrite(code, [], importKey: key),
        returnsNormally,
        reason: c.id,
      );
    }
  }
}

void main() {
  group('parser parity with the server reference (key-file.js)', () {
    test('every synthetic file gets the reference verdict and fields', () {
      expect(parityCases.length, greaterThan(150));
      expectParity(parityCases);
    });

    test('URI spellings, EMAIL letters and NAMEs the first table missed', () {
      expect(parityCasesExtra.length, greaterThan(90));
      expectParity(parityCasesExtra);
      final verdicts = {for (final c in parityCasesExtra) c.id: c.format};
      // The review's findings, as the reference judges them.
      for (final (id, format) in [
        ('v2 URI port 65536', 0),
        ('v2 URI backslash after host', 0),
        ('v2 URI backslashes after scheme', 0),
        ('v2 URI raw BOM before label', 0),
        ('v2 URI raw BOM before secret name', 0),
        ('v2 URI %EF%BB%BF before secret value', 0),
        ('v2 URI tab in host', 2),
        ('v2 URI leading U+0001', 2),
        ('v2 URI %E2%82 in another value', 2),
        ('v2 NAME backslash, raw label', 2),
        ('v2 EMAIL a+U+13A0', 0),
        ('v2 EMAIL a+U+1E900', 0),
        ('v2 EMAIL a+U+00E9', 2),
      ]) {
        expect(verdicts[id], format, reason: id);
      }
    });

    test('EMAIL lower-case follows JavaScript, not Dart, toLowerCase', () {
      bool lower(int cp) => LidarKeyContract.lowerCase(String.fromCharCode(cp));
      for (var cp = 0; cp < 0x80; cp++) {
        expect(lower(cp), !(cp >= 0x41 && cp <= 0x5A), reason: '$cp');
      }
      // Upper-case letters newer than Dart's tables (the review's examples).
      for (final cp in [
        0x037F, 0x0524, 0x10C7, 0x13A0, 0x13F5, 0x1C89, 0x1C90, 0x2C2F, //
        0xA7C0, 0xA7D0, 0x10570, 0x10C80, 0x118A0, 0x16E40, 0x1E900,
      ]) {
        expect(lower(cp), false, reason: cp.toRadixString(16));
      }
      for (final cp in [0x00C0, 0x0130, 0x03A3, 0x1E9E, 0x10400]) {
        expect(lower(cp), false, reason: cp.toRadixString(16));
      }
      // Lower-case letters and letters without a lower-case form.
      for (final cp in [0x00E9, 0x00DF, 0x03C2, 0x0149, 0x2102, 0x13F8]) {
        expect(lower(cp), true, reason: cp.toRadixString(16));
      }
      expect(LidarKeyContract.lowerCase('ct@example.com'), true);
      expect(LidarKeyContract.lowerCase('a\u{1E922}@example.com'), true);
      expect(LidarKeyContract.lowerCase('a\u{1E900}@example.com'), false);
    });

    test('format 1 keeps the Auth 4.4.29 URI rules, even where key-file.js '
        'differs (the server reference must follow, not the app)', () {
      String v1(String uri) =>
          'SEAT=admin1\nNAME=LOCAL TEST\nTOTP_SECRET=$s1\nOTPAUTH_URI=$uri\n';
      LidarMasterKey parse(String uri) =>
          LidarMasterKey.parse(utf8.encode(v1(uri)));
      // 4.4.29 accepts a port above 65535 (key-file.js refuses it) ...
      expect(parse('otpauth://totp:65536/X?secret=$s1').format, 1);
      expect(parse('otpauth://totp:99999/X?secret=$s1').format, 1);
      // ... and refuses a tab in the host or a leading C0 control (key-file.js
      // accepts both).
      for (final uri in [
        'otpauth://to\ttp/X?secret=$s1',
        '\u0001otpauth://totp/X?secret=$s1',
      ]) {
        expect(
          () => parse(uri),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'Invalid LiDAR owner credential.',
            ),
          ),
        );
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

    test('the card label is always the NAME (canonical OTPAUTH_URI)', () {
      for (final name in ['A\\B', 'A/./B', 'A/../B', 'X/.', '..', 'Q?#&=+ /']) {
        final key = LidarMasterKey.parse(utf8.encode(v2File(name: name)));
        final card = key.toCode();
        expect(card.account, name);
        expect(
          card.rawData,
          'otpauth://totp/LiDAR-Knight:${Uri.encodeComponent(name)}'
          '?secret=$s1&issuer=LiDAR-Knight&algorithm=SHA1&digits=6&period=30',
        );
        // The import is not mistaken for a locked seat.
        expect(
          () => LidarCredentialPolicy.checkWrite(card, [], importKey: key),
          returnsNormally,
          reason: name,
        );
        // And the label survives encrypted-storage serialization.
        final restored = Code.fromOTPAuthUrl(
          jsonDecode(stored(card, 'pending').toOTPAuthUrlFormat()),
        );
        expect(restored.account, name);
      }
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
        'a $state card: replaced only by a key the server just proved',
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
          // The old card's EMAIL and GENERATION come from its own file, which
          // the server may never have confirmed: another email (a corrected
          // reissue), an equal or lower generation, or the same activation id
          // with another secret never blocks a key the server proved (v2.4
          // note). The server alone decides; until it does, nothing changes.
          for (final other in [
            key2(generation: 4, activationId: id2, secret: s3),
            key2(generation: 3, activationId: id2, secret: s3),
            key2(
              generation: 5,
              activationId: id2,
              secret: s3,
              email: 'other@example.com',
            ),
            key2(generation: 4, secret: s3),
          ]) {
            expect(
              LidarCredentialPolicy.planImport(other, previous),
              LidarImportPlan.activateFirst,
            );
            final pendingSetup = other.toCode()
              ..generatedID = previous.generatedID;
            expect(
              () => LidarCredentialPolicy.checkWrite(pendingSetup, [previous]),
              throwsStateError,
            );
            await expectReplace(previous, other, allowed: true);
          }
        },
      );
    }

    test('a proof replaces with its own key only', () async {
      final previous = stored(old.toCode(), 'pending');
      final newer = key2(generation: 5, activationId: id2, secret: s3);
      final setup = newer.toCode();
      final ok = await answer(setup, active('admin2', 5));
      final activated = LidarActivation.withOutcome(setup, ok)
        ..generatedID = previous.generatedID;
      // The same proof cannot carry another email, deadline or label.
      for (final changed in [
        activated.copyWith(
          display: activated.display.copyWith(lidarEmail: 'm@x.io'),
        ),
        activated.copyWith(
          display: activated.display.copyWith(
            lidarActivateBy: '2026-10-13T12:00:00Z',
          ),
        ),
        activated.copyWith(account: 'Mallory'),
      ]) {
        changed.generatedID = previous.generatedID;
        expect(
          () => LidarCredentialPolicy.checkWrite(changed, [
            previous,
          ], activation: ok.proof),
          throwsStateError,
        );
      }
      expect(
        () => LidarCredentialPolicy.checkWrite(activated, [
          previous,
        ], activation: ok.proof),
        returnsNormally,
      );
    });

    test(
      'review A: a forged max-generation card never blocks the real key',
      () async {
        // A well-formed file nobody issued (another secret and activation id,
        // the largest GENERATION) is saved as a locked PENDING card.
        final forged = key2(
          generation: 9007199254740991,
          activationId: id2,
          secret: s3,
        );
        final squat = stored(forged.toCode(), 'pending');
        // ACTIVATE: the server does not know it.
        final unknown = await answer(
          squat,
          const LidarHttpReply(404, {'state': 'refused', 'reason': 'unknown'}),
        );
        final refusedSquat = LidarActivation.withOutcome(squat, unknown)
          ..generatedID = squat.generatedID;
        LidarCredentialPolicy.checkWrite(refusedSquat, [
          squat,
        ], activation: unknown.proof);
        expect(refusedSquat.display.lidarReason, 'unknown');
        // The real key, generation 5, at the same seat (with the same or a
        // different email) takes the seat once the server activated it.
        for (final real in [
          key2(generation: 5),
          key2(generation: 5, email: 'owner@example.com'),
        ]) {
          for (final card in [squat, refusedSquat]) {
            expect(
              LidarCredentialPolicy.planImport(real, card),
              LidarImportPlan.activateFirst,
            );
            await expectReplace(card, real, allowed: true);
          }
        }
        // A format-1 setup file proved by a fresh sign-in may follow it too:
        // the squatter's generation is no floor.
        expect(LidarCredentialPolicy.replacementFloor(refusedSquat.display), 0);
        final signin = {
          'seat': 'admin2',
          'caps': ['admin'],
          'expiresAt': 2000,
          'linkedCredential': {
            'protocol': 1,
            'kind': 'enrolled',
            'generation': 5,
          },
        };
        expect(
          LidarResetApproval.validReply(
            signin,
            'admin2',
            LidarCredentialPolicy.replacementFloor(refusedSquat.display),
            1000,
          ),
          true,
        );
        // An active or format-1 card keeps its own generation as the floor.
        expect(
          LidarCredentialPolicy.replacementFloor(
            stored(old.toCode(), 'active').display,
          ),
          4,
        );
        final master = LidarMasterKey.parse(utf8.encode(v1File())).toCode();
        expect(LidarCredentialPolicy.replacementFloor(master.display), 0);
        expect(
          LidarCredentialPolicy.replacementFloor(
            master.display.copyWith(lidarGeneration: 7),
          ),
          7,
        );
      },
    );

    test(
      'review: a corrected-email reissue replaces the old card after 200',
      () async {
        // gen 4 was sent to ct@example.com; the inviting admin reissued gen 5
        // to the corrected address (contract 3: reissueKey { seat, email }).
        for (final state in ['pending', 'expired', 'failed', 'reissued']) {
          final previous = stored(old.toCode(), state);
          final corrected = key2(
            generation: 5,
            activationId: id2,
            secret: s3,
            email: 'corrected@example.com',
          );
          expect(
            LidarCredentialPolicy.planImport(corrected, previous),
            LidarImportPlan.activateFirst,
          );
          await expectReplace(previous, corrected, allowed: true);
        }
      },
    );

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
