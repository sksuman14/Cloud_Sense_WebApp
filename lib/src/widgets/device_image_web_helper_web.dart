// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:universal_html/html.dart' as html;

/// Web implementation using platformViewRegistry and native HTML ImageElement.
void registerDeviceImageViewFactory({
  required String viewType,
  required String imageUrl,
  required String objectFit,
  required void Function() onLoaded,
  required void Function() onError,
}) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) {
      final img = html.ImageElement()
        ..src = imageUrl
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = objectFit
        ..style.objectPosition = 'center'
        ..style.backgroundColor = 'transparent'
        ..style.border = 'none'
        ..style.display = 'block'
        ..style.pointerEvents = 'none'; // Pass clicks to Flutter InkWell

      img.onLoad.listen((_) => onLoaded());
      img.onError.listen((_) => onError());

      return img;
    },
  );
}
