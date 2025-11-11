import 'dart:async';
import 'dart:io' show Platform; // ignore: avoid_web_libraries_in_flutter
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/deeplink/initial_config.dart';


void main() async {
WidgetsFlutterBinding.ensureInitialized();
final InitialConfig? cfg = _readConfigFromUrl();
final bool showAppBar = _readAppBarFlagFromUrl(); // NEW
runApp(MyrentBookingApp(initialConfig: cfg, showAppBar: showAppBar)); // NEW

}


InitialConfig? _readConfigFromUrl() {
if (!kIsWeb) return null; // solo web
try {
final uri = Uri.base; // es. https://host/route?cfg=...
final b64 = uri.queryParameters['cfg'];
return InitialConfig.fromBase64Url(b64);
} catch (_) {
return null;
}
}

bool _readAppBarFlagFromUrl() {            // NEW
  if (!kIsWeb) return false;               // default: invisibile
  try {
    final v = Uri.base.queryParameters['appbar'];
    if (v == null) return false;
    final s = v.toLowerCase();
    return s == '1' || s == 'true' || s == 'yes' || s == 'on';
  } catch (_) {
    return false;
  }
}
