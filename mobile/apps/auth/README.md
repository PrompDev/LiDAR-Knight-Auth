<div align="center">

<img src="../../../lidar-knight/art/title.svg" alt="LiDAR-Knight Auth" width="806">

<img src="../../../lidar-knight/art/tagline.svg" alt="> two-factor codes, made of dots" width="723">

</div>

```text
> cd mobile/apps/auth
  this folder ..... the app: one Flutter codebase for desktop and mobile
  upstream ........ Ente Auth, github.com/ente/ente (AGPL-3.0)
  full readout .... ../../../README.md
> _
```

This is the Flutter project for **LiDAR-Knight Auth**, a red-dot fork of **[Ente Auth](https://github.com/ente/ente)** by Ente Technologies, Inc. The [main README](../../../README.md) covers what it is, where it comes from, safety, [download](../../../README.md#download), credits and licence. This page covers only building.

**Just want the app on Windows?** [DOWNLOAD the one-click installer](https://lidarknight.com/download/LiDAR-Knight-Auth-Setup.exe) (`LiDAR-Knight-Auth-Setup.exe`, 20.8 MB, unsigned; SHA-256, source commit and details in the [main README](../../../README.md#download); if the link returns an error, it is not online yet). Linux, macOS and mobile: build from source, below.

<img src="../../../lidar-knight/art/h-build.svg" alt="Build">

There is no CI: every build of this fork is made locally with these steps.

1. Install [Flutter 3.47.2](https://docs.flutter.dev/get-started/install) exactly, the pinned version (upstream pins it in [`.github/actions/setup-flutter`](../../../.github/actions/setup-flutter/action.yml)). On Windows you also need Visual Studio 2022 with "Desktop development with C++"; on Linux, the packages listed in the [main README](../../../README.md#build).
2. Clone the whole repository (`mobile/` is a pub workspace, and `pub get` needs every member), then pull in the icon pack:
   `git submodule update --init --recursive`
3. From any folder inside `mobile/`, run `flutter pub get --enforce-lockfile`.
4. Run the app from this folder:
   - Windows: `flutter run -d windows`. Release build: `flutter build windows --release`. Installer: compile [`windows/packaging/lidar-knight/LiDAR-Knight-Auth.iss`](windows/packaging/lidar-knight/LiDAR-Knight-Auth.iss) with Inno Setup 6 (its header lists the options); it writes `build/installer/LiDAR-Knight-Auth-Setup.exe`.
   - Linux: `flutter run -d linux`. Release build: `flutter build linux --release`.
   - macOS: `flutter run -d macos`.
   - Android: `flutter run --flavor independent`.
   - iOS: `flutter run`.

For a release APK, [set up your own keystore](https://docs.flutter.dev/deployment/android#create-an-upload-keystore), then run `flutter build apk --release --flavor independent`. For iOS, use `flutter build ios`.

After updating Flutter dependencies, run `pod install` from `ios/` on macOS, and commit `ios/Podfile.lock` if it changes.

<img src="../../../lidar-knight/art/divider.svg" alt="" width="728">

- **Architecture.** Ente documents how tokens are encrypted and synced in [`architecture/README.md`](../../../architecture/README.md#token-encryption). That is upstream's design, and this fork does not change it.
- **Icons.** Service icons come from [simple-icons](https://github.com/simple-icons/simple-icons) (CC0) plus the custom set in `assets/custom-icons`. To add one, see [docs/adding-icons.md](docs/adding-icons.md).
- **Strings and translations** live in the shared [strings package](../../packages/strings/README.md). Ente's translators maintain them upstream.
- **Packaging.** The Windows installer uses only the fork's own script, `windows/packaging/lidar-knight/LiDAR-Knight-Auth.iss`: its own AppId (`9D2BB997-46D5-494B-B352-3AA386B9994D`, never Ente's, never to change after a release), per-user, no administrator prompt. `linux/packaging/*` and `windows/packaging/exe` still carry Ente's identity and AppId; do not use them, or `scripts/build_windows_installer.ps1` either. [CHANGES-LIDAR-KNIGHT.md](CHANGES-LIDAR-KNIGHT.md) lists what is still upstream's.
- **Running next to Ente Auth.** The desktop builds have their own IDs and data folders, so they can run next to Ente Auth. Never change `CompanyName`/`ProductName` in `windows/runner/Runner.rc`, `APPLICATION_ID` in `linux/CMakeLists.txt` or the macOS bundle ID after a release: they name the data folder, and existing installs would lose their codes. On phones the app IDs are still Ente's, so the fork cannot be installed next to Ente Auth.
- **Upstream docs.** Some files in `docs/` here are Ente's own (for example `docs/release.md`). They describe Ente's release process, not this fork's.

Licensed under AGPL-3.0. See [LICENSE](../../../LICENSE).
