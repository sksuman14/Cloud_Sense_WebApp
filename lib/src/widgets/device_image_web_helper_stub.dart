/// Stub implementation for non-web platforms (Android, iOS, Desktop).
void registerDeviceImageViewFactory({
  required String viewType,
  required String imageUrl,
  required String objectFit,
  required void Function() onLoaded,
  required void Function() onError,
}) {
  // No-op on non-web platforms.
}
