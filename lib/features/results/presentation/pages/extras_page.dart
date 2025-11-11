import 'dart:math';
import 'package:car_rent_webui/app.dart';
import 'package:car_rent_webui/core/deeplink/initial_config.dart';
import 'package:car_rent_webui/features/results/models/offer_adapter.dart';
import 'package:car_rent_webui/features/results/widgets/steps_header.dart';
import 'package:car_rent_webui/features/results/presentation/pages/confirm_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/top_nav_bar.dart';

class ExtrasPageArgs {
  final Map<String, dynamic> dataJson;
  final Offer selected;
  final List<InitialExtra> preselectedExtras;

  const ExtrasPageArgs({
    required this.dataJson,
    required this.selected,
    this.preselectedExtras = const [],
  });
}
/// Brand
const kBrand = Color(0xFFFF5A19);
const kBrandDark = Color(0xFFE2470C);

class ExtrasPage extends StatefulWidget {
   static const routeName = '/extras'; // <-- AGGIUNTO
  final Map<String, dynamic> dataJson;
  final Offer selected;
  final InitialConfig? initialConfig; // NEW
final List<InitialExtra> preselectedExtras;
  const ExtrasPage({
    super.key,
    required this.dataJson,
    required this.selected,
    this.preselectedExtras = const [],
    this.initialConfig,
  });

  @override
  State<ExtrasPage> createState() => _ExtrasPageState();
}

class _ExtrasPageState extends State<ExtrasPage> {
  int _selectedPlan = -1; // 0=Gold, 1=Platinum, 2=Premium
  final Set<int> _selectedOptionals = {};

  late final int _rentalDays;
  late final List<_OptionalVM> _optionals;

  // NEW: applica preselezione (match su EquipType, fallback su Description/titolo)
  void _applyPreselectedExtras(List<InitialExtra> xs) {
    if (xs.isEmpty) return;
    for (var i = 0; i < _optionals.length; i++) {
      final code = _extractCodeFromRaw(widget.dataJson, i);
      final title = _optionals[i].title.toLowerCase();
      final hit = xs.any((x) {
        final xcode = x.code.toLowerCase();
        return (code != null && xcode == code.toLowerCase()) || xcode == title;
      });
      if (hit) _selectedOptionals.add(i);
    }
    // non setState qui: initState termina prima del primo build
  }

  // NEW: estrae il codice raw dell'optional (EquipType o Description)
  String? _extractCodeFromRaw(Map<String, dynamic> data, int index) {
    final list = data['optionals'];
    if (list is! List || index < 0 || index >= list.length) return null;
    final m = (list[index] as Map).cast<String, dynamic>();
    final equip = (m['Equipment'] as Map?)?.cast<String, dynamic>();
    return (equip?['EquipType'] as String?) ??
           (equip?['Description'] as String?);
  }

  // NEW: totale grezzo degli extra selezionati, rispettando isMultipliable * giorni
  num get _extrasTotalRaw {
    final list = widget.dataJson['optionals'];
    if (list is! List) return 0;
    num sum = 0;
    for (final idx in _selectedOptionals) {
      final raw = (list[idx] as Map).cast<String, dynamic>();
      final charge = (raw['Charge'] as Map?)?.cast<String, dynamic>() ?? const {};
      final equip  = (raw['Equipment'] as Map?)?.cast<String, dynamic>() ?? const {};
      final amount = (charge['Amount'] as num?) ?? 0;
      final perDay = (equip['isMultipliable'] as bool?) ?? true;
      sum += perDay ? amount * _rentalDays : amount;
    }
    return sum;
  }

  // NEW: formato stringa per StepsHeader
  String get _extrasTotalFmt => _formatMoney(_extrasTotalRaw, 'EUR');

  @override
  void initState() {
    super.initState();
    _rentalDays = _computeRentalDays(widget.dataJson);
    _optionals = _readOptionals(widget.dataJson);

    _applyPreselectedExtras(widget.preselectedExtras); // NEW
  }

