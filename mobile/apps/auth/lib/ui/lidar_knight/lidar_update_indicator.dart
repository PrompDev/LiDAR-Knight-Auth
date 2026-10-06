import 'package:ente_auth/services/lidar_update_notice.dart';
import 'package:ente_auth/theme/lidar_knight_theme.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// The update notice right of the ☰ menu (Auth 4.4.31). Nothing at all unless a
/// newer release is published. Then a small down-arrow in house red; hovering
/// (desktop) or a long press (mobile) shows ONLY DeAndre's message, one plain
/// paragraph on a solid dark plate (no title, no header, no version line). A
/// click opens the Auth page on lidarknight.com. A gentle pulse, off when the
/// system asks for reduced motion.
class LidarUpdateIndicator extends StatefulWidget {
  final LidarUpdateNotice notice;

  LidarUpdateIndicator({super.key, LidarUpdateNotice? notice})
    : notice = notice ?? LidarUpdateNotice.instance;

  @override
  State<LidarUpdateIndicator> createState() => _LidarUpdateIndicatorState();
}

class _LidarUpdateIndicatorState extends State<LidarUpdateIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
    lowerBound: 0.55,
    upperBound: 1,
    value: 1,
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _syncPulse(bool show, bool reduceMotion) {
    if (show && !reduceMotion) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return ValueListenableBuilder<LidarUpdateInfo?>(
      valueListenable: widget.notice.available,
      builder: (context, info, _) {
        _syncPulse(info != null, reduceMotion);
        if (info == null) return const SizedBox.shrink();
        return Tooltip(
          key: const ValueKey('lidar-update-tooltip'),
          richMessage: WidgetSpan(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                info.message,
                key: const ValueKey('lidar-update-message'),
                softWrap: true,
                style: const TextStyle(
                  fontFamily: kLkFontFamily,
                  fontSize: 13.5,
                  height: 1.4,
                  color: LkColors.cream,
                ),
              ),
            ),
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0606),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: LkColors.redDim),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          waitDuration: const Duration(milliseconds: 250),
          showDuration: const Duration(seconds: 8),
          preferBelow: true,
          child: Semantics(
            button: true,
            label: 'Update available',
            hint: info.message,
            child: FadeTransition(
              opacity: _pulse,
              child: IconButton(
                key: const ValueKey('lidar-update-button'),
                icon: const Icon(
                  Icons.download_rounded,
                  color: LkColors.red,
                  size: 20,
                ),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => launchUrl(
                  info.url,
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
