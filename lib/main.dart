import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/deeplink/initial_config.dart';

/// URL di default per la webapp dei risultati
const String kDefaultResultsBaseUrl = 'https://www.mysite.com/result_page';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Config iniziale (cfg=<base64>) dalla URL
  final InitialConfig? cfg = _readConfigFromUrl();

  // Flag per mostrare/nascondere la AppBar (appbar=1 / true / yes / on)
  final bool showAppBar = _readAppBarFlagFromUrl();

  // Base URL della pagina risultati: se non presente redirect_uri → default
  final String resultsBaseUrl = _readResultsBaseUrlFromUrl();

  // Se l'URL corrente è il path/fragment "risultati" (es. /result_page o #/result_page)
  // allora il bootstrap deve partire direttamente dal flusso risultati.
  final bool startOnResults = _readStartOnResultsFlagFromUrl();

  // NUOVO: se l'URL corrente punta alla pagina "gestione prenotazioni"
  // (es. /booking_management o #/booking_management)
  // vogliamo partire direttamente da quella pagina.
  final bool startOnBookingManagement = _readStartOnBookingManagementFlagFromUrl();

  // NUOVO: flag per modalità embedded (is_embedded=1 / true / yes / on)
  final bool isEmbedded = _readIsEmbeddedFlagFromUrl();

  runApp(
    MyrentBookingApp(
      initialConfig: cfg,
      showAppBar: showAppBar,
      resultsBaseUrl: resultsBaseUrl,
      // Se partiamo su Gestione Prenotazioni, disattiviamo il bootstrap "results"
      startOnResults: startOnResults && !startOnBookingManagement,
      isEmbedded: isEmbedded,
      // NUOVO: passiamo l’intento di partire direttamente da Gestione Prenotazioni
      startOnBookingManagement: startOnBookingManagement,
    ),
  );
}

/// Legge la InitialConfig da:
/// - query param `cfg` (path style: /result_page?cfg=...)
/// - oppure dal fragment (hash style: /#/result_page?cfg=...)
InitialConfig? _readConfigFromUrl() {
  if (!kIsWeb) return null; // solo web
  try {
    final uri = Uri.base;

    // 1) prima provo dalla query "normale": ?cfg=...
    String? b64 = uri.queryParameters['cfg'];

    // 2) se non c'è nella query, provo a estrarla dal fragment,
    //    es: http://host/#/result_page?cfg=...
    if ((b64 == null || b64.isEmpty) && uri.fragment.isNotEmpty) {
      final frag = uri.fragment; // es. "/result_page?cfg=..."
      // tolgo l'eventuale "/" iniziale per evitare "//" nel parse
      final fragPath = frag.startsWith('/') ? frag.substring(1) : frag;
      final fake = Uri.parse('http://dummy/$fragPath');
      b64 = fake.queryParameters['cfg'];
    }

    if (b64 == null || b64.isEmpty) return null;

    return InitialConfig.fromBase64Url(b64);
  } catch (_) {
    return null;
  }
}

/// Legge il flag `appbar` dalla query string (1/true/yes/on).
bool _readAppBarFlagFromUrl() {
  if (!kIsWeb) return false; // default: invisibile
  try {
    final v = Uri.base.queryParameters['appbar'];
    if (v == null) return false;
    final s = v.toLowerCase();
    return s == '1' || s == 'true' || s == 'yes' || s == 'on';
  } catch (_) {
    return false;
  }
}

/// NUOVO: legge il flag `is_embedded` dalla query string (1/true/yes/on).
bool _readIsEmbeddedFlagFromUrl() {
  if (!kIsWeb) return false; // default: non embedded
  try {
    final v = Uri.base.queryParameters['is_embedded'];
    if (v == null) return false;
    final s = v.toLowerCase();
    return s == '1' || s == 'true' || s == 'yes' || s == 'on';
  } catch (_) {
    return false;
  }
}

/// Legge `redirect_uri` dalla query string, con fallback a kDefaultResultsBaseUrl.
///
/// Esempi:
/// - nessun redirect_uri:
///     → https://www.mysite.com/result_page
/// - redirect_uri=https%3A%2F%2Fpartner.com%2Fresults:
///     → https://partner.com/results
String _readResultsBaseUrlFromUrl() {
  // Default se non siamo in web o non c'è parametro
  if (!kIsWeb) return kDefaultResultsBaseUrl;

  try {
    final params = Uri.base.queryParameters;
    final raw = params['redirect_uri'];

    if (raw == null || raw.isEmpty) {
      return kDefaultResultsBaseUrl;
    }

    final uri = Uri.parse(raw);

    // Accetto solo URL assoluti tipo "https://..."
    if (!uri.hasScheme || uri.host.isEmpty) {
      return kDefaultResultsBaseUrl;
    }

    return uri.toString();
  } catch (_) {
    return kDefaultResultsBaseUrl;
  }
}

/// Determina se l'entry point attuale è la pagina risultati.
///
/// Considera sia path che fragment:
///  - https://host/result_page?cfg=...
///  - https://host/results?cfg=...
///  - https://host/#/result_page?cfg=...
bool _readStartOnResultsFlagFromUrl() {
  if (!kIsWeb) return false;

  try {
    final uri = Uri.base;
    final path = uri.path.toLowerCase();          // es. '/', '/result_page'
    final fragment = uri.fragment.toLowerCase();  // es. '/result_page?cfg=...'

    bool isResultsLocation(String s) {
      if (s.isEmpty) return false;
      return s.contains('result_page') || s.endsWith('/results');
    }

    if (isResultsLocation(path) || isResultsLocation(fragment)) {
      return true;
    }

    return false;
  } catch (_) {
    return false;
  }
}

/// NUOVO: determina se l'entry point attuale è la pagina **Gestione prenotazioni**.
///
/// Considera sia path che fragment:
///  - https://host/booking_management
///  - https://host/#/booking_management
bool _readStartOnBookingManagementFlagFromUrl() {
  if (!kIsWeb) return false;

  try {
    final uri = Uri.base;
    final path = uri.path.toLowerCase();          // es. '/', '/booking_management'
    final fragment = uri.fragment.toLowerCase();  // es. '/booking_management?foo=bar'

    bool isBookingManagementLocation(String s) {
      if (s.isEmpty) return false;
      // Controllo generico: contiene "booking_management" o termina con "/booking_management"
      return s.contains('booking_management') || s.endsWith('/booking_management');
    }

    if (isBookingManagementLocation(path) ||
        isBookingManagementLocation(fragment)) {
      return true;
    }

    return false;
  } catch (_) {
    return false;
  }
}
