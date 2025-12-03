import 'dart:convert';
import 'package:car_rent_webui/app.dart';
import 'package:car_rent_webui/car_rent_sdk/sdk.dart';
import 'package:car_rent_webui/core/deeplink/initial_config.dart';
import 'package:car_rent_webui/features/results/models/offer_adapter.dart';
import 'package:car_rent_webui/features/results/presentation/pages/extras_page.dart';
import 'package:car_rent_webui/features/results/widgets/steps_header.dart';
import 'package:car_rent_webui/features/results/widgets/vehicle_card.dart';
import 'package:car_rent_webui/features/search/data/myrent_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/top_nav_bar.dart';

/// Brand orange
const kBrand = Color(0xFFFF5A19);
const kBrandDark = Color(0xFFE2470C);

class ResultsArgs {
  final QuotationResponse response;
  final InitialConfig? cfg;

  const ResultsArgs({required this.response, this.cfg});
}

/// Args usati quando arrivo *solo* con InitialConfig (da cfg in URL / deep-link)
class ResultsArgsFromConfig {
  final InitialConfig cfg;
  const ResultsArgsFromConfig(this.cfg);
}

class ResultsPage extends StatefulWidget {
  static const routeName = '/result_page';
  const ResultsPage({super.key});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  /// Repository per caricare la quotation a partire da InitialConfig
  final MyrentRepository _repo = MyrentRepository();

  bool _hydrated = false;   // ho idratato gli stati interni a partire dalla quotation
  bool _loading = false;    // sto chiamando il backend
  String? _error;           // eventuale messaggio d’errore

  Map<String, dynamic>? _rootJson;
  Map<String, dynamic>? _dataJson;

  // Offerte
  List<Offer> _all = [];

  InitialConfig? _cfg;
  Offer? _preselected;

  // Filtri correnti
  String? _fuelFilter;
  String? _gearFilter;
  int? _seatsFilter;

  // Domini filtri
  List<String> _fuels = [];
  List<String> _gears = [];
  List<int> _seats = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Evita di rilanciare logica se già idratato o in loading
    if (_hydrated || _loading) return;

    // 1) Recupero argomenti della route
    final arg = ModalRoute.of(context)?.settings.arguments;
    QuotationResponse? q;

    if (arg is ResultsArgs) {
      // Modalità “vecchia”: ho già la quotation pronta
      q = arg.response;
      _cfg = arg.cfg;
    } else if (arg is QuotationResponse) {
      // Fallback storico: qualcuno passa direttamente la quotation
      q = arg;
    } else if (arg is ResultsArgsFromConfig) {
      // Modalità “nuova”: ho solo InitialConfig, devo chiamare il backend
      _cfg = arg.cfg;
    }

    // 2) Se ho già una quotation → idrato subito
    if (q != null) {
      _hydrateFromQuotation(q);
      return;
    }

    // 3) Se non ho quotation ma ho una InitialConfig → chiamo il backend
    if (_cfg != null) {
      _loadFromConfig(_cfg!); // async, mostrerà loader
      return;
    }

