import 'package:car_rent_webui/app.dart';
import 'package:car_rent_webui/car_rent_sdk/sdk.dart';
import 'package:car_rent_webui/core/deeplink/initial_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/myrent_repository.dart';
import '../../../../core/widgets/top_nav_bar.dart';
import '../../../../theme/app_theme.dart';
import '../widgets/location_dropdown.dart';
import '../../../results/presentation/pages/results_page.dart';
import '../../../../core/shapes/right_diagonal_panel_clipper.dart';


const String kMapAsset = 'assets/images/map_placeholder.png';

// ADD: gutter orizzontale responsivo (sx/dx)
double _hGutter(double w) {
  if (w >= 1600) return 64;
  if (w >= 1366) return 48;
  if (w >= 1200) return 40;
  if (w >= 1024) return 32;
  if (w >= 768)  return 24;
  return 16;
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
  final _repo = MyrentRepository();

  Location? _pickup;
  Location? _dropoff;
  DateTime? _start;
  DateTime? _end;
  int? _age;
  final _couponCtrl = TextEditingController();
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
      _end   = _cfg!.end.toLocal();
      _age   = _cfg!.age;
      _couponCtrl.text = _cfg!.coupon ?? '';

      // Avvio automatico della ricerca → salta le validazioni del form
      WidgetsBinding.instance.addPostFrameCallback((_) => _onSearch());
    }
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    super.dispose();
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

            // 3) Pannello bianco destro con bordo diagonale
// 3) Pannello destro con immagine di sfondo (bordo diagonale)
Positioned.fill(
  child: IgnorePointer(
    child: ClipPath(
      clipper: const RightDiagonalPanelClipper(
        panelWidth: panelWidth,
        insetTop: diagInsetTop,
      ),
      child: DecoratedBox(
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
    width: leftAreaWidth, // lasciamo la stessa width; il Padding crea lo spazio
    child: SingleChildScrollView(
      padding: EdgeInsets.only(
        top: size.height * 0.18,
        bottom: 40,
        right: 16, // (opzionale) un filo di respiro a destra
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
                          onPickupChanged: (l) => setState(() => _pickup = l),
                          onDropoffChanged: (l) => setState(() => _dropoff = l),
                          onStartChanged: (d) => setState(() => _start = d),
                          onEndChanged: (d) => setState(() => _end = d),
                          onAgeChanged: (v) => setState(() => _age = v),
                          onSubmit: _onSearch,
                        ),
                      ),
                    ),
                  ),
                )),

                // --- COLONNA DESTRA (INFO/PLACEHOLDER) ---
                SizedBox(
                  width: panelWidth,
                  child: Center(child: _LocationInfoCard(location: _pickup)),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // ---- LAYOUT STACKED (pannello destro sotto, bordo orizzontale) ----
    // In stacked la UI è dentro due sezioni verticali:
    //  - Section 1 (arancione): form a UNA colonna responsivo
    //  - Section 2 (bianco): info card (il "pannello destro" va sotto)
    //final safeW = size.width;
    // Form single-column, usa fino a 760 ma con padding laterale
    //final formMaxWidthMobile = (safeW - 32).clamp(260.0, 760.0);
final gutter = _hGutter(size.width);
final formMaxWidthMobile = (size.width - gutter * 2).clamp(260.0, 760.0);

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
  // CHANGE: gutter dinamico a sx/dx
  padding: EdgeInsets.fromLTRB(gutter, 28, gutter, 24),
  child: Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: formMaxWidthMobile),
      child: _FormGrid(
        isWide: false,

                    pickup: _pickup,
                    dropoff: _dropoff,
                    start: _start,
                    end: _end,
                    age: _age,
                    couponCtrl: _couponCtrl,
                    onPickupChanged: (l) => setState(() => _pickup = l),
                    onDropoffChanged: (l) => setState(() => _dropoff = l),
                    onStartChanged: (d) => setState(() => _start = d),
                    onEndChanged: (d) => setState(() => _end = d),
                    onAgeChanged: (v) => setState(() => _age = v),
                    onSubmit: _onSearch,
                  ),
                ),
              ),
            ),

            // Sezione bianca (era il pannello destro): bordo orizzontale (niente diagonale)
