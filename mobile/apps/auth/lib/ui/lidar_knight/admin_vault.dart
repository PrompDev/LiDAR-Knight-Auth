import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:ente_auth/core/configuration.dart';
import 'package:ente_auth/events/codes_updated_event.dart';
import 'package:ente_auth/models/code.dart';
import 'package:ente_auth/services/authenticator_service.dart';
import 'package:ente_auth/services/lidar_master_key.dart';
import 'package:ente_auth/store/code_store.dart';
import 'package:ente_auth/utils/platform_util.dart';
import 'package:ente_auth/utils/totp_util.dart';
import 'package:ente_events/event_bus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A separate local-only lane; standard OTP accounts keep the upstream flow.
class LidarAdminVault extends StatefulWidget {
  const LidarAdminVault({super.key});
  @override
  State<LidarAdminVault> createState() => _LidarAdminVaultState();
}

class _LidarAdminVaultState extends State<LidarAdminVault> {
  List<Code> _codes = [];
  String? _notice;
  bool _busy = false;
  StreamSubscription<CodesUpdatedEvent>? _updates;

  @override
  void initState() {
    super.initState();
    _updates = Bus.instance.on<CodesUpdatedEvent>().listen((_) => _load());
    _load();
  }

  Future<void> _load() async {
    if (Configuration.instance.getOfflineSecretKey() == null) return;
    try {
      final codes = await CodeStore.instance.getAllCodes(
        accountMode: AccountMode.offline,
      );
      if (mounted) {
        setState(
          () => _codes = codes
              .where((c) => !c.hasError && c.display.lidarLocked)
              .toList(),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _notice = 'Unable to open the local admin vault.');
      }
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      // Native file selection: the key stays in this process and encrypted local storage.
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['env'],
        allowMultiple: false,
        withData: false,
        dialogTitle: 'Import your individual LiDAR owner key',
      );
      if (result == null) return;
      final picked = result.files.single;
      if (picked.size > LidarMasterKey.maxBytes || picked.path == null) {
        throw const FormatException(
          'Choose one individual LiDAR owner ENV file.',
        );
      }
      final file = File(picked.path!);
      // Bounded stream, including when the file changes after the picker stat.
      final bytes = <int>[];
      await for (final chunk in file.openRead(0, LidarMasterKey.maxBytes + 1)) {
        bytes.addAll(chunk);
      }
      final key = LidarMasterKey.parse(bytes);
      bytes.fillRange(0, bytes.length, 0);
      await Configuration.instance.ensureOfflineStorageKey();
      var candidate = key.toCode();
      LidarResetApproval? approval;
      final stored = await CodeStore.instance.getAllCodes(
        accountMode: AccountMode.offline,
      );
      final previous = stored
          .where(
            (c) => c.display.lidarLocked && c.display.lidarSeat == key.seat,
          )
          .firstOrNull;
      if (previous != null && previous.secret == candidate.secret) {
        if (mounted) setState(() => _notice = 'This key is already linked.');
        return;
      }
      if (previous != null && previous.secret != candidate.secret) {
        approval = await LidarResetApproval.verify(candidate, previous);
        candidate = candidate.copyWith(
          display: candidate.display.copyWith(
            lidarGeneration: approval.generation,
          ),
        );
        candidate.generatedID = previous.generatedID;
      }
      await CodeStore.instance.addCode(
        candidate,
        accountMode: AccountMode.offline,
        shouldSync: false,
        lidarResetApproval: approval,
        lidarMasterKey: key,
      );
      await _load();
      if (mounted) {
        setState(
          () => _notice =
              'Key saved locally. Server activation is required for admin access.',
        );
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _notice = error.message);
    } on StateError catch (_) {
      if (mounted) {
        setState(
          () => _notice =
              'This account is locked. Another admin must reset it in the game terminal.',
        );
      }
    } catch (_) {
      // Never log native file paths, parser contents or exception payloads.
      if (mounted) {
        setState(
          () =>
              _notice = 'Import failed. Choose your individual owner ENV file.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _updates?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
    children: [
      if (_codes.isEmpty) ...[
        const Text(
          'ADMIN ACCESS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: Color(0xFFFF6558),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Your key. Your clearance.',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF0EFE9),
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Import your individual master-key ENV. Your six-digit code stays on this device.',
          style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFFB3B6BB)),
        ),
        const SizedBox(height: 18),
      ],
      for (final code in _codes)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: LidarFloatingCodeCard(
            key: ValueKey('lidar-${code.display.lidarSeat}'),
            code: code,
          ),
        ),
      OutlinedButton.icon(
        onPressed: _busy ? null : _import,
        icon: const Icon(Icons.file_upload_outlined, size: 18),
        label: Text(_busy ? 'IMPORTING…' : 'IMPORT MASTER KEY .ENV'),
      ),
      if (_notice != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            _notice!,
            style: const TextStyle(
              color: Color(0xFFCACCD0),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      const SizedBox(height: 7),
      TextButton.icon(
        onPressed: () =>
            PlatformUtil.openUrlInBrowser('https://admin.lidarknight.com/'),
        icon: const Icon(Icons.open_in_new, size: 15),
        label: const Text('OPEN ADMIN ROOM'),
      ),
      const Text(
        'Linked keys cannot be edited or removed here. A different admin authorizes a reset in the game terminal.',
        style: TextStyle(color: Color(0xFF949AA2), fontSize: 11, height: 1.4),
      ),
    ],
  );
}

