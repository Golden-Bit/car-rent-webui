// ignore_for_file: non_constant_identifier_names

import 'dart:convert';
import 'dart:math';

import 'package:car_rent_webui/app.dart';
import 'package:car_rent_webui/car_rent_sdk/sdk.dart';
import 'package:car_rent_webui/core/ui/mobile_bottom_padding.dart';
import 'package:car_rent_webui/features/search/data/myrent_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/deeplink/initial_config.dart';
import '../../../../core/widgets/top_nav_bar.dart';
import '../../models/offer_adapter.dart';
import '../../widgets/steps_header.dart';

class ConfirmArgs {
  final InitialConfig? cfg;
  final Map<String, dynamic>? dataJson;
  final Offer? selected;
  final List<InitialExtra>? selectedExtras;
  final String? insuranceName;
  final String? insuranceTotalFormatted;

  const ConfirmArgs({
    this.cfg,
    this.dataJson,
    this.selected,
    this.selectedExtras,
    this.insuranceName,
    this.insuranceTotalFormatted,
  });
}

class ConfirmPage extends StatefulWidget {
  static const routeName = '/confirm';
  const ConfirmPage({super.key});

  @override
  State<ConfirmPage> createState() => _ConfirmPageState();
}

class _ConfirmPageState extends State<ConfirmPage> {
  static const Color kBrand = Color(0xFFFF5A1F);
  static const Color kBrandDark = Color(0xFFE2470C);
  static const Color kCard = Color(0xFFF7F7F8);
  static const Color kStroke = Color(0xFFE6E6E6);
  static const Color kTxtMuted = Color(0xFF6B6B6B);
  static const Color kCtaGreen = Color(0xFF6FCF97);
  static const double kRadius = 12;
  static const double kGutter = 16;

  final _formKey = GlobalKey<FormState>();
  final MyrentRepository _repo = MyrentRepository();

  Map<String, dynamic>? _dataJson;
  Offer? _selected;
  List<InitialExtra> _selectedExtras = const [];
  InitialConfig? _cfg;

  String? _step1Pickup, _step1Dropoff, _step1Start, _step1End;
  String? _step2Title, _step2Subtitle, _step2Thumb, _step2Price;
  List<String> _step3Extras = const [];
  String? _step3ExtrasTotal;
  String? _step3InsuranceName;
  String? _step3InsuranceTotal;
  bool _hydrated = false;

  PaymentMethod _payMethod = PaymentMethod.payAtDesk;

  final _ccNumber = TextEditingController();
  final _ccExp = TextEditingController();
  final _ccCvc = TextEditingController();

  final _customerFirstName = TextEditingController();
  final _customerLastName = TextEditingController();
  final _customerEmail = TextEditingController();
  final _customerEmailConfirm = TextEditingController();
  final _customerMobile = TextEditingController();
  final _customerCountry = ValueNotifier<String>('IT');
  final _customerCity = TextEditingController();
  final _customerZip = TextEditingController();
  final _customerStreet = TextEditingController();
  final _customerNum = TextEditingController();
  final _customerTaxCode = TextEditingController();
  final _customerBirthPlace = TextEditingController();
  final _customerBirthProvince = TextEditingController();
  final _customerBirthDate = TextEditingController();

  final _customerDocument = TextEditingController(text: 'PATENTE');
  final _customerDocumentNumber = TextEditingController();
  final _customerLicenceType = TextEditingController(text: 'B');
  final _customerIssueBy = TextEditingController();
  final _customerReleaseDate = TextEditingController();
  final _customerExpiryDate = TextEditingController();

  late final _DriverFormBundle _driver1;
  late final _DriverFormBundle _driver2;
  late final _DriverFormBundle _driver3;

  bool _useCustomerAsDriver1 = true;
  bool _enableDriver2 = false;
  bool _enableDriver3 = false;

  bool _accPrivacy = false;
  bool _accTos = false;
  bool _accProfiling = false;
  bool _accDataShare = false;

  bool _isSubmitting = false;
  bool _bookingCompleted = false;
  String? _submitError;

  ReservationComposeResponse? _composeResponse;
  ReservationFullDetailsResponse? _detailsByInternalId;
  ReservationFullDetailsResponse? _detailsByCode;
  String? _detailsByInternalIdError;
  String? _detailsByCodeError;

  @override
  void initState() {
    super.initState();
    _driver1 = _DriverFormBundle(label: 'Driver 1');
    _driver2 = _DriverFormBundle(label: 'Driver 2');
    _driver3 = _DriverFormBundle(label: 'Driver 3');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    final confirm = args is ConfirmArgs ? args : null;

    _cfg = confirm?.cfg;
    _dataJson = confirm?.dataJson;
    _selected = confirm?.selected;
    _selectedExtras = confirm?.selectedExtras ?? const [];
    _step3InsuranceName = confirm?.insuranceName;
    _step3InsuranceTotal = confirm?.insuranceTotalFormatted;

    if (_dataJson != null || _selected != null) {
      _hydrateHeaderFromDataJson(
        _dataJson ?? const <String, dynamic>{},
        _selected,
        _selectedExtras,
      );
    } else {
      final cfg = _cfg ?? _readConfigFromUrl();
      if (cfg != null) {
        _cfg = cfg;
        _hydrateHeaderFromJson(cfg.toJson());
      }
    }

    _seedFormFromFlow();
    _hydrated = true;
  }

