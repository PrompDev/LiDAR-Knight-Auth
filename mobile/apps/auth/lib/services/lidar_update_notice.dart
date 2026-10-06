import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// A newer LiDAR-Knight Auth is published: what the title bar shows.
@immutable
class LidarUpdateInfo {
  /// The published version, 'major.minor.patch'.
  final String version;

  /// DeAndre's note for this release: one plain-text paragraph, at most
  /// [LidarUpdateNotice.maxMessage] characters. Never HTML, never a link.
  final String message;

  /// Where a click goes: always an https page on lidarknight.com.
  final Uri url;

  const LidarUpdateInfo(this.version, this.message, this.url);

  @override
  bool operator ==(Object other) =>
      other is LidarUpdateInfo &&
      other.version == version &&
      other.message == message &&
      other.url == url;

  @override
  int get hashCode => Object.hash(version, message, url);
}

/// The update notice (Auth 4.4.31; DeAndre 2026-10-06: "pushes an update, and
/// when hovering the update shows a message from the admin, short, only one
/// paragraph, no title, no header").
///
/// On start and every six hours it reads https://lidarknight.com/auth/update.json:
///   { version: '4.4.31', url: 'https://lidarknight.com/auth', message: '…',
///     publishedAt: ISO, installer?, sha256? }
/// It sends nothing but the request: no cookie, no identity, no key data. HTTPS
/// to the pinned host only, no redirects, at most 4 KiB read, short timeouts.
/// Anything wrong (offline, malformed, not newer) shows nothing.
class LidarUpdateNotice {
  LidarUpdateNotice._();
  static final LidarUpdateNotice instance = LidarUpdateNotice._();

  static const host = 'lidarknight.com';
  static final Uri feed = Uri.https(host, '/auth/update.json');
  static final Uri defaultPage = Uri.https(host, '/auth');
  static const maxMessage = 280;
  static const interval = Duration(hours: 6);

  /// The newer release, or null (up to date, offline, or nothing published).
  final ValueNotifier<LidarUpdateInfo?> available = ValueNotifier(null);

  Timer? _timer;
  bool _started = false;

  /// Starts the checks once per app run; later calls do nothing.
  void start() {
    if (_started) return;
    _started = true;
    unawaited(check());
    _timer = Timer.periodic(interval, (_) => unawaited(check()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  /// One check: fetch, judge, publish. Never throws.
  Future<void> check() async {
    try {
      final running = (await PackageInfo.fromPlatform()).version;
      final body = await fetch();
      available.value = body == null ? null : parse(body, running);
    } catch (_) {
      // Offline or refused: show nothing (no diagnostics, nothing to leak).
      available.value = null;
    }
  }

  /// GET the feed: HTTPS, the pinned host, no redirects, at most 4 KiB.
  static Future<String?> fetch() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client
          .getUrl(feed)
          .timeout(const Duration(seconds: 8));
      request.followRedirects = false;
      request.persistentConnection = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode != 200) {
        await response.drain<void>().timeout(const Duration(seconds: 5));
        return null;
      }
      final bytes = await response
          .fold<List<int>>(<int>[], (buffer, chunk) {
            if (buffer.length + chunk.length > 4096) {
              throw StateError('Answer too large.');
            }
            buffer.addAll(chunk);
            return buffer;
          })
          .timeout(const Duration(seconds: 8));
      return utf8.decode(bytes);
    } finally {
      client.close(force: true);
    }
  }

  static final _versionRe = RegExp(r'^(\d{1,4})\.(\d{1,4})\.(\d{1,6})$');

  /// The feed's answer → the update to show, or null. [running] is this app's
  /// version ('4.4.31', a '+build' suffix is ignored). Pure: no I/O.
  static LidarUpdateInfo? parse(String body, String running) {
    Object? json;
    try {
      json = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (json is! Map) return null;
    final version = json['version'], message = json['message'];
    if (version is! String || message is! String) return null;
    if (compareVersions(version, running.split('+').first) <= 0) return null;
    final text = cleanMessage(message);
    if (text.isEmpty) return null;
    return LidarUpdateInfo(version, text, pageUrl(json['url']));
  }

  /// Compares 'a.b.c' versions: negative, zero or positive. Anything that is
  /// not three plain numbers sorts as the oldest possible, so a malformed
  /// published version never shows a notice.
  static int compareVersions(String a, String b) {
    final ma = _versionRe.firstMatch(a.trim()), mb = _versionRe.firstMatch(b.trim());
    if (ma == null) return -1;
    if (mb == null) return 1;
    for (var i = 1; i <= 3; i++) {
      final d = int.parse(ma.group(i)!) - int.parse(mb.group(i)!);
      if (d != 0) return d;
    }
    return 0;
  }

  /// One plain paragraph: control and invisible characters become spaces,
  /// whitespace runs (line breaks included) collapse, and the text is cut at
  /// [maxMessage] characters on a whole character, ending with '…' if cut.
  static String cleanMessage(String raw) {
    final flat = raw
        .replaceAll(
          RegExp(
            r'[\u0000-\u001f\u007f-\u009f\u00AD\u200B-\u200F\u2028-\u202E\u2060-\u2064\u2066-\u206F\uFEFF]',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // A lone UTF-16 surrogate (e.g. an emoji cut in half by a tool that trimmed the message) becomes U+FFFD: Text
    // layout throws on ill-formed UTF-16 (Check, review of 4.4.31).
    final chars = flat.runes
        .map((r) => r >= 0xD800 && r <= 0xDFFF ? 0xFFFD : r)
        .toList();
    if (chars.length <= maxMessage) return String.fromCharCodes(chars);
    return '${String.fromCharCodes(chars.take(maxMessage - 1)).trimRight()}…';
  }

  /// Where a click may go: an https page on lidarknight.com (default port, no
  /// user info). Anything else becomes the Auth page.
  static Uri pageUrl(Object? raw) {
    if (raw is! String) return defaultPage;
    final u = Uri.tryParse(raw);
    if (u == null ||
        u.scheme != 'https' ||
        u.host != host ||
        u.hasPort && u.port != 443 ||
        u.userInfo.isNotEmpty) {
      return defaultPage;
    }
    return u;
  }
}