  @override
  Widget build(BuildContext context) {
    final priceForHeader = _formatHeaderPrice(widget.dataJson, widget.selected);

    return Scaffold(
      appBar: AppUiFlags.showAppBarOf(context) ? const TopNavBar() : null,
      body: Column(
        children: [
          // HEADER (Step 3)
          StepsHeader(
            currentStep: 3,
            accent: kBrandDark,
  // NEW ↓ (lista etichette + totale formattato)
  step3Extras: _selectedOptionals.map((i) => _optionals[i].title).toList(),
  step3ExtrasTotal: _extrasTotalFmt,
            step1Pickup: _displayLocationName(
                  widget.dataJson,
                  codeKey: 'PickUpLocation',
                  nameCandidates: const [
                    'PickUpLocationName',
                    'pickupName',
                    'PickupName',
                    'PickupCity',
                    'pickupCity'
                  ],
                ) ??
                widget.dataJson['PickUpLocation']?.toString(),
            step1Dropoff: _displayLocationName(
                  widget.dataJson,
                  codeKey: 'ReturnLocation',
                  nameCandidates: const [
                    'ReturnLocationName',
                    'returnName',
                    'ReturnCity',
                    'returnCity'
                  ],
                ) ??
                widget.dataJson['ReturnLocation']?.toString(),
            step1Start: _fmtDate(widget.dataJson['PickUpDateTime']?.toString()),
            step1End: _fmtDate(widget.dataJson['ReturnDateTime']?.toString()),
            step2Title: widget.selected.group ?? 'Auto',
            step2Subtitle: widget.selected.name ?? '',
            step2Thumb: widget.selected.imageUrl,
            step2Price: priceForHeader,
            onTapStep: (n) {
              if (n == 2) {
                Navigator.of(context).maybePop(); // 3 -> 2
              } else if (n == 1) {
                // 3 -> 2 -> 1 (pop doppio su frame successivo per sicurezza)
                Navigator.of(context).maybePop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).maybePop();
                  }
                });
              }
            },
          ),

