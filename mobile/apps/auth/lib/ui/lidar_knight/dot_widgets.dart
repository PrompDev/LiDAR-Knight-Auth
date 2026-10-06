// LiDAR-Knight Auth: widgets and painters that draw everything out of square
// red dots (dot text, dotted outlines, the diamond emblem, the background
// haze).
//
// Modified work notice (AGPL-3.0 section 5a): this file was added by the
// LiDAR-Knight Auth fork of Ente Auth in 2026. See CHANGES-LIDAR-KNIGHT.md.

import 'dart:async';
import 'dart:math' as math;

import 'package:ente_auth/theme/lidar_knight_theme.dart';
import 'package:flutter/material.dart';

/// The 4x4 ordered (Bayer) dither matrix. A dot at (x, y) is lit when
/// `level16 > kLkBayer4[y % 4][x % 4]`, where level16 runs from 0 to 16.
const List<List<int>> kLkBayer4 = [
  [0, 8, 2, 10],
  [12, 4, 14, 6],
  [3, 11, 1, 9],
  [15, 7, 13, 5],
];

/// 5x7 dot glyphs. Rows run top to bottom and are separated by spaces.
/// `#` is a red dot, `*` a cream highlight dot and `.` is empty.
const Map<String, String> kLkDotGlyphs = {
  '0': '.###. #...# #...# #.#.# #...# #...# .###.',
  '1': '..#.. .##.. ..#.. ..#.. ..#.. ..#.. .###.',
  '2': '.###. #...# ....# ...#. ..#.. .#... #####',
  '3': '####. ....# ....# .###. ....# ....# ####.',
  '4': '...#. ..##. .#.#. #..#. ##### ...#. ...#.',
  '5': '##### #.... ####. ....# ....# #...# .###.',
  '6': '..##. .#... #.... ####. #...# #...# .###.',
  '7': '##### ....# ...#. ..#.. .#... .#... .#...',
  '8': '.###. #...# #...# .###. #...# #...# .###.',
  '9': '.###. #...# #...# .#### ....# ...#. .##..',
  'A': '.###. #...# #...# ##### #...# #...# #...#',
  'B': '####. #...# #...# ####. #...# #...# ####.',
  'C': '.###. #...# #.... #.... #.... #...# .###.',
  'D': '####. #...# #...# #...# #...# #...# ####.',
  'E': '##### #.... #.... ####. #.... #.... #####',
  'F': '##### #.... #.... ####. #.... #.... #....',
  'G': '.###. #...# #.... #.### #...# #...# .####',
  'H': '#...# #...# #...# ##### #...# #...# #...#',
  'I': '.###. ..#.. ..#.. ..#.. ..#.. ..#.. .###.',
  'J': '..### ...#. ...#. ...#. ...#. #..#. .##..',
  'K': '#...# #..#. #.#.. ##... #.#.. #..#. #...#',
  'L': '#.... #.... #.... #.... #.... #.... #####',
  'M': '#...# ##.## #.#.# #.#.# #...# #...# #...#',
  'N': '#...# #...# ##..# #.#.# #..## #...# #...#',
  'O': '.###. #...# #...# #...# #...# #...# .###.',
  'P': '####. #...# #...# ####. #.... #.... #....',
  'Q': '.###. #...# #...# #...# #.#.# #..#. .##.#',
  'R': '####. #...# #...# ####. #.#.. #..#. #...#',
  'S': '.#### #.... #.... .###. ....# ....# ####.',
  'T': '##### ..#.. ..#.. ..#.. ..#.. ..#.. ..#..',
  'U': '#...# #...# #...# #...# #...# #...# .###.',
  'V': '#...# #...# #...# #...# #...# .#.#. ..#..',
  'W': '#...# #...# #...# #.#.# #.#.# #.#.# .#.#.',
  'X': '#...# #...# .#.#. ..#.. .#.#. #...# #...#',
  'Y': '#...# #...# .#.#. ..#.. ..#.. ..#.. ..#..',
  'Z': '##### ....# ...#. ..#.. .#... #.... #####',
  'i': '..*.. ..... .##.. ..#.. ..#.. ..#.. .###.',
  '-': '..... ..... ..... .###. ..... ..... .....',
  '.': '..... ..... ..... ..... ..... ..... ..#..',
  ':': '..... ..#.. ..... ..... ..... ..#.. .....',
  '/': '....# ....# ...#. ..#.. .#... #.... #....',
  '!': '..#.. ..#.. ..#.. ..#.. ..#.. ..... ..#..',
  '?': '.###. #...# ....# ...#. ..#.. ..... ..#..',
  '+': '..... ..#.. ..#.. ##### ..#.. ..#.. .....',
};

