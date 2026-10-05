import 'dart:convert';
import 'dart:io';

import 'package:ente_auth/models/code.dart';
import 'package:ente_auth/models/code_display.dart';
import 'package:ente_auth/utils/totp_util.dart';
import 'package:flutter/foundation.dart';

part 'lidar_activation.dart';

/// The emailed admin key contract (EMAIL-KEY-CONTRACT-v2.md v2.3; the server's
/// public/shared/owner/protocol.js and key-file.js are the reference).
class LidarKeyContract {
  /// The only issuer this app accepts and the only host it activates with.
  static const issuer = 'admin.lidarknight.com';
  static const fields = [
    'LK_FORMAT',
    'ISSUER',
    'SEAT',
    'NAME',
    'EMAIL',
    'GENERATION',
    'ISSUED_AT',
    'ACTIVATE_BY',
    'ACTIVATION_ID',
    'TOTP_SECRET',
    'OTPAUTH_URI',
  ];
  static const states = [
    'pending',
    'active',
    'refused',
    'expired',
    'failed',
    'reissued',
    'revoked',
  ];
  static const reasons = [
    'tampered',
    'wrong-recipient',
    'expired',
    'replayed',
    'revoked',
    'old-generation',
    'already-active',
    'bad-code',
    'locked',
    'unknown',
  ];

  /// A card in one of these states may be replaced by a newer key for the
  /// same seat and email once that key activates (contract 5 and v2.3).
  static const recoverable = {
    'pending',
    'refused',
    'expired',
    'failed',
    'reissued',
    'revoked',
  };
  static const issueMs = 7 * 24 * 3600 * 1000;
  static const maxSafeInteger = 9007199254740991;
  static final seatRe = RegExp(r'^admin[1-5]$');
  static final activationIdRe = RegExp(r'^act_[A-Za-z0-9_-]{22}$');
  static final _emailRe = RegExp(
    r'^[^\s@<>()",;:\\[\]$`\u0000-\u001f\u007f-\u009f]{1,64}@[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$',
  );

  /// The server's validEmail.
  static bool validEmail(String email) =>
      email.length <= 254 && _emailRe.hasMatch(email);
}

/// Parses data only. Never evaluates dotenv, shell interpolation or URLs.
/// Errors intentionally contain no file contents, paths or credential values.
class LidarMasterKey {
  static const maxBytes = 8192;

  /// 1: the four-field master file (read exactly as Auth 4.4.29 read it).
  /// 2: the emailed admin key (contract section 1).
  final int format;
  final String seat;
  final String name;
  final String _secret;
  // Format 2 only ('' and 0 for format 1).
  final String issuer;
  final String email;
  final int generation;
  final String issuedAt;
  final String activateBy;
  final String _activationId;

  const LidarMasterKey._(this.seat, this.name, this._secret)
    : format = 1,
      issuer = '',
      email = '',
      generation = 0,
      issuedAt = '',
      activateBy = '',
      _activationId = '';