  @override
  void dispose() {
    _repo.close();
    _ccNumber.dispose();
    _ccExp.dispose();
    _ccCvc.dispose();
    _customerFirstName.dispose();
    _customerLastName.dispose();
    _customerEmail.dispose();
    _customerEmailConfirm.dispose();
    _customerMobile.dispose();
    _customerCountry.dispose();
    _customerCity.dispose();
    _customerZip.dispose();
    _customerStreet.dispose();
    _customerNum.dispose();
    _customerTaxCode.dispose();
    _customerBirthPlace.dispose();
    _customerBirthProvince.dispose();
    _customerBirthDate.dispose();
    _customerDocument.dispose();
    _customerDocumentNumber.dispose();
    _customerLicenceType.dispose();
    _customerIssueBy.dispose();
    _customerReleaseDate.dispose();
    _customerExpiryDate.dispose();
    _driver1.dispose();
    _driver2.dispose();
    _driver3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showTopBar = AppUiFlags.showAppBarOf(context);
    final extraBottom = mobileBottomPad(context);

    return Scaffold(
      appBar: showTopBar ? const TopNavBar() : null,
      backgroundColor: Colors.white,
      body: Column(
        children: [
          if (!_bookingCompleted)
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
              step3InsuranceName: _step3InsuranceName,
              step3InsuranceTotal: _step3InsuranceTotal,
              onTapStep: _handleStepTap,
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, cs) {
                final maxW = cs.maxWidth.clamp(320, 1100.0);
                return ScrollConfiguration(
                  behavior: const _NoGlow(),
                  child: SingleChildScrollView(
                    primary: true,
                    padding: EdgeInsets.fromLTRB(24, 16, 24, 32 + extraBottom),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxW as double),
                        child:
                            _bookingCompleted
                                ? _buildConfirmationView()
                                : Stack(
                                  children: [
                                    IgnorePointer(
                                      ignoring: _isSubmitting,
                                      child: Opacity(
                                        opacity: _isSubmitting ? 0.55 : 1,
                                        child: Form(
                                          key: _formKey,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _buildAutomaticBookingCard(),
                                              const SizedBox(height: 20),
                                              _buildPriceBreakdownCard(),
                                              const SizedBox(height: 24),
                                              _sectionTitle('Dati cliente'),
                                              const SizedBox(height: 12),
                                              _buildCustomerSection(),
                                              const SizedBox(height: 24),
                                              _sectionTitle(
                                                'Documento e patente del cliente',
                                              ),
                                              const SizedBox(height: 12),
                                              _buildCustomerDocumentSection(),
                                              const SizedBox(height: 24),
                                              _sectionTitle(
                                                'Metodo di pagamento',
                                              ),
                                              const SizedBox(height: 12),
                                              _buildPaymentSection(),
                                              const SizedBox(height: 24),
                                              _sectionTitle('Guidatori'),
                                              const SizedBox(height: 12),
                                              _buildDriversSection(),
                                              const SizedBox(height: 24),
                                              _sectionTitle('Consensi'),
                                              const SizedBox(height: 12),
                                              _buildConsents(),
                                              if (_submitError != null) ...[
                                                const SizedBox(height: 16),
                                                _buildErrorBox(_submitError!),
                                              ],
                                              const SizedBox(height: 18),
                                              Wrap(
                                                spacing: 12,
                                                runSpacing: 12,
                                                children: [
                                                  SizedBox(
                                                    height: 48,
                                                    child: FilledButton.icon(
                                                      style: FilledButton.styleFrom(
                                                        backgroundColor:
                                                            kCtaGreen,
                                                        foregroundColor:
                                                            Colors.white,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 20,
                                                            ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                kRadius,
                                                              ),
                                                        ),
                                                        textStyle:
                                                            const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                      ),
                                                      onPressed: _onSubmit,
                                                      icon: const Icon(
                                                        Icons.check_circle,
                                                      ),
                                                      label: const Text(
                                                        'Prenota',
                                                      ),
                                                    ),
                                                  ),
                                                  OutlinedButton.icon(
                                                    onPressed:
                                                        () =>
                                                            Navigator.of(
                                                              context,
                                                            ).maybePop(),
                                                    icon: const Icon(
                                                      Icons.arrow_back,
                                                    ),
                                                    label: const Text(
                                                      'Torna indietro',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_isSubmitting)
                                      _buildSubmittingOverlay(),
                                  ],
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

  Widget _buildAutomaticBookingCard() {
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
          Row(
            children: const [
              Icon(Icons.auto_awesome, color: kBrandDark),
              SizedBox(width: 8),
              Text(
                'Dati derivati automaticamente dal flusso',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _summaryRow('Pick-up', _step1Pickup ?? '-'),
          _summaryRow('Drop-off', _step1Dropoff ?? '-'),
          _summaryRow(
            'Inizio',
            _dataJson?['PickUpDateTime']?.toString() ?? '-',
          ),
          _summaryRow('Fine', _dataJson?['ReturnDateTime']?.toString() ?? '-'),
          _summaryRow('Vehicle code', _selectedVehicleCode ?? '-'),
          _summaryRow('Veicolo', _selectedVehicleName ?? '-'),
          _summaryRow('Channel', _resolvedChannel),
          _summaryRow(
            'Optional selezionati',
            _selectedExtras.isEmpty
                ? 'Nessuno'
                : _selectedExtras.map((e) => '${e.code} x${e.qty}').join(', '),
          ),
          if (_step3InsuranceName != null)
            _summaryRow('Pacchetto', _step3InsuranceName!),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdownCard() {
    final breakdown = _priceBreakdown;
    final currency = breakdown.currencySymbol;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kStroke),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            color: Color(0x08000000),
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.receipt_long, color: kBrandDark),
              SizedBox(width: 8),
              Text(
                'Composizione del costo',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _summaryRow(
            'Costo giornaliero',
            '${_fmtMoney(breakdown.dailyRateExVat, currency)} x ${breakdown.days} giorni',
          ),
          _summaryRow(
            'Noleggio base IVA esclusa',
            _fmtMoney(breakdown.rentalExVat, currency),
          ),
          _summaryRow(
            'Noleggio base IVA inclusa',
            _fmtMoney(breakdown.rentalIncVat, currency),
          ),
          if (breakdown.insuranceLines.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Pacchetto',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            for (final line in breakdown.insuranceLines)
              _summaryRow(line.label, _fmtMoney(line.amount, currency)),
          ],
          if (breakdown.extraLines.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Extra selezionati',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            for (final line in breakdown.extraLines)
              _summaryRow(line.label, _fmtMoney(line.amount, currency)),
          ],
          const Divider(height: 24),
          _summaryRow(
            'Totale extra',
            _fmtMoney(breakdown.extrasTotal, currency),
            bold: true,
          ),
          _summaryRow(
            'Totale pacchetto',
            _fmtMoney(breakdown.insuranceTotal, currency),
            bold: true,
          ),
          _summaryRow(
            'Totale complessivo stimato',
            _fmtMoney(breakdown.grandTotal, currency),
            bold: true,
            valueColor: kBrandDark,
          ),
          const SizedBox(height: 8),
          Text(
            'Il prezzo sopra mostra separatamente imponibile, IVA e componenti selezionate. Il payload di prenotazione usa in automatico i dati derivati dal flusso precedente.',
            style: const TextStyle(color: kTxtMuted, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection() {
    return _grid(
      children: [
        _labeledField(
          'NOME *',
          controller: _customerFirstName,
          validator: _requiredValidator,
        ),
        _labeledField(
          'COGNOME *',
          controller: _customerLastName,
          validator: _requiredValidator,
        ),
        _labeledField(
          'E-MAIL *',
          controller: _customerEmail,
          keyboardType: TextInputType.emailAddress,
          validator: _emailValidator,
        ),
        _labeledField(
          'CONFERMA E-MAIL *',
          controller: _customerEmailConfirm,
          keyboardType: TextInputType.emailAddress,
          validator: _confirmEmailValidator,
        ),
        _labeledField(
          'TELEFONO *',
          controller: _customerMobile,
          keyboardType: TextInputType.phone,
          validator: _requiredValidator,
        ),
        _selectLabeled(
          'NAZIONE *',
          _customerCountry,
          items: const ['IT', 'FR', 'DE', 'ES', 'GB'],
        ),
        _labeledField(
          'CITTÀ *',
          controller: _customerCity,
          validator: _requiredValidator,
        ),
        _labeledField(
          'CAP *',
          controller: _customerZip,
          keyboardType: TextInputType.number,
          validator: _requiredValidator,
        ),
        _labeledField(
          'INDIRIZZO *',
          controller: _customerStreet,
          validator: _requiredValidator,
        ),
        _labeledField(
          'CIVICO *',
          controller: _customerNum,
          validator: _requiredValidator,
        ),
        _labeledField(
          'CODICE FISCALE *',
          controller: _customerTaxCode,
          validator: _requiredValidator,
        ),
        _dateLabeled(
          'DATA DI NASCITA *',
          controller: _customerBirthDate,
          validator: _requiredValidator,
        ),
        _labeledField(
          'LUOGO DI NASCITA *',
          controller: _customerBirthPlace,
          validator: _requiredValidator,
        ),
        _labeledField(
          'PROVINCIA DI NASCITA *',
          controller: _customerBirthProvince,
          validator: _requiredValidator,
        ),
      ],
    );
  }

  Widget _buildCustomerDocumentSection() {
    return _grid(
      children: [
        _labeledField(
          'DOCUMENTO *',
          controller: _customerDocument,
          validator: _requiredValidator,
        ),
        _labeledField(
          'NUMERO DOCUMENTO *',
          controller: _customerDocumentNumber,
          validator: _requiredValidator,
        ),
        _labeledField(
          'TIPO PATENTE *',
          controller: _customerLicenceType,
          validator: _requiredValidator,
        ),
        _labeledField(
          'RILASCIATA DA *',
          controller: _customerIssueBy,
          validator: _requiredValidator,
        ),
        _dateLabeled(
          'DATA RILASCIO *',
          controller: _customerReleaseDate,
          validator: _requiredValidator,
        ),
        _dateLabeled(
          'DATA SCADENZA *',
          controller: _customerExpiryDate,
          validator: _requiredValidator,
        ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    final breakdown = _priceBreakdown;
    final priceNow = _fmtMoney(breakdown.grandTotal, breakdown.currencySymbol);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _paymentCard(
              method: PaymentMethod.payNow,
              icon: Icons.credit_card,
              title: 'PAGA ORA',
              subtitle: const Text(
                'Invia nel payload il vehicleRequest di pagamento immediato.',
                style: TextStyle(fontSize: 11, color: kTxtMuted),
              ),
              price: priceNow,
            ),
            _paymentCard(
              method: PaymentMethod.payAtDesk,
              icon: Icons.storefront_outlined,
              title: 'PAGA AL RITIRO',
              subtitle: const Text(
                'La prenotazione viene creata senza vehicleRequest.',
                style: TextStyle(fontSize: 11, color: kTxtMuted),
              ),
              price: priceNow,
            ),
            _paymentCard(
              method: PaymentMethod.scalapay,
              icon: Icons.wallet_outlined,
              title: 'SCALAPAY',
              subtitle: const Text(
                'Mantiene la prenotazione con payload di pagamento dedicato.',
                style: TextStyle(fontSize: 11, color: kTxtMuted),
              ),
              price: priceNow,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _cardForm(),
      ],
    );
  }

  Widget _buildDriversSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          value: _useCustomerAsDriver1,
          contentPadding: EdgeInsets.zero,
          activeColor: kBrandDark,
          title: const Text(
            'Usa automaticamente il customer come Driver 1',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            'Se attivo, il backend userà il cliente come primo guidatore senza richiedere un driver1 separato.',
          ),
          onChanged: (value) {
            setState(() => _useCustomerAsDriver1 = value);
          },
        ),
        if (!_useCustomerAsDriver1) ...[
          const SizedBox(height: 8),
          _buildDriverCard(
            title: 'Driver 1',
            bundle: _driver1,
            showCopyFromCustomer: true,
            onCopyFromCustomer: () {
              setState(() => _copyCustomerIntoDriver(_driver1));
            },
          ),
        ],
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          value: _enableDriver2,
          contentPadding: EdgeInsets.zero,
          activeColor: kBrandDark,
          title: const Text('Aggiungi Driver 2'),
          onChanged: (value) => setState(() => _enableDriver2 = value),
        ),
        if (_enableDriver2)
          _buildDriverCard(title: 'Driver 2', bundle: _driver2),
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          value: _enableDriver3,
          contentPadding: EdgeInsets.zero,
          activeColor: kBrandDark,
          title: const Text('Aggiungi Driver 3'),
          onChanged: (value) => setState(() => _enableDriver3 = value),
        ),
        if (_enableDriver3)
          _buildDriverCard(title: 'Driver 3', bundle: _driver3),
      ],
    );
  }

  Widget _buildDriverCard({
    required String title,
    required _DriverFormBundle bundle,
    bool showCopyFromCustomer = false,
    VoidCallback? onCopyFromCustomer,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (showCopyFromCustomer)
                TextButton.icon(
                  onPressed: onCopyFromCustomer,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copia dati cliente'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _grid(
            children: [
              _labeledField(
                'NOME *',
                controller: bundle.firstName,
                validator: _requiredValidator,
              ),
              _labeledField(
                'COGNOME *',
                controller: bundle.lastName,
                validator: _requiredValidator,
              ),
              _labeledField(
                'E-MAIL',
                controller: bundle.email,
                keyboardType: TextInputType.emailAddress,
              ),
              _labeledField(
                'TELEFONO',
                controller: bundle.mobile,
                keyboardType: TextInputType.phone,
              ),
              _selectLabeled(
                'NAZIONE',
                bundle.country,
                items: const ['IT', 'FR', 'DE', 'ES', 'GB'],
              ),
              _labeledField('CITTÀ', controller: bundle.city),
              _labeledField(
                'CAP',
                controller: bundle.zip,
                keyboardType: TextInputType.number,
              ),
              _labeledField('INDIRIZZO', controller: bundle.street),
              _labeledField('CIVICO', controller: bundle.num),
              _labeledField('CODICE FISCALE', controller: bundle.taxCode),
              _dateLabeled('DATA DI NASCITA', controller: bundle.birthDate),
              _labeledField('LUOGO DI NASCITA', controller: bundle.birthPlace),
              _labeledField(
                'PROVINCIA DI NASCITA',
                controller: bundle.birthProvince,
              ),
              _labeledField('DOCUMENTO', controller: bundle.document),
              _labeledField(
                'NUMERO DOCUMENTO',
                controller: bundle.documentNumber,
              ),
              _labeledField('TIPO PATENTE', controller: bundle.licenceType),
              _labeledField('RILASCIATA DA', controller: bundle.issueBy),
              _dateLabeled('DATA RILASCIO', controller: bundle.releaseDate),
              _dateLabeled('DATA SCADENZA', controller: bundle.expiryDate),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConsents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _consentTile(
          value: _accPrivacy,
          onChanged: (v) => setState(() => _accPrivacy = v ?? false),
          text: const Text(
            'Accetto l’informativa privacy per la finalità di prenotazione.',
          ),
        ),
        _consentTile(
          value: _accTos,
          onChanged: (v) => setState(() => _accTos = v ?? false),
          text: const Text(
            'Accetto termini e condizioni generali del servizio.',
          ),
        ),
        _consentTile(
          value: _accProfiling,
          onChanged: (v) => setState(() => _accProfiling = v ?? false),
          text: const Text(
            'Acconsento al trattamento dati per finalità di profilazione.',
          ),
        ),
        _consentTile(
          value: _accDataShare,
          onChanged: (v) => setState(() => _accDataShare = v ?? false),
          text: const Text(
            'Acconsento alla comunicazione dei dati a partner commerciali.',
          ),
        ),
      ],
    );
  }

  Widget _buildSubmittingOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xAAFFFFFF),
        alignment: Alignment.center,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kStroke),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 18,
                    color: Color(0x14000000),
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(height: 8),
                  Icon(Icons.sync, color: kBrandDark, size: 40),
                  SizedBox(height: 16),
                  Text(
                    'Stiamo creando la prenotazione…',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Invio payload compose, attesa esito wrapper e recupero dettagli reservation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kTxtMuted, height: 1.35),
                  ),
                  SizedBox(height: 18),
                  LinearProgressIndicator(minHeight: 8),
                  SizedBox(height: 12),
                  LinearProgressIndicator(minHeight: 8),
                  SizedBox(height: 12),
                  LinearProgressIndicator(minHeight: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmationView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FFF7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD7F2E1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF2E9E5B), size: 32),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Prenotazione completata',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _summaryRow('Booking ID', _composeResponse?.booking_id ?? '-'),
              _summaryRow(
                'Reservation internal ID',
                _composeResponse?.reservation_id_internal ?? '-',
              ),
              _summaryRow('Customer ID', _composeResponse?.customer_id ?? '-'),
              _summaryRow('Channel', _composeResponse?.channel ?? '-'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: kBrandDark,
                      foregroundColor: Colors.white,
                    ),
                    onPressed:
                        () => Navigator.of(context).popUntil((r) => r.isFirst),
                    icon: const Icon(Icons.home),
                    label: const Text('Torna alla home'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _resetForNewBooking,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Nuova prenotazione'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildJsonPanel(
          title: 'Output compose',
          jsonMap: _composeResponse?.toJson(),
        ),
        const SizedBox(height: 16),
        _buildJsonPanel(
          title: 'Dettaglio reservation da internal id',
          jsonMap: _detailsByInternalId?.toJson(),
          error: _detailsByInternalIdError,
        ),
        const SizedBox(height: 16),
        _buildJsonPanel(
          title: 'Dettaglio reservation da code + email + date',
          jsonMap: _detailsByCode?.toJson(),
          error: _detailsByCodeError,
        ),
      ],
    );
  }

  Widget _buildJsonPanel({
    required String title,
    Map<String, dynamic>? jsonMap,
    String? error,
  }) {
    final pretty =
        jsonMap == null
            ? null
            : const JsonEncoder.withIndent('  ').convert(jsonMap);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 10),
          if (error != null)
            _buildErrorBox(error)
          else if (pretty != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kStroke),
              ),
              child: SelectableText(
                pretty,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            )
          else
            const Text(
              'Nessun dato disponibile.',
              style: TextStyle(color: kTxtMuted),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF0CFCF)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF9C2C2C), height: 1.35),
      ),
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
        width: 300,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(
              color: selected ? kBrandDark : kStroke,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _circleIcon(icon),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _radioDot(selected),
                ],
              ),
              if (subtitle != null) ...[const SizedBox(height: 8), subtitle],
              const SizedBox(height: 12),
              Text(
                price,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardForm() {
    final visible =
        _payMethod == PaymentMethod.payNow ||
        _payMethod == PaymentMethod.scalapay;
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
          Row(
            children: [
              _circleIcon(Icons.credit_card, bg: kBrand.withOpacity(.10)),
              const SizedBox(width: 8),
              const Text(
                'Dati carta',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _label('Numero carta'),
          const SizedBox(height: 6),
          _textField(
            controller: _ccNumber,
            hint: '1234 1234 1234 1234',
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
            ],
          ),
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
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9/ ]')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('CVC'),
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
            final right =
                (i + 1 < children.length && !left.span2)
                    ? children[i + 1]
                    : null;

            rows.add(
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: left.effectiveWidth(colW), child: left.child),
                  if (right != null) ...[
                    const SizedBox(width: kGutter),
                    SizedBox(
                      width: right.effectiveWidth(colW),
                      child: right.child,
                    ),
                  ],
                ],
              ),
            );
            i += right == null ? 1 : 2;
          } else {
            rows.add(SizedBox(width: colW, child: children[i].child));
            i += 1;
          }

