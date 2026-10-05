import 'dart:convert';
import 'dart:io';

import 'package:ente_auth/models/code.dart';
import 'package:ente_auth/services/lidar_master_key.dart';
import 'package:flutter_test/flutter_test.dart';

// SYNTHETIC LOCAL TEST ONLY: the contract's example key, never an owner's.
// No network: every HTTPS answer comes from a scripted fake poster.
const secret = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
const activationId = 'act_0123456789abcdefABCDEF';
const exampleFile =
    'LK_FORMAT=2\nISSUER=admin.lidarknight.com\nSEAT=admin2\nNAME="CT"\n'
    'EMAIL=ct@example.com\nGENERATION=4\nISSUED_AT=2026-10-05T12:00:00Z\n'
    'ACTIVATE_BY=2026-10-12T12:00:00Z\nACTIVATION_ID=$activationId\n'
    'TOTP_SECRET=$secret\nOTPAUTH_URI=otpauth://totp/LiDAR-Knight:CT?secret=$secret'
    '&issuer=LiDAR-Knight&algorithm=SHA1&digits=6&period=30\n';

Code pendingCard() =>
    LidarMasterKey.parse(utf8.encode(exampleFile)).toCode()..generatedID = 3;

Code withDisplay(Code card, {String? state, String? issuer}) => Code(
  card.account,
  card.issuer,
  card.digits,
  card.period,
  card.secret,
  card.algorithm,
  card.type,
  card.counter,
  card.rawData,
  generatedID: card.generatedID,
  display: card.display.copyWith(lidarState: state, lidarIssuer: issuer),
);

class FakePoster {
  final List<Object> script;
  final calls = <(Uri, Map<String, Object>)>[];
  FakePoster(this.script);

  Future<LidarHttpReply> call(Uri url, Map<String, Object> body) async {
    calls.add((url, Map.of(body)));
    final next = script.removeAt(0);
    if (next is LidarHttpReply) return next;
    throw next;
  }

  LidarActivation get service =>
      LidarActivation(poster: call, codeFor: (_) => '654321');
}

const activeReply = LidarHttpReply(200, {
  'state': 'active',
  'seat': 'admin2',
  'name': 'CT',
  'linkedCredential': {'protocol': 1, 'kind': 'enrolled', 'generation': 4},
});

LidarHttpReply refusal(
  int status,
  String reason, [
  Map<String, Object>? more,
]) => LidarHttpReply(status, {'state': 'refused', 'reason': reason, ...?more});

