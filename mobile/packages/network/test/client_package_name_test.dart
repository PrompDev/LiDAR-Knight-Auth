import 'package:ente_network/client_package_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('known desktop Auth product names retain the API identity', () {
    for (final name in [
      'ente_auth',
      'Ente Auth',
      'LiDAR-Knight Auth',
      'io.github.prompdev.lidarknightauth',
    ]) {
      expect(
        normalizeAuthClientPackageName(name, isDesktop: true),
        'io.ente.auth',
      );
    }
  });

  test(
    'unknown and lookalike names remain subject to production validation',
    () {
      for (final name in [
        '',
        'Unknown Auth',
        'LiDAR-Knight Auth Fake',
        'lidar-knight auth',
        'io.github.prompdev.lidarknightauth.fake',
      ]) {
        final normalized = normalizeAuthClientPackageName(
          name,
          isDesktop: true,
        );
        expect(normalized, name);
        expect(normalized.startsWith('io.ente.'), isFalse);
      }
    },
  );

  test('mobile and already valid package names are unchanged', () {
    for (final desktop in [true, false]) {
      expect(
        normalizeAuthClientPackageName('io.ente.auth', isDesktop: desktop),
        'io.ente.auth',
      );
      expect(
        normalizeAuthClientPackageName('io.ente.photos', isDesktop: desktop),
        'io.ente.photos',
      );
    }
    expect(
      normalizeAuthClientPackageName('LiDAR-Knight Auth', isDesktop: false),
      'LiDAR-Knight Auth',
    );
  });
}