  const LidarMasterKey._v2({
    required this.seat,
    required this.name,
    required String secret,
    required this.issuer,
    required this.email,
    required this.generation,
    required this.issuedAt,
    required this.activateBy,
    required String activationId,
  }) : format = 2,
       _secret = secret,
       _activationId = activationId;

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
    // A file whose first key is LK_FORMAT is format 2; every other file is
    // read by the unchanged Auth 4.4.29 rules (server key-file.js parity).
    if (_firstKey(text) == 'LK_FORMAT') return _parseV2(text);
    return _parseV1(text);
  }

  static String? _firstKey(String text) {
    for (final rawLine in const LineSplitter().convert(text)) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final equals = line.indexOf('=');
      return equals < 1 ? null : line.substring(0, equals).trim();
    }
    return null;
  }

  // Auth 4.4.29's parser, unchanged.
  static LidarMasterKey _parseV1(String text) {
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

  static const _credential = FormatException('Invalid LiDAR owner credential.');
  static final _hostRe = RegExp(
    r'^[a-z0-9](?:[a-z0-9.-]{0,251}[a-z0-9])?(?::\d{1,5})?$',
  );
  static final _generationRe = RegExp(r'^[1-9]\d{0,15}$');
  static final _secretRe = RegExp(r'^[A-Z2-7]{32}$');
  static final _isoRe = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z$',
  );

  /// 'YYYY-MM-DDTHH:MM:SSZ' naming a real UTC second, or null.
  static DateTime? isoSecond(String value) {
    final m = _isoRe.firstMatch(value);
    if (m == null) return null;
    final p = [for (var i = 1; i <= 6; i++) int.parse(m.group(i)!)];
    final t = DateTime.utc(p[0], p[1], p[2], p[3], p[4], p[5]);
    return t.year == p[0] &&
            t.month == p[1] &&
            t.day == p[2] &&
            t.hour == p[3] &&
            t.minute == p[4] &&
            t.second == p[5]
        ? t
        : null;
  }

  static bool _nameOk(String name) =>
      name.isNotEmpty &&
      name.length <= 80 &&
      !name.contains('%') &&
      !name.runes.any((r) => r < 32 || r == 127);

  // Format 2: KEY=VALUE lines in exactly the contract order, nothing else.
  // Every line is judged in file order, so the first bad line decides.
  static LidarMasterKey _parseV2(String text) {
    const order = LidarKeyContract.fields;
    final fields = <String, String>{};
    var next = 0;
    for (final rawLine in const LineSplitter().convert(text)) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final equals = line.indexOf('=');
      if (equals < 1) throw const FormatException('Invalid owner file format.');
      final key = line.substring(0, equals).trim();
      var value = line.substring(equals + 1).trim();
      if (!order.contains(key) || fields.containsKey(key)) {
        throw const FormatException(
          'Choose an individual owner file, not a provider ENV.',
        );
      }
      if (next >= order.length || order[next++] != key) {
        throw const FormatException('Invalid owner file format.');
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
    if (fields.length != order.length) {
      throw const FormatException('The individual owner file is incomplete.');
    }
    if (fields['LK_FORMAT'] != '2') {
      throw const FormatException('Invalid owner file format.');
    }
    final issuer = fields['ISSUER']!;
    if (!_hostRe.hasMatch(issuer)) throw _credential;
    if (issuer != LidarKeyContract.issuer) {
      throw const FormatException('This admin key belongs to another server.');
    }
    final seat = fields['SEAT']!;
    final name = fields['NAME']!.trim();
    final email = fields['EMAIL']!;
    final generationText = fields['GENERATION']!;
    final generation = _generationRe.hasMatch(generationText)
        ? int.tryParse(generationText)
        : null;
    final issuedAt = isoSecond(fields['ISSUED_AT']!);
    final activateBy = isoSecond(fields['ACTIVATE_BY']!);
    final activationId = fields['ACTIVATION_ID']!;
    final secret = fields['TOTP_SECRET']!;
    if (!LidarKeyContract.seatRe.hasMatch(seat) ||
        !_nameOk(name) ||
        email != email.toLowerCase() ||
        !LidarKeyContract.validEmail(email) ||
        generation == null ||
        generation > LidarKeyContract.maxSafeInteger ||
        issuedAt == null ||
        activateBy == null ||
        activateBy.difference(issuedAt).inMilliseconds !=
            LidarKeyContract.issueMs ||
        !LidarKeyContract.activationIdRe.hasMatch(activationId) ||
        !_secretRe.hasMatch(secret)) {
      throw _credential;
    }
    if (!_uriV2Ok(fields['OTPAUTH_URI']!, secret, name)) throw _credential;
    return LidarMasterKey._v2(
      seat: seat,
      name: name,
      secret: secret,
      issuer: issuer,
      email: email,
      generation: generation,
      issuedAt: fields['ISSUED_AT']!,
      activateBy: fields['ACTIVATE_BY']!,
      activationId: activationId,
    );
  }

  // As format 1, plus: the exact secret, issuer LiDAR-Knight when present and
  // the decoded label exactly 'LiDAR-Knight:' + NAME.
  static bool _uriV2Ok(String text, String secret, String name) {
    try {
      final uri = Uri.parse(text);
      final query = uri.queryParameters;
      if (uri.scheme != 'otpauth' ||
          uri.host != 'totp' ||
          uri.fragment.isNotEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.queryParametersAll.values.any((v) => v.length != 1) ||
          query['secret'] != secret ||
          (query['digits'] ?? '6') != '6' ||
          (query['period'] ?? '30') != '30' ||
          (query['algorithm'] ?? 'SHA1').toUpperCase() != 'SHA1') {
        return false;
      }
      if (query.containsKey('issuer') && query['issuer'] != 'LiDAR-Knight') {
        return false;
      }
      final path = uri.path.isEmpty ? '' : uri.path.substring(1);
      return Uri.decodeComponent(path) == 'LiDAR-Knight:$name';
    } catch (_) {
      return false;
    }
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
    display: format == 2
        // A format-2 import is a locked PENDING card: it shows codes (needed
        // to activate) but is never reported as a server sign-in.
        ? CodeDisplay(
            lidarSeat: seat,
            lidarLocked: true,
            pinned: true,
            lidarGeneration: generation,
            lidarFormat: 2,
            lidarIssuer: issuer,
            lidarEmail: email,
            lidarActivationId: _activationId,
            lidarState: 'pending',
            lidarActivateBy: activateBy,
          )
        : CodeDisplay(lidarSeat: seat, lidarLocked: true, pinned: true),
  );

  // The only initial-creation capability comes from the bounded ENV parser.
  // JSON display flags and a caller-provided generation are not authority.
  bool _allowsInitial(Code candidate) =>
      candidate.generatedID == null &&
      candidate.display.lidarLocked &&
      candidate.display.lidarSeat == seat &&
      (format == 2 ? _matchesV2(candidate.display) : _matchesV1(candidate)) &&
      candidate.secret == _secret &&
      candidate.account == name &&
      candidate.issuer == 'LiDAR-Knight' &&
      candidate.type == Type.totp &&
      candidate.algorithm == Algorithm.sha1 &&
      candidate.digits == 6 &&
      candidate.period == 30 &&
      candidate.counter == 0 &&
      !candidate.isTrashed;

  bool _matchesV1(Code candidate) =>
      candidate.display.lidarGeneration == 0 &&
      LidarCredentialPolicy._plainV1(candidate.display);

  bool _matchesV2(CodeDisplay display) =>
      display.lidarFormat == 2 &&
      display.lidarGeneration == generation &&
      display.lidarIssuer == issuer &&
      display.lidarEmail == email &&
      display.lidarActivationId == _activationId &&
      display.lidarActivateBy == activateBy &&
      display.lidarState == 'pending' &&
      display.lidarReason.isEmpty;

  @override
  String toString() => 'LidarMasterKey([private])';
}

