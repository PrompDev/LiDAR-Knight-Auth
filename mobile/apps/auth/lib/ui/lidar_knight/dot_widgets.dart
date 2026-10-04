// LiDAR-Knight Auth: widgets and painters that draw everything out of square
// red dots (dot text, dotted outlines, the diamond emblem, the background
// haze).
//
// Modified work notice (AGPL-3.0 section 5a): this file was added by the
// LiDAR-Knight Auth fork of Ente Auth in 2026. See CHANGES-LIDAR-KNIGHT.md.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

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

/// The window backdrop: a translucent black veil (opaque on phones, which
/// cannot show what is behind the app) with a red Bayer dither haze that
/// shimmers twelve times a second.
///
/// It sits above every MaterialApp so pages with transparent scaffolds show
/// it. The haze stays still when the system asks for reduced motion, and
/// it stops while the app is in the background.
class LkBackdrop extends StatefulWidget {
  const LkBackdrop({super.key, required this.child});

  final Widget child;

  @override
  State<LkBackdrop> createState() => _LkBackdropState();
}

class _LkBackdropState extends State<LkBackdrop> with WidgetsBindingObserver {
  static const Duration _frame = Duration(milliseconds: 83); // ~12 fps

  final ValueNotifier<int> _tick = ValueNotifier<int>(0);
  final _LkHazeField _field = _LkHazeField();
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
    _timer = Timer.periodic(_frame, (_) => _tick.value = _tick.value + 1);
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
  void didChangeAccessibilityFeatures() {
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = Platform.isAndroid || Platform.isIOS;
    return CustomPaint(
      painter: _LkHazePainter(
        tick: _tick,
        field: _field,
        veil: isMobile ? LkColors.black : LkColors.veil,
      ),
      child: RepaintBoundary(child: widget.child),
    );
  }
}

/// Caches the haze density per cell so a frame only re-thresholds it.
class _LkHazeField {
  static const double pitch = 3;
  static const double dot = 2;

  int _columns = 0;
  int _rows = 0;
  int _epoch = -1;
  Uint8List _levels = Uint8List(0);
  Float32List _points = Float32List(0);

  void _rebuild(int columns, int rows, int epoch) {
    _columns = columns;
    _rows = rows;
    _epoch = epoch;
    _levels = Uint8List(columns * rows);
    _points = Float32List(columns * rows * 2);
    // Two slow patches near the lower-left and upper-right corners thicken
    // the haze to 8/16. The middle, where the codes sit, stays at 2/16.
    final drift = epoch * 0.15;
    final ax = 0.12 + 0.05 * math.sin(drift);
    final ay = 0.88 + 0.04 * math.cos(drift * 0.7);
    final bx = 0.88 + 0.05 * math.cos(drift * 0.9);
    final by = 0.12 + 0.04 * math.sin(drift * 1.3);
    for (int y = 0; y < rows; y++) {
      final ny = rows <= 1 ? 0.0 : y / (rows - 1);
      for (int x = 0; x < columns; x++) {
        final nx = columns <= 1 ? 0.0 : x / (columns - 1);
        final da = math.sqrt((nx - ax) * (nx - ax) + (ny - ay) * (ny - ay));
        final db = math.sqrt((nx - bx) * (nx - bx) + (ny - by) * (ny - by));
        final boost =
            6 * math.max(0.0, 1 - da / 0.45) + 6 * math.max(0.0, 1 - db / 0.45);
        _levels[y * columns + x] = math.min(8, (2 + boost).round());
      }
    }
  }

  /// Returns the centres of the lit dots for this frame.
  Float32List pointsFor(Size size, int tick, int ox, int oy) {
    final columns = (size.width / pitch).ceil();
    final rows = (size.height / pitch).ceil();
    // The patches move every two seconds (24 frames).
    final epoch = tick ~/ 24;
    if (columns != _columns || rows != _rows || epoch != _epoch) {
      _rebuild(columns, rows, epoch);
    }
    int n = 0;
    for (int y = 0; y < rows; y++) {
      final bayerRow = kLkBayer4[(y + oy) & 3];
      for (int x = 0; x < columns; x++) {
        if (_levels[y * columns + x] > bayerRow[(x + ox) & 3]) {
          _points[n++] = x * pitch + pitch / 2;
          _points[n++] = y * pitch + pitch / 2;
        }
      }
    }
    return Float32List.sublistView(_points, 0, n);
  }
}

class _LkHazePainter extends CustomPainter {
  _LkHazePainter({required this.tick, required this.field, required this.veil})
    : super(repaint: tick);

  final ValueNotifier<int> tick;
  final _LkHazeField field;
  final Color veil;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = veil);
    final frame = tick.value;
    // A new random Bayer offset every frame makes the haze shimmer.
    final random = math.Random(frame);
    final ox = frame == 0 ? 0 : random.nextInt(4);
    final oy = frame == 0 ? 0 : random.nextInt(4);
    final points = field.pointsFor(size, frame, ox, oy);
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = LkColors.redDim
      ..strokeWidth = _LkHazeField.dot
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = false;
    canvas.drawRawPoints(ui.PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(_LkHazePainter oldDelegate) =>
      oldDelegate.veil != veil || oldDelegate.field != field;
}
