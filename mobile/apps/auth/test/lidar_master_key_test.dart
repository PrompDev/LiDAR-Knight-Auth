import 'dart:convert';

import 'package:ente_auth/models/code.dart';
import 'package:ente_auth/models/code_display.dart';
import 'package:ente_auth/services/lidar_master_key.dart';
import 'package:flutter_test/flutter_test.dart';

// Public RFC-style fixture, never an owner's key and never accepted by a server.
const fixtureSecret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
String fixture({String seat = 'admin2', String secret = fixtureSecret}) =>
    '# SYNTHETIC LOCAL TEST ONLY\nSEAT=$seat\nNAME=TEST OWNER\n'
    'TOTP_SECRET=$secret\nOTPAUTH_URI=otpauth://totp/LiDAR:TEST?secret=$secret&issuer=LiDAR&digits=6&period=30&algorithm=SHA1\n';

void main() {
  test('encoded account labels survive encrypted-storage serialization', () {
    final text = fixture().replaceFirst(
      'NAME=TEST OWNER',
      'NAME=Équipe?red&blue',
    );
    final original = LidarMasterKey.parse(utf8.encode(text)).toCode();
    final restored = Code.fromOTPAuthUrl(
      jsonDecode(original.toOTPAuthUrlFormat()),
    );
    expect(restored.account, original.account);
    expect(restored.display.lidarLocked, true);
    expect(restored.secret, original.secret);
    expect(
      () => LidarMasterKey.parse(
        utf8.encode(fixture().replaceFirst('NAME=TEST OWNER', 'NAME=%0A')),
      ),
      throwsFormatException,
    );
  });
  test(
    'only current same-seat enrolled server metadata authorizes a successor',
    () {
      final reply = <String, dynamic>{
        'seat': 'admin2',
        'caps': ['admin'],
        'expiresAt': 2000,
        'linkedCredential': {
          'protocol': 1,
          'kind': 'enrolled',
          'generation': 3,
        },
      };
      expect(LidarResetApproval.validReply(reply, 'admin2', 1, 1000), true);
      expect(LidarResetApproval.validReply(reply, 'admin1', 1, 1000), false);
      expect(LidarResetApproval.validReply(reply, 'admin2', 3, 1000), false);
      expect(LidarResetApproval.validReply(reply, 'admin2', 1, 2000), false);
      expect(
        LidarResetApproval.validReply(
          {
            ...reply,
            'linkedCredential': {
              'protocol': 1,
              'kind': 'master',
              'generation': 3,
            },
          },
          'admin2',
          1,
          1000,
        ),
        false,
      );
      expect(
        LidarResetApproval.validReply(
          {...reply, 'linkedCredential': null},
          'admin2',
          1,
          1000,
        ),
        false,
      );
      expect(
        LidarResetApproval.validReply(
          {
            ...reply,
            'caps': ['device'],
          },
          'admin2',
          1,
          1000,
        ),
        false,
      );
    },
  );
  test('four-field ENV parses privately and creates locked six-digit TOTP', () {
    final key = LidarMasterKey.parse(utf8.encode(fixture()));
    final code = key.toCode();
    expect(code.display.lidarSeat, 'admin2');
    expect(code.display.lidarLocked, true);
    expect(code.digits, 6);
    expect(code.period, 30);
    expect(key.toString(), isNot(contains(fixtureSecret)));
  });
  test('BOM and Windows line endings parse', () {
    expect(
      LidarMasterKey.parse(
        utf8.encode('\uFEFF${fixture().replaceAll('\n', '\r\n')}'),
      ).seat,
      'admin2',
    );
  });
  test('provider ENV and duplicate fields are rejected without payloads', () {
    for (final extra in [
      'CF_API_TOKEN=SYNTHETIC_PRIVATE_VALUE\n',
      'SEAT=admin3\n',
    ]) {
      try {
        LidarMasterKey.parse(utf8.encode(fixture() + extra));
        fail('must refuse');
      } on FormatException catch (error) {
        expect(error.toString(), isNot(contains('SYNTHETIC_PRIVATE_VALUE')));
        expect(error.source, isNull);
      }
    }
  });
  test('oversize, non-UTF8, missing fields and invalid seats fail closed', () {
    for (final bytes in [
      List.filled(8193, 65),
      [255],
      utf8.encode('SEAT=admin2'),
      utf8.encode(fixture(seat: 'admin6')),
    ]) {
      expect(() => LidarMasterKey.parse(bytes), throwsFormatException);
    }
  });
  test(
    'secret mismatch, duplicate URI parameters and changed OTP settings refuse',
    () {
      for (final text in [
        fixture().replaceFirst('digits=6', 'digits=8'),
        fixture().replaceFirst('period=30', 'period=60'),
        fixture().replaceFirst('algorithm=SHA1', 'algorithm=SHA256'),
        fixture().replaceFirst(
          '&issuer=LiDAR',
          '&secret=$fixtureSecret&issuer=LiDAR',
        ),
        fixture().replaceFirst('OTPAUTH_URI=otpauth', 'OTPAUTH_URI=https'),
      ]) {
        expect(
          () => LidarMasterKey.parse(utf8.encode(text)),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'metadata round trip preserves lock and seat without changing normal codes',
    () {
      final display = LidarMasterKey.parse(
        utf8.encode(fixture()),
      ).toCode().display;
      final restored = CodeDisplay.fromJson(
        display.copyWith(note: 'label').toJson(),
      );
      expect(restored.lidarLocked, true);
      expect(restored.lidarSeat, 'admin2');
      expect(CodeDisplay.fromJson({'note': 'normal'}).lidarLocked, false);
    },
  );
  test('local lock refuses secret swap, deletion, unlock and seat rewrite', () {
    final code = LidarMasterKey.parse(utf8.encode(fixture())).toCode()
      ..generatedID = 4;
    final changes = [
      code.copyWith(secret: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'),
      code.copyWith(display: code.display.copyWith(trashed: true)),
      code.copyWith(display: code.display.copyWith(lidarLocked: false)),
      code.copyWith(display: code.display.copyWith(lidarSeat: 'admin3')),
    ];
    for (final changed in changes) {
      expect(
        () => LidarCredentialPolicy.checkWrite(changed, [code]),
        throwsStateError,
      );
    }
    expect(
      () => LidarCredentialPolicy.checkWrite(
        code.copyWith(display: code.display.copyWith(position: 3)),
        [code],
      ),
      returnsNormally,
    );
  });
  test(
    'same seat replacement without ID refuses while normal OTP stays editable',
    () {
      final existing = LidarMasterKey.parse(utf8.encode(fixture())).toCode()
        ..generatedID = 4;
      final successor = LidarMasterKey.parse(
        utf8.encode(fixture(secret: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA')),
      ).toCode();
      expect(
        () => LidarCredentialPolicy.checkWrite(successor, [existing]),
        throwsStateError,
      );
      final normal = existing.copyWith(
        issuer: 'Example',
        secret: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        display: CodeDisplay(),
      );
      normal.generatedID = null;
      expect(
        () => LidarCredentialPolicy.checkWrite(normal, []),
        returnsNormally,
      );
    },
  );
  test('new managed accounts require the matching ENV capability', () {
    final key = LidarMasterKey.parse(utf8.encode(fixture()));
    final code = key.toCode();
    expect(() => LidarCredentialPolicy.checkWrite(code, []), throwsStateError);
    expect(
      () => LidarCredentialPolicy.checkWrite(code, [], importKey: key),
      returnsNormally,
    );
    for (final changed in [
      code.copyWith(account: 'Other owner'),
      code.copyWith(secret: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'),
      code.copyWith(display: code.display.copyWith(lidarSeat: 'admin3')),
      code.copyWith(display: code.display.copyWith(lidarGeneration: 1)),
    ]) {
      expect(
        () => LidarCredentialPolicy.checkWrite(changed, [], importKey: key),
        throwsStateError,
      );
    }
  });
  test('generic display JSON cannot poison a seat with a fake generation', () {
    final original = LidarMasterKey.parse(utf8.encode(fixture())).toCode();
    final poisoned = original.copyWith(
      display: CodeDisplay.fromJson({
        'lidarSeat': 'admin2',
        'lidarLocked': true,
        'lidarGeneration': 2147483646,
      }),
    );
    expect(
      () => LidarCredentialPolicy.checkWrite(poisoned, []),
      throwsStateError,
    );
  });
  test(
    'standard imports cannot reserve LiDAR labels or duplicate its secret',
    () {
      final managed = LidarMasterKey.parse(utf8.encode(fixture())).toCode();
      final standard = managed.copyWith(display: CodeDisplay());
      expect(
        () => LidarCredentialPolicy.checkStandard(standard, []),
        throwsStateError,
      );
      expect(
        () => LidarCredentialPolicy.checkStandard(
          standard.copyWith(issuer: 'Example', account: 'different label'),
          [managed],
        ),
        throwsStateError,
      );
      final unrelated = standard.copyWith(
        issuer: 'Example',
        secret: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      );
      expect(
        () => LidarCredentialPolicy.checkStandard(unrelated, [managed]),
        returnsNormally,
      );
      expect(
        () => LidarCredentialPolicy.checkWrite(
          unrelated.copyWith(account: 'edited'),
          [],
        ),
        returnsNormally,
      );
    },
  );
  test('persistent row prevents removal after caller clears lock metadata', () {
    final managed = LidarMasterKey.parse(utf8.encode(fixture())).toCode()
      ..generatedID = 4;
    expect(
      () => LidarCredentialPolicy.checkRemove(
        managed.copyWith(display: CodeDisplay()),
        managed,
      ),
      throwsStateError,
    );
    final normal = managed.copyWith(
      issuer: 'Example',
      secret: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      display: CodeDisplay(),
    );
    expect(
      () => LidarCredentialPolicy.checkRemove(normal, normal),
      returnsNormally,
    );
    expect(
      () => LidarCredentialPolicy.checkRemove(
        normal.copyWith(account: 'stale account'),
        normal,
      ),
      throwsStateError,
    );
  });
}
