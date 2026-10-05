import 'package:ente_auth/theme/lidar_knight_theme.dart';
import 'package:ente_auth/ui/lidar_knight/dot_widgets.dart';
import 'package:flutter/material.dart';

enum LkStartupStage {
  desktop,
  appearance,
  storage,
  network,
  services,
  interface,
}

extension on LkStartupStage {
  String get label => switch (this) {
    LkStartupStage.desktop => 'Preparing the window',
    LkStartupStage.appearance => 'Loading the dot theme',
    LkStartupStage.storage => 'Opening secure local storage',
    LkStartupStage.network => 'Preparing connection settings',
    LkStartupStage.services => 'Starting the authenticator',
    LkStartupStage.interface => 'Opening your authenticator',
  };
}

class LkStartupState {
  const LkStartupState(this.stage, {this.failed = false});
  final LkStartupStage stage;
  final bool failed;
}

/// This screen contains no account data. Failed initialization cannot open
/// the authenticator or bypass its lock; only completed startup replaces it.
class LkStartupScreen extends StatelessWidget {
  const LkStartupScreen({super.key, required this.state});
  final ValueNotifier<LkStartupState> state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: kLkFontFamily),
      ),
      home: LkBackdrop(
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: ValueListenableBuilder<LkStartupState>(
                    valueListenable: state,
                    builder: (context, current, _) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/icons/lidar-knight-auth.png',
                          width: 160,
                          height: 160,
                        ),
                        const SizedBox(height: 24),
                        const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: LkDotText('LiDAR-Knight Auth', pitch: 2.5),
                        ),
                        const SizedBox(height: 24),
                        if (!current.failed)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: LkColors.red,
                            ),
                          ),
                        const SizedBox(height: 20),
                        Text(
                          current.failed
                              ? 'Startup could not finish'
                              : current.stage.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: LkColors.red,
                            fontSize: 18,
                          ),
                        ),
                        if (current.failed) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Stage: ${current.stage.label}\nClose and reopen the app. '
                            'Your saved codes have not been reset.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: LkColors.cream,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
