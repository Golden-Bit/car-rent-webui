import 'dart:convert';
import 'package:car_rent_webui/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/deeplink/initial_config.dart';
import '../../../../core/widgets/top_nav_bar.dart';
import '../../widgets/steps_header.dart';
import '../../models/offer_adapter.dart';

class ConfirmArgs {
  final InitialConfig? cfg;
  final Map<String, dynamic>? dataJson;
  final Offer? selected;
  final List<InitialExtra>? selectedExtras;
  const ConfirmArgs({this.cfg, this.dataJson, this.selected, this.selectedExtras});
}

class ConfirmPage extends StatefulWidget {
  static const routeName = '/confirm';
  const ConfirmPage({super.key});
  @override
  State<ConfirmPage> createState() => _ConfirmPageState();
}

class _ConfirmPageState extends State<ConfirmPage> {
  // Brand (arancione)
  static const Color kBrand = Color(0xFFFF5A1F);
  static const Color kBrandDark = Color(0xFFE2470C);
  // UI neutrali
  static const Color kCard = Color(0xFFF7F7F8);
  static const Color kStroke = Color(0xFFE6E6E6);
  static const Color kTxtMuted = Color(0xFF6B6B6B);
  static const double kRadius = 12;
  static const double kGutter = 16;
  // CTA finale
  static const Color kCtaGreen = Color(0xFF6FCF97);

  // Cards pagamento: altezza uniforme
  static const double kPayCardWidth = 300;
  static const double kPayCardHeight = 180;

  Map<String, dynamic>? _dataJson;
  Offer? _selected;
  List<InitialExtra> _selectedExtras = const [];
  String? _step1Pickup, _step1Dropoff, _step1Start, _step1End;
  String? _step2Title, _step2Subtitle, _step2Thumb, _step2Price;
  List<String> _step3Extras = const [];
  String? _step3ExtrasTotal;
  bool _hydrated = false;

  // Stato UI
  PaymentMethod _payMethod = PaymentMethod.payNow;

  final _ccNumber = TextEditingController(text: '1234 1234 1234 1234');
  final _ccExp = TextEditingController();
  final _ccCvc = TextEditingController();

  BillingType _billingType = BillingType.privato;

  final _nation = ValueNotifier<String>('Italia');
  final _birthNation = ValueNotifier<String>('Italia');
  final _capCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _civicCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _birthCityCtrl = TextEditingController();
  final _birthProvinceCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _sexCtrl = ValueNotifier<String?>('');
  final _taxCodeCtrl = TextEditingController();

  bool _hasPayback = false;
  final _flightCtrl = TextEditingController(text: 'Ad es. BA7885');

  bool _accPrivacy = false;
  bool _accTos = false;
  bool _accProfiling = false;
  bool _accDataShare = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    final ConfirmArgs? confirm = args is ConfirmArgs ? args : null;

    _dataJson = confirm?.dataJson;
    _selected = confirm?.selected;
    _selectedExtras = confirm?.selectedExtras ?? const [];

