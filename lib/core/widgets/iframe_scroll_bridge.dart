// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

class IframeScrollBridge extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final bool debug;

  /// Moltiplicatore per touch-drag al bordo (mobile).
  /// Se WP scorre ancora poco, alza a 2.0–3.0.
  final double touchGain;

  /// Moltiplicatore per wheel/trackpad al bordo (desktop).
  final double wheelGain;

  const IframeScrollBridge({
    super.key,
    required this.child,
    required this.enabled,
    this.debug = true,
    this.touchGain = 2.4,
    this.wheelGain = 1.0,
  });

  @override
  State<IframeScrollBridge> createState() => _IframeScrollBridgeState();
}

class _IframeScrollBridgeState extends State<IframeScrollBridge> {
  String? _parentOrigin;
  ScrollMetrics? _lastMetrics;

  // batching (1 invio per frame)
  double _pending = 0;
  String _pendingVia = 'unknown';
  bool _scheduled = false;

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
      _postToParent(
        'child-ready',
        {
          'childOrigin': html.window.location.origin,
          'href': html.window.location.href,
          'embedded': html.window.parent != html.window,
          'ts': DateTime.now().toIso8601String(),
        },
        forceTargetOrigin: '*', // debug ok
      );
    });
  }

  void _postToParent(String type, Map<String, dynamic> payload, {String? forceTargetOrigin}) {
    if (!kIsWeb || !widget.enabled) return;

    final parent = html.window.parent;
    if (parent == null) return;

    final targetOrigin = forceTargetOrigin ?? _parentOrigin ?? '*';
    final msg = {'type': type, ...payload};

    _log('➡ postMessage type=$type targetOrigin=$targetOrigin payload=$payload');
    parent.postMessage(msg, targetOrigin);
  }

  void _queueScroll(double dy, {required String via}) {
    if (dy == 0) return;

    _pending += dy;
    _pendingVia = via;

    if (_scheduled) return;
    _scheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;

      final send = _pending;
      final sendVia = _pendingVia;
      _pending = 0;

      if (send == 0) return;

      _postToParent(
        'scroll-parent',
        {
          'deltaY': send,
          'via': sendVia,
          'ts': DateTime.now().toIso8601String(),
        },
        forceTargetOrigin: '*', // debug; in produzione: rimuovi e usa _parentOrigin
      );
    });
  }

  bool _atTop(ScrollMetrics m) => m.pixels <= m.minScrollExtent + 0.5;
  bool _atBottom(ScrollMetrics m) => m.pixels >= m.maxScrollExtent - 0.5;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Listener(
      // Desktop: wheel/trackpad
      onPointerSignal: (ps) {
        if (ps is PointerScrollEvent) {
          final m = _lastMetrics;
          if (m == null) return;

          final dy = ps.scrollDelta.dy * widget.wheelGain;
          final atTop = _atTop(m);
          final atBottom = _atBottom(m);

          if ((atBottom && dy > 0) || (atTop && dy < 0)) {
            _log('🛞 PointerScrollEvent atEdge: atTop=$atTop atBottom=$atBottom dy=$dy');
            // evita “lotta” col child
            GestureBinding.instance.pointerSignalResolver.register(ps, (_) {});
            _queueScroll(dy, via: 'pointer-signal');
          }
        }
      },

      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.axis != Axis.vertical) return false;
          _lastMetrics = n.metrics;

          final m = n.metrics;
          final atTop = _atTop(m);
          final atBottom = _atBottom(m);

          // 1) Touch-drag: QUESTO È IL FIX
          // dragDetails esiste durante il drag touch e continua anche quando sei “pinnato” al bordo.
          if (n is ScrollUpdateNotification && n.dragDetails != null) {
            final fingerDy = n.dragDetails!.delta.dy;

            // Convertiamo movimento dito -> scroll host:
            // dito giù => pagina host dovrebbe salire => deltaY negativo
            final hostDy = (-fingerDy) * widget.touchGain;

            // manda solo se stai tentando di “uscire” dal contenuto
            if ((atBottom && hostDy > 0) || (atTop && hostDy < 0)) {
              _log('✋ touch-edge: atTop=$atTop atBottom=$atBottom fingerDy=$fingerDy hostDy=$hostDy');
              _queueScroll(hostDy, via: 'touch-edge');
              return false;
            }
          }

          // 2) Mantieni i tuoi segnali (fallback)
          if (n is OverscrollNotification) {
            _log('🔥 OverscrollNotification overscroll=${n.overscroll}');
            _queueScroll(n.overscroll, via: 'overscroll');
            return false;
          }

          if (n is ScrollUpdateNotification) {
            final d = n.scrollDelta ?? 0.0;
            if ((atBottom && d > 0) || (atTop && d < 0)) {
              _log('⚠ edge-delta: atTop=$atTop atBottom=$atBottom delta=$d');
              _queueScroll(d, via: 'edge-delta');
            }
          }

          return false;
        },
        child: widget.child,
      ),
    );
  }
}
