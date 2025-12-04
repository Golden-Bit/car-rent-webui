// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html; // SOLO per Flutter Web
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;     // SOLO per Flutter Web (postMessage verso il parent)

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:car_rent_webui/app.dart';
import 'package:car_rent_webui/car_rent_sdk/sdk.dart';
import 'package:car_rent_webui/core/deeplink/initial_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';


import '../../../../core/widgets/top_nav_bar.dart';
import '../../../../theme/app_theme.dart';
import '../widgets/location_dropdown.dart';
import '../../../../core/shapes/right_diagonal_panel_clipper.dart';

const String kMapAsset = 'assets/images/map_placeholder.png';

/// Path della rotta risultati interna alla webapp
/// (deve puntare alla pagina Flutter che gestisce i risultati)
const String kResultsRoutePath = '/result_page';

// ADD: gutter orizzontale responsivo (sx/dx)
double _hGutter(double w) {
  if (w >= 1600) return 64;
  if (w >= 1366) return 48;
  if (w >= 1200) return 40;
  if (w >= 1024) return 32;
  if (w >= 768) return 24;
  return 16;
}

/// Costruisce la base URL di default per il redirect risultati
/// quando **non** è stato passato un redirect_uri esterno.
///
/// Esempi:
/// - pagina aperta su http://127.0.0.1:5556/#/advanced
///   → base = http://127.0.0.1:5556/result_page
///
/// - pagina aperta su https://partner.com/widget
///   → base = https://partner.com/result_page
String _buildDefaultResultsBaseUrlFromCurrentPage() {
  try {
    // origin = "scheme://host[:port]" (senza path, query, hash)
    final origin = html.window.location.origin;
    return '$origin$kResultsRoutePath';
  } catch (_) {
    // Fallback di sicurezza: usa la costante globale dell'app
    return kDefaultResultsBaseUrl;
  }
}

class AdvancedSearchArgs {
  final Location? pickup;
  AdvancedSearchArgs({this.pickup});
}

class AdvancedSearchPage extends StatefulWidget {
  static const routeName = '/advanced';
  const AdvancedSearchPage({super.key});

  @override
  State<AdvancedSearchPage> createState() => _AdvancedSearchPageState();
}

class _AdvancedSearchPageState extends State<AdvancedSearchPage> {
  Location? _pickup;
  Location? _dropoff;
  DateTime? _start;
  DateTime? _end;
  int? _age;
  final TextEditingController _couponCtrl = TextEditingController();
  InitialConfig? _cfg;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments;

    if (args is AdvancedSearchArgs) {
      _pickup = args.pickup;
      _dropoff = args.pickup; // default: consegna = ritiro
    }