    if (_dataJson != null || _selected != null) {
      _hydrateHeaderFromDataJson(_dataJson ?? const {}, _selected, _selectedExtras);
    } else {
      final cfg = confirm?.cfg ?? _readConfigFromUrl();
      if (cfg != null) _hydrateHeaderFromJson(cfg.toJson());
    }
    _hydrated = true;
  }

  @override
  void dispose() {
    _ccNumber.dispose();
    _ccExp.dispose();
    _ccCvc.dispose();
    _capCtrl.dispose();
    _provinceCtrl.dispose();
    _addressCtrl.dispose();
    _civicCtrl.dispose();
    _cityCtrl.dispose();
    _birthCityCtrl.dispose();
    _birthProvinceCtrl.dispose();
    _birthDateCtrl.dispose();
    _flightCtrl.dispose();
    _nation.dispose();
    _birthNation.dispose();
    _sexCtrl.dispose();
    _taxCodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showTopBar = AppUiFlags.showAppBarOf(context);

    return Scaffold(
      appBar: showTopBar ? const TopNavBar() : null,
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header step 4
          StepsHeader(
            currentStep: 4,
            accent: kBrandDark,
            step1Pickup: _step1Pickup,
            step1Dropoff: _step1Dropoff,
            step1Start: _step1Start,
            step1End: _step1End,
            step2Title: _step2Title,
            step2Subtitle: _step2Subtitle,
            step2Thumb: _step2Thumb,
            step2Price: _step2Price,
            step3Extras: _step3Extras,
            step3ExtrasTotal: _step3ExtrasTotal,
            onTapStep: (n) => (n == 3 || n == 2 || n == 1) ? Navigator.of(context).maybePop() : null,
          ),

          // Contenuto scrollabile SU TUTTA LA LARGHEZZA
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, cs) {
                final maxW = cs.maxWidth.clamp(320, 1040.0);
                return ScrollConfiguration(
                  behavior: const _NoGlow(),
                  child: SingleChildScrollView(
                    primary: true, // abilita lo scroll anche con mouse/trackpad ovunque
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxW as double),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('I tuoi dati'),
                              const SizedBox(height: 12),
                              _grid(
                                children: [
                                  _labeledField('NOME'),
                                  _labeledField('COGNOME'),
                                  _labeledField('E-MAIL'),
                                  _labeledField('CONFERMA E-MAIL'),
                                  // TELEFONO: mezza larghezza allineata a sx
                                  _labeledField('TELEFONO'),
                                  _ghostCell(), // per mantenere la riga a 2 colonne
                                ],
                              ),

                              const SizedBox(height: 28),
                              _sectionTitle('Metodo di pagamento'),
                              const SizedBox(height: 12),
                              _paymentRow(),
                              const SizedBox(height: 16),
                              _cardForm(),
                              const SizedBox(height: 28),

                              _sectionTitle('Dati fatturazione'),
                              const SizedBox(height: 12),
                              _billingTypeSegment(),
                              const SizedBox(height: 16),
                              _billingGrid(),
                              const SizedBox(height: 12),

                              _paybackTile(),
                              const SizedBox(height: 16),

                              _flightRow(),
                              const SizedBox(height: 16),

                              _faqCta(),
                              const SizedBox(height: 16),

                              _reminderBox(),
                              const SizedBox(height: 20),

                              _consents(),
                              const SizedBox(height: 16),

                              Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  height: 48,
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: kCtaGreen,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(kRadius),
                                      ),
                                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    onPressed: _onSubmit,
                                    child: const Text('Prenota subito!'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- SEZIONI ----------------

  Widget _paymentRow() {
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: [
        _paymentCard(
          method: PaymentMethod.payNow,
          icon: Icons.credit_card,
          title: 'PAGA ORA',
          subtitle: const Text('Risparmia € 2,4', style: TextStyle(fontSize: 10, color: kTxtMuted)),
          price: '€ 45,70',
        ),
        _paymentCard(
          method: PaymentMethod.payAtDesk,
          icon: Icons.room_service_outlined,
          title: 'PAGA AL RITIRO',
          price: '€ 48,11',
        ),
        _paymentCard(
          method: PaymentMethod.scalapay,
          icon: Icons.favorite_outline,
          title: 'SCALAPAY',
          subtitle: const Text(
            'Conferma subito la tua prenotazione e prenditi il tempo\nper pagare lentamente',
            style: TextStyle(fontSize: 10, color: kTxtMuted, height: 1.2),
          ),
          price: '€ 45,70',
        ),
      ],
    );
  }

  Widget _paymentCard({
    required PaymentMethod method,
    required IconData icon,
    required String title,
    Widget? subtitle,
    required String price,
  }) {
    final selected = _payMethod == method;

    return InkWell(
      onTap: () => setState(() => _payMethod = method),
      borderRadius: BorderRadius.circular(kRadius),
      child: SizedBox(
        width: kPayCardWidth,
        height: kPayCardHeight, // ← stessa altezza per tutte
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: kStroke),
          ),
          child: Stack(
            children: [
              // Contenuto
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _circleIcon(icon),
                      const SizedBox(width: 10),
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: .2),
                      ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    subtitle,
                  ],
                  const Spacer(), // spinge il prezzo in basso
                  Text(price, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
                ],
              ),

              // Radio in basso a destra
              Positioned(right: 0, bottom: 0, child: _radioDot(selected)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardForm() {
    final visible = _payMethod == PaymentMethod.payNow || _payMethod == PaymentMethod.scalapay;
    if (!visible) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _circleIcon(Icons.credit_card, bg: kBrand.withOpacity(.1)),
            const SizedBox(width: 8),
            const Text('Carta', style: TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          _label('Numero carta'),
          const SizedBox(height: 6),
          _textField(controller: _ccNumber, hint: '1234 1234 1234 1234'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Data di scadenza'),
                    const SizedBox(height: 6),
                    _textField(
                      controller: _ccExp,
                      hint: 'MM / AA',
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9/ ]'))],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Codice di sicurezza'),
                    const SizedBox(height: 6),
                    _textField(
                      controller: _ccCvc,
                      hint: 'CVC',
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _billingTypeSegment() {
    Widget pill(String text, BillingType type) {
      final sel = _billingType == type;
      return InkWell(
        onTap: () => setState(() => _billingType = type),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: sel ? kBrand.withOpacity(.10) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: sel ? kBrand : kStroke),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _radioTiny(sel),
            const SizedBox(width: 8),
            Text(text),
          ]),
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        pill('Privato/conducente', BillingType.privato),
        pill('Azienda', BillingType.azienda),
        pill('Ditta individuale', BillingType.ditta),
      ],
    );
  }

  Widget _billingGrid() {
    return _grid(
      children: [
        _selectLabeled('NAZIONE', _nation, items: const ['Italia']),
        _labeledField('INDIRIZZO'),
        _labeledField('CIVICO', maxW: 120),
        _labeledField('CITTÀ'),
        _labeledField('CAP', maxW: 200),
        _labeledField('PROVINCIA', maxW: 220),
        _selectLabeled('NAZIONE DI NASCITA', _birthNation, items: const ['Italia']),
        _labeledField('LUOGO DI NASCITA'),
        _dateLabeled('DATA DI NASCITA', controller: _birthDateCtrl),
        _labeledField('PROVINCIA DI NASCITA'),
        _selectLabeled('SESSO', _sexCtrl, items: const ['', 'M', 'F', 'Altro']),
        _labeledField('CODICE FISCALE'),
      ],
    );
  }

  Widget _paybackTile() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kStroke),
      ),
      child: Row(
        children: [
          Container(
            width: 74,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kStroke),
            ),
            child: const Text('PAYBACK', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Hai una Carta Payback?', style: TextStyle(fontWeight: FontWeight.w600))),
          Switch(activeColor: kBrandDark, value: _hasPayback, onChanged: (v) => setState(() => _hasPayback = v)),
        ],
      ),
    );
  }

  Widget _flightRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('NUMERO DI VOLO (FACOLTATIVO) — PERCHÉ È IMPORTANTE'),
        const SizedBox(height: 6),
        _textField(controller: _flightCtrl, hint: 'Ad es. BA7885'),
      ],
    );
  }

  Widget _faqCta() {
    return _textField(
      readOnly: true,
      hint: 'Hai domande sul tuo noleggio? Clicca qui!',
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('FAQ in preparazione')),
      ),
    );
  }

  Widget _reminderBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F5D8),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD5ECC8)),
      ),
      child: const Text(
        'Ti ricordiamo che al momento della consegna del veicolo il firmatario del '
        'contratto (primo conducente) è tenuto a fornire una Carta di credito o di '
        'debito (VISA, Mastercard, American Express, UnionPay) a garanzia del servizio '
        'di noleggio e di eventuali extra non inclusi nella prenotazione. Per maggiori '
        'dettagli consulta la sezione “Informazioni sui depositi cauzionali”.',
        style: TextStyle(height: 1.30),
      ),
    );
  }

  Widget _consents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _consentTile(
          value: _accPrivacy,
          onChanged: (v) => setState(() => _accPrivacy = v ?? false),
          text: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87),
              children: [
                const TextSpan(text: 'Cliccando su prenota subito dichiari di aver preso visione dell’'),
                TextSpan(text: 'Informativa privacy', style: const TextStyle(color: kBrandDark, fontWeight: FontWeight.w600)),
                const TextSpan(text: ' per la finalità di prenotazione delle nostre auto'),
              ],
            ),
          ),
        ),
        _consentTile(
          value: _accTos,
          onChanged: (v) => setState(() => _accTos = v ?? false),
          text: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87),
              children: [
                const TextSpan(text: 'Dichiaro di aver letto compreso e accettato i '),
                TextSpan(text: 'termini e condizioni generali di servizio', style: const TextStyle(color: kBrandDark, fontWeight: FontWeight.w600)),
                const TextSpan(text: ' e il '),
                TextSpan(text: 'tariffario', style: const TextStyle(color: kBrandDark, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        _consentTile(
          value: _accProfiling,
          onChanged: (v) => setState(() => _accProfiling = v ?? false),
          text: const Text('Acconsento al trattamento dei miei dati per attività di Profilazione, al fine di migliorare l’offerta di prodotti e servizi'),
        ),
        _consentTile(
          value: _accDataShare,
          onChanged: (v) => setState(() => _accDataShare = v ?? false),
          text: const Text('Acconsento alla comunicazione dei miei dati a Tomasi Auto S.r.l., per finalità statistiche e/o commerciali'),
        ),
      ],
    );
  }

  // ---------------- AUSILIARI ----------------

  Widget _grid({required List<_GridChild> children}) {
    return LayoutBuilder(
      builder: (ctx, cs) {
        final isWide = cs.maxWidth >= 760;
        final colW = isWide ? (cs.maxWidth - kGutter) / 2 : cs.maxWidth;
        final rows = <Widget>[];
        int i = 0;
        while (i < children.length) {
          if (isWide) {
            final left = children[i];
            final right = (i + 1 < children.length && !left.span2) ? children[i + 1] : null;

            rows.add(Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: left.effectiveWidth(colW), child: left.child),
                if (right != null) ...[
                  const SizedBox(width: kGutter),
                  SizedBox(width: right.effectiveWidth(colW), child: right.child),
                ],
              ],
            ));
            i += (right == null) ? 1 : 2;
          } else {
            rows.add(SizedBox(width: colW, child: children[i].child));
            rows.add(const SizedBox(height: 12));
            i += 1;
          }
          if (isWide && i < children.length) rows.add(const SizedBox(height: 12));
        }
        return Column(children: rows);
      },
    );
  }

  _GridChild _labeledField(String label, {int span = 1, double? maxW}) {
    return _GridChild(
      span2: span == 2,
      maxW: maxW,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 6),
          _textField(hint: ''),
        ],
      ),
    );
  }

  _GridChild _selectLabeled(String label, ValueNotifier<String?> controller,
      {required List<String> items, int span = 1, double? maxW}) {
    return _GridChild(
      span2: span == 2,
      maxW: maxW,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 6),
          ValueListenableBuilder<String?>(
            valueListenable: controller,
            builder: (ctx, v, _) => _selectField(
              value: v,
              items: items,
              onChanged: (nv) => controller.value = nv,
            ),
          ),
        ],
      ),
    );
  }

  _GridChild _dateLabeled(String label, {required TextEditingController controller}) {
    return _GridChild(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 6),
          _textField(
            controller: controller,
            hint: 'gg / mm / aaaa',
            readOnly: true,
            onTap: () async {
              final now = DateTime.now();
              final pick = await showDatePicker(
                context: context,
                initialDate: DateTime(now.year - 30, now.month, now.day),
                firstDate: DateTime(1900),
                lastDate: now,
                builder: (ctx, child) {
                  final base = Theme.of(ctx);
                  return Theme(
                    data: base.copyWith(
                      colorScheme: base.colorScheme.copyWith(primary: kBrandDark),
                      datePickerTheme: base.datePickerTheme.copyWith(
                        headerBackgroundColor: Colors.white,
                        headerForegroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (pick != null) {
                controller.text =
                    '${pick.day.toString().padLeft(2, '0')} / ${pick.month.toString().padLeft(2, '0')} / ${pick.year}';
              }
            },
          ),
        ],
      ),
    );
  }

  _GridChild _ghostCell() => _GridChild(child: const SizedBox());

  Widget _label(String s) => Text(
        s,
        style: const TextStyle(fontSize: 12, color: kTxtMuted, fontWeight: FontWeight.w600),
      );

  Widget _textField({
    TextEditingController? controller,
    String? hint,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: const BorderSide(color: kStroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: const BorderSide(color: kStroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: const BorderSide(color: kBrandDark, width: 1.2),
        ),
      ),
    );
  }

  Widget _selectField({
    required List<String> items,
    String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value ?? items.first,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: const BorderSide(color: kStroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: const BorderSide(color: kStroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: const BorderSide(color: kBrandDark, width: 1.2),
        ),
      ),
      icon: const Icon(Icons.expand_more),
    );
  }

  Widget _radioDot(bool selected) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? kBrandDark : kStroke, width: 2),
      ),
      alignment: Alignment.center,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: selected ? 12 : 0,
        height: selected ? 12 : 0,
        decoration: BoxDecoration(color: kBrandDark, borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _radioTiny(bool selected) {
    return Container(
      width: 14, height: 14,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? kBrandDark : kStroke, width: 1.4)),
      alignment: Alignment.center,
      child: Container(width: 7, height: 7, decoration: BoxDecoration(color: selected ? kBrandDark : Colors.transparent, shape: BoxShape.circle)),
    );
  }

  Widget _circleIcon(IconData icon, {Color? bg}) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: bg ?? kBrand.withOpacity(.10), shape: BoxShape.circle, border: Border.all(color: kStroke)),
      child: Icon(icon, color: kBrandDark),
    );
  }

  Widget _consentTile({required bool value, required Widget text, ValueChanged<bool?>? onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(value: value, onChanged: onChanged, activeColor: kBrandDark, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
          const SizedBox(width: 6),
          Expanded(child: text),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18));

  // ---------------- LOGICA ----------------

  void _onSubmit() {
    if (!_accPrivacy || !_accTos) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accetta privacy e termini per continuare.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prenotazione inviata (demo).')));
  }

  InitialConfig? _readConfigFromUrl() {
    if (!kIsWeb) return null;
    try {
      final uri = Uri.base;
      final b64 = uri.queryParameters['cfg'];
      return InitialConfig.fromBase64Url(b64);
    } catch (_) {
      return null;
    }
  }

  void _hydrateHeaderFromDataJson(Map<String, dynamic> data, Offer? selected, List<InitialExtra> chosen) {
    _step1Pickup = _displayLocationName(data, codeKey: 'PickUpLocation', nameCandidates: const [
      'PickUpLocationName', 'pickupName', 'PickupName', 'PickupCity', 'pickupCity'
    ]) ?? data['PickUpLocation']?.toString();

    _step1Dropoff = _displayLocationName(data, codeKey: 'ReturnLocation', nameCandidates: const [
      'ReturnLocationName', 'returnName', 'ReturnCity', 'returnCity'
    ]) ?? data['ReturnLocation']?.toString();

    _step1Start = _fmtDate(data['PickUpDateTime']?.toString());
    _step1End = _fmtDate(data['ReturnDateTime']?.toString());

    _step2Title = selected?.group ?? 'Auto';
    _step2Subtitle = selected?.name ?? '';
    _step2Thumb = selected?.imageUrl;
    _step2Price = _formatHeaderPrice(data, selected);

    final labels = <String>[];
    num totalExtra = 0;
    final list = data['optionals'];
    final days = _computeRentalDays(data);
    if (list is List && chosen.isNotEmpty) {
      for (final ch in chosen) {
        for (final raw in list) {
          final m = (raw as Map).cast<String, dynamic>();
          final equip = (m['Equipment'] as Map?)?.cast<String, dynamic>() ?? const {};
          final charge = (m['Charge'] as Map?)?.cast<String, dynamic>() ?? const {};
          final code = (equip['EquipType'] as String?) ?? (equip['Description'] as String?);
          final title = (equip['Description'] ?? 'Optional').toString();
          final isPerDay = (equip['isMultipliable'] as bool?) ?? true;
          if (code != null && code.toLowerCase() == ch.code.toLowerCase()) {
            labels.add(title);
            final amount = (charge['Amount'] as num?) ?? 0;
            totalExtra += isPerDay ? amount * days : amount;
            break;
          }
        }
      }
    }
    _step3Extras = labels;
    _step3ExtrasTotal = labels.isEmpty ? null : _formatMoney(totalExtra, 'EUR');
  }

  void _hydrateHeaderFromJson(Map<String, dynamic> m) {
    String? _s(dynamic v) => v == null ? null : v.toString().trim().isEmpty ? null : v.toString().trim();
    _step1Pickup = _s(m['pickupLocation']);
    _step1Dropoff = _s(m['dropoffLocation']);
    _step1Start = _fmtDate(_s(m['start']));
    _step1End = _fmtDate(_s(m['end']));
    final vehicleId = _s(m['vehicleId']);
    _step2Title = (vehicleId?.isNotEmpty == true) ? vehicleId : null;
    _step2Subtitle = null;
    _step2Thumb = null;
    _step2Price = null;

    final extras = <String>[];
    final rawExtras = m['extras'];
    if (rawExtras is List) {
      for (final e in rawExtras) {
        if (e is Map) {
          final em = e.cast<String, dynamic>();
          final code = _s(em['code']);
          if (code != null && code.trim().isNotEmpty) extras.add(code.trim());
        }
      }
    }
    _step3Extras = extras;
    _step3ExtrasTotal = null;
  }

  static String? _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      final dt = DateTime.parse(iso).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      const it = ['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'];
      final mon = it[(dt.month - 1).clamp(0, 11)];
      return '${dt.day} $mon, ${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }

  static String? _displayLocationName(Map<String, dynamic> m, {required String codeKey, required List<String> nameCandidates}) {
    for (final k in nameCandidates) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return m[codeKey]?.toString();
  }

  static int _computeRentalDays(Map<String, dynamic> data) {
    try {
      final pick = DateTime.parse(data['PickUpDateTime'] as String);
      final ret = DateTime.parse(data['ReturnDateTime'] as String);
      final hours = ret.difference(pick).inHours;
      return (hours / 24).ceil().clamp(1, 365);
    } catch (_) {
      return 1;
    }
  }

  static String? _formatHeaderPrice(Map<String, dynamic> dataJson, Offer? selected) {
    String? _fmt(num? amount, String? currencyCode) {
      if (amount == null) return null;
      final symbol = (currencyCode == null || currencyCode == 'EUR') ? '€' : currencyCode;
      return '$symbol ${amount.toStringAsFixed(2)}';
    }

    final tc = (dataJson['TotalCharge'] is Map) ? Map<String, dynamic>.from(dataJson['TotalCharge'] as Map) : null;
    final num? amountFromData = (tc?['RateTotalAmount'] as num?) ?? (tc?['EstimatedTotalAmount'] as num?);
    final String? currFromData = tc?['CurrencyCode'] as String?;
    final formattedFromData = _fmt(amountFromData, currFromData);
    if (formattedFromData != null) return formattedFromData;

    final raw = selected?.raw;
    final tc2 = (raw is Map && raw!['TotalCharge'] is Map) ? Map<String, dynamic>.from(raw['TotalCharge'] as Map) : null;
    final num? amountFromRaw = (tc2?['RateTotalAmount'] as num?) ?? (tc2?['EstimatedTotalAmount'] as num?);
    final String? currFromRaw = tc2?['CurrencyCode'] as String?;
    return _fmt(amountFromRaw, currFromRaw);
  }

  static String _formatMoney(num amount, String? currency) {
    final sym = (currency == null || currency == 'EUR') ? '€' : currency;
    return '$sym ${amount.toStringAsFixed(2)}';
  }
}

// Modelli semplici
enum PaymentMethod { payNow, payAtDesk, scalapay }
enum BillingType { privato, azienda, ditta }

// Item di griglia
class _GridChild {
  final Widget child;
  final bool span2;
  final double? maxW;
  _GridChild({required this.child, this.span2 = false, this.maxW});
  double effectiveWidth(double colW) {
    final w = span2 ? colW * 2 + _ConfirmPageState.kGutter : colW;
    return maxW == null ? w : w.clamp(0, maxW!);
  }
}

// Rimuove glow su web
class _NoGlow extends ScrollBehavior {
  const _NoGlow();
  @override
  Widget buildViewportChrome(BuildContext context, Widget child, AxisDirection axisDirection) => child;
}
