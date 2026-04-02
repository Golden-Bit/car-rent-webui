import 'dart:html' as html;

import 'package:flutter/services.dart';

Future<void> downloadFileFromUrlImpl(String url, {String? fileName}) async {
  final anchor =
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName ?? '')
        ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}

Future<void> downloadAssetFileImpl(String assetKey, {String? fileName}) async {
  final data = await rootBundle.load(assetKey);
  final bytes = data.buffer.asUint8List();
  _downloadBytes(bytes, fileName: fileName ?? 'download.pdf');
}

void _downloadBytes(Uint8List bytes, {required String fileName}) {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor =
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