    // Avvio da deep-link (config già decodificata e passata dal router)
    if (args is AdvancedSearchArgsFromConfig) {
      _cfg = args.cfg;
      _start = _cfg!.start.toLocal();
      _end = _cfg!.end.toLocal();
      _age = _cfg!.age;
      _couponCtrl.text = _cfg!.coupon ?? '';

      // Avvio automatico della ricerca → ora fa redirect diretto alla webapp risultati
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onSearch();
      });
    }
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    super.dispose();
  }

  /// Esegue il redirect verso la webapp dei risultati
  ///
  /// Caso 1: è stato passato un `redirect_uri` all'iframe/widget.
  ///   - AppUiFlags.resultsBaseUrlOf(context) contiene l'URL di quella pagina
  ///     (es. https://partner.com/embedded-results o https://host/#/result_page).
  ///
  /// Caso 2: **non** è stato passato alcun `redirect_uri`.
  ///   - In questo caso, MyrentBookingApp ha usato kDefaultResultsBaseUrl
  ///     come valore di ripiego.
  ///   - Qui lo intercettiamo: se il valore è ancora quello di default,
  ///     costruiamo la base a partire dall'URL corrente della pagina,
  ///     puntando sempre alla rotta interna `/result_page`.
  /// Esegue il redirect verso la webapp dei risultati **oppure**
  /// emette l'URL al parent (iframe / WebView) se l'app è in modalità embedded.
  void _redirectToResults(InitialConfig cfg) {
    // 0) Verifico se siamo in modalità embedded
    final bool isEmbedded = AppUiFlags.isEmbeddedOf(context);

    // 1) Base URL letta dallo scope dell'app (può venire da redirect_uri)
    final String appBaseUrl = AppUiFlags.resultsBaseUrlOf(context);

    // 2) Se appBaseUrl è la costante di default (nessun redirect_uri passato),
    //    allora usiamo l'origin della pagina corrente + /result_page.
    //    Altrimenti, rispettiamo il redirect_uri personalizzato.
    final String effectiveBaseUrl =
        (appBaseUrl.isEmpty || appBaseUrl == kDefaultResultsBaseUrl)
            ? _buildDefaultResultsBaseUrlFromCurrentPage()
            : appBaseUrl;

    // 3) Serializzo la config in base64 url-safe
    final String cfgParam = cfg.toBase64Url();

    // 4) Provo a parsare la base URL; se qualcosa va storto,
    //    ricado comunque sul valore costruito a partire dalla pagina corrente.
    Uri baseUri;
    try {
      baseUri = Uri.parse(effectiveBaseUrl);
    } catch (_) {
      baseUri = Uri.parse(_buildDefaultResultsBaseUrlFromCurrentPage());
    }

    // 5) Mergiamo la query esistente con il nuovo parametro cfg
    final newQuery = <String, String>{
      ...baseUri.queryParameters, // mantiene eventuali query già presenti
      'cfg': cfgParam,
    };

    // 6) Costruiamo l'URI finale con la nuova query
    final redirectUri = baseUri.replace(queryParameters: newQuery);
    final String finalUrl = redirectUri.toString();

    // 7) Comportamento diverso se embedded o no
    if (isEmbedded) {
      // 🔄 Modalità embedded: niente redirect, invio l'URL al parent
      _postMessageToParent(finalUrl);
    } else {
      // 🌐 Modalità normale: redirect del browser
      html.window.location.assign(finalUrl);
    }
  }

  /// Invia l'URL finale al parent (pagina che contiene l'iframe / WebView)
  /// tramite postMessage JavaScript.
  ///
  /// Lato host (es. HTML):
  ///   <iframe src=".../?is_embedded=1"></iframe>
  ///   <script>
  ///     window.addEventListener("message", evt => {
  ///       console.log("URL ricevuto:", evt.data);
  ///       // window.location.href = evt.data; // se vuoi redirigere l'host
  ///     });
  ///   </script>
  void _postMessageToParent(String url) {
    if (!kIsWeb) return;

    try {
      // window.parent.postMessage(url, "*")
      final parent = js.context['parent'];
      if (parent != null) {
        parent.callMethod('postMessage', [url, '*']);
      }
    } catch (_) {
      // in caso di errore (es. non in iframe), non facciamo nulla
    }
  }


  @override
  Widget build(BuildContext context) {
    // Breakpoint per passare da layout side-by-side a layout stacked
    const double kStackBreakpoint = 1024;

    final size = MediaQuery.of(context).size;
    final primary = Theme.of(context).colorScheme.primary;

    const panelWidth = 560.0;
    const diagInsetTop = 140.0;

    final isWide = size.width >= kStackBreakpoint;

    // ---- LAYOUT WIDE (due colonne, pannello destro diagonale) ----
    if (isWide) {
      final leftAreaWidth = size.width - panelWidth;
      // larghezza blocco form a due colonne: ~ 360 + 360 + 24
      final formMaxWidth = leftAreaWidth.clamp(0, 760.0) as double;

      return Scaffold(
        appBar: AppUiFlags.showAppBarOf(context) ? const TopNavBar() : null,
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // 1) Fondo arancione identico alla topbar
            Positioned.fill(child: Container(color: primary)),

            // 2) Velo/gradiente arancione (morbidezza)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(color: Theme.of(context).colorScheme.primary),
              ),
            ),

            // 3) Pannello destro con immagine di sfondo (bordo diagonale)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipPath(
                  clipper: const RightDiagonalPanelClipper(
                    panelWidth: panelWidth,
                    insetTop: diagInsetTop,
                  ),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(kMapAsset),
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 4) Contenuti
            Row(
              children: [
                // --- COLONNA SINISTRA (FORM) ---
                Padding(
                  padding: EdgeInsets.only(left: _hGutter(size.width)),
                  child: SizedBox(
                    width: leftAreaWidth, // il Padding crea lo spazio a sx
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        top: size.height * 0.18,
                        bottom: 40,
                        right: 16, // un filo di respiro a destra
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: formMaxWidth),
                          child: _FormGrid(
                            isWide: true, // <-- 2 colonne
                            pickup: _pickup,
                            dropoff: _dropoff,
                            start: _start,
                            end: _end,
                            age: _age,
                            couponCtrl: _couponCtrl,
                            onPickupChanged: (l) =>
                                setState(() => _pickup = l),
                            onDropoffChanged: (l) =>
                                setState(() => _dropoff = l),
                            onStartChanged: (d) =>
                                setState(() => _start = d),
                            onEndChanged: (d) => setState(() => _end = d),
                            onAgeChanged: (v) => setState(() => _age = v),
                            onSubmit: () => _onSearch(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // --- COLONNA DESTRA (INFO/PLACEHOLDER) ---
                SizedBox(
                  width: panelWidth,
                  child: Center(
                    child: _LocationInfoCard(location: _pickup),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // ---- LAYOUT STACKED (pannello destro sotto, bordo orizzontale) ----
    final gutter = _hGutter(size.width);
    final formMaxWidthMobile =
        (size.width - gutter * 2).clamp(260.0, 760.0);

    return Scaffold(
      appBar: AppUiFlags.showAppBarOf(context) ? const TopNavBar() : null,
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Sezione arancione (form stacked 1 col)
            Container(
              color: primary,
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(gutter, 28, gutter, 24),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: formMaxWidthMobile),
                  child: _FormGrid(
                    isWide: false,
                    pickup: _pickup,
                    dropoff: _dropoff,
                    start: _start,
                    end: _end,
                    age: _age,
                    couponCtrl: _couponCtrl,
                    onPickupChanged: (l) =>
                        setState(() => _pickup = l),
                    onDropoffChanged: (l) =>
                        setState(() => _dropoff = l),
                    onStartChanged: (d) =>
                        setState(() => _start = d),
                    onEndChanged: (d) =>
                        setState(() => _end = d),
                    onAgeChanged: (v) =>
                        setState(() => _age = v),
                    onSubmit: () => _onSearch(),
                  ),
                ),
              ),
            ),

            // Sezione bianca (ex pannello destro, ora sotto)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(kMapAsset),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _LocationInfoCard(location: _pickup),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// NUOVA LOGICA: non chiamiamo più l'API di quotazione qui,
  /// ma costruiamo una InitialConfig e facciamo redirect alla webapp risultati.
  Future<void> _onSearch() async {
    // 1. Determina la InitialConfig da usare

    // Caso A: arrivo da deep-link → ho già _cfg
    InitialConfig? cfgToUse = _cfg;

    // Caso B: l'utente compila il form manualmente
    if (cfgToUse == null) {
      // Validazioni form standard
      if (_pickup == null ||
          _dropoff == null ||
          _start == null ||
          _end == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Completa i campi obbligatori')),
        );
        return;
      }

      if (_age == null || _age! <= 18) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Inserisci un’età valida (maggiore di 18).'),
          ),
        );
        return;
      }

      // Costruisci InitialConfig (flusso manuale)
      cfgToUse = InitialConfig.fromManual(
        pickupCode: _pickup!.locationCode,
        dropoffCode: _dropoff!.locationCode,
        startUtc: _start!.toUtc(),
        endUtc: _end!.toUtc(),
        age: _age,
        coupon: _couponCtrl.text.isEmpty ? null : _couponCtrl.text,
        channel: 'WEB_APP',
        initialStep: 2, // step di ingresso nella webapp risultati
      );
    }

    // 2. Redirect verso la webapp risultati, passando tutta la configurazione
    _redirectToResults(cfgToUse);
  }
}

