# LiDAR-Knight Auth: changes from upstream Ente Auth

LiDAR-Knight Auth is a modified version of [Ente Auth](https://github.com/ente/ente/tree/main/mobile/apps/auth) by Ente Technologies, Inc. Like the original, it is licensed under the GNU Affero General Public License v3.0 (see `LICENSE` at the repository root). This file is the prominent notice of modifications required by AGPL-3.0 section 5(a).

- **Based on:** `ente/ente` at commit `670a770` ("[mobile] Remember Auth's selected tag (#13367)").
- **Modified:** 2026-10-04, by LiDAR-Knight Auth contributors.
- **Kept from upstream:** all code generation, encrypted storage, import, export and sync logic. The changes below cover the name, the look and a few defaults.

## What changed

1. **Name.** The app is called "LiDAR-Knight Auth" on every platform: window titles, the Windows file information, the Linux desktop entry, the iOS and macOS display names, the Android label and quick-settings tile, the web manifest, the tray tooltip and the in-app title. The English strings, plus the `offlineKeyUnavailableMessage` string in other languages where it named the product, use the new name. The shared `enteAuth` string is deliberately left as "Ente Auth" in every language: its only use is the Ente account-deletion screen, where it names Ente's own apps. The Dart package name, the iOS and Android IDs, data file names and URL scheme are unchanged (see "Not changed yet"); the desktop IDs changed (item 13).
2. **Red-dot theme.** Everything is drawn in hot red (`#FF2A12`) square dots on black, with rare cream (`#FFD8CC`) highlights. Warnings use cream rather than a second red. The app is dark-only: the light theme is the same as the dark theme.
3. **Dot-matrix type.** All text uses [Doto](https://github.com/oliverlalan/Doto) by Óliver Lalan (SIL Open Font License 1.1). The font is bundled at `assets/fonts/doto/` with its `OFL.txt` and is never downloaded at runtime. It is listed on the in-app licences page. Codes are larger, grouped 3 + 3, in red; the next code is cream.
4. **Dot widgets.** Code rows have a dotted one-dot outline in place of rounded cards. Selected rows get a diamond marker at each end. The countdown is a row of dots that turns cream in the last five seconds. A copied code flashes cream. The title and share card use 5x7 dot lettering, and a pulsing dot diamond replaces the upstream illustrations on the empty state and onboarding screens.
5. **Translucency.** Surfaces are semi-transparent black over a red Bayer-dither haze that shimmers about twelve times a second. The haze stays still when the system asks for reduced motion, and it pauses in the background. Desktop windows ask for a transparent background through the existing `window_manager` package. Phones and platforms that cannot show through stay opaque black. The lock-screen cover that hides codes is always fully opaque.
6. **Offline first.** On the welcome screen, "Use without backups" (codes stay on this device) is now the main button. Signing up for or logging in to an Ente account for encrypted backup is still available, as the smaller buttons below it.
7. **No Ente update prompts.** The in-app update check, which downloaded Ente's release feed and offered Ente's own binaries, is turned off. New versions of this fork are offered as the Windows installer at `lidarknight.com/download` (see the root README's Download section).
8. **HTML export footer.** The footer no longer loads remote images. It credits Ente Auth and warns that the file holds codes in plain text.
9. **Onboarding copy.** The feature line "Open source and audited by security experts" now reads "Open source fork of Ente Auth (AGPL-3.0)" in every language: the English string changed, and the translated `featureOpenSource` strings were removed so that every other language falls back to the English line. Ente's external audits cover Ente's own releases, not this fork.
10. **Local builds, no CI.** Desktop builds are made locally from this source by the maintainer; the steps are in the root README's Build section (Flutter 3.47.2, Visual Studio 2022 with the C++ workload on Windows, because `local_auth_windows` needs it). The fork's own desktop build workflow was removed before it was ever used. Ente's own workflows are unchanged and kept so the source is complete. **They need Ente's secrets, so if Actions is ever enabled on the fork, disable all of them in the Actions tab first.** Otherwise push-triggered ones such as `docs-deploy.yml` (pushes to `main` touching `docs/**`) run and fail.
11. **Linux AppStream metadata.** `linux/packaging/enteauth.appdata.xml` now describes this fork: no audit claim, the fork's homepage and developer name, a credit to Ente, and no Ente screenshot or update contact.
12. **Art and documentation.** The root `README.md` and `mobile/apps/auth/README.md` are replaced. `lidar-knight/` holds a small Node script that draws the README images as dot-matrix SVGs, and the SVGs themselves. The root README's Install section is now Download, with a big DOWNLOAD button (`button-download.svg`), a Download header (`h-download.svg`, which replaces `h-install.svg`) and an Explore badge (`badge-explore.svg`) that links to `https://lidarknight.com/auth`.
13. **Own desktop identity.** The desktop builds no longer share Ente Auth's identity, so they can run next to a real Ente Auth with separate storage:
    - **Windows:** `windows/runner/Runner.rc` has `CompanyName` "LiDAR-Knight Auth" and `ProductName` "LiDAR-Knight Auth". Ente is credited in `FileDescription` and `LegalCopyright`. The codes database, settings and the secure-storage key file live in `%APPDATA%\LiDAR-Knight Auth\LiDAR-Knight Auth`.
    - **Linux:** `APPLICATION_ID` in `linux/CMakeLists.txt` is `io.github.prompdev.lidarknightauth`, so the app has its own single-instance D-Bus name, its own `~/.local/share/io.github.prompdev.lidarknightauth` data folder and its own WM class. `StartupWMClass` in `linux/packaging/enteauth.desktop` and `startup_wm_class` in `linux/packaging/*/make_config.yaml` match it.
    - **macOS** (not built yet): `macos/Runner/Configs/AppInfo.xcconfig` has `PRODUCT_NAME = LiDAR-Knight Auth` and the bundle ID `io.github.prompdev.lidarknightauth`, which `macos/Runner.xcodeproj/project.pbxproj` also uses in place of `io.ente.auth.mac`. The bundle is "LiDAR-Knight Auth.app", the menu bar shows that name, and the Keychain, preferences and sandbox container are its own. `DEVELOPMENT_TEAM` is still Ente's and must be changed to your own team before signing.
    - **Never change these values after a release.** On Windows, `CompanyName` and `ProductName` name the data folder; on Linux, `APPLICATION_ID` does; on macOS, the bundle ID does. Changing any of them moves the folder, and existing installs lose their codes and offline key.
14. **Windows installer.** `windows/packaging/lidar-knight/LiDAR-Knight-Auth.iss` is the fork's own Inno Setup 6 script. Its AppId is `9D2BB997-46D5-494B-B352-3AA386B9994D`; it never reuses Ente's AppId, so it cannot replace or uninstall a real Ente Auth, and it must never change after a release. It installs per user into `%LOCALAPPDATA%\Programs\LiDAR-Knight Auth` with no administrator prompt, adds Start-menu and desktop shortcuts, launches the app at the end, and ships the AGPL-3.0 licence next to the app. Uninstall is from Windows Settings > Apps. The installer is not code-signed.
15. **Download hosting.** The installer's download link points to Cloudflare at `https://lidarknight.com/download/LiDAR-Knight-Auth-Setup.exe`, not to GitHub Releases.

## Dated log

| Date | Change |
|---|---|
| 2026-10-04 | Local Windows release build of commit `7f314a0` (app version 4.4.27): `flutter build windows --release` with Flutter 3.47.2 and Visual Studio 2022, on the maintainer's machine. No CI. |
| 2026-10-04 | Added the fork's own installer script `windows/packaging/lidar-knight/LiDAR-Knight-Auth.iss` (own AppId `9D2BB997-46D5-494B-B352-3AA386B9994D`, per-user, never Ente's AppId). It produces `LiDAR-Knight-Auth-Setup.exe`. |
| 2026-10-04 | `LiDAR-Knight-Auth-Setup.exe` (20.8 MB, SHA-256 `da6fcb87a3f4d9949ce08265c35cf57501f53081235927e958f9af110900f113`), built from commit `7f314a0` (app version 4.4.27) with the installer script above, for download from Cloudflare at `https://lidarknight.com/download/LiDAR-Knight-Auth-Setup.exe`. |
| 2026-10-04 | New art: `lidar-knight/art/h-download.svg` (replaces `h-install.svg`), `button-download.svg`, `badge-explore.svg`; `build-art.mjs` draws them. The root README's Install section became Download. |

## Files modified

All paths are relative to the repository root.

### Added

- `mobile/apps/auth/CHANGES-LIDAR-KNIGHT.md` (this file)
- `mobile/apps/auth/assets/fonts/doto/Doto-Variable.ttf`
- `mobile/apps/auth/assets/fonts/doto/OFL.txt`
- `mobile/apps/auth/lib/theme/lidar_knight_theme.dart`
- `mobile/apps/auth/lib/ui/lidar_knight/dot_widgets.dart`
- `mobile/packages/ente_components/fonts/Doto-Variable.ttf`
- `mobile/packages/ente_components/fonts/Doto-OFL.txt`
- `lidar-knight/README.md`
- `lidar-knight/dotmatrix/*.mjs` (`render.mjs`, `build-art.mjs`, `check.mjs`)
- `lidar-knight/art/*.svg` (including `h-download.svg`, `button-download.svg` and `badge-explore.svg`; `h-install.svg` was removed)
- `mobile/apps/auth/windows/packaging/lidar-knight/LiDAR-Knight-Auth.iss` (the fork's own Windows installer script)

### Changed: documentation

- `README.md` (repository root): replaced with this fork's README.
- `mobile/apps/auth/README.md`: replaced with this fork's README.

### Changed: app code and assets (`mobile/apps/auth/`)

- `pubspec.yaml`: the description, the Doto font, and its licence as an asset.
- `lib/main.dart`: the backdrop, the window title, the transparent desktop window, the tray tooltip and the font licence.
- `lib/app/view/app.dart`: the app title.
- `lib/ente_theme_data.dart`: the dark-only red-dot theme, with overrides for the shared packages.
- `lib/theme/colors.dart`: the palette.
- `lib/theme/text_style.dart`: Doto, heavier weights and a larger minimum size.
- `lib/ui/code_widget.dart`: the code row.
- `lib/ui/code_timer_progress.dart`: the dot countdown.
- `lib/ui/home/widgets/auth_logo_widget.dart`: the dot title.
- `lib/ui/home/widgets/rounded_action_buttons.dart`: the square buttons.
- `lib/ui/home/home_empty_state.dart`: the empty-state emblem.
- `lib/ui/components/auth_qr_dialog.dart`: the share-card branding.
- `lib/onboarding/view/onboarding_page.dart`: offline-first buttons and the theme.
- `lib/services/update_service.dart`: in-app update checks turned off.
- `lib/ui/settings/data/html_export.dart`: the export title and footer.
- `assets/svg/pin-card.svg`, `assets/svg/button-tint.svg`: recoloured.

### Changed: platform runners and packaging (`mobile/apps/auth/`)

- `windows/runner/main.cpp`, `windows/runner/Runner.rc`, `windows/packaging/exe/make_config.yaml`
- `linux/my_application.cc`, `linux/packaging/enteauth.desktop`, `linux/packaging/enteauth.appdata.xml` (describes the fork), `linux/packaging/{appimage,deb,pacman,rpm}/make_config.yaml` (display name and `startup_wm_class` only), `linux/CMakeLists.txt` (`APPLICATION_ID`)
- `macos/Runner/Info.plist`, `macos/Runner/Configs/AppInfo.xcconfig`, `macos/Runner.xcodeproj/project.pbxproj` and `macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` (product name and bundle ID)
- `ios/Runner/Info.plist`, `ios/Runner.xcodeproj/project.pbxproj`
- `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/io/ente/authenticator/QuickTileService.kt`
- `web/index.html`, `web/manifest.json`

### Changed: shared packages (`mobile/packages/`)

- `ente_components/pubspec.yaml` and `ente_components/lib/theme/text_styles.dart`: component text uses Doto.
- `ui/lib/theme/text_style.dart`: text uses Doto.
- `lock_screen/lib/ui/app_lock.dart`: the cover that hides codes while locked is always opaque.
- `strings/lib/l10n/arb/strings_en.arb`: the offline-key message, the email-verification warning and the open-source feature line.
- `strings/lib/l10n/arb/strings_{bg,de,lt,ru,sv,vi}.arb`: the product name in `offlineKeyUnavailableMessage`.
- `strings/lib/l10n/arb/strings_*.arb`, every language except English: `featureOpenSource` removed, so the English line is used.

## Not changed yet

- App icons and splash screens still use the upstream artwork and purple background colour.
- **Mobile app IDs are still Ente's.** The iOS bundle ID and the Android application ID are `io.ente.auth`, so this fork cannot be installed next to Ente Auth on a phone; on Android the `independent` build uses Ente's `io.ente.auth.independent`, so it cannot be installed next to Ente's own independent build. The desktop IDs are the fork's own (item 13). On Windows the Credential Manager wrapping key is still named after the unchanged `auth` executable and is shared with Ente Auth, so do not delete `key_auth_*` entries from Credential Manager while either app is installed. The Linux icon name (`Icon=io.ente.auth`) and the Flatpak/Snap tray icon name are still Ente's.
- **`linux/packaging/*` and `windows/packaging/exe` still carry Ente's identity and AppId; do not use them.** The `make_config.yaml` files name Ente as maintainer, vendor, packager or publisher with Ente's email and URLs, the rpm display name is still "Auth", all of them use the package name `enteauth`, and the exe config has Ente's `app_id` GUID, so an installer built from it would replace a real Ente Auth install. `macos/packaging/dmg/make-dmg.sh` and its `DS_Store` still expect "Ente Auth.app" and name the volume "Auth"; fix them before making a DMG.
- **Bug reports and support go to Ente.** Settings > Support > Report a bug emails logs to `auth@ente.com` (`lib/ui/settings/support_settings_page.dart`), and "Contact support" emails `support@ente.com` (`lib/utils/dialog_util.dart`, `lib/ui/code_error_widget.dart`). These should point at this repository's issues.
- The Windows Inno Setup script `scripts/build_windows_installer.ps1` still carries upstream's AppId, so it must not be used for this fork until that is changed. The local desktop builds do not use it; the fork's installer uses its own script, `windows/packaging/lidar-knight/LiDAR-Knight-Auth.iss`.
- The store listings under `android/app/src/main/play/` are upstream's.
- Crash reporting is upstream's opt-in Sentry setup, which is off by default in release builds.