          if (i < children.length) {
            rows.add(const SizedBox(height: 12));
          }
        }

        return Column(children: rows);
      },
    );
  }

  _GridChild _labeledField(
    String label, {
    required TextEditingController controller,
    String? hint,
    int span = 1,
    double? maxW,
    bool readOnly = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    VoidCallback? onTap,
  }) {
    return _GridChild(
      span2: span == 2,
      maxW: maxW,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 6),
          _textField(
            controller: controller,
            hint: hint,
            readOnly: readOnly,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: validator,
            onTap: onTap,
          ),
        ],
      ),
    );
  }

  _GridChild _selectLabeled(
    String label,
    ValueNotifier<String> controller, {
    required List<String> items,
    int span = 1,
    double? maxW,
  }) {
    return _GridChild(
      span2: span == 2,
      maxW: maxW,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 6),
          ValueListenableBuilder<String>(
            valueListenable: controller,
            builder:
                (ctx, value, _) => _selectField(
                  items: items,
                  value: value,
                  onChanged: (v) => controller.value = v ?? items.first,
                ),
          ),
        ],
      ),
    );
  }

  _GridChild _dateLabeled(
    String label, {
    required TextEditingController controller,
    String? Function(String?)? validator,
  }) {
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
            validator: validator,
            onTap: () async {
              final now = DateTime.now();
              final parsed = _parseUiDate(controller.text);
              final initial =
                  parsed ?? DateTime(now.year - 30, now.month, now.day);
              final pick = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
                builder: (ctx, child) {
                  final base = Theme.of(ctx);
                  return Theme(
                    data: base.copyWith(
                      colorScheme: base.colorScheme.copyWith(
                        primary: kBrandDark,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (pick != null) {
                controller.text = _formatUiDate(pick);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _label(String s) => Text(
    s,
    style: const TextStyle(
      fontSize: 12,
      color: kTxtMuted,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _textField({
    TextEditingController? controller,
    String? hint,
    bool readOnly = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _selectField({
    required List<String> items,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : items.first,
      items:
          items
              .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
              .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
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
        decoration: BoxDecoration(
          color: kBrandDark,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  Widget _circleIcon(IconData icon, {Color? bg}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg ?? kBrand.withOpacity(.10),
        shape: BoxShape.circle,
        border: Border.all(color: kStroke),
      ),
      child: Icon(icon, color: kBrandDark),
    );
  }

  Widget _consentTile({
    required bool value,
    required Widget text,
    ValueChanged<bool?>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: kBrandDark,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 6),
          Expanded(child: text),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
  );

  Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: kTxtMuted,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleStepTap(int step) {
    const currentStep = 4;
    if (step < 1 || step >= currentStep) return;

    final stepsBack = currentStep - step;
    final nav = Navigator.of(context);
    for (var i = 0; i < stepsBack; i++) {
      if (!nav.canPop()) break;
      nav.pop();
    }
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitError = null);

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      setState(
        () => _submitError = 'Compila correttamente tutti i campi obbligatori.',
      );
      return;
    }

    if (!_accPrivacy || !_accTos) {
      setState(
        () => _submitError = 'Accetta privacy e termini per continuare.',
      );
      return;
    }

    if (_selectedVehicleCode == null || _dataJson == null) {
      setState(
        () =>
            _submitError =
                'Dati di prenotazione incompleti: vehicle o quotation non disponibili.',
      );
      return;
    }

    final payload = _buildComposePayload();

    setState(() {
      _isSubmitting = true;
      _submitError = null;
      _detailsByCodeError = null;
      _detailsByInternalIdError = null;
    });

    final startedAt = DateTime.now();

    try {
      final compose = await _repo.createReservationCompose(
        booking: Map<String, dynamic>.from(payload['booking'] as Map),
        customer: Map<String, dynamic>.from(payload['customer'] as Map),
        customerUpdate:
            payload['customerUpdate'] == null
                ? null
                : Map<String, dynamic>.from(payload['customerUpdate'] as Map),
        driver1:
            payload['driver1'] == null
                ? null
                : Map<String, dynamic>.from(payload['driver1'] as Map),
        driver2:
            payload['driver2'] == null
                ? null
                : Map<String, dynamic>.from(payload['driver2'] as Map),
        driver3:
            payload['driver3'] == null
                ? null
                : Map<String, dynamic>.from(payload['driver3'] as Map),
      );

      ReservationFullDetailsResponse? internal;
      ReservationFullDetailsResponse? byCode;
      String? internalError;
      String? byCodeError;

      try {
        internal = await _repo.getReservationByInternalId(
          compose.reservation_id_internal,
        );
      } catch (e) {
        internalError = e.toString();
      }

      final reservationCode = compose.booking_id;
      final reservationDate = _reservationDateForByCode;
      final customerEmail = _customerEmail.text.trim();

      if (reservationCode.isNotEmpty &&
          reservationDate != null &&
          customerEmail.isNotEmpty) {
        try {
          byCode = await _repo.getReservationByCode(
            reservationCode: reservationCode,
            customerEmail: customerEmail,
            reservationDate: reservationDate,
          );
        } catch (e) {
          byCodeError = e.toString();
        }
      }

      final elapsed = DateTime.now().difference(startedAt);
      final remain = const Duration(seconds: 3) - elapsed;
      if (remain.inMilliseconds > 0) {
        await Future.delayed(remain);
      }

      if (!mounted) return;
      setState(() {
        _composeResponse = compose;
        _detailsByInternalId = internal;
        _detailsByCode = byCode;
        _detailsByInternalIdError = internalError;
        _detailsByCodeError = byCodeError;
        _isSubmitting = false;
        _bookingCompleted = true;
      });
    } catch (e) {
      final elapsed = DateTime.now().difference(startedAt);
      final remain = const Duration(seconds: 3) - elapsed;
      if (remain.inMilliseconds > 0) {
        await Future.delayed(remain);
      }
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError = e.toString();
      });
    }
  }

  void _resetForNewBooking() {
    setState(() {
      _bookingCompleted = false;
      _isSubmitting = false;
      _submitError = null;
      _composeResponse = null;
      _detailsByInternalId = null;
      _detailsByCode = null;
      _detailsByInternalIdError = null;
      _detailsByCodeError = null;
    });
  }

  Map<String, dynamic> _buildComposePayload() {
    final booking = <String, dynamic>{
      'pickupLocation': _pickupCode,
      'dropOffLocation': _dropoffCode,
      'startDate': _pickupIso,
      'endDate': _dropoffIso,
      'vehicleCode': _selectedVehicleCode,
      'channel': _resolvedChannel,
      'optionals':
          _selectedExtras
              .map(
                (e) => {
                  'EquipType': e.code,
                  'Quantity': e.qty,
                  'Selected': true,
                  'Prepaid': false,
                },
              )
              .toList(),
      'youngDriverFee': null,
      'seniorDriverFee': null,
      'seniorDriverFeeDesc': null,
      'youngDriverFeeDesc': null,
      'onlineUser': null,
      'insuranceId': null,
      'agreementCoupon': _cfg?.coupon,
      'TransactionStatusCode': null,
      'PayNowDis': null,
      'isYoungDriverAge': null,
      'isSeniorDriverAge': null,
    };

    final vehicleRequest = _buildVehicleRequest();
    if (vehicleRequest != null) {
      booking['vehicleRequest'] = vehicleRequest;
    }

    return {
      'booking': booking,
      'customer': _buildCustomerPayload(),
      'customerUpdate': _buildCustomerUpdatePayload(),
      'driver1': _useCustomerAsDriver1 ? null : _driver1.toJsonOrNull(),
      'driver2': _enableDriver2 ? _driver2.toJsonOrNull() : null,
      'driver3': _enableDriver3 ? _driver3.toJsonOrNull() : null,
    };
  }

  Map<String, dynamic> _buildCustomerPayload() {
    return {
      'firstName': _customerFirstName.text.trim(),
      'lastName': _customerLastName.text.trim(),
      'email': _customerEmail.text.trim(),
      'mobileNumber': _customerMobile.text.trim(),
      'country': _customerCountry.value.trim(),
      'city': _customerCity.text.trim(),
      'zip': _customerZip.text.trim(),
      'street': _customerStreet.text.trim(),
      'num': _customerNum.text.trim(),
      'taxCode': _customerTaxCode.text.trim(),
      'birthPlace': _customerBirthPlace.text.trim(),
      'birthProvince': _customerBirthProvince.text.trim(),
      'birthDate': _toApiBirthDateTime(_customerBirthDate.text.trim()),
    };
  }

  Map<String, dynamic> _buildCustomerUpdatePayload() {
    return {
      'document': _customerDocument.text.trim(),
      'documentNumber': _customerDocumentNumber.text.trim(),
      'licenceType': _customerLicenceType.text.trim(),
      'issueBy': _customerIssueBy.text.trim(),
      'releaseDate': _toApiDate(_customerReleaseDate.text.trim()),
      'expiryDate': _toApiDate(_customerExpiryDate.text.trim()),
    };
  }

  double _extractPaymentAmountForVehicleRequest() {
    double? readFromMap(Map<String, dynamic>? m) {
      if (m == null) return null;

      for (final key in [
        'RateTotalAmount',
        'EstimatedTotalAmount',
        'TotalAmount',
      ]) {
        final v = m[key];
        if (v is num) return v.toDouble();
        if (v is String) {
          final parsed = double.tryParse(v.replaceAll(',', '.'));
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    // 1) prima prova dal raw dell'offerta selezionata
    final raw = _selected?.raw;
    if (raw != null) {
      final tcRaw = raw['TotalCharge'] ?? raw['total_charge'];
      if (tcRaw is Map) {
        final amount = readFromMap(Map<String, dynamic>.from(tcRaw));
        if (amount != null && amount > 0) return amount;
      }
    }

    // 2) fallback: cerca il veicolo selezionato dentro dataJson['Vehicles']
    final vehicles = _dataJson?['Vehicles'];
    if (vehicles is List) {
      final wantedIds = <String>{
        if (_selected?.id != null) _selected!.id!.toString(),
        if (_selected?.vehicleId != null) _selected!.vehicleId!.toString(),
        if (_selected?.code != null) _selected!.code!.toString(),
      };

      for (final item in vehicles) {
        if (item is! Map) continue;
        final vm = Map<String, dynamic>.from(item as Map);

        final vehicle = vm['Vehicle'];
        final vehicleMap =
            vehicle is Map
                ? Map<String, dynamic>.from(vehicle)
                : const <String, dynamic>{};

        final candidateId =
            (vehicleMap['id'] ??
                    vehicleMap['Id'] ??
                    vehicleMap['Code'] ??
                    vehicleMap['code'] ??
                    vm['id'] ??
                    vm['Id'] ??
                    vm['Code'] ??
                    vm['code'])
                ?.toString();

        if (candidateId == null || !wantedIds.contains(candidateId)) continue;

        final tcRaw = vm['TotalCharge'] ?? vm['total_charge'];
        if (tcRaw is Map) {
          final amount = readFromMap(Map<String, dynamic>.from(tcRaw));
          if (amount != null && amount > 0) return amount;
        }
      }
    }

    // 3) ultimo fallback: usa il totale dell'offerta, se presente
    if (_selected?.total != null && _selected!.total! > 0) {
      return _selected!.total!;
    }

    return 0;
  }

  Map<String, dynamic>? _buildVehicleRequest() {
    //if (_payMethod == PaymentMethod.payAtDesk) return null;

    /*return {
      'paymentType': _payMethod == PaymentMethod.scalapay
          ? 'SCALAPAY'
          : 'CREDIT_CARD',
      'type': 'Payment',
      'paymentAmount': _priceBreakdown.rentalExVat,
      'paymentTransactionTypeCode': 'charge',
      'voucherNumber': _buildVoucherNumber(),
    };
  }*/
    final amount = _extractPaymentAmountForVehicleRequest();
    if (amount <= 0) return null;
    return {
      'PaymentType': '---3BONIFICO---3',
      'type': 'Payment',
      'PaymentAmount': amount,
      'PaymentTransactionTypeCode': 'charge',
      'VoucherNumber': 'TESTDOGMA',
    };
  }

  void _copyCustomerIntoDriver(_DriverFormBundle driver) {
    driver.firstName.text = _customerFirstName.text;
    driver.lastName.text = _customerLastName.text;
    driver.email.text = _customerEmail.text;
    driver.mobile.text = _customerMobile.text;
    driver.country.value = _customerCountry.value;
    driver.city.text = _customerCity.text;
    driver.zip.text = _customerZip.text;
    driver.street.text = _customerStreet.text;
    driver.num.text = _customerNum.text;
    driver.taxCode.text = _customerTaxCode.text;
    driver.birthPlace.text = _customerBirthPlace.text;
    driver.birthProvince.text = _customerBirthProvince.text;
    driver.birthDate.text = _customerBirthDate.text;
    driver.document.text = _customerDocument.text;
    driver.documentNumber.text = _customerDocumentNumber.text;
    driver.licenceType.text = _customerLicenceType.text;
    driver.issueBy.text = _customerIssueBy.text;
    driver.releaseDate.text = _customerReleaseDate.text;
    driver.expiryDate.text = _customerExpiryDate.text;
  }

  void _seedFormFromFlow() {
    _ccNumber.text = '1234 1234 1234 1234';
    _ccExp.text = '12 / 30';
    _ccCvc.text = '123';

    if (_cfg?.age != null && _customerBirthDate.text.trim().isEmpty) {
      final birthYear = DateTime.now().year - _cfg!.age!;
      _customerBirthDate.text = '01 / 01 / $birthYear';
    }
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

  void _hydrateHeaderFromDataJson(
    Map<String, dynamic> data,
    Offer? selected,
    List<InitialExtra> chosen,
  ) {
    _step1Pickup =
        _displayLocationName(
          data,
          codeKey: 'PickUpLocation',
          nameCandidates: const [
            'PickUpLocationName',
            'pickupName',
            'PickupName',
            'PickupCity',
            'pickupCity',
          ],
        ) ??
        data['PickUpLocation']?.toString();

    _step1Dropoff =
        _displayLocationName(
          data,
          codeKey: 'ReturnLocation',
          nameCandidates: const [
            'ReturnLocationName',
            'returnName',
            'ReturnCity',
            'returnCity',
          ],
        ) ??
        data['ReturnLocation']?.toString();

    _step1Start = _fmtDate(data['PickUpDateTime']?.toString());
    _step1End = _fmtDate(data['ReturnDateTime']?.toString());
    _step2Title = selected?.group ?? 'Auto';
    _step2Subtitle = selected?.name ?? '';
    _step2Thumb = selected?.imageUrl;
    _step2Price = _formatHeaderPrice(data, selected);

    final labels = <String>[];
    num totalExtra = 0;
    final days = _computeRentalDays(data);
    final optionals = _selectedVehicleOptionals;

    for (final selectedExtra in chosen) {
      final raw = _findOptionalRaw(selectedExtra.code, optionals);
      final equip =
          raw == null
              ? const <String, dynamic>{}
              : Map<String, dynamic>.from(raw['Equipment'] as Map? ?? const {});
      final charge =
          raw == null
              ? const <String, dynamic>{}
              : Map<String, dynamic>.from(raw['Charge'] as Map? ?? const {});

      final title = (equip['Description'] ?? selectedExtra.code).toString();
      final amount = (charge['Amount'] as num?)?.toDouble() ?? 0;
      final isDaily = selectedExtra.perDay;
      final lineTotal = amount * max(1, selectedExtra.qty) * (isDaily ? 1 : 1);
      labels.add(
        selectedExtra.qty > 1 ? '$title x${selectedExtra.qty}' : title,
      );
      totalExtra += lineTotal;
    }

    _step3Extras = labels;
    _step3ExtrasTotal = labels.isEmpty ? null : _formatMoney(totalExtra, 'EUR');
  }

  void _hydrateHeaderFromJson(Map<String, dynamic> m) {
    String? s(dynamic v) {
      if (v == null) return null;
      final out = v.toString().trim();
      return out.isEmpty ? null : out;
    }

    _step1Pickup = s(m['pickupLocation']);
    _step1Dropoff = s(m['dropoffLocation']);
    _step1Start = _fmtDate(s(m['start']));
    _step1End = _fmtDate(s(m['end']));

    final vehicleId = s(m['vehicleId']);
    _step2Title = (vehicleId?.isNotEmpty == true) ? vehicleId : null;
    _step2Subtitle = null;
    _step2Thumb = null;
    _step2Price = null;

    final extras = <String>[];
    final rawExtras = m['extras'];
    if (rawExtras is List) {
      for (final e in rawExtras) {
        if (e is Map) {
          final code = s(e['code']);
          if (code != null) extras.add(code);
        }
      }
    }
    _step3Extras = extras;
    _step3ExtrasTotal = null;
  }

  static String? _fmtDate(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    final raw = iso.trim();
    final dt =
        DateTime.tryParse(raw) ?? DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (dt == null) return raw;
    try {
      return DateFormat('d MMM, y HH:mm', 'it_IT').format(dt.toLocal());
    } catch (_) {
      return raw;
    }
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

  static String? _formatHeaderPrice(
    Map<String, dynamic> dataJson,
    Offer? selected,
  ) {
    String? fmt(num? amount, String? currencyCode) {
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

    if (selected == null) return null;
    final offerTotal = selected.total;
    if (offerTotal != null) return fmt(offerTotal, 'EUR');

    Map<String, dynamic>? extractTotalChargeFrom(dynamic raw) {
      if (raw is! Map) return null;
      final m = raw.cast<String, dynamic>();
      final tc = m['TotalCharge'] ?? m['total_charge'];
      if (tc is Map) return Map<String, dynamic>.from(tc);
      return null;
    }

    num? amountFromTc(Map<String, dynamic>? tc) {
      if (tc == null) return null;
      return (tc['RateTotalAmount'] as num?) ??
          (tc['EstimatedTotalAmount'] as num?);
    }

    String? currFromTc(Map<String, dynamic>? tc) {
      if (tc == null) return null;
      return tc['CurrencyCode'] as String?;
    }

    final tcFromRaw = extractTotalChargeFrom(selected.raw);
    final fromRaw = fmt(amountFromTc(tcFromRaw), currFromTc(tcFromRaw));
    if (fromRaw != null) return fromRaw;

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
          final tc = extractTotalChargeFrom(vm);
          final out = fmt(amountFromTc(tc), currFromTc(tc));
          if (out != null) return out;
        }
      }
    }
    return null;
  }

  static String _formatMoney(num amount, String? currency) {
    final sym = (currency == null || currency == 'EUR') ? '€' : currency;
    return '$sym ${amount.toStringAsFixed(2)}';
  }

  String get _pickupCode =>
      _dataJson?['PickUpLocation']?.toString() ?? _cfg?.pickupLocation ?? '';

  String get _dropoffCode =>
      _dataJson?['ReturnLocation']?.toString() ?? _cfg?.dropoffLocation ?? '';

  String get _pickupIso =>
      _dataJson?['PickUpDateTime']?.toString() ??
      _cfg?.start.toUtc().toIso8601String() ??
      '';

  String get _dropoffIso =>
      _dataJson?['ReturnDateTime']?.toString() ??
      _cfg?.end.toUtc().toIso8601String() ??
      '';

  String get _resolvedChannel => _cfg?.channel ?? 'RENTAL_PREMIUM_POA';

  String? get _selectedVehicleCode =>
      _selected?.code ?? _selected?.vehicleId ?? _cfg?.vehicleId;

  String? get _selectedVehicleName => _selected?.name ?? _step2Subtitle;

  String? get _reservationDateForByCode {
    try {
      final dt = DateTime.parse(_pickupIso);
      return DateFormat('yyyy-MM-dd').format(dt);
    } catch (_) {
      return null;
    }
  }

  String _buildVoucherNumber() {
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    final suffix = now.substring(max(0, now.length - 8));
    return 'WEB$suffix';
  }

  List<dynamic> get _selectedVehicleOptionals {
    final rawFromSelected = _selected?.raw['optionals'];
    if (rawFromSelected is List) return rawFromSelected;
    final root = _dataJson?['optionals'];
    if (root is List) return root;
    return const [];
  }

  Map<String, dynamic>? _findOptionalRaw(String code, List<dynamic> items) {
    final wanted = code.trim().toUpperCase();
    for (final item in items) {
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      final equip =
          (map['Equipment'] as Map?)?.cast<String, dynamic>() ?? const {};
      final equipType =
          (equip['EquipType'] ?? equip['Code'])?.toString().toUpperCase();
      final desc = equip['Description']?.toString().toUpperCase();
      if (equipType == wanted || desc == wanted) {
        return map;
      }
    }
    return null;
  }

  _BookingPriceBreakdown get _priceBreakdown {
    final selected = _selected;
    final days = _computeRentalDays(_dataJson ?? const {});
    final calc =
        (selected?.raw['Reference'] is Map)
            ? ((selected!.raw['Reference'] as Map)['calculated'] as Map?)
                ?.cast<String, dynamic>()
            : null;
    final dailyRateExVat =
        (calc?['base_daily'] as num?)?.toDouble() ?? selected?.pricePerDay ?? 0;
    final rentalExVat =
        (calc?['pre_vat'] as num?)?.toDouble() ??
        ((selected?.raw['TotalCharge'] as Map?)?['RateTotalAmount'] as num?)
            ?.toDouble() ??
        (dailyRateExVat * days);
    final rentalIncVat =
        (calc?['total'] as num?)?.toDouble() ??
        ((selected?.raw['TotalCharge'] as Map?)?['EstimatedTotalAmount']
                as num?)
            ?.toDouble() ??
        selected?.total ??
        rentalExVat;

    final extraLines = <_PriceLine>[];
    final insuranceLines = <_PriceLine>[];
    for (final extra in _selectedExtras) {
      final raw = _findOptionalRaw(extra.code, _selectedVehicleOptionals);
      final equip =
          raw == null
              ? const <String, dynamic>{}
              : Map<String, dynamic>.from(raw['Equipment'] as Map? ?? const {});
      final charge =
          raw == null
              ? const <String, dynamic>{}
              : Map<String, dynamic>.from(raw['Charge'] as Map? ?? const {});
      final title = (equip['Description'] ?? extra.code).toString();
      final amount =
          ((charge['Amount'] as num?)?.toDouble() ?? 0) * max(1, extra.qty);
      final line = _PriceLine(
        label: extra.qty > 1 ? '$title x${extra.qty}' : title,
        amount: amount,
      );
      final normalized = '${extra.code} $title'.toUpperCase();
      final isInsurance =
          normalized.contains('SILVER') ||
          normalized.contains('GOLD') ||
          normalized.contains('DIAMOND');
      if (isInsurance) {
        insuranceLines.add(line);
      } else {
        extraLines.add(line);
      }
    }

    final extrasTotal = extraLines.fold<double>(0, (sum, e) => sum + e.amount);
    final insuranceTotal = insuranceLines.fold<double>(
      0,
      (sum, e) => sum + e.amount,
    );

    return _BookingPriceBreakdown(
      days: days,
      dailyRateExVat: dailyRateExVat,
      rentalExVat: rentalExVat,
      rentalIncVat: rentalIncVat,
      extraLines: extraLines,
      insuranceLines: insuranceLines,
      extrasTotal: extrasTotal,
      insuranceTotal: insuranceTotal,
      grandTotal: rentalIncVat + extrasTotal + insuranceTotal,
      currencySymbol: '€',
    );
  }

  String _fmtMoney(num amount, String symbol) {
    try {
      return NumberFormat.currency(
        locale: 'it_IT',
        symbol: symbol,
      ).format(amount);
    } catch (_) {
      return '$symbol ${amount.toStringAsFixed(2)}';
    }
  }

  String? Function(String?) get _requiredValidator =>
      (value) =>
          (value == null || value.trim().isEmpty) ? 'Campo obbligatorio' : null;

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo obbligatorio';
    final v = value.trim();
    final ok =
        v.contains('@') &&
        v.contains('.') &&
        !v.startsWith('@') &&
        !v.endsWith('@');
    return ok ? null : 'E-mail non valida';
  }

  String? _confirmEmailValidator(String? value) {
    final required = _emailValidator(value);
    if (required != null) return required;
    if (value!.trim().toLowerCase() !=
        _customerEmail.text.trim().toLowerCase()) {
      return 'Le e-mail non coincidono';
    }
    return null;
  }

  DateTime? _parseUiDate(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      return DateFormat('dd / MM / yyyy').parseStrict(raw.trim());
    } catch (_) {
      try {
        return DateTime.parse(raw.trim());
      } catch (_) {
        return null;
      }
    }
  }

  String _formatUiDate(DateTime d) => DateFormat('dd / MM / yyyy').format(d);

  String? _toApiDate(String raw) {
    final d = _parseUiDate(raw);
    if (d == null) return null;
    return DateFormat('yyyy-MM-dd').format(d);
  }

  String? _toApiBirthDateTime(String raw) {
    final d = _parseUiDate(raw);
    if (d == null) return null;
    return DateFormat("yyyy-MM-dd'T'00:00:00").format(d);
  }
}

enum PaymentMethod { payNow, payAtDesk, scalapay }

class _GridChild {
  final Widget child;
  final bool span2;
  final double? maxW;

  _GridChild({required this.child, this.span2 = false, this.maxW});

  double effectiveWidth(double colW) {
    final w = span2 ? colW * 2 + _ConfirmPageState.kGutter : colW;
    return maxW == null ? w : max(min(w, maxW!), 0);
  }
}

class _NoGlow extends ScrollBehavior {
  const _NoGlow();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

class _PriceLine {
  final String label;
  final double amount;

  const _PriceLine({required this.label, required this.amount});
}

class _BookingPriceBreakdown {
  final int days;
  final double dailyRateExVat;
  final double rentalExVat;
  final double rentalIncVat;
  final List<_PriceLine> extraLines;
  final List<_PriceLine> insuranceLines;
  final double extrasTotal;
  final double insuranceTotal;
  final double grandTotal;
  final String currencySymbol;

  const _BookingPriceBreakdown({
    required this.days,
    required this.dailyRateExVat,
    required this.rentalExVat,
    required this.rentalIncVat,
    required this.extraLines,
    required this.insuranceLines,
    required this.extrasTotal,
    required this.insuranceTotal,
    required this.grandTotal,
    required this.currencySymbol,
  });
}

class _DriverFormBundle {
  final String label;
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final email = TextEditingController();
  final mobile = TextEditingController();
  final country = ValueNotifier<String>('IT');
  final city = TextEditingController();
  final zip = TextEditingController();
  final street = TextEditingController();
  final num = TextEditingController();
  final taxCode = TextEditingController();
  final birthPlace = TextEditingController();
  final birthProvince = TextEditingController();
  final birthDate = TextEditingController();
  final document = TextEditingController();
  final documentNumber = TextEditingController();
  final licenceType = TextEditingController();
  final issueBy = TextEditingController();
  final releaseDate = TextEditingController();
  final expiryDate = TextEditingController();

  _DriverFormBundle({required this.label});

  Map<String, dynamic>? toJsonOrNull() {
    if (firstName.text.trim().isEmpty || lastName.text.trim().isEmpty) {
      return null;
    }
    return {
      'firstName': firstName.text.trim(),
      'lastName': lastName.text.trim(),
      'email': email.text.trim().isEmpty ? null : email.text.trim(),
      'mobileNumber': mobile.text.trim().isEmpty ? null : mobile.text.trim(),
      'country': country.value.trim(),
      'city': city.text.trim().isEmpty ? null : city.text.trim(),
      'zip': zip.text.trim().isEmpty ? null : zip.text.trim(),
      'street': street.text.trim().isEmpty ? null : street.text.trim(),
      'num': num.text.trim().isEmpty ? null : num.text.trim(),
      'taxCode': taxCode.text.trim().isEmpty ? null : taxCode.text.trim(),
      'birthPlace':
          birthPlace.text.trim().isEmpty ? null : birthPlace.text.trim(),
      'birthProvince':
          birthProvince.text.trim().isEmpty ? null : birthProvince.text.trim(),
      'birthDate': _toApiDateStatic(birthDate.text.trim()),
      'document': document.text.trim().isEmpty ? null : document.text.trim(),
      'documentNumber':
          documentNumber.text.trim().isEmpty
              ? null
              : documentNumber.text.trim(),
      'licenceType':
          licenceType.text.trim().isEmpty ? null : licenceType.text.trim(),
      'issueBy': issueBy.text.trim().isEmpty ? null : issueBy.text.trim(),
      'releaseDate': _toApiDateStatic(releaseDate.text.trim()),
      'expiryDate': _toApiDateStatic(expiryDate.text.trim()),
    }..removeWhere((key, value) => value == null);
  }

  static String? _toApiDateStatic(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final d = DateFormat('dd / MM / yyyy').parseStrict(raw.trim());
      return DateFormat('yyyy-MM-dd').format(d);
    } catch (_) {
      try {
        final d = DateTime.parse(raw.trim());
        return DateFormat('yyyy-MM-dd').format(d);
      } catch (_) {
        return null;
      }
    }
  }

  void dispose() {
    firstName.dispose();
    lastName.dispose();
    email.dispose();
    mobile.dispose();
    country.dispose();
    city.dispose();
    zip.dispose();
    street.dispose();
    num.dispose();
    taxCode.dispose();
    birthPlace.dispose();
    birthProvince.dispose();
    birthDate.dispose();
    document.dispose();
    documentNumber.dispose();
    licenceType.dispose();
    issueBy.dispose();
    releaseDate.dispose();
    expiryDate.dispose();
  }
}
