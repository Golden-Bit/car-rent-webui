import 'package:car_rent_webui/car_rent_sdk/sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/myrent_repository.dart';
import '../../../../core/widgets/top_nav_bar.dart';
import '../../../../theme/app_theme.dart';
import '../widgets/location_dropdown.dart';
import '../../../results/presentation/pages/results_page.dart';
import '../../../../core/shapes/right_diagonal_panel_clipper.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args is AdvancedSearchArgs) {
      _pickup = args.pickup;
      _dropoff = args.pickup; // default: consegna = ritiro
    }
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final primary = Theme.of(context).colorScheme.primary;

    // leggera variazione per profondità tipo “hero”
    Color lighten(Color c, [double amount = .12]) {
      final hsl = HSLColor.fromColor(c);
      final l = (hsl.lightness + amount).clamp(0.0, 1.0);
      return hsl.withLightness(l).toColor();
    }

    // dimensioni del pannello mappa (destra) e taglio diagonale
    const panelWidth = 560.0;
    const diagInsetTop = 140.0;

    // larghezza utile della fascia sinistra (quella rosa/arancione)
    final leftAreaWidth = size.width - panelWidth;

    // larghezza “blocco form” (due colonne come nello screenshot)
    // 360 + 360 + 24 (gutter) ≈ 744 → arrotondo a 760
    final formWidth = leftAreaWidth.clamp(0, 760.0);

    return Scaffold(
      appBar: const TopNavBar(),
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1) Fondo arancione identico alla topbar
          Positioned.fill(child: Container(color: primary)),

          // 2) Velo/gradiente arancione per morbidezza
          Positioned.fill(
            child: IgnorePointer(
              child: Container(color: Theme.of(context).colorScheme.primary),
            ),
          ),

          // 3) Pannello bianco destro con bordo diagonale
          Positioned.fill(
            child: IgnorePointer(
              child: ClipPath(
                clipper: const RightDiagonalPanelClipper(
                  panelWidth: panelWidth,
                  insetTop: diagInsetTop,
                ),
                child: Container(color: Colors.white),
              ),
            ),
          ),

          // 4) Contenuti
          Row(
            children: [
              // --- COLONNA SINISTRA (FORM) ---
              SizedBox(
                width: leftAreaWidth,
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    // sposta il blocco un po’ più in basso per matchare la figura
                    top: size.height * 0.18,
                    bottom: 40,
                  ),
                  child: Align(
                    // il blocco è centrato orizzontalmente nella porzione sinistra,
                    // risultando “a sinistra” dell’intera pagina (come nel mock).
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: formWidth as double,
                      ),
                      child: _FormGrid(
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
              ),

              // --- COLONNA DESTRA (MAPPA/INFO PLACEHOLDER) ---
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

  Future<void> _onSearch() async {
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
      Navigator.pushNamed(context, ResultsPage.routeName, arguments: resp);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Errore ricerca: $e')));
    }
  }
}

/* ===========================
 *         WIDGETS
 * ===========================
 */

class _FormGrid extends StatelessWidget {
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
    // griglia a 2 colonne: ciascun Expanded occupa ~ metà del blocco
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
                  child: _DateTimePicker(value: end, onChanged: onEndChanged),
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

                  // DOPO:
                  child: SizedBox(
                    height: 56,
                    child: _AgeNumberField(value: age, onChanged: onAgeChanged),
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
      text:
          (value != null)
              ? DateFormat('dd/MM/yyyy HH:mm').format(value!.toLocal())
              : '',
    );

    return TextField(
      controller: controller,
      readOnly: true,
onTap: () async {
  final now = DateTime.now();

  // Tema "bianco + radius 4" riutilizzabile per entrambi i picker
  Theme themed(BuildContext ctx, Widget? child) {
    final base = Theme.of(ctx);
    final shape4 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
    );
    return Theme(
      data: base.copyWith(
        // Bordi e fondo del dialog
        dialogTheme: base.dialogTheme.copyWith(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: shape4,
        ),
        // Superfici bianche
        colorScheme: base.colorScheme.copyWith(
          surface: Colors.white,
          background: Colors.white,
          onSurface: Colors.black87,
          onBackground: Colors.black87,
        ),
        // Calendario
        datePickerTheme: base.datePickerTheme.copyWith(
          backgroundColor: Colors.white,
          headerBackgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: shape4,
        ),
        // Orologio (TimePicker)
        timePickerTheme: base.timePickerTheme.copyWith(
          backgroundColor: Colors.white,
          shape: shape4,
          dialBackgroundColor: Colors.white,
          // campi ore/minuti & AM/PM completamente bianchi
          hourMinuteColor: Colors.white,
          hourMinuteTextColor: Colors.black87,
          hourMinuteShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0x1F000000)), // tenue
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

  // --- DATE PICKER ---
  final date = await showDatePicker(
    context: context,
    initialDate: value ?? now,
    firstDate: now.subtract(const Duration(days: 1)),
    lastDate: now.add(const Duration(days: 365)),
    builder: (ctx, child) => themed(ctx, child),
  );
  if (date == null) return;

  // --- TIME PICKER ---
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
                    location!.isAirport
                        ? Icons.local_airport
                        : Icons.location_city,
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
