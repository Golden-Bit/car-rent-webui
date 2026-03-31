import 'dart:convert';
import 'dart:math';
import 'package:car_rent_webui/app.dart';
import 'package:car_rent_webui/core/deeplink/initial_config.dart';
import 'package:car_rent_webui/core/ui/mobile_bottom_padding.dart';
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
  final InitialConfig? initialConfig;

  const ExtrasPageArgs({
    required this.dataJson,
    required this.selected,
    this.preselectedExtras = const [],
    this.initialConfig,
  });
}

/// Brand
const kBrand = Color(0xFFFF5A19);
const kBrandDark = Color(0xFFE2470C);

class ExtrasPage extends StatefulWidget {
  static const routeName = '/extras';
  final Map<String, dynamic> dataJson;
  final Offer selected;
  final InitialConfig? initialConfig;
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
  /// 0 = SILVER, 1 = GOLD, 2 = DIAMOND, -1 = nessuno
  int _selectedPlan = -1;

  /// Indici (sulla lista RAW) selezionati
  final Set<int> _selectedOptionals = {};

  /// qty per optional (solo se multipliable=true e non locked). Key = rawIndex
  final Map<int, int> _qtyByOptionalIndex = {};

  /// Optional RAW e VM
  late final List<dynamic> _rawOptionals;
  late final int _rentalDays;
  late final List<_OptionalVM> _optionals;

  /// Binding “Assicurazioni <-> Extra”
  late final Map<int, int?>
  _insurancePackageIndexByPlan; // planIndex -> rawIndex package
  late final Set<int>
  _insurancePackageIndices; // tutti i rawIndex dei package (da nascondere in griglia)

  /// Penalità vincolate ai pacchetti (0€) -> planIndex -> set rawIndex
  late final Map<int, Set<int>> _planPenaltyIndices;
  late final Set<int> _linkedPenaltyIndices;

  /// Extra LOCKED (non deselezionabili / non selezionabili)
  late final Set<int> _lockedOptionals;

  /// Indici effettivamente mostrati nella griglia (rawIndex), escludendo i package assicurativi
  late final List<int> _displayIndices;

  /// Definizione UI piani assicurativi
  late final List<_InsurancePlanDef> _insurancePlans;

  /* ------------------------- INIT ------------------------- */

  @override
  void initState() {
    super.initState();
    _rentalDays = _computeRentalDays(widget.dataJson);

    _rawOptionals = _optionalsForSelected(widget.dataJson, widget.selected);
    _optionals = _readOptionals(_rawOptionals);

    _lockedOptionals = <int>{};

    _initInsuranceBindings();
    _applyZeroEuroDefaults();
    _applyPreselectedExtras(widget.preselectedExtras);
    _syncInsuranceSelection(); // assicura coerenza (se preselected include package)
  }

  /* ------------------------- NORMALIZE / RAW READ ------------------------- */