          // CONTENUTO (Sliver: niente nested scrollables/problematic Flex)
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _InsuranceSection(
                      days: _rentalDays,
                      selectedIndex: _selectedPlan,
                      onSelect: (i) => setState(() => _selectedPlan = i),
                    ),
                  ),
                ),

                // Titolo sezione Optional
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Rendi unico il tuo noleggio',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .2,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Scegli i nostri accessori e servizi extra per personalizzare il tuo viaggio e rendere unica la tua esperienza di noleggio',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),

                // Griglia Optional – responsive
                if (_optionals.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final it = _optionals[i];
                          final isSel = _selectedOptionals.contains(i);
                          return _OptionalCard(
                            vm: it,
                            selected: isSel,
                            onTap: () {
                              setState(() {
                                if (isSel) {
                                  _selectedOptionals.remove(i);
                                } else {
                                  _selectedOptionals.add(i);
                                }
                              });
                            },
                          );
                        },
                        childCount: _optionals.length,
                      ),
                      // max 420px a tile -> 4/3/2/1 colonne a seconda della larghezza
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 420,
                        mainAxisExtent: 150,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: const SliverToBoxAdapter(
                      child: Text('Nessun optional disponibile per questa offerta.'),
                    ),
                  ),

                // Pulsante Prosegui
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: Align(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBrandDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 26, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
onPressed: () {
  // 1) Costruisci la lista di InitialExtra dai selezionati
  final extras = <InitialExtra>[];
  final rawList = (widget.dataJson['optionals'] as List?) ?? const [];
  for (final idx in _selectedOptionals) {
    if (idx < 0 || idx >= rawList.length) continue;
    final raw = (rawList[idx] as Map).cast<String, dynamic>();
    final equip = (raw['Equipment'] as Map?)?.cast<String, dynamic>() ?? const {};
    final code = (equip['EquipType'] as String?) ??
        (equip['Description'] as String?) ??
        'EXTRA_${idx + 1}';
    final perDay = (equip['isMultipliable'] as bool?) ?? true;
    extras.add(InitialExtra(code: code, qty: 1, perDay: perDay));
  }

  // 2) Partiamo dalla cfg già presente o ricostruiamola dal dataJson
  final pickCode = widget.dataJson['PickUpLocation']?.toString() ?? '';
  final dropCode = widget.dataJson['ReturnLocation']?.toString() ?? '';
  final startIso = widget.dataJson['PickUpDateTime']?.toString();
  final endIso = widget.dataJson['ReturnDateTime']?.toString();

  InitialConfig base = widget.initialConfig ??
      InitialConfig.fromManual(
        pickupCode: pickCode,
        dropoffCode: dropCode,
        startUtc: startIso != null ? DateTime.parse(startIso) : DateTime.now().toUtc(),
        endUtc: endIso != null ? DateTime.parse(endIso) : DateTime.now().toUtc(),
        channel: 'WEB_APP',
        initialStep: 3,
      );

  // 3) Aggiorna con step=4, vehicleId e extras → e assicurati originalMap
  final cfgForConfirm = base
      .copyWith(
        step: 4,
        vehicleId: base.vehicleId ?? widget.selected.id ?? widget.selected.vehicleId ?? widget.selected.code,
        extras: extras,
      )
      .withOriginalFromSelf();

  // 4) Vai alla Confirm
Navigator.pushNamed(
  context,
  ConfirmPage.routeName,
  arguments: ConfirmArgs(
    cfg: cfgForConfirm,
    dataJson: widget.dataJson,
    selected: widget.selected,
    selectedExtras: extras, // la lista InitialExtra costruita al “Prosegui”
  ),
);
},

                        child: const Text('Prosegui'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /* ---------------- helpers ---------------- */

  static int _computeRentalDays(Map<String, dynamic> data) {
    try {
      final pick = DateTime.parse(data['PickUpDateTime'] as String);
      final ret = DateTime.parse(data['ReturnDateTime'] as String);
      final hours = ret.difference(pick).inHours;
      return max(1, (hours / 24.0).ceil());
    } catch (_) {
      return 1;
    }
  }

  static List<_OptionalVM> _readOptionals(Map<String, dynamic> data) {
    final list = data['optionals'];
    if (list is! List) return const [];
    return list.map<_OptionalVM>((raw) {
      final m = (raw is Map) ? raw.cast<String, dynamic>() : <String, dynamic>{};
      final charge = (m['Charge'] is Map)
          ? (m['Charge'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      final equip = (m['Equipment'] is Map)
          ? (m['Equipment'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};

      final amount = (charge['Amount'] as num?)?.toDouble();
      final currency = charge['CurrencyCode'] as String?;
      final desc = (equip['Description'] ?? '').toString();
      final isPerDay = (equip['isMultipliable'] as bool?) ?? true;
      final image = equip['optionalImage']?.toString();

      return _OptionalVM(
        title: desc.isEmpty ? 'Optional' : desc,
        price: _formatMoney(amount, currency),
        perDay: isPerDay,
        imageUrl: image,
      );
    }).toList();
  }

  static String? _formatHeaderPrice(Map<String, dynamic> dataJson, Offer selected) {
    String? _fmt(num? amount, String? currencyCode) {
      if (amount == null) return null;
      final symbol =
          (currencyCode == 'EUR' || currencyCode == null) ? '€' : currencyCode;
      try {
        return NumberFormat.currency(locale: 'it_IT', symbol: symbol).format(amount);
      } catch (_) {
        return '$symbol ${amount.toStringAsFixed(2)}';
      }
    }

    final tc = (dataJson['TotalCharge'] is Map)
        ? Map<String, dynamic>.from(dataJson['TotalCharge'] as Map)
        : null;

    final num? amountFromData =
        (tc?['RateTotalAmount'] as num?) ?? (tc?['EstimatedTotalAmount'] as num?);
    final String? currFromData = tc?['CurrencyCode'] as String?;

    final formattedFromData = _fmt(amountFromData, currFromData);
    if (formattedFromData != null) return formattedFromData;

    final raw = selected.raw;
    final tc2 = (raw is Map && raw['TotalCharge'] is Map)
        ? Map<String, dynamic>.from(raw['TotalCharge'] as Map)
        : null;

    final num? amountFromRaw =
        (tc2?['RateTotalAmount'] as num?) ?? (tc2?['EstimatedTotalAmount'] as num?);
    final String? currFromRaw = tc2?['CurrencyCode'] as String?;

    return _fmt(amountFromRaw, currFromRaw);
  }

  static String? _displayLocationName(
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

  static String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('d MMM, y HH:mm', 'it_IT').format(dt);
    } catch (_) {
      return iso;
    }
  }

  static String _formatMoney(num? amount, String? currency) {
    final sym = (currency == null || currency == 'EUR') ? '€' : currency;
    if (amount == null) return '$sym 0,00';
    try {
      return NumberFormat.currency(locale: 'it_IT', symbol: sym).format(amount);
    } catch (_) {
      return '$sym ${amount.toStringAsFixed(2)}';
    }
  }
}

/* ========================
 *  SEZIONE 1 – ASSICURAZIONE (foto 1)
 * ======================== */

class _InsuranceSection extends StatelessWidget {
  final int days;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _InsuranceSection({
    required this.days,
    required this.selectedIndex,
    required this.onSelect,
  });

  static const _green = Color(0xFF5E9D2D);
  static const _greenPale = Color(0xFFE9F8E9);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: LayoutBuilder(
        builder: (ctx, c) {
          // Colonna sinistra (testi "Il tuo piano include")
          final left = SizedBox(
            width: min(380.0, max(280.0, c.maxWidth * 0.28)),
            child: const _LeftIncluded(),
          );

          // Colonne pacchetti – larghezza minima 280 per renderle come in foto
          final colWidth = min(360.0, max(280.0, (c.maxWidth - 420) / 3));
          final plans = [
            SizedBox(
              width: colWidth,
              child: _PlanColumn(
                title: 'GOLD',
                damageTextTop: '€ 0,00',
                damageTextBottom: 'Nessun costo',
                theftText: '€ 1.600,00',
                items: const [
                  _PlanItem('Assistenza stradale Plus', included: false),
                  _PlanItem('Protezione PAI', included: false),
                  _PlanItem('Guidatore aggiuntivo', included: false),
                  _PlanItem('Priority lane', included: false),
                ],
                pricePerDay: 29.00,
                days: days,
                selected: selectedIndex == 0,
                onTap: () => onSelect(0),
              ),
            ),
            SizedBox(
              width: colWidth,
              child: _PlanColumn(
                title: 'PLATINUM',
                damageTextTop: '€ 0,00',
                damageTextBottom: 'Nessun costo',
                theftText: '€ 0,00',
                items: const [
                  _PlanItem('Assistenza stradale Plus', included: true),
                  _PlanItem('Protezione PAI', included: false),
                  _PlanItem('Guidatore aggiuntivo', included: false),
                  _PlanItem('Priority lane', included: false),
                ],
                pricePerDay: 42.00,
                days: days,
                selected: selectedIndex == 1,
                onTap: () => onSelect(1),
              ),
            ),
            SizedBox(
              width: colWidth,
              child: _PlanColumn(
                title: 'PREMIUM',
                damageTextTop: '€ 0,00',
                damageTextBottom: 'Nessun costo',
                theftText: '€ 0,00',
                items: const [
                  _PlanItem('Assistenza stradale Plus', included: true),
                  _PlanItem('Protezione PAI', included: true),
                  _PlanItem('Guidatore aggiuntivo', included: true),
                  _PlanItem('Priority lane', included: true),
                ],
                pricePerDay: 46.20,
                days: days,
                selected: selectedIndex == 2,
                onTap: () => onSelect(2),
              ),
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NOLEGGIA SENZA PENSIERI.',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .2,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Scegli il pacchetto su misura più adatto alle tue esigenze per evitare costi imprevisti e goderti il tuo viaggio senza pensieri!',
                style: TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 16),

              // Layout stabile: nessun Expanded → nessuna assert in scroll
              Wrap(
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.start,
                spacing: 18,
                runSpacing: 18,
                children: [left, ...plans],
              ),
            ],
          );
        },
      ),
    );
  }

  static BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      );
}

