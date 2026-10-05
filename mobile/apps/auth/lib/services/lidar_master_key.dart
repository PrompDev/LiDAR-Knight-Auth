import 'dart:convert';
import 'dart:io';

import 'package:ente_auth/models/code.dart';
import 'package:ente_auth/models/code_display.dart';
import 'package:ente_auth/utils/totp_util.dart';

/// Parses data only. Never evaluates dotenv, shell interpolation or URLs.
/// Errors intentionally contain no file contents, paths or credential values.
class LidarMasterKey {
  static const maxBytes = 8192;
  final String seat;
  final String name;
  final String _secret;

  const LidarMasterKey._(this.seat, this.name, this._secret);

  static LidarMasterKey parse(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException(
        'Choose one individual LiDAR owner ENV file.',
      );
    }
    String text;
    try {
      text = utf8.decode(bytes).replaceFirst(RegExp(r'^\uFEFF'), '');
    } catch (_) {
      throw const FormatException('The owner file must be UTF-8 text.');
    }
    final fields = <String, String>{};
    const allowed = {'SEAT', 'NAME', 'TOTP_SECRET', 'OTPAUTH_URI'};
    for (final rawLine in const LineSplitter().convert(text)) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final equals = line.indexOf('=');
      if (equals < 1) throw const FormatException('Invalid owner file format.');
      final key = line.substring(0, equals).trim();
      var value = line.substring(equals + 1).trim();
      if (!allowed.contains(key) || fields.containsKey(key)) {
        throw const FormatException(
          'Choose an individual owner file, not a provider ENV.',
        );
      }
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      if (value.contains(r'$') ||
          value.contains('`') ||
          value.contains('\u0000')) {
        throw const FormatException('Invalid owner file format.');
      }
      fields[key] = value;
    }
    if (fields.length != allowed.length || !allowed.every(fields.containsKey)) {
      throw const FormatException('The individual owner file is incomplete.');
    }
    final seat = fields['SEAT']!;
    final name = fields['NAME']!.trim();
    final secret = fields['TOTP_SECRET']!.toUpperCase();
    if (!RegExp(r'^admin[1-5]$').hasMatch(seat) ||
        name.isEmpty ||
        name.length > 80 ||
        name.contains('%') ||
        name.runes.any((r) => r < 32 || r == 127) ||
        !RegExp(r'^[A-Z2-7]{32}$').hasMatch(secret)) {
      throw const FormatException('Invalid LiDAR owner credential.');
    }
    Uri uri;
    try {
      uri = Uri.parse(fields['OTPAUTH_URI']!);
      if (uri.scheme != 'otpauth' ||
          uri.host != 'totp' ||
          uri.fragment.isNotEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.queryParametersAll.values.any((v) => v.length != 1) ||
          uri.queryParameters['secret']?.toUpperCase() != secret ||
          (uri.queryParameters['digits'] ?? '6') != '6' ||
          (uri.queryParameters['period'] ?? '30') != '30' ||
          (uri.queryParameters['algorithm'] ?? 'SHA1').toUpperCase() !=
              'SHA1') {
        throw const FormatException('Invalid LiDAR owner credential.');
      }
    } catch (_) {
      throw const FormatException('Invalid LiDAR owner credential.');
    }
    return LidarMasterKey._(seat, name, secret);
  }

  Code toCode() => Code.fromOTPAuthUrl(
    Uri(
      scheme: 'otpauth',
      host: 'totp',
      path: '/LiDAR-Knight:$name',
      queryParameters: {
        'secret': _secret,
        'issuer': 'LiDAR-Knight',
        'algorithm': 'SHA1',
        'digits': '6',
        'period': '30',
      },
    ).toString(),
    display: CodeDisplay(lidarSeat: seat, lidarLocked: true, pinned: true),
  );

  // The only initial-creation capability comes from the bounded ENV parser.
  // JSON display flags and a caller-provided generation are not authority.
  bool _allowsInitial(Code candidate) =>
      candidate.generatedID == null &&
      candidate.display.lidarLocked &&
      candidate.display.lidarSeat == seat &&
      candidate.display.lidarGeneration == 0 &&
      candidate.secret == _secret &&
      candidate.account == name &&
      candidate.issuer == 'LiDAR-Knight' &&
      candidate.type == Type.totp &&
      candidate.algorithm == Algorithm.sha1 &&
      candidate.digits == 6 &&
      candidate.period == 30 &&
      candidate.counter == 0 &&
      !candidate.isTrashed;

  @override
  String toString() => 'LidarMasterKey([private])';
}