/// What importing a format-2 file means for the seat's existing card.
enum LidarImportPlan {
  /// No card for the seat yet: save the new key as a PENDING card.
  create,

  /// The same key is already on this device.
  alreadyLinked,

  /// A transient PENDING SETUP: the new key replaces the card only after it
  /// activates (200 active at its own generation). Until then nothing changes.
  activateFirst,

  /// A pending, refused, expired, failed, reissued or revoked card is replaced
  /// only by a key for the same seat and email with a higher generation.
  refusedNotNewer,

  /// An active or master card is replaced only by a strictly higher
  /// generation, after a different admin's reset and a new issue.
  refusedLocked,
}

class LidarCredentialPolicy {
  static bool managed(Code code) => code.display.lidarLocked;

  static String _secretIdentity(String secret) =>
      secret.replaceAll(RegExp(r'[\s=]'), '').toUpperCase();

  static bool _plainV1(CodeDisplay d) =>
      d.lidarFormat == 1 &&
      d.lidarIssuer.isEmpty &&
      d.lidarEmail.isEmpty &&
      d.lidarActivationId.isEmpty &&
      d.lidarState.isEmpty &&
      d.lidarReason.isEmpty &&
      d.lidarActivateBy.isEmpty;

  static bool _validKeyMeta(CodeDisplay d) {
    if (d.lidarFormat == 1) return _plainV1(d);
    return d.lidarFormat == 2 &&
        d.lidarIssuer == LidarKeyContract.issuer &&
        LidarKeyContract.validEmail(d.lidarEmail) &&
        LidarKeyContract.activationIdRe.hasMatch(d.lidarActivationId) &&
        d.lidarGeneration >= 1 &&
        LidarKeyContract.states.contains(d.lidarState) &&
        (d.lidarReason.isEmpty ||
            LidarKeyContract.reasons.contains(d.lidarReason)) &&
        LidarMasterKey.isoSecond(d.lidarActivateBy) != null;
  }