class _LeftIncluded extends StatelessWidget {
  const _LeftIncluded();

  @override
  Widget build(BuildContext context) {
    Widget row(String title, [String? sub]) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle, size: 18, color: Color(0xFF5E9D2D)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (sub != null)
                      Text(sub, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Il tuo piano include:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        const Text('BASIC', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        row('Responsabilità danni € 1.300,00', 'Costo massimo in caso di danni'),
        row('Responsabilità furto € 1.600,00', 'Costo fisso in caso di furto'),
        row('Oneri aeroportuali e ferroviari', '(eventuali)'),
        row('Oneri di circolazione'),
        row('Tasse'),
        row('Km inclusi: illimitati'),
      ],
    );
  }
}

class _PlanItem {
  final String text;
  final bool included;
  const _PlanItem(this.text, {required this.included});
}

class _PlanColumn extends StatelessWidget {
  final String title;
  final String damageTextTop;
  final String damageTextBottom;
  final String theftText;
  final List<_PlanItem> items;
  final double pricePerDay;
  final int days;
  final bool selected;
  final VoidCallback onTap;

  const _PlanColumn({
    super.key,
    required this.title,
    required this.damageTextTop,
    required this.damageTextBottom,
    required this.theftText,
    required this.items,
    required this.pricePerDay,
    required this.days,
    required this.selected,
    required this.onTap,
  });

