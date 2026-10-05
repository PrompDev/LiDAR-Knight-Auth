import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:ente_auth/core/configuration.dart';
import 'package:ente_auth/events/codes_updated_event.dart';
import 'package:ente_auth/models/code.dart';
import 'package:ente_auth/models/code_display.dart';
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

/// A newer emailed key for a seat that already has a card. It lives in memory
/// only and replaces the stored card only after its own activation answered
/// active (contract 5, v2.3); until then the stored card stays untouched.
class _LidarSetup {
  final Code card;
  final Code previous;
  const _LidarSetup(this.card, this.previous);
}

class _LidarAdminVaultState extends State<LidarAdminVault> {
  // One per app session; activation is pinned to admin.lidarknight.com.
  static final LidarActivation _activation = LidarActivation();
  List<Code> _codes = [];
  String? _notice;
  bool _busy = false;
  _LidarSetup? _setup;
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
      if (key.format == 2) {
        await _importEmailedKey(key);
        return;
      }
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

  void _say(String notice) {
    if (mounted) setState(() => _notice = notice);
  }

  // Format 2 (contract 5): a new seat gets a locked PENDING card; a seat that
  // already has a card gets a transient PENDING SETUP, never an overwrite.
  Future<void> _importEmailedKey(LidarMasterKey key) async {
    final candidate = key.toCode();
    final stored = await CodeStore.instance.getAllCodes(
      accountMode: AccountMode.offline,
    );
    final previous = stored
        .where((c) => c.display.lidarLocked && c.display.lidarSeat == key.seat)
        .firstOrNull;
    switch (LidarCredentialPolicy.planImport(key, previous)) {
      case LidarImportPlan.create:
        await CodeStore.instance.addCode(
          candidate,
          accountMode: AccountMode.offline,
          shouldSync: false,
          lidarMasterKey: key,
        );
        await _load();
        _say(
          'Key saved locally as PENDING. It is not signed in: press ACTIVATE to activate it with admin.lidarknight.com.',
        );
      case LidarImportPlan.alreadyLinked:
        _say('This key is already linked.');
      case LidarImportPlan.activateFirst:
        if (mounted) setState(() => _setup = _LidarSetup(candidate, previous!));
        _say(
          'PENDING SETUP: press ACTIVATE. The ${key.seat} card changes only after admin.lidarknight.com activates this newer key.',
        );
      case LidarImportPlan.refusedNotNewer:
        _say(
          'This seat already holds a key. Only a newer key issued to the same email replaces it, after it activates.',
        );
      case LidarImportPlan.refusedLocked:
        _say(
          'This account is locked. Another admin must reset it in the game terminal.',
        );
    }
  }