  static String _norm(String s) =>
      s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), ' ').trim();

  Map<String, dynamic> _rawAt(int rawIndex) {
    if (rawIndex < 0 || rawIndex >= _rawOptionals.length) return const {};
    final v = _rawOptionals[rawIndex];
    return (v is Map) ? v.cast<String, dynamic>() : const {};
  }

  Map<String, dynamic> _equipAt(int rawIndex) {
    final raw = _rawAt(rawIndex);
    final e = raw['Equipment'];
    return (e is Map) ? e.cast<String, dynamic>() : const {};
  }

  Map<String, dynamic> _chargeAt(int rawIndex) {
    final raw = _rawAt(rawIndex);
    final c = raw['Charge'];
    return (c is Map) ? c.cast<String, dynamic>() : const {};
  }

  String _descAt(int rawIndex) {
    final equip = _equipAt(rawIndex);
    final charge = _chargeAt(rawIndex);
    final d = (equip['Description'] ?? charge['Description'] ?? '').toString();
    return d;
  }

  String _equipTypeAt(int rawIndex) {
    final equip = _equipAt(rawIndex);
    return (equip['EquipType'] ?? '').toString();
  }

  num _amountAt(int rawIndex) {
    final charge = _chargeAt(rawIndex);
    return (charge['Amount'] as num?) ?? 0;
  }

  String? _currencyAt(int rawIndex) {
    final charge = _chargeAt(rawIndex);
    return charge['CurrencyCode'] as String?;
  }

  bool _isMultipliableAt(int rawIndex) {
    final equip = _equipAt(rawIndex);
    return (equip['isMultipliable'] as bool?) ?? true;
  }

  String? _extractCodeFromRaw(List<dynamic> list, int index) {
    if (index < 0 || index >= list.length) return null;
    final m = (list[index] as Map).cast<String, dynamic>();
    final equip = (m['Equipment'] as Map?)?.cast<String, dynamic>();
    return (equip?['EquipType'] as String?) ??
        (equip?['Description'] as String?);
  }

  bool _isLocked(int rawIndex) => _lockedOptionals.contains(rawIndex);

  int _qtyOf(int rawIndex) => max(1, _qtyByOptionalIndex[rawIndex] ?? 1);

  /* ------------------------- INSURANCE BINDINGS ------------------------- */

  void _initInsuranceBindings() {
    // 1) trova i 3 package tra gli extra
    final silverPkg = _findInsurancePackageIndex(
      planToken: 'SILVER',
      italianToken: 'ARGENTO',
    );
    final goldPkg = _findInsurancePackageIndex(
      planToken: 'GOLD',
      italianToken: 'ORO',
    );
    final diamondPkg = _findInsurancePackageIndex(
      planToken: 'DIAMOND',
      italianToken: 'DIAMANTE',
    );

    _insurancePackageIndexByPlan = {0: silverPkg, 1: goldPkg, 2: diamondPkg};

    _insurancePackageIndices = {
      if (silverPkg != null) silverPkg,
      if (goldPkg != null) goldPkg,
      if (diamondPkg != null) diamondPkg,
    };

    // 2) trova penalità “vincolate” ai pacchetti (0€) -> PENALITA + token piano
    _planPenaltyIndices = {0: <int>{}, 1: <int>{}, 2: <int>{}};
    for (var i = 0; i < _rawOptionals.length; i++) {
      final amount = _amountAt(i);
      if (amount != 0) continue;

      final n = _norm('${_descAt(i)} ${_equipTypeAt(i)}');
      if (!n.contains('PENALITA')) continue;

      // Vincolate: solo quelle che portano il token del piano (SILVER/GOLD/DIAMOND o ARGENTO/ORO/DIAMANTE)
      if (n.contains('SILVER') || n.contains('ARGENTO')) {
        _planPenaltyIndices[0]!.add(i);
      }
      if (n.contains('GOLD') || n.contains('ORO')) {
        _planPenaltyIndices[1]!.add(i);
      }
      if (n.contains('DIAMOND') || n.contains('DIAMANTE')) {
        _planPenaltyIndices[2]!.add(i);
      }
    }

    _linkedPenaltyIndices = {
      ..._planPenaltyIndices[0]!,
      ..._planPenaltyIndices[1]!,
      ..._planPenaltyIndices[2]!,
    };

    // 3) i package assicurativi NON devono essere visibili come extra:
    // => costruisco la lista degli indici da mostrare escludendo i package.
    _displayIndices = List<int>.generate(_rawOptionals.length, (i) => i)
        .where((i) => !_insurancePackageIndices.contains(i))
        .toList(growable: false);

    // 4) definisci i piani assicurativi UI:
    // prezzi/nome ALLINEATI ai package tra gli extra.
    // Manteniamo la UI “€/giorno + totale per giorni”: impostiamo pricePerDay = (totalePackage / giorni)
    _insurancePlans = [
      _makePlanDef(
        title: 'SILVER PACKAGE',
        planIndex: 0,
        damageTextTop: 'Come da tabella',
        damageTextBottom: 'Riduzione deposito cauzionale come da tabella',
        theftText: '€ 0,00',
        items: const [
          _PlanItem('Responsabilita furto a 0€', included: true),
          _PlanItem(
            'Deposito cauzionale ridotto (come da tabella)',
            included: true,
          ),
          _PlanItem('Responsabilita danni', included: false),
          _PlanItem('Danni da incuria o negligenza', included: false),
        ],
      ),
      _makePlanDef(
        title: 'GOLD PACKAGE',
        planIndex: 1,
        damageTextTop: '€ 0,00',
        damageTextBottom: 'Riduzione deposito cauzionale come da tabella',
        theftText: 'Come da tabella',
        items: const [
          _PlanItem('Responsabilita danni a 0€', included: true),
          _PlanItem(
            'Deposito cauzionale ridotto (come da tabella)',
            included: true,
          ),
          _PlanItem('Responsabilita furto', included: false),
          _PlanItem('Danni da incuria o negligenza', included: false),
        ],
      ),
      _makePlanDef(
        title: 'DIAMOND PACKAGE',
        planIndex: 2,
        damageTextTop: '€ 0,00',
        damageTextBottom: 'Deposito cauzionale ridotto a 100€',
        theftText: '€ 0,00',
        items: const [
          _PlanItem('Responsabilita danni a 0€', included: true),
          _PlanItem('Responsabilita furto a 0€', included: true),
          _PlanItem('Deposito cauzionale ridotto a 100€', included: true),
          _PlanItem('Danni da incuria o negligenza', included: false),
        ],
      ),
    ];
  }

  int? _findInsurancePackageIndex({
    required String planToken,
    required String italianToken,
  }) {
    for (var i = 0; i < _rawOptionals.length; i++) {
      final n = _norm('${_descAt(i)} ${_equipTypeAt(i)}');
      final isPkg =
          (n.contains('PACKAGE') || n.contains('PACCHETTO')) &&
          (n.contains(planToken) || n.contains(italianToken));
      if (isPkg) return i;
    }
    return null;
  }

  _InsurancePlanDef _makePlanDef({
    required String title,
    required int planIndex,
    required String damageTextTop,
    required String damageTextBottom,
    required String theftText,
    required List<_PlanItem> items,
  }) {
    final pkgIdx = _insurancePackageIndexByPlan[planIndex];
    final total = (pkgIdx != null) ? _amountAt(pkgIdx) : 0;
    final currency = (pkgIdx != null) ? _currencyAt(pkgIdx) : 'EUR';

    final perDay =
        (_rentalDays <= 0)
            ? total.toDouble()
            : (total / _rentalDays).toDouble();

    return _InsurancePlanDef(
      title: title,
      damageTextTop: damageTextTop,
      damageTextBottom: damageTextBottom,
      theftText: theftText,
      items: items,
      pricePerDay: perDay,
      // per mostrare anche il totale “reale” allineato agli extra (utile per header)
      totalForRental: total,
      currencyCode: currency,
    );
  }

  /// Seleziona automaticamente:
  /// - tutti gli extra a 0€ => selezionati e NON deselezionabili
  /// - ECCEZIONE: penalità vincolate ai pacchetti (linkedPenalty) => NON selezionate di default
  ///             (si attivano SOLO con il pacchetto), e NON selezionabili manualmente
  void _applyZeroEuroDefaults() {
    for (var i = 0; i < _rawOptionals.length; i++) {
      final amount = _amountAt(i);
      if (amount != 0) continue;

      // linked penalty -> NON selezionata di default ma sempre locked (non selezionabile manualmente)
      if (_linkedPenaltyIndices.contains(i)) {
        _lockedOptionals.add(i);
        continue;
      }

      // tutti gli altri 0€: selezionati e locked
      _selectedOptionals.add(i);
      _lockedOptionals.add(i);
    }

    // anche i package assicurativi e le linked penalty saranno “locked” (i package non li mostriamo)
    for (final idx in _insurancePackageIndices) {
      _lockedOptionals.add(idx);
    }
  }

  /* ------------------------- PRESELECTED ------------------------- */

  void _applyPreselectedExtras(List<InitialExtra> xs) {
    if (xs.isEmpty) return;

    for (var rawIndex = 0; rawIndex < _optionals.length; rawIndex++) {
      final code = _extractCodeFromRaw(_rawOptionals, rawIndex);
      final title = _optionals[rawIndex].title.toLowerCase();

      final hit = xs.any((x) {
        final xcode = x.code.toLowerCase();
        return (code != null && xcode == code.toLowerCase()) || xcode == title;
      });

      if (!hit) continue;

      // Se è un package assicurativo, trasforma in selezione piano
      final planFromPkg = _planIndexFromInsurancePackage(rawIndex);
      if (planFromPkg != null) {
        _selectedPlan = planFromPkg;
        continue;
      }

      // Altrimenti: normale extra (se non locked)
      if (_isLocked(rawIndex)) continue;

      _selectedOptionals.add(rawIndex);
      if (_optionals[rawIndex].multipliable) {
        _qtyByOptionalIndex[rawIndex] = max(
          1,
          _qtyByOptionalIndex[rawIndex] ?? 1,
        );
      }
    }
  }

  int? _planIndexFromInsurancePackage(int rawIndex) {
    for (final e in _insurancePackageIndexByPlan.entries) {
      if (e.value == rawIndex) return e.key;
    }
    return null;
  }

  /* ------------------------- INSURANCE SELECTION SYNC ------------------------- */

  void _selectPlan(int planIndex) {
    setState(() {
      // toggle: se clicchi lo stesso piano lo deselezioni (torni a -1)
      _selectedPlan = (_selectedPlan == planIndex) ? -1 : planIndex;
      _syncInsuranceSelection();
    });
  }

  void _syncInsuranceSelection() {
    // 1) rimuovi sempre tutti i package assicurativi da selected
    for (final idx in _insurancePackageIndices) {
      _selectedOptionals.remove(idx);
      _qtyByOptionalIndex.remove(idx);
    }

    // 2) rimuovi tutte le penalità vincolate ai pacchetti da selected
    for (final idx in _linkedPenaltyIndices) {
      _selectedOptionals.remove(idx);
      _qtyByOptionalIndex.remove(idx);
    }

    // 3) se un piano è selezionato: aggiungi package + penalità collegate (non removibili)
    if (_selectedPlan != -1) {
      final pkgIdx = _insurancePackageIndexByPlan[_selectedPlan];
      if (pkgIdx != null) {
        _selectedOptionals.add(pkgIdx);
        _lockedOptionals.add(pkgIdx);
      }

      final penalties = _planPenaltyIndices[_selectedPlan] ?? const <int>{};
      for (final pIdx in penalties) {
        _selectedOptionals.add(pIdx);
        _lockedOptionals.add(pIdx);
      }
    }

    // 4) assicurati che i 0€ “generici” restino selezionati e locked (salvo linkedPenalty)
    for (var i = 0; i < _rawOptionals.length; i++) {
      if (_amountAt(i) != 0) continue;
      if (_linkedPenaltyIndices.contains(i)) continue; // gestite dal piano
      _selectedOptionals.add(i);
      _lockedOptionals.add(i);
    }
  }

  /* ------------------------- OPTIONAL SELECT/QTY ------------------------- */

  void _toggleOptional(int rawIndex) {
    if (_isLocked(rawIndex)) return; // non toccare i locked

    setState(() {
      final isSelected = _selectedOptionals.contains(rawIndex);
      if (isSelected) {
        _selectedOptionals.remove(rawIndex);
        _qtyByOptionalIndex.remove(rawIndex);
      } else {
        _selectedOptionals.add(rawIndex);
        if (_optionals[rawIndex].multipliable) {
          _qtyByOptionalIndex[rawIndex] = max(
            1,
            _qtyByOptionalIndex[rawIndex] ?? 1,
          );
        }
      }
    });
  }

  void _incQty(int rawIndex) {
    if (_isLocked(rawIndex)) return;
    setState(() {
      final cur = _qtyByOptionalIndex[rawIndex] ?? 1;
      _qtyByOptionalIndex[rawIndex] = cur + 1;
    });
  }

  void _decQty(int rawIndex) {
    if (_isLocked(rawIndex)) return;
    setState(() {
      final cur = _qtyByOptionalIndex[rawIndex] ?? 1;
      if (cur <= 1) return;
      _qtyByOptionalIndex[rawIndex] = cur - 1;
    });
  }

  /* ------------------------- TOTALS / HEADER ------------------------- */

  num get _extrasTotalRaw {
    num sum = 0;
    for (final rawIndex in _selectedOptionals) {
      if (rawIndex < 0 || rawIndex >= _rawOptionals.length) continue;

      final amount = _amountAt(rawIndex);
      final multipliable = _isMultipliableAt(rawIndex);

      final qty = multipliable && !_isLocked(rawIndex) ? _qtyOf(rawIndex) : 1;

      // logica: multipliable => per giorno => * giorni
      sum += multipliable ? amount * _rentalDays * qty : amount * qty;
    }
    return sum;
  }

  String get _extrasTotalFmt => _formatMoney(_extrasTotalRaw, 'EUR');

  /// Header: include anche:
  /// - package assicurativo selezionato (anche se NON visibile in griglia)
  /// - penalità vincolate al pacchetto (auto)
  /// - tutti i 0€ (auto)
  List<String> get _extrasForHeader {
    final items = <String>[];

    final sorted =
        _selectedOptionals.toList()
          ..sort((a, b) => _optionals[a].title.compareTo(_optionals[b].title));

    for (final rawIndex in sorted) {
      final title = _optionals[rawIndex].title;

      final multipliable = _optionals[rawIndex].multipliable;
      final locked = _isLocked(rawIndex);

      if (multipliable && !locked) {
        final q = _qtyOf(rawIndex);
        items.add(q > 1 ? '$title x$q' : title);
      } else {
        items.add(title);
      }
    }
    return items;
  }

  String? get _insuranceNameForHeader {
    switch (_selectedPlan) {
      case 0:
        return 'SILVER PACKAGE';
      case 1:
        return 'GOLD PACKAGE';
      case 2:
        return 'DIAMOND PACKAGE';
      default:
        return null;
    }
  }

  /// Totale assicurazione = totale del package assicurativo (allineato all’extra)
  String? get _insuranceTotalFmtForHeader {
    if (_selectedPlan == -1) return null;
    final pkgIdx = _insurancePackageIndexByPlan[_selectedPlan];
    if (pkgIdx == null) return null;
    final amt = _amountAt(pkgIdx);
    final cur = _currencyAt(pkgIdx);
    return _formatMoney(amt, cur);
  }

  /* ------------------------- PROCEED ------------------------- */

  Future<void> _handleProceed(BuildContext context) async {
    if (_selectedPlan == -1) {
      final proceed = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => Theme(
              data: Theme.of(ctx).copyWith(
                dialogTheme: const DialogThemeData(
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                ),
                colorScheme: Theme.of(ctx).colorScheme.copyWith(
                  surface: Colors.white,
                  onSurface: Colors.black87,
                ),
              ),
              child: AlertDialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                titleTextStyle: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                contentTextStyle: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                ),
                title: const Text('Procedere senza pacchetto?'),
                content: const Text(
                  'Sicuro di voler procedere senza aver selezionato nessun pacchetto?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Torna indietro'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBrandDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Procedi'),
                  ),
                ],
              ),
            ),
      );

      if (proceed != true) return;
    }

    _goNext(context);
  }

  void _goNext(BuildContext context) {
    // Costruisci la lista di InitialExtra dai selezionati (include 0€ + package + penalità vincolate)
    final extras = <InitialExtra>[];

    final sorted =
        _selectedOptionals.toList()
          ..sort((a, b) => _optionals[a].title.compareTo(_optionals[b].title));

    for (final rawIndex in sorted) {
      if (rawIndex < 0 || rawIndex >= _rawOptionals.length) continue;

      final equip = _equipAt(rawIndex);
      final code =
          (equip['EquipType'] as String?) ??
          (equip['Description'] as String?) ??
          'EXTRA_${rawIndex + 1}';

      final multipliable = (equip['isMultipliable'] as bool?) ?? true;

      // qty regolabile SOLO se multipliable e non locked; altrimenti 1
      final qty = (multipliable && !_isLocked(rawIndex)) ? _qtyOf(rawIndex) : 1;

      extras.add(InitialExtra(code: code, qty: qty, perDay: multipliable));
    }

    final pickCode = widget.dataJson['PickUpLocation']?.toString() ?? '';
    final dropCode = widget.dataJson['ReturnLocation']?.toString() ?? '';
    final startIso = widget.dataJson['PickUpDateTime']?.toString();
    final endIso = widget.dataJson['ReturnDateTime']?.toString();

    InitialConfig base =
        widget.initialConfig ??
        InitialConfig.fromManual(
          pickupCode: pickCode,
          dropoffCode: dropCode,
          startUtc:
              startIso != null
                  ? DateTime.parse(startIso)
                  : DateTime.now().toUtc(),
          endUtc:
              endIso != null ? DateTime.parse(endIso) : DateTime.now().toUtc(),
          channel: 'WEB_APP',
          initialStep: 3,
        );

    final cfgForConfirm =
        base
            .copyWith(
              step: 4,
              vehicleId:
                  base.vehicleId ??
                  widget.selected.id ??
                  widget.selected.vehicleId ??
                  widget.selected.code,
              extras: extras,
            )
            .withOriginalFromSelf();

    Navigator.pushNamed(
      context,
      ConfirmPage.routeName,
      arguments: ConfirmArgs(
        cfg: cfgForConfirm,
        dataJson: widget.dataJson,
        selected: widget.selected,
        selectedExtras: extras,
        insuranceName: _insuranceNameForHeader,
        insuranceTotalFormatted: _insuranceTotalFmtForHeader,
      ),
    );
  }

  /* ------------------------- UI ------------------------- */

  @override
  Widget build(BuildContext context) {
    final priceForHeader = _formatHeaderPrice(widget.dataJson, widget.selected);
    final double extraBottom = mobileBottomPad(context);

    final proceedButton = _ProceedButton(
      label: 'Prosegui',
      onPressed: () => _handleProceed(context),
    );

    return Scaffold(
      appBar: AppUiFlags.showAppBarOf(context) ? const TopNavBar() : null,
      body: CustomScrollView(
        slivers: [
          // StepsHeader SCROLLABILE
          SliverToBoxAdapter(
            child: StepsHeader(
              currentStep: 3,
              accent: kBrandDark,
              step3InsuranceName: _insuranceNameForHeader,
              step3InsuranceTotal: _insuranceTotalFmtForHeader,
              step3Extras: _extrasForHeader,
              step3ExtrasTotal: _extrasTotalFmt,
              step1Pickup:
                  _displayLocationName(
                    widget.dataJson,
                    codeKey: 'PickUpLocation',
                    nameCandidates: const [
                      'PickUpLocationName',
                      'pickupName',
                      'PickupName',
                      'PickupCity',
                      'pickupCity',
                    ],
                  ) ??
                  widget.dataJson['PickUpLocation']?.toString(),
              step1Dropoff:
                  _displayLocationName(
                    widget.dataJson,
                    codeKey: 'ReturnLocation',
                    nameCandidates: const [
                      'ReturnLocationName',
                      'returnName',
                      'ReturnCity',
                      'returnCity',
                    ],
                  ) ??
                  widget.dataJson['ReturnLocation']?.toString(),
              step1Start: _fmtDate(
                widget.dataJson['PickUpDateTime']?.toString(),
              ),
              step1End: _fmtDate(widget.dataJson['ReturnDateTime']?.toString()),
              step2Title: widget.selected.group ?? 'Auto',
              step2Subtitle: widget.selected.name ?? '',
              step2Thumb: widget.selected.imageUrl,
              step2Price: priceForHeader,
              onTapStep: (n) {
                if (n == 2) {
                  Navigator.of(context).maybePop();
                } else if (n == 1) {
                  Navigator.of(context).maybePop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).maybePop();
                    }
                  });
                }
              },
            ),
          ),

          // ✅ PROSEGUI “ALTO” sotto lo header (centrato)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Center(child: proceedButton),
            ),
          ),

          // Sezione assicurazione (nomi/prezzi allineati ai package extra)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _InsuranceSection(
                days: _rentalDays,
                selectedIndex: _selectedPlan,
                onSelect: _selectPlan,
                plans: _insurancePlans,
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

          // Griglia Optional (NOTA: i package assicurativi NON compaiono)
          if (_displayIndices.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate((context, gridPos) {
                  final rawIndex = _displayIndices[gridPos];
                  final it = _optionals[rawIndex];

                  final isSel = _selectedOptionals.contains(rawIndex);
                  final raw = _rawAt(rawIndex);

                  final isLocked = _isLocked(rawIndex);

                  // quantità: solo se selezionato + multipliable + NON locked
                  final showQty = isSel && it.multipliable && !isLocked;
                  final qty = showQty ? _qtyOf(rawIndex) : 1;

                  // Locked label / reason
                  String? lockLabel;
                  String? lockHint;

                  if (_linkedPenaltyIndices.contains(rawIndex)) {
                    lockLabel = isSel ? 'Vincolato' : 'Vincolato';
                    lockHint = 'Associato al pacchetto selezionato';
                  } else if (_amountAt(rawIndex) == 0) {
                    lockLabel = 'Incluso';
                    lockHint = 'Extra a costo zero';
                  } else if (_insurancePackageIndices.contains(rawIndex)) {
                    // non dovrebbe mai succedere in griglia (li filtriamo), ma per sicurezza:
                    lockLabel = 'Pacchetto';
                    lockHint = 'Selezionabile solo dalla sezione pacchetti';
                  }

                  return _OptionalCard(
                    vm: it,
                    rawJson: raw,
                    selected: isSel,
                    locked: isLocked,
                    lockedLabel: lockLabel,
                    lockedHint: lockHint,
                    showQty: showQty,
                    quantity: qty,
                    onAddRemove: () => _toggleOptional(rawIndex),
                    onIncQty: () => _incQty(rawIndex),
                    onDecQty: () => _decQty(rawIndex),
                  );
                }, childCount: _displayIndices.length),
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

          // ✅ PROSEGUI “BASSO” (più grande)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Center(child: proceedButton),
            ),
          ),

          if (extraBottom > 0)
            SliverToBoxAdapter(child: SizedBox(height: extraBottom)),
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

  static List<dynamic> _optionalsForSelected(
    Map<String, dynamic> dataJson,
    Offer selected,
  ) {
    List<dynamic>? _pickListFromMap(Map m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is List) return v;
      }
      return null;
    }

    final raw = selected.raw;
    if (raw is Map) {
      final o = _pickListFromMap(raw, const ['optionals', 'Optionals']);
      if (o != null) return o;
    }

    final vehicles = dataJson['Vehicles'] ?? dataJson['vehicles'];
    if (vehicles is List) {
      final wanted = <String>{
        if (selected.id != null) selected.id!.toString(),
        if (selected.vehicleId != null) selected.vehicleId!.toString(),
        if (selected.code != null) selected.code!.toString(),
      };

      for (final v in vehicles) {
        if (v is! Map) continue;
        final vm = (v as Map).cast<String, dynamic>();

        final vid =
            (vm['VehicleId'] ??
                    vm['vehicleId'] ??
                    vm['id'] ??
                    vm['code'] ??
                    vm['vehicleCode'])
                ?.toString();

        if (vid != null && wanted.contains(vid)) {
          final o = _pickListFromMap(vm, const ['optionals', 'Optionals']);
          if (o != null) return o;
        }
      }
    }

    final root = dataJson['optionals'] ?? dataJson['Optionals'];
    return (root is List) ? root : const [];
  }

  static List<_OptionalVM> _readOptionals(List<dynamic> list) {
    if (list.isEmpty) return const [];

    return list.map<_OptionalVM>((raw) {
      final m =
          (raw is Map) ? raw.cast<String, dynamic>() : <String, dynamic>{};

      final charge =
          (m['Charge'] is Map)
              ? (m['Charge'] as Map).cast<String, dynamic>()
              : <String, dynamic>{};

      final equip =
          (m['Equipment'] is Map)
              ? (m['Equipment'] as Map).cast<String, dynamic>()
              : <String, dynamic>{};

      final amount = (charge['Amount'] as num?)?.toDouble() ?? 0;
      final currency = charge['CurrencyCode'] as String?;
      final desc = (equip['Description'] ?? '').toString();
      final multipliable = (equip['isMultipliable'] as bool?) ?? true;
      final image = equip['optionalImage']?.toString();

      return _OptionalVM(
        title: desc.isEmpty ? 'Optional' : desc,
        price: _formatMoney(amount, currency),
        multipliable: multipliable,
        imageUrl: image,
        amount: amount,
        currency: currency,
      );
    }).toList();
  }

  static String? _formatHeaderPrice(
    Map<String, dynamic> dataJson,
    Offer selected,
  ) {
    String? _fmt(num? amount, String? currencyCode) {
      if (amount == null) return null;
      final symbol =
          (currencyCode == null || currencyCode == 'EUR') ? '€' : currencyCode;
      try {
        return NumberFormat.currency(
          locale: 'it_IT',
          symbol: symbol,
        ).format(amount);
      } catch (_) {
        return '$symbol ${amount.toStringAsFixed(2)}';
      }
    }

    final num? offerTotal = selected.total;
    if (offerTotal != null) {
      return _fmt(offerTotal, 'EUR');
    }

    Map<String, dynamic>? _extractTotalChargeFrom(dynamic raw) {
      if (raw is! Map) return null;
      final m = raw.cast<String, dynamic>();
      final tc = m['TotalCharge'] ?? m['total_charge'];
      if (tc is Map) return Map<String, dynamic>.from(tc);
      return null;
    }

    num? _amountFromTc(Map<String, dynamic>? tc) {
      if (tc == null) return null;
      return (tc['RateTotalAmount'] as num?) ??
          (tc['EstimatedTotalAmount'] as num?);
    }

    String? _currFromTc(Map<String, dynamic>? tc) {
      if (tc == null) return null;
      return tc['CurrencyCode'] as String?;
    }

    final tcFromRaw = _extractTotalChargeFrom(selected.raw);
    final formattedFromRaw = _fmt(
      _amountFromTc(tcFromRaw),
      _currFromTc(tcFromRaw),
    );
    if (formattedFromRaw != null) return formattedFromRaw;

    final vehicles = dataJson['Vehicles'];
    if (vehicles is List) {
      final wantedIds = <String>{
        if (selected.id != null) selected.id!.toString(),
        if (selected.vehicleId != null) selected.vehicleId!.toString(),
        if (selected.code != null) selected.code!.toString(),
      };

      for (final v in vehicles) {
        if (v is! Map) continue;
        final vm = v.cast<String, dynamic>();

        final vid =
            (vm['VehicleId'] ??
                    vm['vehicleId'] ??
                    vm['id'] ??
                    vm['Id'] ??
                    vm['Code'] ??
                    vm['code'])
                ?.toString();

        if (vid != null && wantedIds.contains(vid)) {
          final tcV = _extractTotalChargeFrom(vm);
          final formattedV = _fmt(_amountFromTc(tcV), _currFromTc(tcV));
          if (formattedV != null) return formattedV;
        }
      }
    }

    return null;
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
 *  UI – PROSEGUI BUTTON (più grande)
 * ======================== */

class _ProceedButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ProceedButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 320),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: kBrandDark,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

