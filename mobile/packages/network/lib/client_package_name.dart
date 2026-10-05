/// Keep the desktop product/storage identity separate from the Ente API's
/// client identity. Only known Auth names are normalized; arbitrary names
/// still reach the production endpoint's existing validation unchanged.
String normalizeAuthClientPackageName(
  String packageName, {
  required bool isDesktop,
}) {
  if (!isDesktop) return packageName;
  return switch (packageName) {
    'ente_auth' ||
    'Ente Auth' ||
    'LiDAR-Knight Auth' ||
    'io.github.prompdev.lidarknightauth' => 'io.ente.auth',
    _ => packageName,
  };
}