  Future<void> _activateCard(Code card) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    LidarActivationOutcome? outcome;
    try {
      outcome = await _activation.activate(card);
      final proof = outcome.proof;
      if (proof != null) {
        await CodeStore.instance.addCode(
          LidarActivation.withOutcome(card, outcome),
          accountMode: AccountMode.offline,
          shouldSync: false,
          lidarActivation: proof,
        );
        await _load();
      }
      _say(lidarOutcomeNotice(outcome));
    } catch (_) {
      // Never log codes, activation ids or exception payloads.
      _say(
        outcome?.proof == null
            ? 'Activation failed. Nothing changed.'
            : 'admin.lidarknight.com answered, but this device could not record it. Press ACTIVATE again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activateSetup() async {
    final setup = _setup;
    if (_busy || setup == null) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    LidarActivationOutcome? outcome;
    try {
      outcome = await _activation.activate(setup.card);
      if (outcome.isActive) {
        await CodeStore.instance.addCode(
          LidarActivation.withOutcome(setup.card, outcome)
            ..generatedID = setup.previous.generatedID,
          accountMode: AccountMode.offline,
          shouldSync: false,
          lidarActivation: outcome.proof,
        );
        if (mounted) setState(() => _setup = null);
        await _load();
      } else if (outcome.proof != null && mounted) {
        // Only the transient setup shows the answer; the stored card stays.
        setState(
          () => _setup = _LidarSetup(
            LidarActivation.withOutcome(setup.card, outcome!),
            setup.previous,
          ),
        );
      }
      _say(lidarOutcomeNotice(outcome));
    } catch (_) {
      _say(
        outcome?.proof == null
            ? 'Activation failed. Nothing changed.'
            : 'admin.lidarknight.com answered, but this device could not replace the card. Press ACTIVATE again.',
      );
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
      if (_codes.isEmpty && _setup == null) ...[
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
          'Import your individual master-key ENV or your emailed admin key. Your six-digit code stays on this device.',
          style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFFB3B6BB)),
        ),
        const SizedBox(height: 18),
      ],
      for (final code in _codes)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: code.display.lidarFormat == 2
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LidarFloatingCodeCard(
                      key: ValueKey('lidar-${code.display.lidarSeat}'),
                      code: code,
                    ),
                    LidarKeyStatus(
                      code: code,
                      busy: _busy,
                      onActivate: () => _activateCard(code),
                    ),
                  ],
                )
              : LidarFloatingCodeCard(
                  key: ValueKey('lidar-${code.display.lidarSeat}'),
                  code: code,
                ),
        ),
      if (_setup != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LidarFloatingCodeCard(
                key: ValueKey('lidar-setup-${_setup!.card.display.lidarSeat}'),
                code: _setup!.card,
                setup: true,
              ),
              LidarKeyStatus(
                code: _setup!.card,
                setup: true,
                busy: _busy,
                onActivate: _activateSetup,
                onCancel: () => setState(() => _setup = null),
              ),
            ],
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

  /// A transient PENDING SETUP of a newer emailed key (never stored).
  final bool setup;
  const LidarFloatingCodeCard({
    super.key,
    required this.code,
    this.setup = false,
  });
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

  // A format-2 key that the server has not activated: its codes are shown
  // (needed to activate) but never as a signed-in admin credential.
  bool get _notActivated =>
      widget.code.display.lidarFormat == 2 &&
      widget.code.display.lidarState != 'active';

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
                      if (lidarStateLabel(
                            widget.code.display,
                            setup: widget.setup,
                          )
                          case final label?)
                        LidarStateBadge(
                          label: label,
                          active: widget.code.display.lidarState == 'active',
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
                            ? (_notActivated
                                  ? 'PENDING CODE · REFRESHES IN $_remaining SEC'
                                  : 'REFRESHES IN $_remaining SEC')
                            : (_notActivated
                                  ? 'NOT ACTIVATED · LOCAL VAULT'
                                  : 'PRIVATE · LOCAL VAULT'),
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

/// The card badge for an emailed (format-2) key, in the contract's state names;
/// a refusal shows its reason verbatim. Format-1 master cards have no badge.
String? lidarStateLabel(CodeDisplay display, {bool setup = false}) {
  if (display.lidarFormat != 2) return null;
  switch (display.lidarState) {
    case 'pending':
      return setup ? 'PENDING SETUP' : 'PENDING';
    case 'refused':
      return display.lidarReason.isEmpty
          ? 'REFUSED'
          : 'REFUSED (${display.lidarReason})';
    case 'active' || 'expired' || 'failed' || 'reissued' || 'revoked':
      return display.lidarState.toUpperCase();
    default:
      return null;
  }
}

/// 'YYYY-MM-DDTHH:MM:SSZ' as 'YYYY-MM-DD HH:MM UTC'.
String lidarUtc(String iso) => LidarMasterKey.isoSecond(iso) == null
    ? iso
    : '${iso.substring(0, 10)} ${iso.substring(11, 16)} UTC';

/// What a format-2 card's state means (contract section 2), in plain words.
String lidarStateMessage(CodeDisplay display, {bool setup = false}) {
  final seat = display.lidarSeat;
  switch (display.lidarState) {
    case 'pending':
      return setup
          ? 'PENDING SETUP: this newer key replaces the $seat card only after admin.lidarknight.com activates it. Until then the $seat card stays as it is.'
          : 'PENDING: saved on this device only, not activated and not signed in. ACTIVATE sends the current code to admin.lidarknight.com. Activate by ${lidarUtc(display.lidarActivateBy)}.';
    case 'refused':
      return setup
          ? 'REFUSED (${display.lidarReason}): this newer key was not activated. The $seat card stays as it was.'
          : 'REFUSED (${display.lidarReason}): the last activation was refused. The card stays as it was.';
    case 'active':
      return lidarActiveGuidance;
    case 'expired':
      return 'EXPIRED: the activation deadline passed. Ask the inviting admin to reissue.';
    case 'failed':
      return 'FAILED: 5 wrong activation codes. Ask the inviting admin to reissue.';
    case 'reissued':
      return 'REISSUED: a newer key replaced this one. Import the newer file.';
    case 'revoked':
      return 'REVOKED: the seat was revoked or reset by a different admin.';
    default:
      return '';
  }
}

const lidarActiveGuidance =
    'Delete the downloaded file and the email: the app keeps your key.';

/// The notice after one ACTIVATE. Never holds a code, secret or activation id.
String lidarOutcomeNotice(LidarActivationOutcome outcome) {
  switch (outcome.problem) {
    case 'unreachable':
      return 'Could not reach admin.lidarknight.com. Nothing changed: press ACTIVATE again.';
    case 'unexpected':
      return 'admin.lidarknight.com gave an answer this app does not accept. Nothing changed.';
    case 'not-pending' || 'no-key':
      return 'This key is not waiting for activation.';
  }
  switch (outcome.state) {
    case 'active':
      return 'ACTIVE: admin.lidarknight.com activated this key. Sign in to the admin room with your six-digit code.';
    case 'refused':
      return [
        'Activation refused (${outcome.reason}).',
        if (outcome.problem == 'local')
          'This key does not belong to admin.lidarknight.com.',
        if (outcome.attemptsLeft != null)
          '${outcome.attemptsLeft} attempts left.',
        if (outcome.retryAfter != null) 'Try again in ${outcome.retryAfter} s.',
        'The card stays as it was.',
      ].join(' ');
    case 'expired':
      return 'EXPIRED: the activation deadline passed. Ask the inviting admin to reissue.';
    case 'failed':
      return 'FAILED: 5 wrong activation codes. Ask the inviting admin to reissue.';
    case 'reissued':
      return 'REISSUED: a newer key replaced this one. Import the newer file.';
    case 'revoked':
      return 'REVOKED: the seat was revoked or reset by a different admin.';
    default:
      return 'Nothing changed.';
  }
}

class LidarStateBadge extends StatelessWidget {
  final String label;
  final bool active;
  const LidarStateBadge({super.key, required this.label, this.active = false});

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 190),
    margin: const EdgeInsets.symmetric(horizontal: 8),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFF14181D),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(
        color: active ? const Color(0xFF8C9096) : const Color(0xFF71332F),
      ),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: active ? const Color(0xFFF0EFE9) : const Color(0xFFFF8A7B),
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    ),
  );
}

