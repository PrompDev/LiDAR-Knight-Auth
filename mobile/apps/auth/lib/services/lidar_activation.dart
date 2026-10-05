part of 'lidar_master_key.dart';

/// One HTTPS answer: its status and its decoded JSON body (null when the body
/// was empty or not JSON).
class LidarHttpReply {
  final int status;
  final Object? json;
  const LidarHttpReply(this.status, this.json);
}

typedef LidarPoster =
    Future<LidarHttpReply> Function(Uri url, Map<String, Object> body);

/// A fresh server answer about one format-2 key. Only [LidarActivation] mints
/// it, from a validated HTTPS answer of the pinned host; a file, a local flag
/// or pasted JSON cannot. For 60 seconds it authorizes recording that answer
/// on the card, or replacing the seat's card with the key it activated.
class LidarActivationProof {
  final String _seat;
  final String _activationId;
  final int _generation;
  final String _secret;
  final String state;
  final String reason;
  final int _at;
  LidarActivationProof._(
    this._seat,
    this._activationId,
    this._generation,
    this._secret,
    this.state,
    this.reason,
    this._at,
  );

  bool get _fresh {
    final age = DateTime.now().millisecondsSinceEpoch - _at;
    return age >= 0 && age < 60000;
  }

  bool _isKey(Code code) {
    final d = code.display;
    return d.lidarFormat == 2 &&
        d.lidarSeat == _seat &&
        d.lidarActivationId == _activationId &&
        d.lidarGeneration == _generation &&
        code.secret == _secret;
  }

  // The same card records the server's answer. An ACTIVE card never moves
  // back to pending or refused.
  bool _allowsUpdate(Code existing, Code next) =>
      _fresh &&
      _isKey(existing) &&
      _isKey(next) &&
      LidarCredentialPolicy._sameIdentity(existing, next) &&
      existing.display.lidarState != 'active' &&
      next.display.lidarState == state &&
      next.display.lidarReason == reason;

  // Contract 5 and v2.3: a newer key takes the seat's card only after its
  // own activation answered active at its own generation.
  bool _allowsReplacement(Code existing, Code next) {
    final old = existing.display;
    final neu = next.display;
    if (!_fresh ||
        state != 'active' ||
        !_isKey(next) ||
        neu.lidarState != 'active' ||
        neu.lidarReason.isNotEmpty ||
        old.lidarSeat != _seat ||
        next.secret == existing.secret) {
      return false;
    }
    if (old.lidarFormat == 2 &&
        LidarKeyContract.recoverable.contains(old.lidarState)) {
      // Pending-card recovery: the same EMAIL and a HIGHER generation.
      return neu.lidarEmail == old.lidarEmail &&
          _generation > old.lidarGeneration;
    }
    // An ACTIVE card or a format-1 master card: the linked-credential rule
    // (same seat, kind enrolled, strictly higher generation, fresh HTTPS).
    return _generation > old.lidarGeneration;
  }

  @override
  String toString() => 'LidarActivationProof([private])';
}

/// The result of one ACTIVATE. [proof] is set only when the server answered;
/// [problem] says why nothing changed otherwise: 'unreachable' (no answer),
/// 'unexpected' (an answer outside the contract), 'local' (refused on this
/// device), 'not-pending' or 'no-key'.
class LidarActivationOutcome {
  final String state;
  final String reason;
  final int? attemptsLeft;
  final int? retryAfter;
  final String problem;
  final LidarActivationProof? proof;
  const LidarActivationOutcome._({
    this.state = '',
    this.reason = '',
    this.attemptsLeft,
    this.retryAfter,
    this.problem = '',
    this.proof,
  });

  bool get isActive => proof != null && state == 'active';
}