void main() {
  test(
    'success: the exact contract body to the pinned host, then ACTIVE',
    () async {
      final fake = FakePoster([activeReply]);
      final outcome = await fake.service.activate(pendingCard());
      expect(fake.calls.length, 1);
      final (url, body) = fake.calls.single;
      expect(
        url.toString(),
        'https://admin.lidarknight.com/api/owner/activate',
      );
      expect(body, {
        'format': 2,
        'issuer': 'admin.lidarknight.com',
        'seat': 'admin2',
        'email': 'ct@example.com',
        'generation': 4,
        'activationId': activationId,
        'code': '654321',
      });
      expect(
        [outcome.state, outcome.reason, outcome.isActive],
        ['active', '', true],
      );
      expect(outcome.proof.toString(), isNot(contains(secret)));
      final next = LidarActivation.withOutcome(pendingCard(), outcome);
      expect(next.display.lidarState, 'active');
      expect(next.rawData, pendingCard().rawData, reason: 'stored data kept');
      expect(
        () => LidarCredentialPolicy.checkWrite(next, [
          pendingCard(),
        ], activation: outcome.proof),
        returnsNormally,
      );
    },
  );

  test(
    'a 200 that does not match the card exactly is refused as tampered',
    () async {
      for (final body in <Map<String, Object>>[
        {...activeReply.json as Map<String, Object>, 'seat': 'admin3'},
        {
          ...activeReply.json as Map<String, Object>,
          'linkedCredential': {
            'protocol': 1,
            'kind': 'enrolled',
            'generation': 5,
          },
        },
        {
          ...activeReply.json as Map<String, Object>,
          'linkedCredential': {
            'protocol': 1,
            'kind': 'master',
            'generation': 4,
          },
        },
        {
          ...activeReply.json as Map<String, Object>,
          'linkedCredential': {
            'protocol': 2,
            'kind': 'enrolled',
            'generation': 4,
          },
        },
        {...activeReply.json as Map<String, Object>, 'state': 'pending'},
        {'state': 'active', 'seat': 'admin2'},
      ]) {
        final outcome = await FakePoster([
          LidarHttpReply(200, body),
        ]).service.activate(pendingCard());
        expect(
          [outcome.state, outcome.reason, outcome.isActive],
          ['refused', 'tampered', false],
          reason: jsonEncode(body),
        );
      }
      final notJson = await FakePoster([
        const LidarHttpReply(200, null),
      ]).service.activate(pendingCard());
      expect([notJson.state, notJson.reason], ['refused', 'tampered']);
    },
  );

  test(
    'every refusal with its contract HTTP status maps to the card state',
    () async {
      final cases = <(LidarHttpReply, String, String, int?, int?)>[
        (refusal(403, 'tampered'), 'refused', 'tampered', null, null),
        (
          refusal(403, 'wrong-recipient'),
          'refused',
          'wrong-recipient',
          null,
          null,
        ),
        (
          refusal(401, 'bad-code', {'attemptsLeft': 3}),
          'refused',
          'bad-code',
          3,
          null,
        ),
        (refusal(400, 'bad-code'), 'refused', 'bad-code', null, null),
        (refusal(404, 'unknown'), 'refused', 'unknown', null, null),
        (refusal(410, 'expired'), 'expired', '', null, null),
        (refusal(410, 'revoked'), 'revoked', '', null, null),
        (refusal(410, 'old-generation'), 'reissued', '', null, null),
        (
          refusal(423, 'locked', {'attemptsLeft': 0}),
          'failed',
          'locked',
          0,
          null,
        ),
        (
          refusal(429, 'locked', {'retryAfter': 10}),
          'refused',
          'locked',
          null,
          10,
        ),
      ];
      for (final (reply, state, reason, left, retry) in cases) {
        final outcome = await FakePoster([
          reply,
        ]).service.activate(pendingCard());
        final what = jsonEncode(reply.json);
        expect(outcome.state, state, reason: what);
        expect(outcome.reason, reason, reason: what);
        expect(outcome.attemptsLeft, left, reason: what);
        expect(outcome.retryAfter, retry, reason: what);
        expect(outcome.proof, isNotNull, reason: what);
        expect(outcome.isActive, false, reason: what);
        // The answer may be recorded on that card, and only as that answer.
        expect(
          () => LidarCredentialPolicy.checkWrite(
            LidarActivation.withOutcome(pendingCard(), outcome),
            [pendingCard()],
            activation: outcome.proof,
          ),
          returnsNormally,
          reason: what,
        );
      }
    },
  );

  test('answers outside the contract change nothing', () async {
    for (final reply in [
      refusal(401, 'tampered'),
      refusal(410, 'bad-code'),
      refusal(403, 'nonsense'),
      refusal(409, 'expired'),
      const LidarHttpReply(503, {'error': 'owner keys are not configured'}),
      const LidarHttpReply(400, {'error': 'bad json'}),
      const LidarHttpReply(301, null),
      const LidarHttpReply(500, null),
      const LidarHttpReply(401, {'reason': 'bad-code'}),
    ]) {
      final outcome = await FakePoster([reply]).service.activate(pendingCard());
      expect(outcome.proof, isNull, reason: jsonEncode(reply.json));
      expect(outcome.problem, 'unexpected', reason: jsonEncode(reply.json));
    }
    final down = await FakePoster([
      const SocketException('synthetic offline'),
    ]).service.activate(pendingCard());
    expect([down.problem, down.state, down.proof], ['unreachable', '', null]);
  });

  test(
    'lost answer: replayed or already-active, then status settles it',
    () async {
      Future<LidarActivationOutcome> run(String reason, Object status) async {
        final fake = FakePoster([refusal(409, reason), status]);
        final outcome = await fake.service.activate(pendingCard());
        if (fake.calls.length == 2) {
          final (url, body) = fake.calls[1];
          expect(
            url.toString(),
            'https://admin.lidarknight.com/api/owner/activation/status',
          );
          expect(body, {'activationId': activationId});
        }
        return outcome;
      }

      LidarHttpReply status(
        String state, {
        String seat = 'admin2',
        int gen = 4,
      }) => LidarHttpReply(200, {
        'state': state,
        'seat': seat,
        'generation': gen,
        'activateBy': '2026-10-12T12:00:00Z',
      });

      for (final reason in ['replayed', 'already-active']) {
        final ok = await run(reason, status('active'));
        expect([ok.state, ok.isActive], ['active', true], reason: reason);
        // Never active without the status at the file's own generation.
        for (final other in [
          status('active', gen: 5),
          status('active', seat: 'admin3'),
          status('pending'),
          const LidarHttpReply(404, {'state': 'refused', 'reason': 'unknown'}),
          const LidarHttpReply(429, {
            'state': 'refused',
            'reason': 'locked',
            'retryAfter': 10,
          }),
          const SocketException('synthetic offline'),
        ]) {
          final outcome = await run(reason, other);
          expect(
            [outcome.state, outcome.reason, outcome.isActive],
            ['refused', reason, false],
            reason: '$reason / $other',
          );
        }
        expect((await run(reason, status('revoked'))).state, 'revoked');
        expect((await run(reason, status('reissued'))).state, 'reissued');
        expect((await run(reason, status('expired'))).state, 'expired');
        final failed = await run(reason, status('failed'));
        expect([failed.state, failed.reason], ['failed', 'locked']);
      }
    },
  );

  test(
    'host pinning: another ISSUER is refused locally, nothing is sent',
    () async {
      final fake = FakePoster([activeReply]);
      for (final issuer in [
        'admin.evil.test',
        'ADMIN.lidarknight.com',
        '127.0.0.1:8797',
        'admin.lidarknight.com:443',
        '',
      ]) {
        final outcome = await fake.service.activate(
          withDisplay(pendingCard(), issuer: issuer),
        );
        expect(
          [outcome.state, outcome.reason, outcome.problem],
          ['refused', 'tampered', 'local'],
        );
        expect(outcome.proof, isNull);
      }
      expect(fake.calls, isEmpty);
      expect(LidarActivation.pinned(LidarActivation.activateUrl), true);
      expect(LidarActivation.pinned(LidarActivation.statusUrl), true);
      for (final url in [
        'http://admin.lidarknight.com/api/owner/activate',
        'https://admin.lidarknight.com:8443/api/owner/activate',
        'https://evil.test/api/owner/activate',
        'https://admin.lidarknight.com.evil.test/api/owner/activate',
        'https://u:p@admin.lidarknight.com/api/owner/activate',
        'https://admin.lidarknight.com/api/owner/activate?x=1',
        'https://admin.lidarknight.com/api/owner/activate#x',
        'https://admin.lidarknight.com/api/owner/signin',
      ]) {
        expect(LidarActivation.pinned(Uri.parse(url)), false, reason: url);
      }
      // The real HTTPS poster refuses any other URL before opening a socket.
      expect(
        () => LidarActivation.httpsPost(
          Uri.parse('http://127.0.0.1:8797/api/owner/activate'),
          {},
        ),
        throwsStateError,
      );
    },
  );

  test('only pending or refused format-2 cards are sent', () async {
    final fake = FakePoster([]);
    for (final state in [
      'active',
      'expired',
      'failed',
      'reissued',
      'revoked',
    ]) {
      final outcome = await fake.service.activate(
        withDisplay(pendingCard(), state: state),
      );
      expect([outcome.problem, outcome.proof], ['not-pending', null]);
    }
    const v1 =
        'SEAT=admin2\nNAME=LOCAL TEST\nTOTP_SECRET=$secret\nOTPAUTH_URI=otpauth://totp/TEST?secret=$secret\n';
    final master = LidarMasterKey.parse(utf8.encode(v1)).toCode();
    expect((await fake.service.activate(master)).problem, 'no-key');
    expect(fake.calls, isEmpty);
    final refused = FakePoster([activeReply]);
    final again = await refused.service.activate(
      withDisplay(pendingCard(), state: 'refused'),
    );
    expect(again.isActive, true, reason: 'a refused card may activate again');
  });
}