/* ========================
 *  SEZIONE 1 – ASSICURAZIONE
 * ======================== */

class _InsurancePlanDef {
  final String title;
  final String damageTextTop;
  final String damageTextBottom;
  final String theftText;
  final List<_PlanItem> items;

  final double pricePerDay;
  final num totalForRental;
  final String? currencyCode;

  _InsurancePlanDef({
    required this.title,
    required this.damageTextTop,
    required this.damageTextBottom,
    required this.theftText,
    required this.items,
    required this.pricePerDay,
    required this.totalForRental,
    required this.currencyCode,
  });
}

class _InsuranceSection extends StatelessWidget {
  final int days;
  final int selectedIndex; // -1 none
  final ValueChanged<int> onSelect;
  final List<_InsurancePlanDef> plans; // 3 piani

  const _InsuranceSection({
    required this.days,
    required this.selectedIndex,
    required this.onSelect,
    required this.plans,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: LayoutBuilder(
        builder: (ctx, c) {
          final left = SizedBox(
            width: min(380.0, max(280.0, c.maxWidth * 0.28)),
            child: const _LeftIncluded(),
          );

          final colWidth = min(360.0, max(280.0, (c.maxWidth - 420) / 3));

          final planWidgets = <Widget>[];
          for (var i = 0; i < plans.length; i++) {
            final p = plans[i];
            planWidgets.add(
              SizedBox(
                width: colWidth,
                child: _PlanColumn(
                  title: p.title,
                  damageTextTop: p.damageTextTop,
                  damageTextBottom: p.damageTextBottom,
                  theftText: p.theftText,
                  items: p.items,
                  pricePerDay: p.pricePerDay,
                  days: days,
                  selected: selectedIndex == i,
                  onTap: () => onSelect(i),
                ),
              ),
            );
          }

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
              Wrap(
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.start,
                spacing: 18,
                runSpacing: 18,
                children: [left, ...planWidgets],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFDCCF)),
                ),
                child: const Text(
                  'I pacchetti non coprono i danni derivanti da incuria o negligenza del locatario: errato rifornimento, danni agli interni o alle dotazioni (giacca catarifrangente, seggiolino bambini, catene da neve, carta di circolazione, navigatore satellitare, chiavi del veicolo, targa), lesioni a cerchi, gomme o vetri per condotta sconsiderata (ad esempio guida su strade sterrate o in stato d\'ebbrezza), e guasti causati da calamita naturali.',
                  style: TextStyle(color: Colors.black87, height: 1.35),
                ),
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
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (sub != null)
                  Text(
                    sub,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Il tuo piano include:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        const Text('BASIC', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        row(
          'Responsabilità danni € 1.300,00',
          'Costo massimo in caso di danni',
        ),
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

    final priceStr = NumberFormat.currency(
      locale: 'it_IT',
      symbol: '€',
    ).format(pricePerDay);
    final totalStr = NumberFormat.currency(
      locale: 'it_IT',
      symbol: '€',
    ).format(total);

    Widget includeRow(_PlanItem it) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(it.text)),
          it.included
              ? const Text(
                'Inclusa',
                style: TextStyle(color: _green, fontWeight: FontWeight.w700),
              )
              : const Text('Esclusa', style: TextStyle(color: Colors.black54)),
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
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'INFO',
                style: TextStyle(
                  color: kBrandDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

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
                const Text(
                  'Responsabilità danni',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  damageTextTop,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  damageTextBottom,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Responsabilità furto',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  theftText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          for (final it in items) includeRow(it),
          const Divider(height: 28),

          Row(
            children: [
              Text(
                '$priceStr ',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const Text('/ giorno', style: TextStyle(color: Colors.black54)),
            ],
          ),
          Text(
            '$totalStr Totale per giorni',
            style: const TextStyle(color: Colors.black45, fontSize: 12),
          ),

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
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            onPressed: onTap,
            child: Text(selected ? 'selezionato' : 'seleziona'),
          ),
        ],
      ),
    );
  }
}

/* ========================
 *  SEZIONE 2 – OPTIONAL
 * ======================== */

class _OptionalVM {
  final String title;
  final String price; // formattato
  final bool multipliable; // isMultipliable
  final String? imageUrl;

