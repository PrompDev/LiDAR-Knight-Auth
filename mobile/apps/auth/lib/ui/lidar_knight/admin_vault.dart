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
import 'package:ente_auth/theme/lidar_knight_theme.dart';
import 'package:ente_auth/utils/platform_util.dart';
import 'package:ente_auth/utils/totp_util.dart';
import 'package:ente_events/event_bus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The offline vault as the LIDAR ADMIN tab uses it: the encrypted CodeStore,
/// which checks every write again against the stored rows.
class LidarVaultStore {
  const LidarVaultStore();

  /// The managed LiDAR cards on this device.
  Future<List<Code>> cards() async {
    if (Configuration.instance.getOfflineSecretKey() == null) return [];
    final codes = await CodeStore.instance.getAllCodes(
      accountMode: AccountMode.offline,
    );
    return codes.where((c) => !c.hasError && c.display.lidarLocked).toList();
  }

  Future<void> prepare() => Configuration.instance.ensureOfflineStorageKey();

  Future<void> save(
    Code card, {
    LidarMasterKey? key,
    LidarResetApproval? approval,
    LidarActivationProof? activation,
  }) => CodeStore.instance.addCode(
    card,
    accountMode: AccountMode.offline,
    shouldSync: false,
    lidarMasterKey: key,
    lidarResetApproval: approval,
    lidarActivation: activation,
  );

  /// A key of another seat that the server has just activated takes the slot.
  Future<void> moveSlot(
    Code previous,
    Code next, {
    required LidarMasterKey key,
    required LidarActivationProof proof,
  }) => CodeStore.instance.replaceLidarSlot(
    previous,
    next,
    key: key,
    proof: proof,
  );

  /// REMOVE, after the owner confirmed it on the card: this device only.
  Future<void> remove(Code card) => CodeStore.instance.removeLidarCard(card);
}

/// A separate local-only lane with ONE key slot (4.4.31); standard OTP
/// accounts keep the upstream flow.
class LidarAdminVault extends StatefulWidget {
  /// Seams for debug and test builds only: a release build always uses the
  /// encrypted CodeStore, the pinned activation and the native file picker.
  final LidarVaultStore? store;
  final LidarActivation? activation;
  final Future<List<int>?> Function()? readKeyFile;
  const LidarAdminVault({
    super.key,
    this.store,
    this.activation,
    this.readKeyFile,
  });
  @override
  State<LidarAdminVault> createState() => _LidarAdminVaultState();
}

/// A newer key waiting in the slot. It lives in memory only and takes the slot
/// only after its own activation answered active (contract 5, v2.3), or for a
/// format-1 file after a fresh sign-in proof; until then the stored card stays
/// untouched, and CANCEL drops it.
class _LidarSetup {
  final Code card;
  final Code previous;
  final LidarMasterKey key;
  const _LidarSetup(this.card, this.previous, this.key);
}

const _lockedNotice =
    'This account is locked. Another admin must reset it in the game terminal.';

class _LidarAdminVaultState extends State<LidarAdminVault> {
  // One per app session; activation is pinned to admin.lidarknight.com.
  static final LidarActivation _pinned = LidarActivation();
  List<Code> _cards = [];
  String? _notice;
  // 'import', 'activate' or 'remove' while one runs.
  String? _working;
  _LidarSetup? _setup;
  StreamSubscription<CodesUpdatedEvent>? _updates;

  LidarVaultStore get _store =>
      (kReleaseMode ? null : widget.store) ?? const LidarVaultStore();
  LidarActivation get _activation =>
      (kReleaseMode ? null : widget.activation) ?? _pinned;
  bool get _busy => _working != null;

  /// The one card the tab shows: a working key before a broken one.
  static Code? _slotOf(List<Code> cards) =>
      cards.where((c) => !lidarBroken(c.display)).firstOrNull ??
      cards.firstOrNull;

  @override
  void initState() {
    super.initState();
    _updates = Bus.instance.on<CodesUpdatedEvent>().listen((_) => _load());
    _load();
  }