class LidarFloatingCodeCard extends StatefulWidget {
  final Code code;
  const LidarFloatingCodeCard({super.key, required this.code});
  @override
  State<LidarFloatingCodeCard> createState() => _LidarFloatingCodeCardState();
}

class _LidarFloatingCodeCardState extends State<LidarFloatingCodeCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _scene;
  Timer? _hideTimer;
  Timer? _clock;
  String? _lastCopied;
  bool _revealed = false;
  String _code = '';
  int _remaining = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scene = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_revealed && mounted) _refresh();
    });
  }

  void _refresh() {
    setState(() {
      _code = getOTP(widget.code);
      _remaining =
          widget.code.period -
          (millisecondsSinceEpoch() ~/ 1000) % widget.code.period;
    });
  }

  void _hide() {
    _hideTimer?.cancel();
    _clearOwnClipboard();
    if (mounted) {
      setState(() {
        _revealed = false;
        _code = '';
      });
    }
  }

  Future<void> _clearOwnClipboard() async {
    final copied = _lastCopied;
    _lastCopied = null;
    if (copied == null) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text == copied) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    } catch (_) {
      /* Never log clipboard contents. */
    }
  }

  @override
  void didUpdateWidget(covariant LidarFloatingCodeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code.secret != widget.code.secret ||
        oldWidget.code.display.lidarSeat != widget.code.display.lidarSeat ||
        oldWidget.code.display.lidarGeneration !=
            widget.code.display.lidarGeneration) {
      _hide();
    }
  }

  void _toggle() {
    if (_revealed) {
      _hide();
      return;
    }
    setState(() => _revealed = true);
    _refresh();
    _hideTimer = Timer(const Duration(seconds: 15), _hide);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _hide();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearOwnClipboard();
    _clock?.cancel();
    _hideTimer?.cancel();
    _scene.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _scene,
    builder: (context, _) => Transform.translate(
      offset: Offset(0, math.sin(_scene.value * math.pi * 2) * 2),
      child: Container(
        height: 176,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF0C1015),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF71332F)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x331F0907),
              blurRadius: 25,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CodeMistPainter(_scene.value, _revealed),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFFFF6558),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.code.account.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFE5E7EB),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.lock_outline,
                        color: Color(0xFF9B9DA3),
                        size: 14,
                      ),
                    ],
                  ),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: _revealed
                          ? 'Hide admin code'
                          : 'Reveal admin code',
                      child: InkWell(
                        onTap: _toggle,
                        child: Center(
                          // Replace immediately when hidden: never retain an
                          // outgoing readable code during a fade animation.
                          child: SizedBox(
                            child: _revealed
                                ? Text(
                                    _code,
                                    key: const ValueKey('visible'),
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 36,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFF4F1E7),
                                      letterSpacing: 7,
                                    ),
                                  )
                                : const Column(
                                    key: ValueKey('hidden'),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '• • •  • • •',
                                        style: TextStyle(
                                          color: Color(0xFFD0C6BF),
                                          fontSize: 28,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      SizedBox(height: 5),
                                      Text(
                                        'CLICK TO REVEAL',
                                        style: TextStyle(
                                          color: Color(0xFFB3B6BB),
                                          fontSize: 10,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _revealed
                            ? 'REFRESHES IN $_remaining SEC'
                            : 'PRIVATE · LOCAL VAULT',
                        style: const TextStyle(
                          color: Color(0xFFADB0B5),
                          fontSize: 9,
                          letterSpacing: 1,
                        ),
                      ),
                      if (_revealed)
                        InkWell(
                          onTap: () async {
                            final copied = _code;
                            await Clipboard.setData(
                              ClipboardData(text: copied),
                            );
                            _lastCopied = copied;
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            child: Text(
                              'COPY CODE',
                              style: TextStyle(
                                color: Color(0xFFFF8A7B),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CodeMistPainter extends CustomPainter {
  final double time;
  final bool clear;
  const _CodeMistPainter(this.time, this.clear);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    for (var i = 0; i < 5; i++) {
      final x = size.width * (i / 4) + math.sin(time * math.pi * 2 + i) * 35;
      final y = size.height * .58 + math.cos(time * math.pi * 2 + i * 2) * 25;
      paint.color = Color.fromRGBO(164, 47, 39, clear ? .05 : .19);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 130, height: 40),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CodeMistPainter old) =>
      old.time != time || old.clear != clear;
}