    // 4) Caso di fallback: nessun dato e nessuna config
    setState(() {
      _hydrated = true;
      _loading = false;
      _error = 'Nessuna configurazione (cfg) trovata per caricare i risultati.';
    });
  }

  /// Carica la quotation dal backend partendo da InitialConfig
  /// imponendo un tempo minimo di caricamento di 4 secondi.
  Future<void> _loadFromConfig(InitialConfig cfg) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // Stopwatch per misurare il tempo effettivo della chiamata
    final sw = Stopwatch()..start();

    try {
      final q = await _repo.createQuotationFromConfig(cfg);

      // Calcolo quanto tempo manca per arrivare almeno a 4 secondi
      sw.stop();
      const minDuration = Duration(seconds: 4);
      final elapsed = sw.elapsed;
      final remaining = minDuration - elapsed;
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }

      if (!mounted) return;
      _hydrateFromQuotation(q);
    } catch (e) {
      sw.stop();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Errore durante il caricamento dei risultati: $e';
      });
    }
  }

  /// Idra tutta la pagina a partire da una QuotationResponse
  void _hydrateFromQuotation(QuotationResponse q) {
    // 1) Estraggo JSON sorgente
    _rootJson = q.toJson() as Map<String, dynamic>?;
    _dataJson = (_rootJson?['data'] is Map)
        ? _rootJson!['data'] as Map<String, dynamic>
        : null;

    // 2) Leggo "Vehicles" in modo sicuro (senza assumere i tipi)
    final List<Map<String, dynamic>> raw = (_dataJson?['Vehicles'] is List)
        ? List<Map<String, dynamic>>.from(
            (_dataJson!['Vehicles'] as List)
                .where((e) => e is Map)
                .map((e) => Map<String, dynamic>.from(e as Map)),
          )
        : <Map<String, dynamic>>[];

    // 3) Popolo `_all` usando l’adapter
    _all = raw.map((m) => Offer.fromJson(m)).toList();

    // (facoltativo) ordino per totale se disponibile
    _all.sort((a, b) {
      final ax = a.total ?? double.infinity;
      final bx = b.total ?? double.infinity;
      return ax.compareTo(bx);
    });

    // 4) Ora posso calcolare la preselezione (serve `_all` piena)
    _preselected = _selectByVehicleId(_cfg?.vehicleId);

    // 5) Domini per i filtri (ora che `_all` è popolata)
    _fuels = {
      for (final o in _all)
        if (o.fuel?.isNotEmpty == true) o.fuel!
    }.toList()
      ..sort();

    _gears = {
      for (final o in _all)
        if (o.transmission?.isNotEmpty == true) o.transmission!
    }.toList()
      ..sort();

    _seats = {
      for (final o in _all)
        if (o.seats != null && o.seats! > 0) o.seats!
    }.toList()
      ..sort();

    _hydrated = true;
    _loading = false;
    _error = null;

    if (mounted) {
      setState(() {});
    }

    // 6) Deep-link avanzato: se step>=3 con auto pre-selezionata, vai direttamente agli extra
    if (_cfg != null &&
        (_cfg!.step) >= 3 &&
        _preselected != null &&
        _dataJson != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExtrasPage(
              dataJson: _dataJson!,
              selected: _preselected!,
              preselectedExtras: _cfg!.extras,
              initialConfig: _cfg,
            ),
          ),
        );
      });
    }
  }

  /// Se ho nel cfg un vehicleId di partenza, lo cerco nelle offerte
  Offer? _selectByVehicleId(String? vehicleId) {
    if (vehicleId == null || vehicleId.isEmpty) return null;

    // helper locale stile firstWhereOrNull
    Offer? _firstWhereOrNull(bool Function(Offer) test) {
      for (final o in _all) {
        if (test(o)) return o;
      }
      return null;
    }

    // tentativi in ordine: id, vehicleId, code, nationalCode
    return _firstWhereOrNull(
          (o) =>
              (o.id?.toString() == vehicleId) ||
              (o.vehicleId?.toString() == vehicleId),
        ) ??
        _firstWhereOrNull(
          (o) =>
              (o.code?.toString() == vehicleId) ||
              (o.nationalCode?.toString() == vehicleId),
        );
  }

  /// UI di caricamento con barra di progresso infinita
  Widget _buildLoadingScaffold(BuildContext context, String message) {
    return Scaffold(
      appBar: AppUiFlags.showAppBarOf(context) ? const TopNavBar() : null,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Caricamento risultati',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Barra di avanzamento infinita
                const SizedBox(
                  width: double.infinity,
                  child: LinearProgressIndicator(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1) Loading iniziale: sto chiamando il backend partendo da cfg
    if (_loading && !_hydrated) {
      return _buildLoadingScaffold(
        context,
        'Stiamo calcolando le migliori offerte per la tua ricerca...',
      );
    }

    // 2) Errore di caricamento
    if (_error != null) {
      return Scaffold(
        appBar: AppUiFlags.showAppBarOf(context) ? const TopNavBar() : null,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (_cfg != null)
                  FilledButton(
                    onPressed: () => _loadFromConfig(_cfg!),
                    child: const Text('Riprova'),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // 3) Fallback: non sto più caricando ma non sono idratato (caso raro)
    if (!_hydrated) {
      // ri-uso la stessa UI di loading
      return _buildLoadingScaffold(
        context,
        'Prepariamo i risultati per la tua ricerca...',
      );
    }

    // 4) Dati pronti: UI classica dei risultati
    final hasData = _dataJson != null && _all.isNotEmpty;

    return Scaffold(
      appBar: AppUiFlags.showAppBarOf(context) ? const TopNavBar() : null,
      body: hasData
          ? Column(
              children: [
                // HEADER: pagina Step 2 (qui non c'è ancora una vettura selezionata)
                StepsHeader(
                  currentStep: 2,
                  accent: kBrandDark,
                  step2Title: _preselected?.group,
                  step2Subtitle: _preselected?.name,
                  step2Thumb: _preselected?.imageUrl,
                  step1Pickup: _displayLocationName(
                        _dataJson!,
                        codeKey: 'PickUpLocation',
                        nameCandidates: const [
                          'PickUpLocationName',
                          'pickupName',
                          'PickupName',
                          'PickupCity',
                          'pickupCity',
                        ],
                      ) ??
                      _dataJson?['PickUpLocation']?.toString(),
                  step1Dropoff: _displayLocationName(
                        _dataJson!,
                        codeKey: 'ReturnLocation',
                        nameCandidates: const [
                          'ReturnLocationName',
                          'returnName',
                          'ReturnCity',
                          'returnCity',
                        ],
                      ) ??
                      _dataJson?['ReturnLocation']?.toString(),
                  step1Start:
                      _fmtDate(_dataJson?['PickUpDateTime']?.toString()),
                  step1End:
                      _fmtDate(_dataJson?['ReturnDateTime']?.toString()),
                  // Navigazione dagli step nell'header:
                  // - clic su step 1 (o "MODIFICA" di step 1) -> torna alla pagina precedente
                  // - clic su step 2 non fa nulla (siamo già allo step 2)
                  onTapStep: (n) {
                    if (n == 1) {
                      Navigator.of(context).maybePop();
                    }
                  },
                ),

                const SizedBox(height: 12),

                // FILTRI — dropdown ancorati al campo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Text(
                          'filtra per',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_fuels.isNotEmpty)
                        _ModernDropdown<String>(
                          label: 'alimentazione',
                          value: _fuelFilter,
                          items: _fuels,
                          itemLabel: (s) => s,
                          onChanged: (v) =>
                              setState(() => _fuelFilter = v),
                        ),
                      if (_gears.isNotEmpty)
                        _ModernDropdown<String>(
                          label: 'trasmissione',
                          value: _gearFilter,
                          items: _gears,
                          itemLabel: (s) => s,
                          onChanged: (v) =>
                              setState(() => _gearFilter = v),
                        ),
                      if (_seats.isNotEmpty)
                        _ModernDropdown<int>(
                          label: 'numero di posti',
                          value: _seatsFilter,
                          items: _seats,
                          itemLabel: (n) => '$n',
                          onChanged: (v) =>
                              setState(() => _seatsFilter = v),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // GRIGLIA OFFERTE (card altezza fissa)
                Expanded(
                  child: LayoutBuilder(
                    builder: (ctx, c) {
                      const minTile = 500.0;
                      const spacing = 16.0;

                      int cols = (c.maxWidth / minTile).floor();
                      cols = cols.clamp(1, 6);

                      while (cols > 1) {
                        final available =
                            c.maxWidth - (cols - 1) * spacing;
                        final tile = available / cols;
                        if (tile >= minTile) break;
                        cols--;
                      }

                      final filtered = _filtered();

                      return GridView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: spacing,
                          crossAxisSpacing: spacing,
                          mainAxisExtent: VehicleCard.cardHeight,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => VehicleCard(
                          offer: filtered[i],
                          accent: kBrandDark,
                          includeItems: const [
                            'IVA',
                            'Km illimitati',
                            'Oneri aeroportuali (ove previsti)',
                            'Oneri circolazione',
                            'Riduzione responsabilità danni',
                            'Riduzione responsabilità furto',
                          ],
                          excludeItems: const [
                            'Traffico all’estero',
                            'Opzioni facoltative disponibili al desk',
                          ],
                          onChoose: () {
                            final selectedOffer = filtered[i];

                            // Partiamo dalla cfg (se presente) o la ricostruiamo dai dati base
                            final cfgStep3 =
                                (_cfg ??
                                        InitialConfig.fromManual(
                                          pickupCode: _dataJson![
                                                      'PickUpLocation']
                                                  ?.toString() ??
                                              '',
                                          dropoffCode:
                                              _dataJson!['ReturnLocation']
                                                      ?.toString() ??
                                                  '',
                                          startUtc: DateTime.parse(
                                            _dataJson!['PickUpDateTime']
                                                as String,
                                          ),
                                          endUtc: DateTime.parse(
                                            _dataJson!['ReturnDateTime']
                                                as String,
                                          ),
                                          age: null,
                                          coupon: null,
                                          channel: 'WEB_APP',
                                          initialStep: 3,
                                        ))
                                    .copyWith(
                                      step: 3,
                                      vehicleId: selectedOffer.id ??
                                          selectedOffer.vehicleId ??
                                          selectedOffer.code,
                                    )
                                    .withOriginalFromSelf(); // assicura originalMap

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExtrasPage(
                                  dataJson: _dataJson!,
                                  selected: selectedOffer,
                                  initialConfig: cfgStep3,
                                  preselectedExtras: const [],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            )
          : _JsonPretty(obj: _rootJson ?? const {'error': 'Nessun dato'}),
    );
  }

  List<Offer> _filtered() {
    return _all.where((o) {
      final okFuel = _fuelFilter == null ||
          (o.fuel?.toLowerCase() == _fuelFilter!.toLowerCase());
      final okGear = _gearFilter == null ||
          (o.transmission?.toLowerCase() == _gearFilter!.toLowerCase());
      final okSeats = _seatsFilter == null || (o.seats == _seatsFilter);
      return okFuel && okGear && okSeats;
    }).toList();
  }
}

/* ----------------- UI helper locali ----------------- */

/// Dropdown moderno ancorato al campo: menu sotto al pulsante,
/// con gap verticale, larghezza uguale al pulsante e bordo grigio sottile.
class _ModernDropdown<T> extends StatefulWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _ModernDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  State<_ModernDropdown<T>> createState() => _ModernDropdownState<T>();
}

class _ModernDropdownState<T> extends State<_ModernDropdown<T>> {
  final MenuController _menu = MenuController();
  final GlobalKey _fieldKey = GlobalKey();
  double _menuWidth = 0;

  void _open(MenuController c) {
    // misura la larghezza del pulsante
    final ctx = _fieldKey.currentContext;
    if (ctx != null) {
      final box = ctx.findRenderObject() as RenderBox?;
      if (box != null) _menuWidth = box.size.width;
    }
    setState(() {});
    c.open();
  }

  @override
  Widget build(BuildContext context) {
    final field = Container(
      key: _fieldKey,
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.value == null
                ? widget.label
                : widget.itemLabel(widget.value as T),
            style: TextStyle(
              color: widget.value == null
                  ? Colors.black54
                  : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard_arrow_down, size: 18),
        ],
      ),
    );

    return MenuAnchor(
      controller: _menu,
      style: MenuStyle(
        backgroundColor: MaterialStateProperty.all(Colors.white),
        elevation: MaterialStateProperty.all(10),
        surfaceTintColor: MaterialStateProperty.all(Colors.white),
        // bordo grigio sottile + angoli 4px
        shape: MaterialStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
        ),
        padding: MaterialStateProperty.all(EdgeInsets.zero),
        shadowColor: MaterialStateProperty.all(
          Colors.black.withOpacity(.12),
        ),
      ),
      menuChildren: [
        SizedBox(
          width: _menuWidth > 0 ? _menuWidth : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final it in widget.items)
                SizedBox(
                  width: double.infinity,
                  child: MenuItemButton(
                    style: ButtonStyle(
                      padding: MaterialStateProperty.all(
                        const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                      overlayColor: MaterialStateProperty.all(
                        const Color(0xFFEEEEEE),
                      ),
                    ),
                    onPressed: () {
                      widget.onChanged(it);
                      _menu.close();
                    },
                    child: Text(widget.itemLabel(it)),
                  ),
                ),
            ],
          ),
        ),
      ],
      builder: (context, controller, child) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () =>
              controller.isOpen ? controller.close() : _open(controller),
          child: field,
        );
      },
    );
  }
}

class _JsonPretty extends StatelessWidget {
  final Object obj;
  const _JsonPretty({required this.obj});

  @override
  Widget build(BuildContext context) {
    final jsonStr =
        const JsonEncoder.withIndent('  ').convert(obj);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1020),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SelectableText(
          jsonStr,
          style: const TextStyle(
            fontFamily: 'monospace',
            color: Color(0xFFCCF2FF),
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}

/* ----------------- funzioni utili ----------------- */

String? _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  try {
    final dt = DateTime.parse(iso).toLocal();
    return DateFormat('d MMM, y HH:mm', 'it_IT').format(dt);
  } catch (_) {
    return iso;
  }
}

String? _displayLocationName(
  Map<String, dynamic> m, {
  required String codeKey,
  required List<String> nameCandidates,
}) {
  for (final k in nameCandidates) {
    final v = m[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return m[codeKey]?.toString();
}