class LidarCredentialPolicy {
  static bool managed(Code code) => code.display.lidarLocked;

  static String _secretIdentity(String secret) =>
      secret.replaceAll(RegExp(r'[\s=]'), '').toUpperCase();

  /// Standard imports cannot move a known admin secret into export/sync flows.
  /// The inventory must come from persistent offline storage, not UI hints.
  static void checkStandard(Code candidate, Iterable<Code> offlineInventory) {
    if (managed(candidate)) return;
    final issuer = candidate.issuer.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    final knownSecret = offlineInventory.any(
      (existing) =>
          !existing.hasError &&
          managed(existing) &&
          _secretIdentity(existing.secret) == _secretIdentity(candidate.secret),
    );
    if (issuer.startsWith('lidarknight') ||
        candidate.display.lidarSeat.isNotEmpty ||
        candidate.display.lidarGeneration != 0 ||
        knownSecret) {
      throw StateError('Import LiDAR credentials through the admin tab.');
    }
  }

  static void checkRemove(Code candidate, Code? persistent) {
    if (managed(candidate) || (persistent != null && managed(persistent))) {
      throw StateError(
        'Another admin must reset this LiDAR account in the game terminal.',
      );
    }
    if (persistent != null &&
        (candidate.generatedID != persistent.generatedID ||
            candidate.secret != persistent.secret ||
            candidate.account != persistent.account ||
            candidate.issuer != persistent.issuer ||
            candidate.type != persistent.type)) {
      throw StateError(
        'The saved account changed. Refresh before removing it.',
      );
    }
  }

  static void checkWrite(
    Code candidate,
    Iterable<Code> stored, {
    LidarResetApproval? approval,
    LidarMasterKey? importKey,
  }) {
    final persistentCodes = stored.toList(growable: false);
    checkStandard(candidate, persistentCodes);
    final existingManagedID = persistentCodes.any(
      (existing) =>
          managed(existing) &&
          candidate.generatedID != null &&
          candidate.generatedID == existing.generatedID,
    );
    if (managed(candidate) && !existingManagedID) {
      final seatAlreadyLinked = persistentCodes.any(
        (existing) =>
            managed(existing) &&
            existing.display.lidarSeat == candidate.display.lidarSeat,
      );
      if (seatAlreadyLinked ||
          !(importKey?._allowsInitial(candidate) ?? false)) {
        throw StateError('Import LiDAR credentials through the admin tab.');
      }
    }
    for (final existing in persistentCodes) {
      if (!managed(existing)) continue;
      final sameID =
          candidate.generatedID != null &&
          candidate.generatedID == existing.generatedID;
      final sameSeat =
          candidate.display.lidarSeat == existing.display.lidarSeat;
      if (!sameID && !sameSeat) continue;
      final replacementAuthorized =
          approval?._allows(existing, candidate) ?? false;
      if (!managed(candidate) ||
          candidate.display.lidarSeat != existing.display.lidarSeat ||
          (!replacementAuthorized &&
              (candidate.secret != existing.secret ||
                  candidate.account != existing.account ||
                  candidate.issuer != existing.issuer ||
                  candidate.display.lidarGeneration !=
                      existing.display.lidarGeneration)) ||
          candidate.type != existing.type ||
          candidate.algorithm != existing.algorithm ||
          candidate.digits != existing.digits ||
          candidate.period != existing.period ||
          candidate.counter != existing.counter ||
          candidate.isTrashed) {
        throw StateError(
          'Another admin must reset this LiDAR account in the game terminal.',
        );
      }
    }
    if (managed(candidate) &&
        (!RegExp(r'^admin[1-5]$').hasMatch(candidate.display.lidarSeat) ||
            candidate.type != Type.totp ||
            candidate.algorithm != Algorithm.sha1 ||
            candidate.digits != 6 ||
            candidate.period != 30 ||
            candidate.isTrashed)) {
      throw StateError('Invalid locked LiDAR account.');
    }
  }
}

