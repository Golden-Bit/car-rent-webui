import 'dart:convert';
import 'package:car_rent_webui/app.dart';
import 'package:car_rent_webui/car_rent_sdk/sdk.dart';
import 'package:car_rent_webui/core/deeplink/initial_config.dart';
import 'package:car_rent_webui/features/results/models/offer_adapter.dart';
import 'package:car_rent_webui/features/results/presentation/pages/extras_page.dart';
import 'package:car_rent_webui/features/results/widgets/steps_header.dart';
import 'package:car_rent_webui/features/results/widgets/vehicle_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/top_nav_bar.dart';

/// Brand orange
const kBrand = Color(0xFFFF5A19);
const kBrandDark = Color(0xFFE2470C);

class ResultsArgs {
  final QuotationResponse response;
  final InitialConfig? cfg;
  ResultsArgs({required this.response, this.cfg});
}

class ResultsPage extends StatefulWidget {
  static const routeName = '/results';
  const ResultsPage({super.key});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  bool _hydrated = false;

  late final Map<String, dynamic>? _rootJson;
  late final Map<String, dynamic>? _dataJson;

  // Offerte
  List<Offer> _all = [];

  InitialConfig? _cfg;               
  Offer? _preselected;              

  // Filtri
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
  if (_hydrated) return;

  // 1) Recupero argomenti
  final arg = ModalRoute.of(context)?.settings.arguments;
  QuotationResponse? q;
  if (arg is ResultsArgs) {
    q = arg.response;
    _cfg = arg.cfg;
  } else if (arg is QuotationResponse) {
    q = arg;
  }

  // 2) Estraggo JSON sorgente
  _rootJson = q?.toJson() as Map<String, dynamic>?;
  _dataJson = (_rootJson?['data'] is Map)
      ? _rootJson!['data'] as Map<String, dynamic>
      : null;