/// POST https://admin.lidarknight.com/api/owner/activate with the card's own
/// fields and its current code (contract section 3 and v2.3). HTTPS only, to
/// the pinned host only, no redirects followed, bounded answers, timeouts.
class LidarActivation {
  static const host = LidarKeyContract.issuer;
  static final Uri activateUrl = Uri.https(host, '/api/owner/activate');
  static final Uri statusUrl = Uri.https(host, '/api/owner/activation/status');
  static const timeout = Duration(seconds: 12);

  // The HTTP status of each refusal reason (server KEY_HTTP; bad-code is also
  // 400 for a malformed code; locked is 423, or 429 for a rate limit).
  static const _http = <String, List<int>>{
    'tampered': [403],
    'wrong-recipient': [403],
    'bad-code': [401, 400],
    'replayed': [409],
    'already-active': [409],
    'expired': [410],
    'revoked': [410],
    'old-generation': [410],
    'locked': [423, 429],
    'unknown': [404],
  };

  final LidarPoster _post;
  final String Function(Code) _codeFor;

  /// [poster] and [codeFor] are seams for debug and test builds only: a
  /// release build always posts with [httpsPost] to the pinned host.
  LidarActivation({LidarPoster? poster, String Function(Code)? codeFor})
    : _post = kReleaseMode || poster == null ? httpsPost : poster,
      _codeFor = kReleaseMode || codeFor == null ? getOTP : codeFor;

  /// The only URLs this app sends a key's fields to.
  static bool pinned(Uri url) =>
      url.scheme == 'https' &&
      url.host == host &&
      url.port == 443 &&
      url.userInfo.isEmpty &&
      !url.hasQuery &&
      !url.hasFragment &&
      (url.path == activateUrl.path || url.path == statusUrl.path);

  static Future<LidarHttpReply> httpsPost(
    Uri url,
    Map<String, Object> body,
  ) async {
    if (!pinned(url)) {
      throw StateError('Activation is pinned to https://$host.');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client
          .postUrl(url)
          .timeout(const Duration(seconds: 8));
      request.followRedirects = false;
      request.persistentConnection = false;
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.write(jsonEncode(body));
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      final bytes = await response
          .fold<List<int>>(<int>[], (buffer, chunk) {
            if (buffer.length + chunk.length > 4096) {
              throw StateError('Answer too large.');
            }
            buffer.addAll(chunk);
            return buffer;
          })
          .timeout(const Duration(seconds: 8));
      Object? json;
      try {
        json = jsonDecode(utf8.decode(bytes));
      } catch (_) {
        json = null;
      }
      return LidarHttpReply(response.statusCode, json);
    } finally {
      client.close(force: true);
    }
  }

