// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

class IframeScrollBridge extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final bool debug;

  const IframeScrollBridge({
    super.key,
    required this.child,
    required this.enabled,
    this.debug = true,
  });

  @override
  State<IframeScrollBridge> createState() => _IframeScrollBridgeState();
}

class _IframeScrollBridgeState extends State<IframeScrollBridge> {
  String? _parentOrigin;

  // Ultime metriche note dello scroll (servono per capire se siamo al bordo)
  ScrollMetrics? _lastMetrics;

  void _log(Object msg) {
    if (!widget.debug) return;
    // ignore: avoid_print
    print('[IframeScrollBridge] $msg');
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;

    _log('initState: enabled=${widget.enabled}');
    _log('child href=${html.window.location.href}');
    _log('child origin=${html.window.location.origin}');
    _log('embedded=${html.window.parent != html.window}');

    html.window.onMessage.listen((event) {
      final data = event.data;
      _log('⬅ onMessage origin=${event.origin} data=$data');

      if (data is Map && data['type'] == 'init') {
        final po = data['parentOrigin'];
        if (po is String && po.isNotEmpty) {
          _parentOrigin = po;
          _log('✅ init ricevuto. parentOrigin=$_parentOrigin');

          _postToParent('child-ack', {
            'received': 'init',
            'childOrigin': html.window.location.origin,
            'ts': DateTime.now().toIso8601String(),
          });
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _postToParent('child-ready', {
        'childOrigin': html.window.location.origin,
        'href': html.window.location.href,
        'embedded': html.window.parent != html.window,
        'ts': DateTime.now().toIso8601String(),
      }, forceTargetOrigin: '*'); // debug: ok
    });
  }

  void _postToParent(String type, Map<String, dynamic> payload,
      {String? forceTargetOrigin}) {
    if (!kIsWeb || !widget.enabled) return;

    final parent = html.window.parent;
    if (parent == null) return;

    final targetOrigin = forceTargetOrigin ?? _parentOrigin ?? '*';
    final msg = {'type': type, ...payload};

    _log('➡ postMessage type=$type targetOrigin=$targetOrigin payload=$payload');
    parent.postMessage(msg, targetOrigin);
  }

  void _sendScrollToParent(double dy, {required String via}) {
    if (dy == 0) return;
    _postToParent('scroll-parent', {
      'deltaY': dy,
      'via': via,
      'ts': DateTime.now().toIso8601String(),
    }, forceTargetOrigin: '*'); // debug
  }

  bool _atTop(ScrollMetrics m) => m.pixels <= m.minScrollExtent + 0.5;
  bool _atBottom(ScrollMetrics m) => m.pixels >= m.maxScrollExtent - 0.5;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Listener(
      // ✅ Questo cattura wheel/trackpad anche quando lo scroll è “bloccato” al bordo
      onPointerSignal: (ps) {
        if (ps is PointerScrollEvent) {
          final m = _lastMetrics;
          if (m == null) return;

          final dy = ps.scrollDelta.dy;
          final atTop = _atTop(m);
          final atBottom = _atBottom(m);

          // Se sei al bordo e continui nella stessa direzione, passa al parent
          if ((atBottom && dy > 0) || (atTop && dy < 0)) {
            _log('🛞 PointerScrollEvent atEdge: atTop=$atTop atBottom=$atBottom dy=$dy');
            _sendScrollToParent(dy, via: 'pointer-signal');
          }
        }
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.axis != Axis.vertical) return false;

          _lastMetrics = n.metrics;

          // 1) Overscroll vero (se c’è)
          if (n is OverscrollNotification) {
            _log('🔥 OverscrollNotification overscroll=${n.overscroll}');
            _sendScrollToParent(n.overscroll, via: 'overscroll');
            return false;
          }

          // 2) Edge-delta: quando sei al bordo e lo scroll “cerca” di andare oltre
          if (n is ScrollUpdateNotification) {
            final d = n.scrollDelta ?? 0.0;
            final m = n.metrics;

            final atTop = _atTop(m);
            final atBottom = _atBottom(m);

            if ((atBottom && d > 0) || (atTop && d < 0)) {
              _log('⚠ ScrollUpdate atEdge: atTop=$atTop atBottom=$atBottom delta=$d');
              _sendScrollToParent(d, via: 'edge-delta');
            }
          }

          return false;
        },
        child: widget.child,
      ),
    );
  }
}