/// Under a format-2 card: what its state means, and ACTIVATE while it is
/// pending or refused (CANCEL too for a transient PENDING SETUP).
class LidarKeyStatus extends StatelessWidget {
  final Code code;
  final bool setup;
  final bool busy;
  final VoidCallback? onActivate;
  final VoidCallback? onCancel;
  const LidarKeyStatus({
    super.key,
    required this.code,
    this.setup = false,
    this.busy = false,
    this.onActivate,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final display = code.display;
    if (display.lidarFormat != 2) return const SizedBox.shrink();
    final canActivate =
        display.lidarState == 'pending' || display.lidarState == 'refused';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lidarStateMessage(display, setup: setup),
            style: const TextStyle(
              color: Color(0xFFCACCD0),
              fontSize: 11,
              height: 1.4,
            ),
          ),
          if (display.lidarState == 'active')
            const Text(
              'Empty Trash or Deleted Items too.',
              style: TextStyle(
                color: Color(0xFF949AA2),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          if (canActivate || setup)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (canActivate)
                    OutlinedButton.icon(
                      onPressed: busy ? null : onActivate,
                      icon: const Icon(Icons.verified_user_outlined, size: 16),
                      label: Text(busy ? 'ACTIVATING…' : 'ACTIVATE'),
                    ),
                  if (setup)
                    TextButton(
                      onPressed: busy ? null : onCancel,
                      child: const Text('CANCEL'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
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