  Future<void> _load() async {
    try {
      final cards = await _store.cards();
      if (mounted) setState(() => _cards = cards);
    } catch (_) {
      _say('Unable to open the local admin vault.');
    }
  }

  void _say(String notice) {
    if (mounted) setState(() => _notice = notice);
  }

  bool _start(String work) {
    if (_busy || !mounted) return false;
    setState(() {
      _working = work;
      _notice = null;
    });
    return true;
  }

  void _done() {
    if (mounted) setState(() => _working = null);
  }

  Future<void> _import() async {
    if (!_start('import')) return;
    try {
      final read = (kReleaseMode ? null : widget.readKeyFile) ?? _pickKeyFile;
      final bytes = await read();
      if (bytes == null) return;
      final LidarMasterKey key;
      try {
        key = LidarMasterKey.parse(bytes);
      } on FormatException catch (error) {
        // A clearer word for an encoded file or a newer format (4.4.31).
        throw FormatException(
          LidarMasterKey.importHint(bytes) ?? error.message,
        );
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
      await _store.prepare();
      // The plan comes from the stored rows, never from what the tab shows.
      final stored = await _store.cards();
      final sameSeat = stored
          .where((c) => c.display.lidarSeat == key.seat)
          .firstOrNull;
      final previous = sameSeat ?? _slotOf(stored);
      final candidate = key.toCode();
      final plan = LidarCredentialPolicy.planSlotImport(
        key,
        sameSeat: sameSeat,
        slot: previous,
      );
      // One slot: a new key waits in it until it is proved; any other
      // answer leaves the stored card in it.
      if (mounted) {
        setState(
          () => _setup = plan == LidarImportPlan.activateFirst
              ? _LidarSetup(candidate, previous!, key)
              : null,
        );
      }
      switch (plan) {
        case LidarImportPlan.create:
          await _store.save(candidate, key: key);
          await _load();
          _say(
            key.format == 2
                ? 'Key saved locally as PENDING. It is not signed in: press ACTIVATE to activate it with admin.lidarknight.com.'
                : 'Key saved locally. Server activation is required for admin access.',
          );
        case LidarImportPlan.alreadyLinked:
          _say('This key is already linked.');
        case LidarImportPlan.activateFirst:
          _say(
            'PENDING SETUP: press ACTIVATE. The ${previous!.display.lidarSeat} card changes only after admin.lidarknight.com activates this key.',
          );
        case LidarImportPlan.refusedLocked:
          _say(_lockedNotice);
        case LidarImportPlan.removeFirst:
          _say('One key at a time: REMOVE this key first, then import.');
      }
    } on FormatException catch (error) {
      _say(error.message);
    } on StateError catch (_) {
      _say(_lockedNotice);
    } catch (_) {
      // Never log native file paths, parser contents or exception payloads.
      _say('Import failed. Choose your individual owner ENV file.');
    } finally {
      _done();
    }
  }

  Future<void> _activateCard(Code card) async {
    if (!_start('activate')) return;
    LidarActivationOutcome? outcome;
    try {
      outcome = await _activation.activate(card);
      final proof = outcome.proof;
      if (proof != null) {
        await _store.save(
          LidarActivation.withOutcome(card, outcome),
          activation: proof,
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
      _done();
    }
  }

  Future<void> _activateSetup() async {
    final setup = _setup;
    if (setup == null || !_start('activate')) return;
    try {
      if (setup.key.format == 2) {
        await _activateEmailedSetup(setup);
      } else {
        await _activateMasterSetup(setup);
      }
    } finally {
      _done();
    }
  }

  // Format 2: the slot changes only after the new key's own activation
  // answered active; any other answer stays on the waiting key.
  Future<void> _activateEmailedSetup(_LidarSetup setup) async {
    LidarActivationOutcome? outcome;
    try {
      outcome = await _activation.activate(setup.card);
      final proof = outcome.proof;
      if (outcome.isActive && proof != null) {
        final next = LidarActivation.withOutcome(setup.card, outcome);
        if (next.display.lidarSeat == setup.previous.display.lidarSeat) {
          await _store.save(
            next..generatedID = setup.previous.generatedID,
            activation: proof,
          );
        } else {
          await _store.moveSlot(
            setup.previous,
            next,
            key: setup.key,
            proof: proof,
          );
        }
        if (mounted) setState(() => _setup = null);
        await _load();
      } else if (proof != null && mounted) {
        setState(
          () => _setup = _LidarSetup(
            LidarActivation.withOutcome(setup.card, outcome!),
            setup.previous,
            setup.key,
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
    }
  }

  // Format 1, the seat's own card (the 4.4.29 rule): a fresh HTTPS sign-in
  // with the new key proves it before the card changes.
  Future<void> _activateMasterSetup(_LidarSetup setup) async {
    try {
      final approval = await LidarResetApproval.verify(
        setup.card,
        setup.previous,
      );
      final next = setup.card.copyWith(
        display: setup.card.display.copyWith(
          lidarGeneration: approval.generation,
        ),
      );
      next.generatedID = setup.previous.generatedID;
      await _store.save(next, key: setup.key, approval: approval);
      if (mounted) setState(() => _setup = null);
      await _load();
      _say(
        'Key saved locally. Server activation is required for admin access.',
      );
    } on StateError catch (_) {
      _say(_lockedNotice);
    } catch (_) {
      _say('Activation failed. Nothing changed.');
    }
  }

  void _cancelSetup() {
    if (_busy) return;
    setState(() {
      _setup = null;
      _notice = null;
    });
  }

  // The card asked and the owner confirmed (REMOVE, then REMOVE KEY).
  Future<void> _remove(Code card) async {
    if (!_start('remove')) return;
    try {
      await _store.remove(card);
      await _load();
      _say('Key removed from this device.');
    } catch (_) {
      _say('The key was not removed. Nothing changed.');
    } finally {
      _done();
    }
  }

  @override
  void dispose() {
    _updates?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setup = _setup;
    final card = setup?.card ?? _slotOf(_cards);
    final import = Text(
      _working == 'import' ? 'IMPORTING…' : 'IMPORT MASTER KEY .ENV',
    );
    const importIcon = Icon(Icons.file_upload_outlined, size: 18);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      children: [
        if (card == null) ...[
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
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFFB3B6BB),
            ),
          ),
          const SizedBox(height: 8),
          // No key yet: IMPORT is the one primary button.
          OutlinedButton.icon(
            key: const ValueKey('lidar-import'),
            onPressed: _busy ? null : _import,
            icon: importIcon,
            label: import,
          ),
        ] else ...[
          LidarFloatingCodeCard(
            key: ValueKey(setup == null ? 'lidar-card' : 'lidar-setup'),
            code: card,
            setup: setup != null,
            onRemove: setup == null ? () => _remove(card) : null,
          ),
          LidarKeyStatus(
            code: card,
            setup: setup != null,
            replaces: setup?.previous.display.lidarSeat,
            busy: _working == 'activate',
            disabled: _busy,
            onActivate: setup != null
                ? _activateSetup
                : () => _activateCard(card),
            onCancel: setup != null ? _cancelSetup : null,
          ),
          // A key in the slot: IMPORT drops to a link.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('lidar-import'),
              onPressed: _busy ? null : _import,
              icon: importIcon,
              label: import,
            ),
          ),
        ],
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _notice!,
              style: const TextStyle(
                color: Color(0xFFCACCD0),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                PlatformUtil.openUrlInBrowser('https://admin.lidarknight.com/'),
            icon: const Icon(Icons.open_in_new, size: 15),
            label: const Text('OPEN ADMIN ROOM'),
          ),
        ),
      ],
    );
  }
}

