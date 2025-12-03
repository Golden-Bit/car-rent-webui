import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

// Home & Search
import 'features/search/presentation/pages/home_page.dart';
import 'features/search/presentation/pages/advanced_search_page.dart';

// Results & Extras
import 'features/results/presentation/pages/results_page.dart';
import 'features/results/presentation/pages/extras_page.dart';
import 'features/results/presentation/pages/confirm_page.dart';

// Long term
import 'features/long_term/presentation/pages/long_term_offer_page.dart';

// Deep link / Config iniziale
import 'core/deeplink/initial_config.dart';

/// URL di default per la webapp dei risultati.
/// (stesso valore usato in main.dart; va bene ridefinirlo per questa libreria)
const String kDefaultResultsBaseUrl = 'https://www.mysite.com/result_page';

/// Navigator globale, usato per il bootstrap da InitialConfig
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// App root con supporto a deep-link iniziale (InitialConfig)
///
/// Gestisce **entrambi** i flussi:
/// - flusso "search": home + advanced, con redirect esterno (o interno) verso /result_page
/// - flusso "results": entry direct su /result_page?cfg=... con loader + lista risultati
class MyrentBookingApp extends StatefulWidget {
  final InitialConfig? initialConfig;
  final bool showAppBar;       // controlla globalmente la visibilità della top bar
  final String resultsBaseUrl; // base URL per il redirect verso la pagina risultati
  final bool startOnResults;   // se true, bootstrap direttamente su ResultsPage
  final bool isEmbedded;       // NUOVO: modalità embedded/iframe/webview

  const MyrentBookingApp({
    super.key,
    this.initialConfig,
    this.showAppBar = false,
    this.resultsBaseUrl = kDefaultResultsBaseUrl,
    this.startOnResults = false,
    this.isEmbedded = false,   // default: non embedded
  });

  @override
  State<MyrentBookingApp> createState() => _MyrentBookingAppState();
}

class _MyrentBookingAppState extends State<MyrentBookingApp> {
  // Evita di eseguire il drive da config più volte (es. hot reload/ricostruzioni)
  bool _bootstrapped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;

    // Se presente una InitialConfig, orchestri l’avvio dopo il primo frame
    if (widget.initialConfig != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _driveFromConfig(
          widget.initialConfig!,
          widget.startOnResults,
        );
      });
    }

    _bootstrapped = true;
  }

  @override
  Widget build(BuildContext context) {
    return AppUiFlags(
      showAppBar: widget.showAppBar,
      resultsBaseUrl: widget.resultsBaseUrl,
      isEmbedded: widget.isEmbedded, // ⬅️ passa il flag nel contesto
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Myrent – Prenotazione',
        theme: buildAppTheme(),

        // Usiamo onGenerateRoute per gestire pagine con argomenti tipizzati
        onGenerateRoute: (settings) {
          switch (settings.name) {
            // Root → Home (da cui si va ad Advanced)
            case '/':
              return MaterialPageRoute(
                builder: (_) => const HomePage(),
                settings: settings,
              );

            case AdvancedSearchPage.routeName:
              // AdvancedSearchPage non necessita arg obbligatori,
              // ma può ricevere AdvancedSearchArgs / AdvancedSearchArgsFromConfig.
              return MaterialPageRoute(
                builder: (_) => const AdvancedSearchPage(),
                settings: settings,
              );

            case ResultsPage.routeName:
              // ResultsPage si prende gli arguments da ModalRoute.of(context)
              // e gestisce:
              //  - ResultsArgs (quotation + cfg)
              //  - QuotationResponse
              //  - ResultsArgsFromConfig (solo cfg → chiama il backend)
              return MaterialPageRoute(
                builder: (_) => const ResultsPage(),
                settings: settings,
              );

            case ExtrasPage.routeName:
              // Se hai definito ExtrasPageArgs, puoi tipizzarlo qui.
              final args = settings.arguments;
              if (args is ExtrasPageArgs) {
                return MaterialPageRoute(
                  builder: (_) => ExtrasPage(
                    dataJson: args.dataJson,
                    selected: args.selected,
                    preselectedExtras: args.preselectedExtras,
                    initialConfig: args.initialConfig,
                  ),
                  settings: settings,
                );
              }
              // Fallback difensivo: evita crash se la route viene usata male
              return MaterialPageRoute(
                builder: (_) => const SizedBox.shrink(),
                settings: settings,
              );

            case ConfirmPage.routeName:
              return MaterialPageRoute(
                builder: (_) => const ConfirmPage(),
                settings: settings,
              );

            case LongTermOfferPage.routeName:
              return MaterialPageRoute(
                builder: (_) => const LongTermOfferPage(),
                settings: settings,
              );
          }

          // Se non matcha nulla, lascia che Flutter gestisca (404 navigator)
          return null;
        },

        // Route di avvio logica: il bootstrap spingerà poi la pagina giusta.
        initialRoute: '/',
      ),
    );
  }
}

/// Orchestrazione iniziale basata su InitialConfig.
///
/// Se `startOnResults == false`:
///   - Naviga ad AdvancedSearchPage con i campi precompilati (via AdvancedSearchArgsFromConfig).
///   - AdvancedSearchPage esegue l’auto-submit e, invece di aprire una ResultsPage interna,
///     effettua il **redirect** verso la pagina risultati (`resultsBaseUrl` + ?cfg=...).
///
/// Se `startOnResults == true`:
///   - Naviga direttamente a ResultsPage, passandole la InitialConfig (ResultsArgsFromConfig),
///     che mostrerà il loader e chiamerà `createQuotationFromConfig(cfg)`.
Future<void> _driveFromConfig(
  InitialConfig cfg,
  bool startOnResults,
) async {
  final nav = rootNavigatorKey.currentState;
  if (nav == null) return;

  if (startOnResults) {
    // Entry point diretto risultati: es. /result_page?cfg=...
    await nav.pushNamed(
      ResultsPage.routeName,
      arguments: ResultsArgsFromConfig(cfg),
    );
  } else {
    // Flusso classico: search → redirect verso result_page
    await nav.pushNamed(
      AdvancedSearchPage.routeName,
      arguments: AdvancedSearchArgsFromConfig(cfg),
    );
  }

  // Dopo il push, la pagina (Advanced o Results) gestisce da sola
  // il proseguimento del flusso (redirect o extra/conferma).
}

/// Scope UI flags (es. showAppBar, resultsBaseUrl, isEmbedded) tramite InheritedWidget
class AppUiFlags extends InheritedWidget {
  final bool showAppBar;
  final String resultsBaseUrl;
  final bool isEmbedded; // ⬅️ nuovo flag nel contesto

  const AppUiFlags({
    super.key,
    required this.showAppBar,
    required this.resultsBaseUrl,
    required this.isEmbedded,
    required Widget child,
  }) : super(child: child);

  static bool showAppBarOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppUiFlags>()
          ?.showAppBar ??
      false;

  /// Restituisce la base URL della pagina risultati
  /// (redirect_uri della query string oppure default).
  static String resultsBaseUrlOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppUiFlags>()
          ?.resultsBaseUrl ??
      kDefaultResultsBaseUrl;

  /// NUOVO: restituisce il flag embedded per le pagine
  static bool isEmbeddedOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppUiFlags>()
          ?.isEmbedded ??
      false;

  @override
  bool updateShouldNotify(AppUiFlags oldWidget) =>
      oldWidget.showAppBar != showAppBar ||
      oldWidget.resultsBaseUrl != resultsBaseUrl ||
      oldWidget.isEmbedded != isEmbedded;
}