  static bool _sameKeyMeta(CodeDisplay a, CodeDisplay b) =>
      a.lidarFormat == b.lidarFormat &&
      a.lidarIssuer == b.lidarIssuer &&
      a.lidarEmail == b.lidarEmail &&
      a.lidarActivationId == b.lidarActivationId &&
      a.lidarActivateBy == b.lidarActivateBy;

  static bool _sameIdentity(Code a, Code b) =>
      a.secret == b.secret &&
      a.account == b.account &&
      a.issuer == b.issuer &&
      a.display.lidarGeneration == b.display.lidarGeneration &&
      _sameKeyMeta(a.display, b.display);

  static bool _sameState(CodeDisplay a, CodeDisplay b) =>
      a.lidarState == b.lidarState && a.lidarReason == b.lidarReason;

  /// Contract 5 and v2.3, decided before anything is sent or stored.
  static LidarImportPlan planImport(LidarMasterKey key, Code? previous) {
    if (key.format != 2) throw ArgumentError('format-2 keys only');
    if (previous == null) return LidarImportPlan.create;
    // As for format 1: the same secret on the seat is the same key.
    if (previous.secret == key._secret) return LidarImportPlan.alreadyLinked;
    final old = previous.display;
    if (old.lidarFormat == 2 &&
        LidarKeyContract.recoverable.contains(old.lidarState)) {
      return old.lidarEmail == key.email && key.generation > old.lidarGeneration
          ? LidarImportPlan.activateFirst
          : LidarImportPlan.refusedNotNewer;
    }
    // An ACTIVE format-2 card or a format-1 master card: the existing
    // linked-credential rule (same seat, enrolled, strictly higher
    // generation, proven by a fresh HTTPS answer).
    return key.generation > old.lidarGeneration
        ? LidarImportPlan.activateFirst
        : LidarImportPlan.refusedLocked;
  }

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
        !_plainV1(candidate.display) ||
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
    LidarActivationProof? activation,
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
          (approval?._allows(existing, candidate) ?? false) ||
          (activation?._allowsReplacement(existing, candidate) ?? false);
      // A card's activation state changes only with a fresh server answer.
      final stateAuthorized =
          replacementAuthorized ||
          _sameState(candidate.display, existing.display) ||
          (activation?._allowsUpdate(existing, candidate) ?? false);
      if (!managed(candidate) ||
          candidate.display.lidarSeat != existing.display.lidarSeat ||
          (!replacementAuthorized && !_sameIdentity(candidate, existing)) ||
          !stateAuthorized ||
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
            candidate.isTrashed ||
            !_validKeyMeta(candidate.display))) {
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
      generation == next.display.lidarGeneration &&
      // A sign-in proof replaces with a format-1 file (today's rule); a
      // format-2 key is authorized by its own activation answer instead.
      LidarCredentialPolicy._plainV1(next.display);

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