  // 3) Leggo "Vehicles" in modo sicuro (senza assumere i tipi)
  final List<Map<String, dynamic>> raw = (_dataJson?['Vehicles'] is List)
      ? List<Map<String, dynamic>>.from(
          (_dataJson!['Vehicles'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
        )
      : <Map<String, dynamic>>[];

  // 4) **POPOLO `_all`** usando l’adapter che mi hai dato
  _all = raw.map((m) => Offer.fromJson(m)).toList();

  // (facoltativo) ordino per totale se disponibile
  _all.sort((a, b) {
    final ax = a.total ?? double.infinity;
    final bx = b.total ?? double.infinity;
    return ax.compareTo(bx);
  });

  // 5) Ora posso calcolare la preselezione (serve `_all` piena)
  _preselected = _selectByVehicleId(_cfg?.vehicleId);

  // 6) Domini per i filtri (ora che `_all` è popolata)
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
  if (mounted) setState(() {});

  // 7) Se arrivo da deep-link ed è richiesto Step>=3 con auto pre-selezionata, vai direttamente agli extra
  if (_cfg != null && (_cfg!.step) >= 3 && _preselected != null && _dataJson != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExtrasPage(
            dataJson: _dataJson!,
            selected: _preselected!,
            preselectedExtras: _cfg!.extras,
            initialConfig: _cfg, // NEW
          ),
        ),
      );
    });
  }
}


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
           (o) => (o.id?.toString() == vehicleId) || (o.vehicleId?.toString() == vehicleId),
         ) ??
         _firstWhereOrNull(
           (o) => (o.code?.toString() == vehicleId) || (o.nationalCode?.toString() == vehicleId),
         );
}


  @override
  Widget build(BuildContext context) {
    if (!_hydrated) {
      return const Scaffold(
        appBar: null,
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
                    step2Title: _preselected?.group,        // ADD
  step2Subtitle: _preselected?.name,      // ADD
  step2Thumb: _preselected?.imageUrl,     // ADD
                  step1Pickup: _displayLocationName(
                        _dataJson!,
                        codeKey: 'PickUpLocation',
                        nameCandidates: const [
                          'PickUpLocationName',
                          'pickupName',
                          'PickupName',
                          'PickupCity',
                          'pickupCity'
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
                          'returnCity'
                        ],
                      ) ??
                      _dataJson?['ReturnLocation']?.toString(),
                  step1Start: _fmtDate(_dataJson?['PickUpDateTime']?.toString()),
                  step1End: _fmtDate(_dataJson?['ReturnDateTime']?.toString()),
                  // Navigazione dagli step nell'header:
                  // - clic su step 1 (o "MODIFICA" di step 1) -> torna alla pagina precedente (inserimento dati)
                  // - clic su step 2 non fa nulla (siamo già allo step 2)
                  onTapStep: (n) {
                    if (n == 1) {
                      Navigator.of(context).maybePop();
                    }
                  },
                ),

                const SizedBox(height: 12),

                // FILTRI — dropdown ancorati con bordo, gap e larghezza uguale al pulsante
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
                          onChanged: (v) => setState(() => _fuelFilter = v),
                        ),
                      if (_gears.isNotEmpty)
                        _ModernDropdown<String>(
                          label: 'trasmissione',
                          value: _gearFilter,
                          items: _gears,
                          itemLabel: (s) => s,
                          onChanged: (v) => setState(() => _gearFilter = v),
                        ),
                      if (_seats.isNotEmpty)
                        _ModernDropdown<int>(
                          label: 'numero di posti',
                          value: _seatsFilter,
                          items: _seats,
                          itemLabel: (n) => '$n',
                          onChanged: (v) => setState(() => _seatsFilter = v),
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
                        final available = c.maxWidth - (cols - 1) * spacing;
                        final tile = available / cols;
                        if (tile >= minTile) break;
                        cols--;
                      }

                      final filtered = _filtered();

                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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

  // Partiamo dalla cfg (già passata da AdvancedSearchPage)
  final cfgStep3 = (_cfg ?? InitialConfig.fromManual(
        pickupCode: _dataJson!['PickUpLocation']?.toString() ?? '',
        dropoffCode: _dataJson!['ReturnLocation']?.toString() ?? '',
        startUtc: DateTime.parse(_dataJson!['PickUpDateTime'] as String),
        endUtc: DateTime.parse(_dataJson!['ReturnDateTime'] as String),
        age: null,
        coupon: null,
        channel: 'WEB_APP',
        initialStep: 3,
      ))
      .copyWith(
        step: 3,
        vehicleId: selectedOffer.id ?? selectedOffer.vehicleId ?? selectedOffer.code,
      )
      .withOriginalFromSelf(); // assicura originalMap

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ExtrasPage(
        dataJson: _dataJson!,
        selected: selectedOffer,
        initialConfig: cfgStep3,          // <<<<<<<<<<<<<<<<<<<<<<<<
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
          : _JsonPretty(obj: _rootJson ?? {'error': 'Nessun dato'}),
    );
  }

  List<Offer> _filtered() {
    return _all.where((o) {
      final okFuel =
          _fuelFilter == null || (o.fuel?.toLowerCase() == _fuelFilter!.toLowerCase());
      final okGear =
          _gearFilter == null || (o.transmission?.toLowerCase() == _gearFilter!.toLowerCase());
      final okSeats = _seatsFilter == null || (o.seats == _seatsFilter);
      return okFuel && okGear && okSeats;
    }).toList();
  }
}

/* ----------------- UI helper locali ----------------- */

/// Dropdown moderno ancorato al campo: menu sotto al pulsante,
/// con **gap verticale**, **larghezza uguale al pulsante** e **bordo grigio sottile**.
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.value == null ? widget.label : widget.itemLabel(widget.value as T),
            style: TextStyle(
              color: widget.value == null ? Colors.black54 : Colors.black87,
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
        shadowColor: MaterialStateProperty.all(Colors.black.withOpacity(.12)),
      ),
      menuChildren: [
        // gap tra pulsante e menu (visivo): 6px
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
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          onTap: () => controller.isOpen ? controller.close() : _open(controller),
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
    final jsonStr = const JsonEncoder.withIndent('  ').convert(obj);
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