  // utili (non indispensabili, ma comodi)
  final double amount;
  final String? currency;

  _OptionalVM({
    required this.title,
    required this.price,
    required this.multipliable,
    this.imageUrl,
    required this.amount,
    required this.currency,
  });
}

class _OptionalCard extends StatelessWidget {
  final _OptionalVM vm;
  final dynamic rawJson;
  final bool selected;

  final bool locked;
  final String? lockedLabel; // es: "Incluso" / "Vincolato"
  final String? lockedHint;

  final bool showQty;
  final int quantity;
  final VoidCallback onAddRemove;
  final VoidCallback onIncQty;
  final VoidCallback onDecQty;

  const _OptionalCard({
    required this.vm,
    required this.rawJson,
    required this.selected,
    required this.locked,
    required this.lockedLabel,
    required this.lockedHint,
    required this.showQty,
    required this.quantity,
    required this.onAddRemove,
    required this.onIncQty,
    required this.onDecQty,
  });

  void _showRawJsonDialog(BuildContext context) {
    String pretty;
    try {
      pretty = const JsonEncoder.withIndent('  ').convert(rawJson);
    } catch (_) {
      pretty = rawJson?.toString() ?? '(null)';
    }

    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Extra – JSON grezzo\n${vm.title}'),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: SelectableText(
                  pretty,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Chiudi'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF6FB43F);
    final bg = selected ? green : Colors.white;
    final fg = selected ? Colors.white : Colors.black87;
    final border = selected ? Colors.transparent : const Color(0xFFE6E6E6);

    final infoButton = InkWell(
      onTap: () => _showRawJsonDialog(context),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              selected
                  ? Colors.white.withOpacity(.20)
                  : const Color(0xFFF1F1F3),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                selected
                    ? Colors.white.withOpacity(.35)
                    : const Color(0xFFE2E2E6),
          ),
        ),
        child: Text(
          'i',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : kBrandDark,
          ),
        ),
      ),
    );

    final qtyPill = _QtyPill(
      selected: selected,
      quantity: quantity,
      canDec: quantity > 1,
      onInc: onIncQty,
      onDec: onDecQty,
    );

    Widget actionWidget() {
      // locked: non deselezionabile (e per linked penalty anche non selezionabile manualmente)
      if (locked) {
        final label = lockedLabel ?? 'Bloccato';
        return Tooltip(
          message: lockedHint ?? '',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? Colors.white : const Color(0xFFF1F1F3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    selected
                        ? Colors.white.withOpacity(.85)
                        : const Color(0xFFE2E2E6),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: selected ? green : Colors.black54,
              ),
            ),
          ),
        );
      }

      return TextButton(
        style: TextButton.styleFrom(
          foregroundColor: selected ? green : Colors.white,
          backgroundColor: selected ? Colors.white : kBrand,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        onPressed: onAddRemove,
        child: Text(selected ? 'Rimuovi' : 'Aggiungi'),
      );
    }

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
          // Top row
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
              const Spacer(),
              infoButton,
            ],
          ),
          const SizedBox(height: 10),

          // Title row
          Row(
            children: [
              Icon(
                Icons.star_rounded,
                color: selected ? Colors.white : kBrandDark,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  vm.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          // Bottom row: price + qty + action
          Row(
            children: [
              Text(
                vm.price,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              if (vm.multipliable)
                Text(
                  ' / giorno',
                  style: TextStyle(
                    color: selected ? Colors.white70 : Colors.black54,
                  ),
                ),
              const Spacer(),

              if (showQty) ...[qtyPill, const SizedBox(width: 10)],

              actionWidget(),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyPill extends StatelessWidget {
  final bool selected;
  final int quantity;
  final bool canDec;
  final VoidCallback onInc;
  final VoidCallback onDec;

  const _QtyPill({
    required this.selected,
    required this.quantity,
    required this.canDec,
    required this.onInc,
    required this.onDec,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : kBrandDark;
    final bg =
        selected ? Colors.white.withOpacity(.18) : const Color(0xFFF1F1F3);
    final border =
        selected ? Colors.white.withOpacity(.30) : const Color(0xFFE2E2E6);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QtyIcon(
            icon: Icons.remove,
            color: fg.withOpacity(canDec ? 1 : .35),
            onTap: canDec ? onDec : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '$quantity',
              style: TextStyle(color: fg, fontWeight: FontWeight.w900),
            ),
          ),
          _QtyIcon(icon: Icons.add, color: fg, onTap: onInc),
        ],
      ),
    );
  }
}

class _QtyIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _QtyIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