const int _glyphColumns = 5;
const int _glyphRows = 7;
const int _glyphAdvance = 6;
const int _spaceAdvance = 3;

String? _glyphFor(String char) =>
    kLkDotGlyphs[char] ?? kLkDotGlyphs[char.toUpperCase()];

int _dotTextColumns(String text) {
  int columns = 0;
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    columns += _glyphFor(char) == null ? _spaceAdvance : _glyphAdvance;
  }
  // No trailing gap after the last glyph.
  return math.max(0, columns - 1);
}

/// Text drawn from 5x7 square dots.
///
/// Lower-case letters are drawn as capitals except `i`, whose dot is a cream
/// highlight. Unknown characters become a narrow gap. The widget exposes
/// [text] to screen readers.
class LkDotText extends StatelessWidget {
  const LkDotText(
    this.text, {
    super.key,
    this.pitch = 3,
    this.dotSize,
    this.color = LkColors.red,
    this.highlightColor = LkColors.cream,
  });

  final String text;

  /// Distance between dot centres, in logical pixels.
  final double pitch;

  /// Side of each square dot. Defaults to one pixel less than [pitch].
  final double? dotSize;
  final Color color;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    final columns = _dotTextColumns(text);
    return Semantics(
      label: text,
      container: true,
      child: CustomPaint(
        size: Size(columns * pitch, _glyphRows * pitch),
        painter: _LkDotTextPainter(
          text: text,
          pitch: pitch,
          dotSize: dotSize ?? math.max(1.0, pitch - 1),
          color: color,
          highlightColor: highlightColor,
        ),
      ),
    );
  }
}

class _LkDotTextPainter extends CustomPainter {
  _LkDotTextPainter({
    required this.text,
    required this.pitch,
    required this.dotSize,
    required this.color,
    required this.highlightColor,
  });

  final String text;
  final double pitch;
  final double dotSize;
  final Color color;
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = color
      ..isAntiAlias = false;
    final highlightPaint = Paint()
      ..color = highlightColor
      ..isAntiAlias = false;
    int column = 0;
    for (final rune in text.runes) {
      final glyph = _glyphFor(String.fromCharCode(rune));
      if (glyph == null) {
        column += _spaceAdvance;
        continue;
      }
      final rows = glyph.split(' ');
      for (int y = 0; y < rows.length && y < _glyphRows; y++) {
        final row = rows[y];
        for (int x = 0; x < row.length && x < _glyphColumns; x++) {
          final cell = row[x];
          if (cell == '.') continue;
          canvas.drawRect(
            Rect.fromLTWH((column + x) * pitch, y * pitch, dotSize, dotSize),
            cell == '*' ? highlightPaint : dotPaint,
          );
        }
      }
      column += _glyphAdvance;
    }
  }

  @override
  bool shouldRepaint(_LkDotTextPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.pitch != pitch ||
        oldDelegate.dotSize != dotSize ||
        oldDelegate.color != color ||
        oldDelegate.highlightColor != highlightColor;
  }
}

/// Draws a 3x3 plus-shaped diamond of dots centred on [center].
void _drawDiamondMarker(
  Canvas canvas,
  Offset center,
  double pitch,
  double dot,
  Paint paint,
) {
  const cells = [
    [0, -1],
    [-1, 0],
    [0, 0],
    [1, 0],
    [0, 1],
  ];
  for (final cell in cells) {
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx + cell[0] * pitch - dot / 2,
        center.dy + cell[1] * pitch - dot / 2,
        dot,
        dot,
      ),
      paint,
    );
  }
}

/// A dotted one-dot outline around a rectangle. With [showMarkers] a small
/// diamond sits at the middle of the left and right edges (selected rows).
class LkDotOutlinePainter extends CustomPainter {
  const LkDotOutlinePainter({
    this.color = LkColors.redOutline,
    this.pitch = 4,
    this.dotSize = 2,
    this.showMarkers = false,
    this.markerColor = LkColors.red,
  });