/* ===========================
 *         WIDGETS
 * ===========================
 */

class _FormGrid extends StatelessWidget {
  final bool isWide;

  final Location? pickup;
  final Location? dropoff;
  final DateTime? start;
  final DateTime? end;
  final int? age;
  final TextEditingController couponCtrl;

  final ValueChanged<Location?> onPickupChanged;
  final ValueChanged<Location?> onDropoffChanged;
  final ValueChanged<DateTime> onStartChanged;
  final ValueChanged<DateTime> onEndChanged;
  final ValueChanged<int?> onAgeChanged;

  final VoidCallback onSubmit;

  const _FormGrid({
    required this.isWide,
    required this.pickup,
    required this.dropoff,
    required this.start,
    required this.end,
    required this.age,
    required this.couponCtrl,
    required this.onPickupChanged,
    required this.onDropoffChanged,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onAgeChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    // Due rendering: 2 colonne (wide) oppure 1 colonna (stacked)
    if (isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _FieldLabel(
                  label: 'Località di ritiro',
                  labelColor: Colors.white,
                  child: SizedBox(
                    height: 56,
                    child: LocationDropdown(
                      hintText: 'Seleziona località di ritiro',
                      initialValue: pickup,
                      onSelected: onPickupChanged,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _FieldLabel(
                  label: 'Località di consegna',
                  labelColor: Colors.white,
                  child: SizedBox(
                    height: 56,
                    child: LocationDropdown(
                      hintText: 'Seleziona località di consegna',
                      initialValue: dropoff,
                      onSelected: onDropoffChanged,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _FieldLabel(
                  label: 'Data di ritiro',
                  help:
                      'Seleziona data e ora. Fuori orario: +40€ (demo).',
                  labelColor: Colors.white,
                  iconColor: Colors.white70,
                  child: SizedBox(
                    height: 56,
                    child: _DateTimePicker(
                      value: start,
                      onChanged: onStartChanged,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _FieldLabel(
                  label: 'Data di consegna',
                  help:
                      'La riconsegna deve essere successiva al ritiro.',
                  labelColor: Colors.white,
                  iconColor: Colors.white70,
                  child: SizedBox(
                    height: 56,
                    child: _DateTimePicker(
                      value: end,
                      onChanged: onEndChanged,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _FieldLabel(
                  label: 'Età',
                  labelColor: Colors.white,
                  child: SizedBox(
                    height: 56,
                    child: _AgeNumberField(
                      value: age,
                      onChanged: onAgeChanged,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _FieldLabel(
                  label: 'Codice sconto',
                  labelColor: Colors.white,
                  child: SizedBox(
                    height: 56,
                    child: TextField(
                      controller: couponCtrl,
                      decoration: const InputDecoration(
                        hintText: 'codice',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kCtaGreen,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: .4,
                  ),
                ),
                onPressed: onSubmit,
                child: const Text('CERCA LA TUA AUTO'),
              ),
            ),
          ),
        ],
      );
    }

    // --- variante 1 colonna (mobile/stacked) ---
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(
          label: 'Località di ritiro',
          labelColor: Colors.white,
          child: SizedBox(
            height: 56,
            child: LocationDropdown(
              hintText: 'Seleziona località di ritiro',
              initialValue: pickup,
              onSelected: onPickupChanged,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _FieldLabel(
          label: 'Località di consegna',
          labelColor: Colors.white,
          child: SizedBox(
            height: 56,
            child: LocationDropdown(
              hintText: 'Seleziona località di consegna',
              initialValue: dropoff,
              onSelected: onDropoffChanged,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _FieldLabel(
          label: 'Data di ritiro',
          help:
              'Seleziona data e ora. Fuori orario: +40€ (demo).',
          labelColor: Colors.white,
          iconColor: Colors.white70,
          child: SizedBox(
            height: 56,
            child: _DateTimePicker(
              value: start,
              onChanged: onStartChanged,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _FieldLabel(
          label: 'Data di consegna',
          help:
              'La riconsegna deve essere successiva al ritiro.',
          labelColor: Colors.white,
          iconColor: Colors.white70,
          child: SizedBox(
            height: 56,
            child: _DateTimePicker(
              value: end,
              onChanged: onEndChanged,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _FieldLabel(
          label: 'Età',
          labelColor: Colors.white,
          child: SizedBox(
            height: 56,
            child: _AgeNumberField(
              value: age,
              onChanged: onAgeChanged,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _FieldLabel(
          label: 'Codice sconto',
          labelColor: Colors.white,
          child: SizedBox(
            height: 56,
            child: TextField(
              controller: couponCtrl,
              decoration: const InputDecoration(
                hintText: 'codice',
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: kCtaGreen,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: .4,
              ),
            ),
            onPressed: onSubmit,
            child: const Text('CERCA LA TUA AUTO'),
          ),
        ),
      ],
    );
  }
}

class _AgeNumberField extends StatefulWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  const _AgeNumberField({
    required this.value,
    required this.onChanged,
    Key? key,
  }) : super(key: key);

  @override
  State<_AgeNumberField> createState() => _AgeNumberFieldState();
}

class _AgeNumberFieldState extends State<_AgeNumberField> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.value == null ? '' : widget.value.toString(),
    );
  }

  @override
  void didUpdateWidget(covariant _AgeNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        (widget.value?.toString() ?? '') != _ctrl.text) {
      _ctrl.text =
          widget.value == null ? '' : widget.value.toString();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleChange(String v) {
    final parsed = int.tryParse(v);
    setState(() {
      if (parsed == null) {
        _error =
            null; // campo vuoto: nessun errore, lo gestirà la submit
      } else if (parsed <= 18) {
        _error = 'L’età deve essere > 18';
      } else {
        _error = null;
      }
    });
    widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 2,
      onChanged: _handleChange,
      decoration: const InputDecoration(
        hintText: 'es. 25',
        counterText: '',
        suffixText: 'anni',
      ).copyWith(errorText: _error),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final String? help;
  final Color? labelColor;
  final Color? iconColor;
  final Widget child;
  const _FieldLabel({
    required this.label,
    this.help,
    this.labelColor,
    this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final lc = labelColor ?? Colors.black87;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style:
                  TextStyle(color: lc, fontWeight: FontWeight.w600),
            ),
            if (help != null)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: iconColor ?? Colors.black45,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _DateTimePicker extends StatelessWidget {
  final DateTime? value;
  final void Function(DateTime) onChanged;
  const _DateTimePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(
      text: (value != null)
          ? DateFormat('dd/MM/yyyy HH:mm')
              .format(value!.toLocal())
          : '',
    );

    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () async {
        final now = DateTime.now();

        Theme themed(BuildContext ctx, Widget? child) {
          final base = Theme.of(ctx);
          final shape4 = RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          );
          return Theme(
            data: base.copyWith(
              dialogTheme: base.dialogTheme.copyWith(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: shape4,
              ),
              colorScheme: base.colorScheme.copyWith(
                surface: Colors.white,
                background: Colors.white,
                onSurface: Colors.black87,
                onBackground: Colors.black87,
              ),
              datePickerTheme: base.datePickerTheme.copyWith(
                backgroundColor: Colors.white,
                headerBackgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: shape4,
              ),
              timePickerTheme: base.timePickerTheme.copyWith(
                backgroundColor: Colors.white,
                shape: shape4,
                dialBackgroundColor: Colors.white,
                hourMinuteColor: Colors.white,
                hourMinuteTextColor: Colors.black87,
                hourMinuteShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(
                      color: Color(0x1F000000)),
                ),
                dayPeriodColor: base.colorScheme.primary,
                dayPeriodTextColor: Colors.black87,
                dayPeriodShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(
                      color: Color(0x1F000000)),
                ),
                helpTextStyle:
                    const TextStyle(color: Colors.black87),
                entryModeIconColor: Colors.black54,
              ),
            ),
            child: child!,
          );
        }

        // Date picker
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: now.subtract(const Duration(days: 1)),
          lastDate: now.add(const Duration(days: 365)),
          builder: (ctx, child) => themed(ctx, child),
        );
        if (date == null) return;

        // Time picker
        final time = await showTimePicker(
          context: context,
          initialTime:
              TimeOfDay.fromDateTime(value ?? now),
          builder: (ctx, child) => themed(ctx, child),
        );

        final dt = DateTime(
          date.year,
          date.month,
          date.day,
          time?.hour ?? 10,
          time?.minute ?? 0,
        );
        onChanged(dt);
      },
      decoration: const InputDecoration(
        hintText: '',
        suffixIcon: Icon(Icons.expand_more),
      ),
    );
  }
}

class _LocationInfoCard extends StatelessWidget {
  final Location? location;
  const _LocationInfoCard({required this.location});

  @override
  Widget build(BuildContext context) {
    if (location == null) {
      return const Text(
        'Seleziona una località',
        style: TextStyle(color: Colors.black54),
      );
    }
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(24),
      color: const Color(0xFFFFF1EA),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    location!.isAirport
                        ? Icons.local_airport
                        : Icons.location_city,
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      location!.locationName.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const Icon(Icons.close,
                      color: Colors.black45),
                ],
              ),
              const SizedBox(height: 8),
              if (location!.email != null)
                //Text(location!.email!),
                Text('info@rentalpremium.it'),
              if (location!.telephoneNumber != null)
                //Text(
                //    'phone: ${location!.telephoneNumber!}'),
              if (location!.locationAddress != null)
                Padding(
                  padding:
                      const EdgeInsets.only(top: 8.0),
                  child: Text(
                      location!.locationAddress!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
