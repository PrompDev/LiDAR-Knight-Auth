import 'dart:convert';

import 'package:ente_auth/services/lidar_master_key.dart';
import 'package:ente_auth/services/lidar_update_notice.dart';
import 'package:ente_auth/ui/lidar_knight/lidar_update_indicator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Auth 4.4.31: the update notice (DeAndre 2026-10-06) and the clearer import hints.
void main() {
  String feed(Map<String, Object?> m) => jsonEncode(m);
  const note = 'Fixes the key email and adds update notices. Install it over your current app; your codes stay.';

  group('LidarUpdateNotice.parse', () {
    test('a newer published version shows its message and page', () {
      final info = LidarUpdateNotice.parse(
        feed({'version': '4.4.32', 'url': 'https://lidarknight.com/auth', 'message': note, 'publishedAt': '2026-10-07T00:00:00Z'}),
        '4.4.31',
      );
      expect(info, isNotNull);
      expect(info!.version, '4.4.32');
      expect(info.message, note);
      expect(info.url, Uri.parse('https://lidarknight.com/auth'));
    });

    test('the same, an older or a malformed version shows nothing', () {
      for (final v in ['4.4.31', '4.4.30', '4.3.99', '4.4', 'v4.4.32', '4.4.32-beta', '', '99999.0.0']) {
        expect(LidarUpdateNotice.parse(feed({'version': v, 'message': note}), '4.4.31'), isNull, reason: v);
      }
      // A '+build' suffix on the running version is ignored.
      expect(LidarUpdateNotice.parse(feed({'version': '4.4.32', 'message': note}), '4.4.31+1011'), isNotNull);
      expect(LidarUpdateNotice.parse(feed({'version': '4.4.31', 'message': note}), '4.4.31+1011'), isNull);
    });

    test('numbers compare as numbers, not text', () {
      expect(LidarUpdateNotice.compareVersions('4.4.100', '4.4.31'), greaterThan(0));
      expect(LidarUpdateNotice.compareVersions('4.10.0', '4.9.9'), greaterThan(0));
      expect(LidarUpdateNotice.compareVersions('5.0.0', '4.99.99'), greaterThan(0));
      expect(LidarUpdateNotice.compareVersions('4.4.31', '4.4.31'), 0);
    });

    test('not JSON, not an object, or a missing or empty message shows nothing', () {
      for (final body in ['', 'nope', '[]', '"4.4.32"', feed({'version': '4.4.32'}), feed({'version': '4.4.32', 'message': '   '}), feed({'version': '4.4.32', 'message': 7})]) {
        expect(LidarUpdateNotice.parse(body, '4.4.31'), isNull, reason: body);
      }
    });

    test('the message becomes one plain paragraph of at most 280 characters', () {
      expect(LidarUpdateNotice.cleanMessage('Line one.\nLine two.\r\n\tThree\u202E.'), 'Line one. Line two. Three .');
      expect(LidarUpdateNotice.cleanMessage('<b>no</b> html'), '<b>no</b> html', reason: 'shown as plain text, never rendered');
      final long = 'x' * 400;
      final cut = LidarUpdateNotice.cleanMessage(long);
      expect(cut.runes.length, 280);
      expect(cut.endsWith('…'), isTrue);
      final emoji = '🛡️' * 200;
      expect(LidarUpdateNotice.cleanMessage(emoji).runes.length, lessThanOrEqualTo(280), reason: 'cut on whole characters');
    });

    test('a click only ever goes to an https page on lidarknight.com', () {
      final ok = LidarUpdateNotice.pageUrl('https://lidarknight.com/auth');
      expect(ok, Uri.parse('https://lidarknight.com/auth'));
      for (final bad in [null, 7, 'http://lidarknight.com/auth', 'https://evil.example/auth', 'https://lidarknight.com.evil.example/', 'https://admin.lidarknight.com/', 'https://u:p@lidarknight.com/', 'https://lidarknight.com:8443/', 'javascript:alert(1)', 'not a url']) {
        expect(LidarUpdateNotice.pageUrl(bad), LidarUpdateNotice.defaultPage, reason: '$bad');
      }
    });

    test('the feed is the pinned https URL', () {
      expect(LidarUpdateNotice.feed.toString(), 'https://lidarknight.com/auth/update.json');
    });
  });

  group('LidarMasterKey.importHint', () {
    List<int> b(String s) => utf8.encode(s);
    const v2 = 'LK_FORMAT=2\nISSUER=admin.lidarknight.com\nSEAT=admin2\nNAME="CT"\nEMAIL=ct@example.com\nGENERATION=4\nISSUED_AT=2026-10-05T12:00:00Z\nACTIVATE_BY=2026-10-12T12:00:00Z\nACTIVATION_ID=act_0123456789abcdefABCDEF\nTOTP_SECRET=ABCDEFGHIJKLMNOPQRSTUVWXYZ234567\nOTPAUTH_URI=otpauth://totp/LiDAR-Knight:CT?secret=ABCDEFGHIJKLMNOPQRSTUVWXYZ234567&issuer=LiDAR-Knight&algorithm=SHA1&digits=6&period=30\n';

    test('a key file that arrived encoded (one base64 line) says so, and shows nothing of it', () {
      final encoded = base64.encode(utf8.encode(v2));
      final hint = LidarMasterKey.importHint(b(encoded));
      expect(hint, contains('encoded, not a key file'));
      expect(hint!.contains(encoded.substring(0, 12)), isFalse);
      expect(() => LidarMasterKey.parse(b(encoded)), throwsFormatException, reason: 'the parser still refuses it');
    });

    test('a newer format or an unknown field asks for a newer app', () {
      expect(LidarMasterKey.importHint(b(v2.replaceFirst('LK_FORMAT=2', 'LK_FORMAT=3'))), contains('newer LiDAR Knight Auth'));
      expect(LidarMasterKey.importHint(b('${v2}FUTURE_FIELD=1\n')), contains('newer LiDAR Knight Auth'));
    });

    test('ordinary files get no hint (the parser keeps its own words)', () {
      expect(LidarMasterKey.importHint(b(v2)), isNull);
      expect(LidarMasterKey.importHint(b('SEAT=admin1\nNAME=X\nTOTP_SECRET=ABCDEFGHIJKLMNOPQRSTUVWXYZ234567\nOTPAUTH_URI=otpauth://totp/x?secret=ABCDEFGHIJKLMNOPQRSTUVWXYZ234567\n')), isNull);
      expect(LidarMasterKey.importHint(b('DATABASE_URL=postgres://x\n')), isNull);
      expect(LidarMasterKey.importHint([0xff, 0xfe, 0x00]), isNull);
    });
  });

  group('LidarUpdateIndicator', () {
    tearDown(() => LidarUpdateNotice.instance.available.value = null);

    testWidgets('nothing when up to date; an arrow with only the message when an update exists', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: LidarUpdateIndicator()))));
      expect(find.byKey(const ValueKey('lidar-update-button')), findsNothing);
      LidarUpdateNotice.instance.available.value = LidarUpdateInfo('4.4.32', note, LidarUpdateNotice.defaultPage);
      await tester.pump();
      expect(find.byKey(const ValueKey('lidar-update-button')), findsOneWidget);
      final tip = tester.widget<Tooltip>(find.byKey(const ValueKey('lidar-update-tooltip')));
      expect(tip.message, isNull, reason: 'a rich message only: the note itself');
      // Hover shows exactly the note, no title or version line.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('lidar-update-button'))));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('lidar-update-message')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('lidar-update-message'))).data, note);
      expect(find.textContaining('4.4.32'), findsNothing);
      await gesture.removePointer();
      LidarUpdateNotice.instance.available.value = null;
      await tester.pump(const Duration(seconds: 9));
      expect(find.byKey(const ValueKey('lidar-update-button')), findsNothing);
    });
  });
}
