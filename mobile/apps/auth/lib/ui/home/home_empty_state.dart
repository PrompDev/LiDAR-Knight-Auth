import 'package:ente_auth/theme/lidar_knight_theme.dart';
import 'package:ente_auth/ui/settings/data/import_page.dart';
import 'package:ente_auth/utils/platform_util.dart';
import 'package:ente_pure_utils/ente_pure_utils.dart';
import 'package:ente_strings/ente_strings.dart';
import 'package:flutter/material.dart';

/// Compact standard-auth entry. LiDAR admin enrollment has its own tab.
/// All QR/manual/import routes remain their original callbacks.
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
    final isMobile = PlatformDetector.isMobile();
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Semantics(
      container: true,
      identifier: 'auth_empty_state',
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 12 + safeBottom),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/icons/lidar-knight-auth.png',
                        width: 40,
                        height: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.setupFirstAccount,
                          style: const TextStyle(
                            fontFamily: kLkFontFamily,
                            fontWeight: FontWeight.w600,
                            color: LkColors.text,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Standard authenticator accounts. Your codes are generated '
                    'privately on this device.',
                    style: TextStyle(
                      fontFamily: kLkFontFamily,
                      color: LkColors.textMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    button: true,
                    identifier: isMobile
                        ? 'auth_empty_scan'
                        : 'auth_empty_gallery',
                    child: ElevatedButton.icon(
                      onPressed: isMobile ? onScanTap : onImportImageTap,
                      icon: Icon(
                        isMobile ? Icons.qr_code_scanner : Icons.image_outlined,
                        size: 18,
                      ),
                      label: Text(
                        isMobile ? l10n.scanAQrCode : l10n.importFromGallery,
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    button: true,
                    identifier: 'auth_empty_manual_setup',
                    child: OutlinedButton.icon(
                      onPressed: onManuallySetupTap,
                      icon: const Icon(Icons.key_outlined, size: 18),
                      label: Text(l10n.importEnterSetupKey),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LkColors.text,
                        backgroundColor: LkColors.row,
                        side: const BorderSide(color: LkColors.redOutline),
                        minimumSize: const Size(0, 42),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () =>
                            routeToPage(context, const ImportCodePage()),
                        child: Text(l10n.importCodes),
                      ),
                      TextButton(
                        onPressed: () => PlatformUtil.openUrlInBrowser(
                          'https://ente.com/help/auth/faq',
                        ),
                        child: Text(l10n.faq),
                      ),
                    ],
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
