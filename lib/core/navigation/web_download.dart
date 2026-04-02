import 'web_download_stub.dart' if (dart.library.html) 'web_download_web.dart';

Future<void> downloadFileFromUrl(String url, {String? fileName}) =>
    downloadFileFromUrlImpl(url, fileName: fileName);

Future<void> downloadAssetFile(String assetKey, {String? fileName}) =>
    downloadAssetFileImpl(assetKey, fileName: fileName);
