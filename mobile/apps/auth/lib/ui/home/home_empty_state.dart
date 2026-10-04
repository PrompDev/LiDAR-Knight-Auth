import 'package:ente_auth/ui/lidar_knight/dot_widgets.dart';
import 'package:ente_auth/ui/settings/data/import_page.dart';
import 'package:ente_auth/utils/platform_util.dart';
import 'package:ente_components/ente_components.dart';
import 'package:ente_pure_utils/ente_pure_utils.dart';
import 'package:ente_strings/ente_strings.dart';
import 'package:flutter/material.dart';

class HomeEmptyStateWidget extends StatelessWidget {
  final VoidCallback? onScanTap;
  final VoidCallback? onImportImageTap;
  final VoidCallback? onManuallySetupTap;

  const HomeEmptyStateWidget({
    super.key,
    required this.onScanTap,
    required this.onImportImageTap,
    required this.onManuallySetupTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.strings;
    final colors = context.componentColors;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final extraBottomPadding = PlatformDetector.isMobile()
        ? (bottomPadding > 0 ? bottomPadding : 24.0)
        : 24.0;

    return Semantics(
      container: true,
      identifier: 'auth_empty_state',
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: Spacing.xl,
                right: Spacing.xl,
                top: Spacing.xl,
                bottom: extraBottomPadding,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // LiDAR-Knight Auth: a pulsing dot diamond around a
                        // keyhole instead of the upstream illustration.
                        const SizedBox(
                          height: 188,
                          child: Center(child: LkDiamondEmblem(size: 165)),
                        ),
                        const SizedBox(height: Spacing.xxl),
                        SizedBox(
                          width: 240,
                          child: Text(
                            l10n.setupFirstAccount,
                            textAlign: TextAlign.center,
                            style: TextStyles.h1.copyWith(
                              color: colors.textBase,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.xxl),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (PlatformDetector.isMobile()) ...[
                            Semantics(
                              button: true,
                              identifier: 'auth_empty_scan',
                              child: ButtonComponent(
                                label: l10n.scanAQrCode,
                                onTap: onScanTap,
                              ),
                            ),
                          ] else ...[
                            Semantics(
                              button: true,
                              identifier: 'auth_empty_gallery',
                              child: ButtonComponent(
                                label: l10n.importFromGallery,
                                onTap: onImportImageTap,
                              ),
                            ),
                          ],
                          const SizedBox(height: Spacing.md),
                          Semantics(
                            button: true,
                            identifier: 'auth_empty_manual_setup',
                            child: ButtonComponent(
                              label: l10n.importEnterSetupKey,
                              variant: ButtonComponentVariant.secondary,
                              onTap: onManuallySetupTap,
                            ),
                          ),
                          const SizedBox(height: Spacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ButtonComponent(
                                label: l10n.importCodes,
                                size: ButtonComponentSize.small,
                                variant: ButtonComponentVariant.link,
                                onTap: () {
                                  routeToPage(context, const ImportCodePage());
                                },
                              ),
                              ButtonComponent(
                                label: l10n.faq,
                                size: ButtonComponentSize.small,
                                variant: ButtonComponentVariant.link,
                                onTap: () {
                                  PlatformUtil.openUrlInBrowser(
                                    'https://ente.com/help/auth/faq',
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
