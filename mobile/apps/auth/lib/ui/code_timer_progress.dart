import 'dart:async';
import 'dart:io';

import 'package:ente_auth/ui/lidar_knight/dot_widgets.dart';
import 'package:flutter/material.dart';

class CodeTimerProgress extends StatefulWidget {
  final int period;
  final bool isCompactMode;
  final int timeOffsetInMilliseconds;
  const CodeTimerProgress({
    super.key,
    required this.period,
    this.isCompactMode = false,
    this.timeOffsetInMilliseconds = 0,
  });

  @override
  State<CodeTimerProgress> createState() => _CodeTimerProgressState();
}

class _CodeTimerProgressState extends State<CodeTimerProgress> {
  late final Timer _timer;
  late final ValueNotifier<double> _progress;
  late final int _periodInMilii;

  final int _updateIntervalMs = (Platform.isAndroid || Platform.isIOS)
      ? 16
      : 500;

  @override
  void initState() {
    super.initState();
    _periodInMilii = widget.period * 1000;
    _progress = ValueNotifier<double>(0.0);
    _updateTimeRemaining(DateTime.now().millisecondsSinceEpoch);

    _timer = Timer.periodic(Duration(milliseconds: _updateIntervalMs), (timer) {
      final now = DateTime.now().millisecondsSinceEpoch;
      _updateTimeRemaining(now);
    });
  }

  void _updateTimeRemaining(int currentMilliSeconds) {
    final elapsed =
        (currentMilliSeconds + widget.timeOffsetInMilliseconds) %
        _periodInMilii;
    final timeRemaining = _periodInMilii - elapsed;
    _progress.value = timeRemaining / _periodInMilii;
  }

  @override
  void didUpdateWidget(covariant CodeTimerProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _periodInMilii = widget.period * 1000;
      _updateTimeRemaining(DateTime.now().millisecondsSinceEpoch);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.isCompactMode ? 2 : 3,
      width: double.infinity,
      child: ValueListenableBuilder<double>(
        valueListenable: _progress,
        builder: (context, progress, _) {
          // LiDAR-Knight Auth: a row of square dots counts down; in the
          // last five seconds the lit dots turn cream.
          return CustomPaint(
            painter: LkDotCountdownPainter(
              progress: progress,
              highlight: progress * widget.period <= 5,
            ),
          );
        },
      ),
    );
  }
}
