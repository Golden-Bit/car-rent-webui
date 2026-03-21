import 'dart:html' as html;

Future<void> redirectToUrlSameTabImpl(String url) async {
  html.window.location.assign(url);
}