  Future<LidarActivationOutcome> activate(Code card) async {
    final d = card.display;
    if (!d.lidarLocked || d.lidarFormat != 2) {
      return const LidarActivationOutcome._(problem: 'no-key');
    }
    // Activation goes ONLY to https://admin.lidarknight.com, and only for a
    // key whose ISSUER is that host; anything else is refused here.
    if (d.lidarIssuer != host ||
        !LidarKeyContract.seatRe.hasMatch(d.lidarSeat) ||
        !LidarKeyContract.validEmail(d.lidarEmail) ||
        !LidarKeyContract.activationIdRe.hasMatch(d.lidarActivationId) ||
        d.lidarGeneration < 1) {
      return const LidarActivationOutcome._(
        state: 'refused',
        reason: 'tampered',
        problem: 'local',
      );
    }
    if (d.lidarState != 'pending' && d.lidarState != 'refused') {
      return const LidarActivationOutcome._(problem: 'not-pending');
    }
    final LidarHttpReply reply;
    try {
      reply = await _post(activateUrl, {
        'format': 2,
        'issuer': d.lidarIssuer,
        'seat': d.lidarSeat,
        'email': d.lidarEmail,
        'generation': d.lidarGeneration,
        'activationId': d.lidarActivationId,
        'code': _codeFor(card),
      }).timeout(timeout);
    } catch (_) {
      // No answer: nothing changes. If this attempt did arrive, a retry
      // answers replayed or already-active and the status call settles it.
      return const LidarActivationOutcome._(problem: 'unreachable');
    }
    final json = reply.json;
    if (reply.status == 200) {
      return _validActive(json, d)
          ? _answer(card, 'active', '')
          : _answer(card, 'refused', 'tampered');
    }
    if (json is! Map ||
        json['state'] != 'refused' ||
        json['reason'] is! String ||
        !(_http[json['reason']]?.contains(reply.status) ?? false)) {
      return const LidarActivationOutcome._(problem: 'unexpected');
    }
    final reason = json['reason'] as String;
    final left = json['attemptsLeft'];
    final wait = json['retryAfter'];
    final attemptsLeft = left is int && left >= 0 ? left : null;
    final retryAfter = wait is num && wait > 0 ? wait.ceil() : null;
    switch (reason) {
      case 'replayed' || 'already-active':
        return _recover(card, reason);
      case 'expired':
        return _answer(card, 'expired', '');
      case 'old-generation':
        return _answer(card, 'reissued', '');
      case 'revoked':
        return _answer(card, 'revoked', '');
      case 'locked':
        return reply.status == 423
            ? _answer(card, 'failed', 'locked', attemptsLeft: 0)
            : _answer(card, 'refused', 'locked', retryAfter: retryAfter);
      default:
        return _answer(card, 'refused', reason, attemptsLeft: attemptsLeft);
    }
  }

  static bool _validActive(Object? json, CodeDisplay d) {
    if (json is! Map) return false;
    final linked = json['linkedCredential'];
    return json['state'] == 'active' &&
        json['seat'] == d.lidarSeat &&
        linked is Map &&
        linked['protocol'] == 1 &&
        linked['kind'] == 'enrolled' &&
        linked['generation'] is int &&
        linked['generation'] == d.lidarGeneration;
  }

  // Lost answer (v2.3): after replayed or already-active, the card is active
  // only when the status call says active at the file's own generation.
  Future<LidarActivationOutcome> _recover(Code card, String reason) async {
    final d = card.display;
    try {
      final reply = await _post(statusUrl, {
        'activationId': d.lidarActivationId,
      }).timeout(timeout);
      final json = reply.json;
      if (reply.status == 200 &&
          json is Map &&
          json['seat'] == d.lidarSeat &&
          json['generation'] is int &&
          json['generation'] == d.lidarGeneration) {
        switch (json['state']) {
          case 'active':
            return _answer(card, 'active', '');
          case 'expired' || 'reissued' || 'revoked':
            return _answer(card, json['state'] as String, '');
          case 'failed':
            return _answer(card, 'failed', 'locked', attemptsLeft: 0);
        }
      }
    } catch (_) {
      /* No status answer: the refusal itself stands. */
    }
    return _answer(card, 'refused', reason);
  }

  LidarActivationOutcome _answer(
    Code card,
    String state,
    String reason, {
    int? attemptsLeft,
    int? retryAfter,
  }) {
    final d = card.display;
    return LidarActivationOutcome._(
      state: state,
      reason: reason,
      attemptsLeft: attemptsLeft,
      retryAfter: retryAfter,
      proof: LidarActivationProof._(
        d.lidarSeat,
        d.lidarActivationId,
        d.lidarGeneration,
        card.secret,
        state,
        reason,
        DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// [card] with [outcome] recorded. The stored otpauth data is kept as it is
  /// (Code.copyWith would rebuild it from an unencoded label).
  static Code withOutcome(Code card, LidarActivationOutcome outcome) {
    if (outcome.proof == null) return card;
    return Code(
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
        display: card.display.copyWith(
          lidarState: outcome.state,
          lidarReason: outcome.reason,
        ),
      )
      ..createdAt = card.createdAt
      ..hasSynced = card.hasSynced;
  }
}
