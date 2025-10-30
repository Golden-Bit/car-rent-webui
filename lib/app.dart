import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

// Home & Search
import 'features/search/presentation/pages/home_page.dart';
import 'features/search/presentation/pages/advanced_search_page.dart';

// Results & Extras
import 'features/results/presentation/pages/results_page.dart';
import 'features/results/presentation/pages/extras_page.dart';

// Long term
import 'features/long_term/presentation/pages/long_term_offer_page.dart';

// Step 4 placeholder (conferma)
import 'package:car_rent_webui/features/search/presentation/pages/confirm_page.dart';

// Deep link / Config iniziale
import 'core/deeplink/initial_config.dart';

/// App root con supporto a deep-link iniziale (InitialConfig)
class MyrentBookingApp extends StatefulWidget {
  final InitialConfig? initialConfig;

  const MyrentBookingApp({super.key, this.initialConfig});

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
        await _driveFromConfig(context, widget.initialConfig!);
      });
    }

    _bootstrapped = true;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
            // ma può ricevere AdvancedSearchArgs (es. da InitialConfig)
            return MaterialPageRoute(
              builder: (_) {
                // Pass-through degli args (se presenti) direttamente alla page
                final args = settings.arguments;
                if (args is AdvancedSearchArgs) {
                  // La pagina recupererà gli args da ModalRoute.of(context)!.settings.arguments
                  // come già implementato nel tuo AdvancedSearchPage
                  return const AdvancedSearchPage();
                }
                return const AdvancedSearchPage();
              },
              settings: settings,
            );

          case ResultsPage.routeName:
            // ResultsPage legge QuotationResponse dagli arguments
            return MaterialPageRoute(
              builder: (_) => const ResultsPage(),
              settings: settings,
            );

          case LongTermOfferPage.routeName:
            return MaterialPageRoute(
              builder: (_) => const LongTermOfferPage(),
              settings: settings,
            );

          case ExtrasPage.routeName:
            // Soluzione A: named route tip-safe con ExtrasPageArgs
            final args = settings.arguments;
            if (args is ExtrasPageArgs) {
              return MaterialPageRoute(
                builder: (_) => ExtrasPage(
                  dataJson: args.dataJson,
                  selected: args.selected,
                  preselectedExtras: args.preselectedExtras,
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
        }

        // Se non matcha nulla, lascia che Flutter gestisca (404 navigator)
        return null;
      },

      // Route di avvio
      initialRoute: '/',
    );
  }
}

/// Orchestrazione iniziale basata su InitialConfig.
/// - Naviga ad AdvancedSearchPage con i campi precompilati (via AdvancedSearchArgsFromConfig)
/// - La Advanced esegue auto-submit → Results
/// - Da Results si seleziona il veicolo per `vehicleId` e, se step>=3, si entra in Extras
/// - Per step==4, Extras porta a ConfirmPage (placeholder) quando l’utente preme Prosegui.
/// NOTE: le parti after-Results sono implementate nelle rispettive pagine (Results/Extras)
///       usando la stessa InitialConfig (già prevista nella tua architettura).
Future<void> _driveFromConfig(BuildContext context, InitialConfig cfg) async {
  // 1) Vai alla Advanced con form precompilato; la pagina gestisce:
  //    - pre-fill dei campi
  //    - auto-submit (creazione quotazione)
  //    - routing automatico verso Results
  await Navigator.pushNamed(
    context,
    AdvancedSearchPage.routeName,
    arguments: AdvancedSearchArgsFromConfig(cfg),
  );

  // Da qui in poi la flow prosegue dentro ResultsPage/ExtrasPage
  // (che usano `cfg` per selezionare il vehicleId e gli extra, e per raggiungere lo step richiesto).
  // Non forziamo altre navigation qui per evitare race con la navigazione della Advanced.
}