/// Only a fresh HTTPS sign-in to the current enrolled credential can authorize
/// replacing a locked key. A file, local flag or pasted JSON cannot mint this.
class LidarResetApproval {
  final String _seat;
  final String _secret;
  final int generation;
  final int _approvedAt;
  LidarResetApproval._(
    this._seat,
    this._secret,
    this.generation,
    this._approvedAt,
  );

  bool _allows(Code old, Code next) =>
      DateTime.now().millisecondsSinceEpoch - _approvedAt >= 0 &&
      DateTime.now().millisecondsSinceEpoch - _approvedAt < 60000 &&
      _seat == old.display.lidarSeat &&
      _seat == next.display.lidarSeat &&
      _secret == next.secret &&
      next.secret != old.secret &&
      generation > old.display.lidarGeneration &&
      generation == next.display.lidarGeneration;

  static bool validReply(
    Map<String, dynamic> data,
    String seat,
    int previousGeneration,
    int now,
  ) {
    final linked = data['linkedCredential'];
    return data['seat'] == seat &&
        data['caps'] is List &&
        (data['caps'] as List).contains('admin') &&
        data['expiresAt'] is num &&
        (data['expiresAt'] as num) > now &&
        linked is Map &&
        linked['protocol'] == 1 &&
        linked['kind'] == 'enrolled' &&
        linked['generation'] is int &&
        linked['generation'] > previousGeneration &&
        linked['generation'] < 2147483647;
  }

  static Future<LidarResetApproval> verify(
    Code candidate,
    Code previous,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    final cookies = <Cookie>[];
    try {
      final request = await client
          .postUrl(Uri.parse('https://admin.lidarknight.com/api/owner/signin'))
          .timeout(const Duration(seconds: 8));
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.headers.set('Origin', 'https://admin.lidarknight.com');
      request.headers.set('X-LK-Request', '1');
      request.write(jsonEncode({'code': getOTP(candidate)}));
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      cookies.addAll(response.cookies);
      final bytes = await response
          .fold<List<int>>(<int>[], (buffer, chunk) {
            if (buffer.length + chunk.length > 4096) {
              throw StateError('Replacement not authorized.');
            }
            buffer.addAll(chunk);
            return buffer;
          })
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw StateError('Replacement not authorized.');
      }
      final data = jsonDecode(utf8.decode(bytes));
      final now = DateTime.now().millisecondsSinceEpoch;
      if (data is! Map<String, dynamic> ||
          !validReply(
            data,
            previous.display.lidarSeat,
            previous.display.lidarGeneration,
            now,
          )) {
        throw StateError('Replacement not authorized.');
      }
      return LidarResetApproval._(
        candidate.display.lidarSeat,
        candidate.secret,
        data['linkedCredential']['generation'],
        now,
      );
    } catch (_) {
      throw StateError('Replacement not authorized.');
    } finally {
      // This proof's short-lived cookie session is never persisted or reused.
      // Sign out only that session; no unrelated browser/app sessions touched.
      if (cookies.isNotEmpty) {
        try {
          final request = await client
              .postUrl(
                Uri.parse('https://admin.lidarknight.com/api/owner/signout'),
              )
              .timeout(const Duration(seconds: 5));
          request.followRedirects = false;
          request.headers.set('Origin', 'https://admin.lidarknight.com');
          request.headers.set('X-LK-Request', '1');
          request.cookies.addAll(cookies);
          request.headers.contentType = ContentType.json;
          request.write('{}');
          final response = await request.close().timeout(
            const Duration(seconds: 5),
          );
          await response.drain<void>().timeout(const Duration(seconds: 5));
        } catch (_) {
          /* Session expiry is server-enforced; no secret diagnostics. */
        }
      }
      cookies.clear();
      client.close(force: true);
    }
  }
}
