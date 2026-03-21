import 'web_redirect_stub.dart'
    if (dart.library.html) 'web_redirect_web.dart';

Future<void> redirectToUrlSameTab(String url) => redirectToUrlSameTabImpl(url);