  final Color color;
  final double pitch;
  final double dotSize;
  final bool showMarkers;
  final Color markerColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < dotSize || size.height < dotSize) return;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    final right = size.width - dotSize;
    final bottom = size.height - dotSize;
    for (double x = 0; x <= right; x += pitch) {
      canvas.drawRect(Rect.fromLTWH(x, 0, dotSize, dotSize), paint);
      canvas.drawRect(Rect.fromLTWH(x, bottom, dotSize, dotSize), paint);
    }
    for (double y = pitch; y < bottom; y += pitch) {
      canvas.drawRect(Rect.fromLTWH(0, y, dotSize, dotSize), paint);
      canvas.drawRect(Rect.fromLTWH(right, y, dotSize, dotSize), paint);
    }
    if (showMarkers) {
      final markerPaint = Paint()
        ..color = markerColor
        ..isAntiAlias = false;
      final markerDot = dotSize + 1;
      final markerPitch = markerDot + 1;
      final midY = size.height / 2;
      _drawDiamondMarker(
        canvas,
        Offset(markerPitch * 1.5, midY),
        markerPitch,
        markerDot,
        markerPaint,
      );
      _drawDiamondMarker(
        canvas,
        Offset(size.width - markerPitch * 1.5, midY),
        markerPitch,
        markerDot,
        markerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(LkDotOutlinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.pitch != pitch ||
        oldDelegate.dotSize != dotSize ||
        oldDelegate.showMarkers != showMarkers ||
        oldDelegate.markerColor != markerColor;
  }
}

/// A row of square dots that counts down: lit dots show the time left and go
/// out from the right. In the last few seconds the lit dots turn cream.
class LkDotCountdownPainter extends CustomPainter {
  const LkDotCountdownPainter({
    required this.progress,
    required this.highlight,
    this.color = LkColors.red,
    this.highlightColor = LkColors.cream,
    this.offColor = LkColors.redSoft,
  });

  /// Fraction of the period left, from 1 down to 0.
  final double progress;

  /// True in the last seconds of the period.
  final bool highlight;
  final Color color;
  final Color highlightColor;
  final Color offColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0 || size.width <= 0) return;
    final dot = size.height;
    final pitch = dot + 1;
    final count = math.max(1, ((size.width + 1) / pitch).floor());
    final double left = progress < 0 ? 0 : (progress > 1 ? 1 : progress);
    final lit = (left * count).ceil();
    final onPaint = Paint()
      ..color = highlight ? highlightColor : color
      ..isAntiAlias = false;
    final offPaint = Paint()
      ..color = offColor
      ..isAntiAlias = false;
    for (int i = 0; i < count; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * pitch, 0, dot, dot),
        i < lit ? onPaint : offPaint,
      );
    }
  }

  @override
  bool shouldRepaint(LkDotCountdownPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.highlight != highlight ||
        oldDelegate.color != color ||
        oldDelegate.highlightColor != highlightColor ||
        oldDelegate.offColor != offColor;
  }
}

/// The empty-state emblem: an outline diamond of square dots around a dot
/// keyhole, with a cream dot on the top point. The fill pulses in Bayer
/// steps (0 to 4/16 and back over two seconds) unless animations are off.
class LkDiamondEmblem extends StatefulWidget {
  const LkDiamondEmblem({super.key, this.size = 150});

  final double size;

  @override
  State<LkDiamondEmblem> createState() => _LkDiamondEmblemState();
}

class _LkDiamondEmblemState extends State<LkDiamondEmblem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final level = _controller.isAnimating
                ? (4 * (1 - (2 * t - 1).abs())).round()
                : 2;
            return CustomPaint(painter: _LkEmblemPainter(fillLevel: level));
          },
        ),
      ),
    );
  }
}

class _LkEmblemPainter extends CustomPainter {
  _LkEmblemPainter({required this.fillLevel});

  /// Fill density in sixteenths (0 to 16).
  final int fillLevel;

  static const int _grid = 15;
  static const int _c = _grid ~/ 2;

  // Keyhole, 5 columns x 7 rows, centred on the emblem.
  static const List<String> _keyhole = [
    '.###.',
    '#####',
    '#####',
    '.###.',
    '..#..',
    '.###.',
    '#####',
  ];