Container(
  width: double.infinity,
  padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
  decoration: BoxDecoration(
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

  Future<void> _onSearch() async {
    // Flusso da deep-link: salta validazioni form e usa la cfg
    if (_cfg != null) {
      try {
        final resp = await _repo.createQuotationFromConfig(_cfg!);
        if (!mounted) return;
        Navigator.pushNamed(
          context,
          ResultsPage.routeName,
          arguments: ResultsArgs(response: resp, cfg: _cfg),
        );
        return;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore ricerca (cfg): $e')),
        );
        return;
      }
    }

    // Validazioni form standard
    if (_pickup == null || _dropoff == null || _start == null || _end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa i campi obbligatori')),
      );
      return;
    }

    if (_age == null || _age! <= 18) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci un’età valida (maggiore di 18).'),
        ),
      );
      return;
    }

    try {
      final resp = await _repo.createQuotation(
        pickupCode: _pickup!.locationCode,
        dropoffCode: _dropoff!.locationCode,
        startUtc: _start!.toUtc(),
        endUtc: _end!.toUtc(),
        age: _age,
        coupon: _couponCtrl.text.isEmpty ? null : _couponCtrl.text,
        channel: 'WEB_APP',
        macro: null,
      );
      if (!mounted) return;

      // Costruisci InitialConfig se non presente (flusso manuale)
      InitialConfig? cfgToPass = _cfg;
      if (cfgToPass == null) {
        cfgToPass = InitialConfig.fromManual(
          pickupCode: _pickup!.locationCode,
          dropoffCode: _dropoff!.locationCode,
          startUtc: _start!.toUtc(),
          endUtc: _end!.toUtc(),
          age: _age,
          coupon: _couponCtrl.text.isEmpty ? null : _couponCtrl.text,
          channel: 'WEB_APP',
          initialStep: 2,
        );
      }

      Navigator.pushNamed(
        context,
        ResultsPage.routeName,
        arguments: ResultsArgs(response: resp, cfg: cfgToPass),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Errore ricerca: $e')));
    }
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
                  help: 'Seleziona data e ora. Fuori orario: +40€ (demo).',
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
                  help: 'La riconsegna deve essere successiva al ritiro.',
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
                    child: _AgeNumberField(value: age, onChanged: onAgeChanged),
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
                      decoration: const InputDecoration(hintText: 'codice'),
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
                  padding: const EdgeInsets.symmetric(horizontal: 28),
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
          help: 'Seleziona data e ora. Fuori orario: +40€ (demo).',
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
          help: 'La riconsegna deve essere successiva al ritiro.',
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
            child: _AgeNumberField(value: age, onChanged: onAgeChanged),
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
              decoration: const InputDecoration(hintText: 'codice'),
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
              padding: const EdgeInsets.symmetric(horizontal: 28),
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
      _ctrl.text = widget.value == null ? '' : widget.value.toString();
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
        _error = null; // campo vuoto: nessun errore, lo gestirà la submit
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
              style: TextStyle(color: lc, fontWeight: FontWeight.w600),
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
          ? DateFormat('dd/MM/yyyy HH:mm').format(value!.toLocal())
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
                  side: const BorderSide(color: Color(0x1F000000)),
                ),
                dayPeriodColor: base.colorScheme.primary,
                dayPeriodTextColor: Colors.black87,
                dayPeriodShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0x1F000000)),
                ),
                helpTextStyle: const TextStyle(color: Colors.black87),
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
          initialTime: TimeOfDay.fromDateTime(value ?? now),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    location!.isAirport ? Icons.local_airport : Icons.location_city,
                    color: Theme.of(context).colorScheme.primary,
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
                  const Icon(Icons.close, color: Colors.black45),
                ],
              ),
              const SizedBox(height: 8),
              if (location!.email != null) Text(location!.email!),
              if (location!.telephoneNumber != null)
                Text('phone: ${location!.telephoneNumber!}'),
              if (location!.locationAddress != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(location!.locationAddress!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