  static const _green = Color(0xFF5E9D2D);
  static const _greenPale = Color(0xFFE9F8E9);

  @override
  Widget build(BuildContext context) {
    final total = pricePerDay * days;
    final priceStr =
        NumberFormat.currency(locale: 'it_IT', symbol: '€').format(pricePerDay);
    final totalStr =
        NumberFormat.currency(locale: 'it_IT', symbol: '€').format(total);

    Widget includeRow(_PlanItem it) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(child: Text(it.text)),
              it.included
                  ? const Text('Inclusa',
                      style: TextStyle(color: _green, fontWeight: FontWeight.w700))
                  : const Text('Esclusa',
                      style: TextStyle(color: Colors.black54)),
            ],
          ),
        );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? kBrandDark : const Color(0xFFE6E6E6),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titolo + INFO (stilizzato come nella foto)
          Row(
            children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(width: 10),
              Text('INFO',
                  style: TextStyle(
                    color: kBrandDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  )),
            ],
          ),
          const SizedBox(height: 10),

          // Box verde – franchigie
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _greenPale,
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Responsabilità danni',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 4),
                Text(damageTextTop,
                    style:
                        const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(damageTextBottom,
                    style: const TextStyle(color: Colors.black54, fontSize: 12)),
                const SizedBox(height: 12),
                const Text('Responsabilità furto',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 4),
                Text(theftText,
                    style:
                        const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Dotazioni incluse/escluse
          for (final it in items) includeRow(it),
          const Divider(height: 28),

          // Prezzi
          Row(
            children: [
              Text('$priceStr ',
                  style:
                      const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const Text('/ giorno', style: TextStyle(color: Colors.black54)),
            ],
          ),
          Text('$totalStr Totale per giorni',
              style: const TextStyle(color: Colors.black45, fontSize: 12)),

          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: selected ? kBrandDark : kBrand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            onPressed: onTap,
            child: const Text('seleziona'),
          ),
        ],
      ),
    );
  }
}

/* ========================
 *  SEZIONE 2 – OPTIONAL (foto 2)
 * ======================== */

class _OptionalVM {
  final String title;
  final String price; // formattato
  final bool perDay;
  final String? imageUrl;

  _OptionalVM({
    required this.title,
    required this.price,
    required this.perDay,
    this.imageUrl,
  });
}

class _OptionalCard extends StatelessWidget {
  final _OptionalVM vm;
  final bool selected;
  final VoidCallback onTap;

  const _OptionalCard({
    required this.vm,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF6FB43F);
    final bg = selected ? green : Colors.white;
    final fg = selected ? Colors.white : Colors.black87;
    final border = selected ? Colors.transparent : const Color(0xFFE6E6E6);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // “INFO” in alto a destra/sinistra (come preferisci)
          Row(
            children: [
              Text(
                'INFO',
                style: TextStyle(
                  color: selected ? Colors.white : kBrandDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Titolo + icona
          Row(
            children: [
              Icon(Icons.star_rounded,
                  color: selected ? Colors.white : kBrandDark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  vm.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: fg, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ],
          ),
          const Spacer(),

          // Prezzo + bottone
          Row(
            children: [
              Text(
                vm.price,
                style:
                    TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 14),
              ),
              if (vm.perDay)
                Text(' / giorno',
                    style: TextStyle(
                        color: selected ? Colors.white70 : Colors.black54)),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: selected ? green : Colors.white,
                  backgroundColor: selected ? Colors.white : kBrand,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
                onPressed: onTap,
                child: Text(selected ? 'Rimuovi' : 'Aggiungi'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