  bool _isKeyhole(int x, int y) {
    final kx = x - (_c - 2);
    final ky = y - (_c - 3);
    if (kx < 0 || kx >= 5 || ky < 0 || ky >= _keyhole.length) return false;
    return _keyhole[ky][kx] == '#';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pitch = (math.min(size.width, size.height) / _grid).floorToDouble();
    if (pitch < 2) return;
    final dot = pitch - 1;
    final origin = Offset(
      ((size.width - pitch * _grid) / 2).floorToDouble(),
      ((size.height - pitch * _grid) / 2).floorToDouble(),
    );
    final red = Paint()
      ..color = LkColors.red
      ..isAntiAlias = false;
    final dim = Paint()
      ..color = LkColors.redDim
      ..isAntiAlias = false;
    final cream = Paint()
      ..color = LkColors.cream
      ..isAntiAlias = false;
    for (int y = 0; y < _grid; y++) {
      for (int x = 0; x < _grid; x++) {
        final d = (x - _c).abs() + (y - _c).abs();
        Paint? paint;
        if (d == _c) {
          paint = (x == _c && y == 0) ? cream : red;
        } else if (d < _c) {
          if (_isKeyhole(x, y)) {
            paint = red;
          } else if (fillLevel > kLkBayer4[y & 3][x & 3]) {
            paint = dim;
          }
        }
        if (paint == null) continue;
        canvas.drawRect(
          Rect.fromLTWH(origin.dx + x * pitch, origin.dy + y * pitch, dot, dot),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LkEmblemPainter oldDelegate) =>
      oldDelegate.fillLevel != fillLevel;
}

/// Opaque black LiDAR scene: drifting mist, sparse scan points and a dark
/// corridor silhouette. Information is rendered by the child in crisp text.
/// Reduced-motion preferences and background lifecycle pause the animation.
class LkBackdrop extends StatefulWidget {
  const LkBackdrop({super.key, required this.child});
  final Widget child;

  @override
  State<LkBackdrop> createState() => _LkBackdropState();
}

class _LkBackdropState extends State<LkBackdrop> with WidgetsBindingObserver {
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);
  Timer? _timer;

  bool get _reduceMotion => WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .disableAnimations;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = null;
    if (_reduceMotion) return;
    _timer = Timer.periodic(
      const Duration(milliseconds: 125),
      (_) => _tick.value = _tick.value + 1,
    );
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else {
      _stop();
    }
  }

  @override
  void didChangeAccessibilityFeatures() => _start();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _LkScenePainter(tick: _tick),
    child: RepaintBoundary(child: widget.child),
  );
}

class _LkScenePainter extends CustomPainter {
  _LkScenePainter({required this.tick}) : super(repaint: tick);
  final ValueNotifier<int> tick;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = LkColors.black);
    if (size.isEmpty) return;
    final phase = tick.value / 80.0;
    final glow = Offset(
      size.width * (0.78 + 0.03 * math.sin(phase)),
      size.height * (0.58 + 0.05 * math.cos(phase * 0.7)),
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader =
            const RadialGradient(
              colors: [
                Color(0x1AFF2A12),
                Color(0x060D141C),
                Colors.transparent,
              ],
              stops: [0, 0.55, 1],
            ).createShader(
              Rect.fromCircle(center: glow, radius: size.width * 0.65),
            ),
    );

    // A quiet, distant hall drawn as surveyed geometry rather than a noisy
    // full-screen matrix. The central code panel always takes priority.
    final vanishing = Offset(size.width * 0.76, size.height * 0.38);
    final line = Paint()
      ..color = const Color(0x267D2019)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (int i = 0; i < 6; i++) {
      final depth = (i + 1) / 7;
      final spread = size.width * depth * 0.52;
      final top = vanishing.dy - size.height * depth * 0.30;
      final bottom = vanishing.dy + size.height * depth * 0.60;
      final hall = Path()
        ..moveTo(vanishing.dx - spread, bottom)
        ..lineTo(vanishing.dx - spread, top + spread * 0.32)
        ..lineTo(vanishing.dx, top)
        ..lineTo(vanishing.dx + spread, top + spread * 0.32)
        ..lineTo(vanishing.dx + spread, bottom);
      canvas.drawPath(hall, line);
    }
    for (int i = 0; i < 9; i++) {
      final x = size.width * i / 8;
      canvas.drawLine(vanishing, Offset(x, size.height), line);
    }

    // Sparse point cloud on the outer scene. No dots are used for labels,
    // buttons or codes and no desktop content is visible underneath.
    final random = math.Random(6238);
    final point = Paint()..color = const Color(0x427D2019);
    for (int i = 0; i < 90; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final centre = (x / size.width - 0.5).abs();
      if (centre < 0.29 && y < size.height * 0.80) continue;
      final drift = math.sin(phase + i * 0.17) * 1.5;
      canvas.drawCircle(Offset(x, y + drift), i % 9 == 0 ? 1.1 : 0.55, point);
    }
    final scanY = size.height * ((tick.value % 480) / 480);
    canvas.drawRect(
      Rect.fromLTWH(0, scanY, size.width, 24),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0x087D2019), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, scanY, size.width, 24)),
    );
  }

  @override
  bool shouldRepaint(_LkScenePainter oldDelegate) => oldDelegate.tick != tick;
}