// Native file selection: the key stays in this process and encrypted local
// storage. Bounded stream, including when the file changes after the stat.
Future<List<int>?> _pickKeyFile() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['env'],
    allowMultiple: false,
    withData: false,
    dialogTitle: 'Import your individual LiDAR owner key',
  );
  if (result == null) return null;
  final picked = result.files.single;
  if (picked.size > LidarMasterKey.maxBytes || picked.path == null) {
    throw const FormatException('Choose one individual LiDAR owner ENV file.');
  }
  final bytes = <int>[];
  await for (final chunk in File(
    picked.path!,
  ).openRead(0, LidarMasterKey.maxBytes + 1)) {
    bytes.addAll(chunk);
  }
  return bytes;
}

/// A status sentence. Its state words, up to the first ': ' when that is
/// short (PENDING:, REFUSED (bad-code):, FAILED:), are bold.
Widget _statusText(String text, {Color ink = const Color(0xFFCACCD0)}) {
  final cut = text.indexOf(': ');
  final head = cut > 0 && cut < 40 ? text.substring(0, cut + 1) : '';
  return Text.rich(
    TextSpan(
      children: [
        if (head.isNotEmpty)
          TextSpan(
            text: head,
            style: const TextStyle(
              color: LkColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        TextSpan(text: text.substring(head.length)),
      ],
    ),
    style: TextStyle(color: ink, fontSize: 12, height: 1.45),
  );
}

/// REMOVE's question on the card (APP-FOLLOWUP, DeAndre 2026-10-06), word for
/// word. Removal is local only: server access ends only when a different
/// admin resets or revokes the seat.
const lidarRemoveQuestion =
    'Remove this key from this device? You will need a new key from an admin to sign in again.';

class LidarFloatingCodeCard extends StatefulWidget {
  final Code code;

  /// A newer key waiting in the slot (never stored until it is proved).
  final bool setup;

  /// REMOVE on the card, called only after the second step (REMOVE KEY).
  /// Null: no REMOVE (a waiting key is dropped with CANCEL instead).
  final VoidCallback? onRemove;
  const LidarFloatingCodeCard({
    super.key,
    required this.code,
    this.setup = false,
    this.onRemove,
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
  bool _confirming = false;
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
            widget.code.display.lidarGeneration ||
        oldWidget.code.display.lidarState != widget.code.display.lidarState ||
        oldWidget.setup != widget.setup) {
      _confirming = false;
      _hide();
    }
  }

  void _toggle() {
    if (_broken) return;
    if (_revealed) {
      _hide();
      return;
    }
    setState(() => _revealed = true);
    _refresh();
    _hideTimer = Timer(const Duration(seconds: 15), _hide);
  }

  // REMOVE, step 1: the card asks.
  void _askRemove() {
    _hide();
    setState(() => _confirming = true);
  }

  // REMOVE, step 2: REMOVE KEY.
  void _confirmRemove() {
    setState(() => _confirming = false);
    widget.onRemove?.call();
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

  // A key waiting in the slot, or a format-2 key the server has not
  // activated: its codes are shown (needed to activate) but never as a
  // signed-in admin credential.
  bool get _notActivated =>
      widget.setup ||
      (widget.code.display.lidarFormat == 2 &&
          widget.code.display.lidarState != 'active');

  // A BROKEN key never shows a code.
  bool get _broken => lidarBroken(widget.code.display);

  Widget _link(Key key, String label, VoidCallback onTap) => InkWell(
    key: key,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFFF8A7B),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  Widget get _header => Row(
    children: [
      const Icon(Icons.shield_outlined, color: Color(0xFFFF6558), size: 16),
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
      if (_broken)
        const LidarStateBadge(label: 'BROKEN', broken: true)
      else if (lidarStateLabel(widget.code.display, setup: widget.setup)
          case final label?)
        LidarStateBadge(
          label: label,
          active: widget.code.display.lidarState == 'active',
        ),
      const Icon(Icons.lock_outline, color: Color(0xFF9B9DA3), size: 14),
    ],
  );

  // BROKEN: the one reason line and what to do, in place of the code.
  List<Widget> get _brokenLines => [
    const SizedBox(height: 10),
    _statusText(lidarBrokenReason(widget.code.display), ink: LkColors.text),
    const SizedBox(height: 2),
    const Text(
      lidarBrokenAdvice,
      style: TextStyle(color: LkColors.red, fontSize: 12, height: 1.45),
    ),
  ];

  List<Widget> get _confirmLines => [
    const SizedBox(height: 10),
    const Text(
      lidarRemoveQuestion,
      style: TextStyle(color: LkColors.text, fontSize: 12.5, height: 1.45),
    ),
    const SizedBox(height: 10),
    Row(
      children: [
        OutlinedButton(
          key: const ValueKey('lidar-remove-confirm'),
          onPressed: _confirmRemove,
          child: const Text('REMOVE KEY'),
        ),
        const SizedBox(width: 12),
        TextButton(
          key: const ValueKey('lidar-remove-cancel'),
          onPressed: () => setState(() => _confirming = false),
          child: const Text('CANCEL'),
        ),
      ],
    ),
  ];

  Widget get _codeArea => Semantics(
    button: true,
    label: _revealed ? 'Hide admin code' : 'Reveal admin code',
    child: InkWell(
      onTap: _toggle,
      child: Center(
        // Replace immediately when hidden: never retain an outgoing readable
        // code during a fade animation.
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
  );

  Widget get _footer => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        _broken
            ? 'LOCAL VAULT · CODE HIDDEN'
            : _revealed
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
        _link(const ValueKey('lidar-copy'), 'COPY CODE', () async {
          final copied = _code;
          await Clipboard.setData(ClipboardData(text: copied));
          _lastCopied = copied;
        })
      else if (widget.onRemove != null)
        _link(const ValueKey('lidar-remove'), 'REMOVE', _askRemove),
    ],
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _scene,
    builder: (context, _) => Transform.translate(
      offset: Offset(0, math.sin(_scene.value * math.pi * 2) * 2),
      child: Container(
        // The REMOVE question grows the card; otherwise it keeps its size.
        height: _confirming ? null : 176,
        constraints: _confirming ? const BoxConstraints(minHeight: 176) : null,
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
                mainAxisSize: _confirming ? MainAxisSize.min : MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header,
                  if (_broken) ..._brokenLines,
                  if (_confirming)
                    ..._confirmLines
                  else if (_broken) ...[
                    const Spacer(),
                    _footer,
                  ] else ...[
                    Expanded(child: _codeArea),
                    _footer,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Why a BROKEN key stopped working (contract section 2), one line each.
const _lidarBrokenReasons = {
  'expired': 'EXPIRED: the activation deadline passed.',
  'failed': 'FAILED: 5 wrong activation codes.',
  'reissued': 'REISSUED: a newer key replaced this one.',
  'revoked': 'REVOKED: the seat was revoked or reset by a different admin.',
};

const _lidarBrokenNext = {
  'expired': ' Ask the inviting admin to reissue.',
  'failed': ' Ask the inviting admin to reissue.',
  'reissued': ' Import the newer file.',
  'revoked': '',
};

/// On a BROKEN card, under its reason.
const lidarBrokenAdvice = 'Ask an admin for a new key.';

/// A BROKEN key (4.4.31): a format-2 key that failed, expired, was revoked or
/// was reissued. It can never activate again; its code stays hidden and the
/// owner can only REMOVE it.
bool lidarBroken(CodeDisplay display) =>
    display.lidarFormat == 2 &&
    _lidarBrokenReasons.containsKey(display.lidarState);

/// The one reason line of a BROKEN key ('' for any other key).
String lidarBrokenReason(CodeDisplay display) =>
    lidarBroken(display) ? _lidarBrokenReasons[display.lidarState]! : '';

String _lidarEnded(String state) =>
    '${_lidarBrokenReasons[state]}${_lidarBrokenNext[state]}';

/// The card badge for an emailed (format-2) key, in the contract's state names;
/// a refusal shows its reason verbatim. A format-1 master card has no badge
/// unless it waits in the slot. The card itself shows BROKEN for an ended key.
String? lidarStateLabel(CodeDisplay display, {bool setup = false}) {
  if (display.lidarFormat != 2) return setup ? 'PENDING SETUP' : null;
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

/// What a card's state means (contract section 2), in plain words. For a key
/// waiting in the slot ([setup]), [replaces] names the seat of the card it
/// replaces (its own seat by default).
String lidarStateMessage(
  CodeDisplay display, {
  bool setup = false,
  String? replaces,
}) {
  final seat = replaces ?? display.lidarSeat;
  final waiting =
      'PENDING SETUP: this key replaces the $seat card only after admin.lidarknight.com activates it. Until then the $seat card stays as it is.';
  if (setup && display.lidarFormat != 2) return waiting;
  switch (display.lidarState) {
    case 'pending':
      return setup
          ? waiting
          : 'PENDING: saved on this device only, not activated and not signed in. ACTIVATE sends the current code to admin.lidarknight.com. Activate by ${lidarUtc(display.lidarActivateBy)}.';
    case 'refused':
      return setup
          ? 'REFUSED (${display.lidarReason}): this newer key was not activated. The $seat card stays as it was.'
          : 'REFUSED (${display.lidarReason}): the last activation was refused. The card stays as it was.';
    case 'active':
      return lidarActiveGuidance;
    case 'expired' || 'failed' || 'reissued' || 'revoked':
      return _lidarEnded(display.lidarState);
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
    case 'expired' || 'failed' || 'reissued' || 'revoked':
      return _lidarEnded(outcome.state);
    default:
      return 'Nothing changed.';
  }
}

class LidarStateBadge extends StatelessWidget {
  final String label;
  final bool active;

  /// BROKEN: the one red badge.
  final bool broken;
  const LidarStateBadge({
    super.key,
    required this.label,
    this.active = false,
    this.broken = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 190),
    margin: const EdgeInsets.symmetric(horizontal: 8),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFF14181D),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(
        color: broken
            ? LkColors.red
            : active
            ? const Color(0xFF8C9096)
            : const Color(0xFF71332F),
      ),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: broken
            ? LkColors.red
            : active
            ? const Color(0xFFF0EFE9)
            : const Color(0xFFFF8A7B),
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    ),
  );
}

/// Under the slot's card: its one status line, then ACTIVATE as the full-width
/// primary while the key is pending or refused (or waits in the slot), and
/// CANCEL under it for a waiting key. A BROKEN key says everything on its card.
class LidarKeyStatus extends StatelessWidget {
  final Code code;
  final bool setup;

  /// The seat of the card a waiting key replaces.
  final String? replaces;

  /// This key is activating.
  final bool busy;

  /// Another action is running.
  final bool disabled;
  final VoidCallback? onActivate;
  final VoidCallback? onCancel;
  const LidarKeyStatus({
    super.key,
    required this.code,
    this.setup = false,
    this.replaces,
    this.busy = false,
    this.disabled = false,
    this.onActivate,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final display = code.display;
    final broken = lidarBroken(display);
    final canActivate =
        !broken &&
        (setup ||
            (display.lidarFormat == 2 &&
                (display.lidarState == 'pending' ||
                    display.lidarState == 'refused')));
    final idle = !busy && !disabled;
    final status = broken
        ? ''
        : lidarStateMessage(display, setup: setup, replaces: replaces);
    final cancel = setup ? onCancel : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _statusText(status),
          ),
        if (!setup &&
            display.lidarFormat == 2 &&
            display.lidarState == 'active')
          const Text(
            'Empty Trash or Deleted Items too.',
            style: TextStyle(
              color: Color(0xFF949AA2),
              fontSize: 12,
              height: 1.45,
            ),
          ),
        if (canActivate && onActivate != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('lidar-activate'),
                onPressed: idle ? onActivate : null,
                icon: const Icon(Icons.verified_user_outlined, size: 16),
                label: Text(busy ? 'ACTIVATING…' : 'ACTIVATE'),
              ),
            ),
          ),
        if (cancel != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('lidar-cancel'),
              onPressed: idle ? cancel : null,
              child: const Text('CANCEL'),
            ),
          ),
      ],
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
