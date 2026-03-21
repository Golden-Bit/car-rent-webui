// ignore_for_file: non_constant_identifier_names

import 'package:car_rent_webui/app.dart';
import 'package:car_rent_webui/car_rent_sdk/sdk.dart';
import 'package:car_rent_webui/core/deeplink/initial_config.dart';
import 'package:car_rent_webui/core/navigation/web_redirect.dart';
import 'package:car_rent_webui/core/widgets/top_nav_bar.dart';
import 'package:car_rent_webui/features/results/models/offer_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

const String kBookingConfirmedHomeUrl = 'https://www.rentalpremium.it/';

class BookingConfirmedArgs {
  final ReservationComposeResponse composeResponse;
  final ReservationFullDetailsResponse? detailsByInternalId;
  final ReservationFullDetailsResponse? detailsByCode;
  final Map<String, dynamic>? dataJson;
  final Offer? selected;
  final List<InitialExtra> selectedExtras;
  final String? insuranceName;
  final String? insuranceTotalFormatted;

  const BookingConfirmedArgs({
    required this.composeResponse,
    this.detailsByInternalId,
    this.detailsByCode,
    this.dataJson,
    this.selected,
    this.selectedExtras = const [],
    this.insuranceName,
    this.insuranceTotalFormatted,
  });
}

class BookingConfirmedPage extends StatelessWidget {
  static const routeName = '/booking_confirmed';

  static const Color kBrand = Color(0xFFFF5A1F);
  static const Color kBrandDark = Color(0xFFE2470C);
  static const Color kCard = Color(0xFFF7F7F8);
  static const Color kStroke = Color(0xFFE6E6E6);
  static const Color kTxtMuted = Color(0xFF6B6B6B);
  static const Color kSuccessBg = Color(0xFFF0FFF7);
  static const Color kSuccessBorder = Color(0xFFD7F2E1);
  static const Color kSuccessText = Color(0xFF2E9E5B);
  static const double kRadius = 16;
  static const double kGutter = 18;

  const BookingConfirmedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final showTopBar = AppUiFlags.showAppBarOf(context);
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is! BookingConfirmedArgs) {
      return Scaffold(
        appBar: showTopBar ? const TopNavBar() : null,
        backgroundColor: Colors.white,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(kRadius),
                border: Border.all(color: kStroke),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 12,
                    color: Color(0x0A000000),
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'I dati di conferma della prenotazione non sono disponibili.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      );
    }

    final resolved = _ResolvedBookingConfirmation.fromArgs(args);

    return Scaffold(
      appBar: showTopBar ? const TopNavBar() : null,
      backgroundColor: Colors.white,
      body: ScrollConfiguration(
        behavior: const _NoGlow(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1360),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final sectionCards = <Widget>[
                    _buildOverviewSection(context, resolved),
                    _buildPickupSection(context, resolved),
                    _buildDropoffSection(context, resolved),
                    _buildVehicleSection(context, resolved),
                    _buildAmountsSection(context, resolved),
                    _buildCustomerSection(context, resolved),
                    _buildDriversSection(context, resolved),
                    _buildSelectedExtrasSection(context, resolved),
                  ];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHero(context, resolved),
                      const SizedBox(height: 18),
                      _buildResponsiveSectionGrid(
                        constraints.maxWidth,
                        sectionCards,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, _ResolvedBookingConfirmation r) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kSuccessBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kSuccessBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: kSuccessText, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Prenotazione confermata',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                ),
              ),
              _statusBadge(r.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Conserva il tuo riferimento di prenotazione. Ti servirà per eventuali comunicazioni relative al noleggio.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _heroChip(
                icon: Icons.confirmation_number_outlined,
                label: 'Riferimento',
                value: r.bookingId,
              ),
              _heroChip(
                icon: Icons.calendar_month_outlined,
                label: 'Periodo',
                value: r.periodLabel,
              ),
              _heroChip(
                icon: Icons.euro_outlined,
                label: 'Totale',
                value: r.money.totalFormatted,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: kBrandDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                onPressed: () => _goToHome(context),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Torna alla home'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                onPressed: () => _copyToClipboard(
                  context,
                  r.bookingId,
                  success: 'Riferimento prenotazione copiato',
                ),
                icon: const Icon(Icons.copy),
                label: const Text('Copia riferimento'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSection(
    BuildContext context,
    _ResolvedBookingConfirmation r,
  ) {
    return _sectionCard(
      id: 'overview',
      title: 'Riepilogo del noleggio',
      icon: Icons.receipt_long_outlined,
      subtitle: 'Informazioni essenziali sulla prenotazione confermata.',
      initiallyExpanded: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;
          final itemWidth = isWide
              ? (constraints.maxWidth - 12) / 2
              : constraints.maxWidth;

          final items = [
            _overviewTile(
              'Società di noleggio',
              r.rentalCompany.isEmpty ? '-' : r.rentalCompany,
              Icons.storefront_outlined,
            ),
            _overviewTile(
              'Durata',
              '${r.rentalDays} ${r.rentalDays == 1 ? 'giorno' : 'giorni'}',
              Icons.timelapse_outlined,
            ),
            _overviewTile(
              'Veicolo',
              r.vehicle.shortLabel.isEmpty ? '-' : r.vehicle.shortLabel,
              Icons.directions_car_outlined,
            ),
            _overviewTile(
              'Importo totale',
              r.money.totalFormatted,
              Icons.payments_outlined,
              emphasize: true,
            ),
          ];

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: items
                .map((item) => SizedBox(width: itemWidth, child: item))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildPickupSection(
    BuildContext context,
    _ResolvedBookingConfirmation r,
  ) {
    return _sectionCard(
      id: 'pickup',
      title: 'Ritiro',
      icon: Icons.login_rounded,
      subtitle: 'Luogo e data di inizio noleggio.',
      initiallyExpanded: false,
      child: _buildLocationContent(context, r.pickup),
    );
  }

  Widget _buildDropoffSection(
    BuildContext context,
    _ResolvedBookingConfirmation r,
  ) {
    return _sectionCard(
      id: 'dropoff',
      title: 'Riconsegna',
      icon: Icons.logout_rounded,
      subtitle: 'Luogo e data di fine noleggio.',
      initiallyExpanded: false,
      child: _buildLocationContent(context, r.dropoff),
    );
  }

  Widget _buildLocationContent(BuildContext context, _LocationInfo data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.title.isEmpty ? '-' : data.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        if (data.address.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            data.address,
            style: const TextStyle(
              color: kTxtMuted,
              height: 1.45,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kStroke),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule, color: kBrandDark, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.dateTimeFormatted.isEmpty ? '-' : data.dateTimeFormatted,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleSection(
    BuildContext context,
    _ResolvedBookingConfirmation r,
  ) {
    final v = r.vehicle;

    return _sectionCard(
      id: 'vehicle',
      title: 'Veicolo assegnato',
      icon: Icons.directions_car_filled_outlined,
      subtitle: 'Dettagli del veicolo risultante in prenotazione.',
      initiallyExpanded: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (v.displayName.isNotEmpty)
            Text(
              v.displayName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          if (v.subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              v.subtitle,
              style: const TextStyle(color: kTxtMuted, height: 1.45),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (v.transmission.isNotEmpty)
                _specChip(Icons.settings, v.transmission),
              if (v.fuel.isNotEmpty)
                _specChip(Icons.local_gas_station_outlined, v.fuel),
              if (v.seats.isNotEmpty)
                _specChip(Icons.event_seat_outlined, '${v.seats} posti'),
              if (v.km.isNotEmpty)
                _specChip(Icons.speed_outlined, '${v.km} km'),
            ],
          ),
          const SizedBox(height: 16),
          if (v.code.isNotEmpty) _infoRow('Codice veicolo', v.code),
          if (v.plateNo.isNotEmpty) _infoRow('Targa', v.plateNo),
          if (v.color.isNotEmpty) _infoRow('Colore', v.color),
          if (v.version.isNotEmpty && v.version != v.model)
            _infoRow('Versione', v.version),
        ],
      ),
    );
  }

  Widget _buildAmountsSection(
    BuildContext context,
    _ResolvedBookingConfirmation r,
  ) {
    final money = r.money;

    return _sectionCard(
      id: 'amounts',
      title: 'Importi',
      icon: Icons.payments_outlined,
      subtitle: 'Totale e dettagli economici disponibili.',
      initiallyExpanded: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFD8C8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Totale prenotazione',
                  style: TextStyle(
                    color: kTxtMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  money.totalFormatted,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: kBrandDark,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (money.net > 0) _infoRow('Imponibile', money.netFormatted),
          if (money.vat > 0) _infoRow('IVA', money.vatFormatted),
          if (money.currencyLabel.isNotEmpty)
            _infoRow('Valuta', money.currencyLabel),
        ],
      ),
    );
  }

  Widget _buildCustomerSection(
    BuildContext context,
    _ResolvedBookingConfirmation r,
  ) {
    final c = r.customer;

    return _sectionCard(
      id: 'customer',
      title: 'Intestatario prenotazione',
      icon: Icons.person_outline,
      subtitle: 'Dati anagrafici e recapiti associati alla prenotazione.',
      initiallyExpanded: false,
      child: c == null
          ? const Text(
              'Le informazioni dell’intestatario non sono disponibili.',
              style: TextStyle(color: kTxtMuted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.fullName.isEmpty ? '-' : c.fullName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 14),
                if (c.email.isNotEmpty) _infoRow('E-mail', c.email),
                if (c.mobile.isNotEmpty) _infoRow('Telefono', c.mobile),
                if (c.birthDate.isNotEmpty)
                  _infoRow('Data di nascita', c.birthDate),
                if (c.birthPlaceSummary.isNotEmpty)
                  _infoRow('Luogo di nascita', c.birthPlaceSummary),
                if (c.addressSummary.isNotEmpty)
                  _infoRow('Indirizzo', c.addressSummary),
                if (c.documentSummary.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Documento e patente',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  _infoRow('Dettagli', c.documentSummary),
                  if (c.releaseDate.isNotEmpty)
                    _infoRow('Rilascio', c.releaseDate),
                  if (c.expiryDate.isNotEmpty)
                    _infoRow('Scadenza', c.expiryDate),
                ],
              ],
            ),
    );
  }

  Widget _buildDriversSection(
    BuildContext context,
    _ResolvedBookingConfirmation r,
  ) {
    return _sectionCard(
      id: 'drivers',
      title: 'Guidatori',
      icon: Icons.badge_outlined,
      subtitle: 'Guidatore principale ed eventuali guidatori aggiuntivi.',
      initiallyExpanded: false,
      child: r.drivers.isEmpty
          ? const Text(
              'Non risultano guidatori aggiuntivi o dettagli specifici dei guidatori.',
              style: TextStyle(color: kTxtMuted),
            )
          : Column(
              children: r.drivers
                  .map(
                    (driver) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kStroke),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver.roleLabel,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            driver.displayName.isEmpty ? '-'
                                : driver.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (driver.note.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              driver.note,
                              style: const TextStyle(
                                color: kTxtMuted,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildSelectedExtrasSection(
    BuildContext context,
    _ResolvedBookingConfirmation r,
  ) {
    final insurance = r.selectedInsurance;

    return _sectionCard(
      id: 'selected_extras',
      title: 'Extra richiesti',
      icon: Icons.add_shopping_cart_outlined,
      subtitle: 'Servizi risultanti attivi nella prenotazione.',
      initiallyExpanded: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (insurance != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD8C8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Copertura selezionata',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  _infoRow('Piano', insurance.planLabel),
                  if (insurance.amountLabel.isNotEmpty)
                    _infoRow('Importo', insurance.amountLabel),
                ],
              ),
            ),
          if (r.displayedExtras.isEmpty)
            const Text(
              'Non risultano extra attivi nella prenotazione.',
              style: TextStyle(color: kTxtMuted),
            )
          else
            ...r.displayedExtras.map(
              (extra) => _lineCard(
                title: extra.title,
                subtitle: extra.subtitle,
                trailing: extra.amountLabel,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResponsiveSectionGrid(double width, List<Widget> sections) {
    final useTwoColumns = width >= 1040;
    final cardWidth = useTwoColumns ? (width - kGutter) / 2 : width;

    return Wrap(
      spacing: kGutter,
      runSpacing: kGutter,
      children: sections
          .map((section) => SizedBox(width: cardWidth, child: section))
          .toList(),
    );
  }

  Widget _sectionCard({
    required String id,
    required String title,
    required IconData icon,
    required String subtitle,
    required Widget child,
    bool initiallyExpanded = false,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kStroke),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            color: Color(0x08000000),
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: ThemeData(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          key: PageStorageKey<String>('section_$id'),
          initiallyExpanded: initiallyExpanded,
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          leading: _circleIcon(icon),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              color: kTxtMuted,
              height: 1.35,
            ),
          ),
          children: [child],
        ),
      ),
    );
  }

  Widget _heroChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kStroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: kBrandDark),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _overviewTile(
    String label,
    String value,
    IconData icon, {
    bool emphasize = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: emphasize ? const Color(0xFFFFF7F2) : kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: emphasize ? const Color(0xFFFFD8C8) : kStroke,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: kStroke),
            ),
            child: Icon(
              icon,
              color: emphasize ? kBrandDark : Colors.black87,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: kTxtMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: emphasize ? kBrandDark : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _specChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kStroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: kBrandDark),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _lineCard({
    required String title,
    required String subtitle,
    required String trailing,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kStroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: kBrandDark, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: kTxtMuted, height: 1.35),
                  ),
                ],
              ],
            ),
          ),
          if (trailing.isNotEmpty) ...[
            const SizedBox(width: 12),
            Text(
              trailing,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
  }

  Widget _circleIcon(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: kBrand.withOpacity(.10),
        shape: BoxShape.circle,
        border: Border.all(color: kStroke),
      ),
      child: Icon(icon, color: kBrandDark),
    );
  }

  Widget _statusBadge(String value) {
    final normalized = value.trim().toLowerCase();
    final isConfirmed = normalized == 'confirmed' || normalized == 'confermato';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isConfirmed
            ? const Color(0xFFE8F8EE)
            : const Color(0xFFFFF3E8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isConfirmed
              ? const Color(0xFFBFE7CB)
              : const Color(0xFFFFD5B6),
        ),
      ),
      child: Text(
        value.isEmpty ? '-' : value,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: isConfirmed ? const Color(0xFF2E9E5B) : kBrandDark,
        ),
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    bool dense = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 2 : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
            child: Text(
              label,
              style: const TextStyle(
                color: kTxtMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _copyToClipboard(
    BuildContext context,
    String text, {
    required String success,
  }) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success)),
    );
  }

  static Future<void> _goToHome(BuildContext context) async {
    if (kBookingConfirmedHomeUrl.trim().isNotEmpty) {
      await redirectToUrlSameTab(kBookingConfirmedHomeUrl);
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

class _ResolvedBookingConfirmation {
  final String bookingId;
  final String status;
  final String rentalCompany;
  final int rentalDays;
  final String periodLabel;
  final _LocationInfo pickup;
  final _LocationInfo dropoff;
  final _VehicleInfo vehicle;
  final _MoneyInfo money;
  final _CustomerInfo? customer;
  final List<_DriverInfo> drivers;
  final _SelectedInsuranceInfo? selectedInsurance;
  final List<_DisplayLine> displayedExtras;

  const _ResolvedBookingConfirmation({
    required this.bookingId,
    required this.status,
    required this.rentalCompany,
    required this.rentalDays,
    required this.periodLabel,
    required this.pickup,
    required this.dropoff,
    required this.vehicle,
    required this.money,
    required this.customer,
    required this.drivers,
    required this.selectedInsurance,
    required this.displayedExtras,
  });

  factory _ResolvedBookingConfirmation.fromArgs(BookingConfirmedArgs args) {
    final detail = args.detailsByInternalId ?? args.detailsByCode;
    final bookingDetail =
        detail?.booking_detail ?? args.composeResponse.booking_detail;
    final bookingMap = Map<String, dynamic>.from(bookingDetail);
    final rawBooking = _map(bookingMap['raw']) ?? <String, dynamic>{};

    final composePrimary =
        _firstBookingCreateDataRow(args.composeResponse.booking_create);
    final composePrimaryMap = composePrimary == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(composePrimary);

    final vehicleMap = _map(bookingMap['vehicle']) ??
        _map(rawBooking['Vehicle']) ??
        _map(composePrimaryMap['vehicle']) ??
        <String, dynamic>{};

    final locationDetails = _list(bookingMap['location_details']) ??
        _list(rawBooking['LocationDetails']) ??
        _list(composePrimaryMap['location_details']) ??
        const <dynamic>[];

    final optionals = _resolveOptionals(
      bookingMap,
      rawBooking,
      composePrimaryMap,
    );

    final pickupLoc = _findLocationByContext(locationDetails, 'pickup');
    final returnLoc = _findLocationByContext(locationDetails, 'return');

    final pickupDateTimeRaw = _string(
      bookingMap['pick_up_date_time'] ??
          rawBooking['PickUpDateTime'] ??
          composePrimaryMap['pick_up_date_time'],
    );
    final returnDateTimeRaw = _string(
      bookingMap['return_date_time'] ??
          rawBooking['ReturnDateTime'] ??
          composePrimaryMap['return_date_time'],
    );

    final pickupDt = _parseDateTime(pickupDateTimeRaw);
    final returnDt = _parseDateTime(returnDateTimeRaw);
    final rentalDays = _computeDays(pickupDt, returnDt);

    final customerMap = _resolveCustomerMap(args, bookingMap, rawBooking);
    final customerInfo =
        customerMap == null ? null : _CustomerInfo.fromMap(customerMap);

    final moneyInfo = _MoneyInfo.fromBookingDetail(
      bookingMap,
      rawBooking,
      _parsePaymentRules(bookingMap['payment_role']),
    );

    final selectedInsurance = _resolveSelectedInsurance(
      optionals,
      moneyInfo.currencyCode,
      fallbackInsuranceName: args.insuranceName,
      fallbackInsuranceTotalFormatted: args.insuranceTotalFormatted,
    );

    final displayedExtras = optionals.isNotEmpty
        ? _buildDisplayedExtras(
            optionals: optionals,
            currencyCode: moneyInfo.currencyCode,
            selectedInsuranceTier: selectedInsurance?.tier ?? '',
          )
        : _extractFlowSelectedExtras(
            args.selectedExtras,
            args.dataJson,
            args.selected,
            rentalDays,
            moneyInfo.currencyCode,
          );

    return _ResolvedBookingConfirmation(
      bookingId: args.composeResponse.booking_id,
      status: _string(bookingMap['status']).isNotEmpty
          ? _string(bookingMap['status'])
          : 'Confermato',
      rentalCompany: _string(bookingMap['vendor']).isNotEmpty
          ? _string(bookingMap['vendor'])
          : _string(rawBooking['Vendor']),
      rentalDays: rentalDays,
      periodLabel: _buildPeriodLabel(pickupDt, returnDt),
      pickup: _LocationInfo(
        title: _string(pickupLoc?['Name']).isNotEmpty
            ? _string(pickupLoc?['Name'])
            : _string(bookingMap['pick_up_location']),
        address: _formatLocationAddress(pickupLoc),
        dateTimeFormatted: _formatDateTime(pickupDt),
      ),
      dropoff: _LocationInfo(
        title: _string(returnLoc?['Name']).isNotEmpty
            ? _string(returnLoc?['Name'])
            : _string(bookingMap['return_location']),
        address: _formatLocationAddress(returnLoc),
        dateTimeFormatted: _formatDateTime(returnDt),
      ),
      vehicle: _VehicleInfo.fromMap(vehicleMap),
      money: moneyInfo,
      customer: customerInfo,
      drivers: _extractDrivers(args, detail),
      selectedInsurance: selectedInsurance,
      displayedExtras: displayedExtras,
    );
  }

  static Map<String, dynamic>? _firstBookingCreateDataRow(
    Map<String, dynamic> bookingCreate,
  ) {
    final data = bookingCreate['data'];
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    return null;
  }

  static List<dynamic> _resolveOptionals(
    Map<String, dynamic> bookingMap,
    Map<String, dynamic> rawBooking,
    Map<String, dynamic> composePrimaryMap,
  ) {
    final lower = _list(bookingMap['optionals']);
    if (lower != null) return lower;

    final raw = _list(rawBooking['optionals']);
    if (raw != null) return raw;

    final compose = _list(composePrimaryMap['optionals']);
    if (compose != null) return compose;

    return const <dynamic>[];
  }

  static Map<String, dynamic>? _resolveCustomerMap(
    BookingConfirmedArgs args,
    Map<String, dynamic> bookingMap,
    Map<String, dynamic> rawBooking,
  ) {
    if (args.composeResponse.customer_after_update != null &&
        args.composeResponse.customer_after_update!.isNotEmpty) {
      return Map<String, dynamic>.from(
        args.composeResponse.customer_after_update!,
      );
    }

    final detailCustomer =
        args.detailsByInternalId?.customer ?? args.detailsByCode?.customer;
    if (detailCustomer != null && detailCustomer.isNotEmpty) {
      return Map<String, dynamic>.from(detailCustomer);
    }

    final bookingCustomer = _map(bookingMap['customer']);
    if (bookingCustomer != null && bookingCustomer.isNotEmpty) {
      return bookingCustomer;
    }

    final rawCustomer = _map(rawBooking['customer']);
    if (rawCustomer != null && rawCustomer.isNotEmpty) {
      return rawCustomer;
    }

    if (args.composeResponse.customer_before_update != null &&
        args.composeResponse.customer_before_update!.isNotEmpty) {
      return Map<String, dynamic>.from(
        args.composeResponse.customer_before_update!,
      );
    }

    return null;
  }

  static _SelectedInsuranceInfo? _resolveSelectedInsurance(
    List<dynamic> optionals,
    String currencyCode, {
    String? fallbackInsuranceName,
    String? fallbackInsuranceTotalFormatted,
  }) {
    _NormalizedOptional? chosen;

    for (final item in optionals) {
      final option = _NormalizedOptional.fromDynamic(item);
      if (!option.isActive) continue;
      if (!option.isInsurancePackage) continue;

      if (chosen == null) {
        chosen = option;
        continue;
      }

      if (option.insuranceTierPriority > chosen.insuranceTierPriority) {
        chosen = option;
      }
    }

    if (chosen != null) {
      return _SelectedInsuranceInfo(
        tier: chosen.insuranceTier,
        planLabel: chosen.insurancePlanLabel,
        amountLabel: chosen.amount > 0
            ? _formatMoney(chosen.amount, currencyCode)
            : '',
      );
    }

    final fallbackName = _string(fallbackInsuranceName);
    final fallbackAmount = _string(fallbackInsuranceTotalFormatted);
    if (fallbackName.isEmpty && fallbackAmount.isEmpty) {
      return null;
    }

    final fallbackTier = _tierFromText(fallbackName);

    return _SelectedInsuranceInfo(
      tier: fallbackTier,
      planLabel: fallbackName.isNotEmpty
          ? fallbackName
          : (fallbackTier.isNotEmpty ? fallbackTier : 'Copertura'),
      amountLabel: fallbackAmount,
    );
  }

  static String _tierFromText(String text) {
    final upper = text.toUpperCase();
    if (upper.contains('DIAMOND')) return 'DIAMOND';
    if (upper.contains('GOLD')) return 'GOLD';
    if (upper.contains('SILVER')) return 'SILVER';
    return '';
  }

  static List<_DisplayLine> _buildDisplayedExtras({
    required List<dynamic> optionals,
    required String currencyCode,
    required String selectedInsuranceTier,
  }) {
    final lines = <_DisplayLine>[];

    for (final item in optionals) {
      final option = _NormalizedOptional.fromDynamic(item);
      if (!option.isActive) continue;

      if (_shouldHideInsuranceSpecificOption(
        option: option,
        selectedInsuranceTier: selectedInsuranceTier,
      )) {
        continue;
      }

      lines.add(
        _DisplayLine(
          title: option.title,
          subtitle: option.displaySubtitle,
          amountLabel:
              option.amount > 0 ? _formatMoney(option.amount, currencyCode) : '',
          sortOrder: option.sortOrder,
        ),
      );
    }

    lines.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      if (byOrder != 0) return byOrder;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return lines;
  }

  static bool _shouldHideInsuranceSpecificOption({
    required _NormalizedOptional option,
    required String selectedInsuranceTier,
  }) {
    if (!option.isInsuranceSpecific) return false;
    if (option.insuranceTier.isEmpty) return false;

    if (selectedInsuranceTier.isEmpty) {
      return true;
    }

    return option.insuranceTier != selectedInsuranceTier;
  }

  static List<_DisplayLine> _extractFlowSelectedExtras(
    List<InitialExtra> selectedExtras,
    Map<String, dynamic>? dataJson,
    Offer? selected,
    int rentalDays,
    String currencyCode,
  ) {
    final out = <_DisplayLine>[];

    final selectedRaw = selected?.raw;
    final selectedOptionals =
        (selectedRaw != null && selectedRaw['optionals'] is List)
            ? List<dynamic>.from(selectedRaw['optionals'] as List)
            : const <dynamic>[];

    final rootOptionals = (dataJson != null && dataJson['optionals'] is List)
        ? List<dynamic>.from(dataJson['optionals'] as List)
        : const <dynamic>[];

    final allOptionals = <dynamic>[
      ...selectedOptionals,
      ...rootOptionals,
    ];

    for (final extra in selectedExtras) {
      final raw = _findOptionalByCode(extra.code, allOptionals);
      final equip = raw == null
          ? <String, dynamic>{}
          : (_map(raw['Equipment']) ?? <String, dynamic>{});
      final charge = raw == null
          ? <String, dynamic>{}
          : (_map(raw['Charge']) ?? <String, dynamic>{});

      final title = _string(equip['Description']).isNotEmpty
          ? _string(equip['Description'])
          : extra.code;

      final unitAmount = _double(charge['Amount']);
      final multiplier = extra.perDay ? rentalDays : 1;
      final quantity = extra.qty <= 0 ? 1 : extra.qty;
      final total = unitAmount * quantity * multiplier;

      final subtitle = extra.perDay
          ? 'Quantità: $quantity • tariffa giornaliera • $rentalDays giorni'
          : 'Quantità: $quantity';

      out.add(
        _DisplayLine(
          title: title,
          subtitle: subtitle,
          amountLabel: unitAmount > 0 ? _formatMoney(total, currencyCode) : '',
        ),
      );
    }

    return out;
  }

  static Map<String, dynamic>? _findOptionalByCode(
    String code,
    List<dynamic> items,
  ) {
    final wanted = code.trim().toUpperCase();
    for (final item in items) {
      final map = _map(item);
      if (map == null) continue;

      final equip = _map(map['Equipment']) ?? <String, dynamic>{};
      final equipType = _string(equip['EquipType']).toUpperCase();
      final equipCode = _string(equip['Code']).toUpperCase();
      final desc = _string(equip['Description']).toUpperCase();

      if (equipType == wanted || equipCode == wanted || desc == wanted) {
        return map;
      }
    }
    return null;
  }

  static List<_DriverInfo> _extractDrivers(
    BookingConfirmedArgs args,
    ReservationFullDetailsResponse? detail,
  ) {
    final out = <_DriverInfo>[];
    final sameAsCustomer = args.composeResponse.used_customer_as_driver1;
    final setCustomerAsDriver1 =
        args.composeResponse.set_customer_as_driver1_result;
    final customerAfter = args.composeResponse.customer_after_update;

    final customerFullName = [
      _string(customerAfter?['firstName']),
      _string(customerAfter?['lastName']),
    ].where((e) => e.isNotEmpty).join(' ');

    if (sameAsCustomer) {
      out.add(
        _DriverInfo(
          roleLabel: 'Guidatore principale',
          displayName: customerFullName.isNotEmpty
              ? customerFullName
              : (_string(setCustomerAsDriver1?['driver1']).isNotEmpty
                    ? _string(setCustomerAsDriver1?['driver1'])
                    : 'Coincide con l’intestatario'),
          note:
              'Il guidatore principale coincide con l’intestatario della prenotazione.',
        ),
      );
    } else if (_string(detail?.driver1).isNotEmpty ||
        args.composeResponse.driver1_result != null) {
      out.add(
        _DriverInfo(
          roleLabel: 'Guidatore principale',
          displayName: _string(detail?.driver1).isNotEmpty
              ? _string(detail?.driver1)
              : _driverLabelFromMap(args.composeResponse.driver1_result),
        ),
      );
    }

    if (_string(detail?.driver2).isNotEmpty ||
        args.composeResponse.driver2_result != null) {
      out.add(
        _DriverInfo(
          roleLabel: 'Guidatore aggiuntivo 2',
          displayName: _string(detail?.driver2).isNotEmpty
              ? _string(detail?.driver2)
              : _driverLabelFromMap(args.composeResponse.driver2_result),
        ),
      );
    }

    if (_string(detail?.driver3).isNotEmpty ||
        args.composeResponse.driver3_result != null) {
      out.add(
        _DriverInfo(
          roleLabel: 'Guidatore aggiuntivo 3',
          displayName: _string(detail?.driver3).isNotEmpty
              ? _string(detail?.driver3)
              : _driverLabelFromMap(args.composeResponse.driver3_result),
        ),
      );
    }

    return out;
  }

  static String _driverLabelFromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return '-';

    final first = _string(map['firstName']);
    final last = _string(map['lastName']);
    final full = [first, last].where((e) => e.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;

    final generic = _string(map['driver']);
    return generic.isNotEmpty ? generic : '-';
  }

  static Map<String, dynamic>? _findLocationByContext(
    List<dynamic> items,
    String keyword,
  ) {
    for (final item in items) {
      final map = _map(item);
      if (map == null) continue;
      final codeContext = _string(map['CodeContext']).toLowerCase();
      if (codeContext.contains(keyword.toLowerCase())) return map;
    }
    return null;
  }

  static String _formatLocationAddress(Map<String, dynamic>? loc) {
    if (loc == null) return '';

    final address = _map(loc['Address']) ?? <String, dynamic>{};
    final stateProv = _map(address['StateProv']) ?? <String, dynamic>{};

    final parts = <String>[
      _string(address['StreetNmbr']),
      _string(address['PostalCode']),
      _string(address['CityName']),
      _string(stateProv['StateCode']),
      _string(address['CountryName']),
    ].where((e) => e.isNotEmpty).toList();

    return parts.join(' • ');
  }

  static String _buildPeriodLabel(DateTime? pickup, DateTime? dropoff) {
    final pickupText = _formatDateShort(pickup);
    final dropoffText = _formatDateShort(dropoff);

    if (pickupText.isEmpty && dropoffText.isEmpty) return '-';
    if (pickupText.isNotEmpty && dropoffText.isNotEmpty) {
      return '$pickupText → $dropoffText';
    }
    return pickupText.isNotEmpty ? pickupText : dropoffText;
  }

  static DateTime? _parseDateTime(String raw) {
    if (raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static int _computeDays(DateTime? start, DateTime? end) {
    if (start == null || end == null || !end.isAfter(start)) return 1;
    final hours = end.difference(start).inHours;
    return ((hours / 24).ceil()).clamp(1, 365);
  }

  static String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    try {
      return DateFormat('dd/MM/yyyy • HH:mm', 'it_IT').format(dt.toLocal());
    } catch (_) {
      return dt.toIso8601String();
    }
  }

  static String _formatDateShort(DateTime? dt) {
    if (dt == null) return '';
    try {
      return DateFormat('dd/MM/yyyy', 'it_IT').format(dt.toLocal());
    } catch (_) {
      return dt.toIso8601String();
    }
  }

  static String _formatMoney(double amount, String currencyCode) {
    final symbol = _currencySymbol(currencyCode);
    try {
      return NumberFormat.currency(
        locale: 'it_IT',
        symbol: symbol,
      ).format(amount);
    } catch (_) {
      return '$symbol ${amount.toStringAsFixed(2)}';
    }
  }

  static String _currencySymbol(String currencyCode) {
    final normalized = currencyCode.trim().toUpperCase();
    if (normalized.isEmpty || normalized == 'EUR') return '€';
    return normalized;
  }

  static String _string(dynamic v) => v == null ? '' : v.toString().trim();

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(_string(v)) ?? 0;
  }

  static double _double(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(_string(v).replaceAll(',', '.')) ?? 0;
  }

  static bool _bool(dynamic v) {
    if (v is bool) return v;
    final s = _string(v).toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  static Map<String, dynamic>? _map(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  static List<dynamic>? _list(dynamic v) {
    if (v is List) return List<dynamic>.from(v);
    return null;
  }
}

class _LocationInfo {
  final String title;
  final String address;
  final String dateTimeFormatted;

  const _LocationInfo({
    required this.title,
    required this.address,
    required this.dateTimeFormatted,
  });
}

class _VehicleInfo {
  final String code;
  final String brand;
  final String model;
  final String version;
  final String plateNo;
  final String color;
  final String transmission;
  final String fuel;
  final String seats;
  final String km;
  final String displayName;
  final String subtitle;
  final String shortLabel;

  const _VehicleInfo({
    required this.code,
    required this.brand,
    required this.model,
    required this.version,
    required this.plateNo,
    required this.color,
    required this.transmission,
    required this.fuel,
    required this.seats,
    required this.km,
    required this.displayName,
    required this.subtitle,
    required this.shortLabel,
  });

  factory _VehicleInfo.fromMap(Map<String, dynamic> map) {
    final makeModelRaw = map['VehMakeModel'];
    String displayName = '';

    if (makeModelRaw is Map) {
      displayName = _ResolvedBookingConfirmation._string(makeModelRaw['Name']);
    } else if (makeModelRaw is List &&
        makeModelRaw.isNotEmpty &&
        makeModelRaw.first is Map) {
      displayName = _ResolvedBookingConfirmation._string(
        (makeModelRaw.first as Map)['Name'],
      );
    }

    final brand = _ResolvedBookingConfirmation._string(map['brand']);
    final model = _ResolvedBookingConfirmation._string(map['model']);
    final version = _ResolvedBookingConfirmation._string(map['version']);
    final fuelType = _ResolvedBookingConfirmation._string(map['fuelType']);
    final fuel = fuelType.isNotEmpty
        ? fuelType
        : _ResolvedBookingConfirmation._string(map['fuel']);

    final subtitleParts = <String>[
      if (brand.isNotEmpty) brand,
      if (model.isNotEmpty) model,
      if (version.isNotEmpty && version != model) version,
    ];

    final shortLabel = displayName.isNotEmpty
        ? displayName
        : (model.isNotEmpty ? model : brand);

    return _VehicleInfo(
      code: _ResolvedBookingConfirmation._string(map['Code']),
      brand: brand,
      model: model,
      version: version,
      plateNo: _ResolvedBookingConfirmation._string(map['plate_no']),
      color: _ResolvedBookingConfirmation._string(map['color']),
      transmission: _ResolvedBookingConfirmation._string(map['transmission']),
      fuel: fuel,
      seats: _ResolvedBookingConfirmation._string(map['seats']),
      km: _ResolvedBookingConfirmation._string(map['km']),
      displayName: displayName,
      subtitle: subtitleParts.join(' • '),
      shortLabel: shortLabel,
    );
  }
}

class _MoneyInfo {
  final String currencyCode;
  final double total;
  final double vat;
  final double net;
  final List<_PaymentRuleInfo> paymentRules;

  const _MoneyInfo({
    required this.currencyCode,
    required this.total,
    required this.vat,
    required this.net,
    required this.paymentRules,
  });

  factory _MoneyInfo.fromBookingDetail(
    Map<String, dynamic> bookingDetail,
    Map<String, dynamic> rawBooking,
    List<_PaymentRuleInfo> paymentRules,
  ) {
    final estimated = _ResolvedBookingConfirmation._double(
      bookingDetail['estimated_total_amount'] ??
          _map(bookingDetail['total_charge'])?['EstimatedTotalAmount'] ??
          _map(rawBooking['TotalCharge'])?['EstimatedTotalAmount'],
    );

    final rateTotal = _ResolvedBookingConfirmation._double(
      bookingDetail['rate_total_amount'] ??
          _map(bookingDetail['total_charge'])?['RateTotalAmount'] ??
          _map(rawBooking['TotalCharge'])?['RateTotalAmount'],
    );

    final rentalRate =
        _ResolvedBookingConfirmation._map(bookingDetail['rental_rate']) ??
            _ResolvedBookingConfirmation._map(rawBooking['RentalRate']) ??
            <String, dynamic>{};

    final taxAmounts =
        _ResolvedBookingConfirmation._map(rentalRate['TaxAmounts']) ??
            <String, dynamic>{};
    final taxAmount =
        _ResolvedBookingConfirmation._map(taxAmounts['TaxAmount']) ??
            <String, dynamic>{};

    final vat = _ResolvedBookingConfirmation._double(taxAmount['Total']);
    final taxInclusive =
        _ResolvedBookingConfirmation._bool(rentalRate['TaxInclusive']);
    final amountFromRentalRate =
        _ResolvedBookingConfirmation._double(rentalRate['Amount']);

    final total = estimated > 0
        ? estimated
        : (rateTotal > 0 ? rateTotal : amountFromRentalRate);

    final net = total > 0
        ? (taxInclusive
            ? (total - vat).clamp(0, double.infinity).toDouble()
            : total)
        : 0.0;

    final bookingCurrency =
        _ResolvedBookingConfirmation._string(bookingDetail['currency_code']);
    final rateCurrency =
        _ResolvedBookingConfirmation._string(rentalRate['CurrencyCode']);
    final currencyCode =
        bookingCurrency.isNotEmpty ? bookingCurrency : rateCurrency;

    return _MoneyInfo(
      currencyCode: currencyCode,
      total: total,
      vat: vat,
      net: net,
      paymentRules: paymentRules,
    );
  }

  String get currencyLabel =>
      _ResolvedBookingConfirmation._currencySymbol(currencyCode);

  String get totalFormatted =>
      _ResolvedBookingConfirmation._formatMoney(total, currencyCode);

  String get vatFormatted =>
      _ResolvedBookingConfirmation._formatMoney(vat, currencyCode);

  String get netFormatted =>
      _ResolvedBookingConfirmation._formatMoney(net, currencyCode);

  static Map<String, dynamic>? _map(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }
}

class _PaymentRuleInfo {
  final String label;
  final double amount;
  final String currencyCode;
  final String percent;
  final DateTime? dateTime;

  const _PaymentRuleInfo({
    required this.label,
    required this.amount,
    required this.currencyCode,
    required this.percent,
    required this.dateTime,
  });

  static List<_PaymentRuleInfo> fromRaw(dynamic raw) {
    final list = raw is List ? List<dynamic>.from(raw) : const <dynamic>[];
    final out = <_PaymentRuleInfo>[];

    for (final item in list) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);

      final percentRaw = _ResolvedBookingConfirmation._string(map['Percent']);
      out.add(
        _PaymentRuleInfo(
          label: _ResolvedBookingConfirmation._string(map['content']).isNotEmpty
              ? _ResolvedBookingConfirmation._string(map['content'])
              : 'Pagamento',
          amount: _ResolvedBookingConfirmation._double(map['Amount']),
          currencyCode:
              _ResolvedBookingConfirmation._string(map['CurrencyCode']),
          percent: percentRaw.isNotEmpty ? '$percentRaw%' : '',
          dateTime: DateTime.tryParse(
            _ResolvedBookingConfirmation._string(map['DateTime']),
          ),
        ),
      );
    }

    return out;
  }

  String get amountFormatted =>
      _ResolvedBookingConfirmation._formatMoney(amount, currencyCode);

  String get dateTimeFormatted {
    if (dateTime == null) return '';
    try {
      return DateFormat('dd/MM/yyyy • HH:mm', 'it_IT')
          .format(dateTime!.toLocal());
    } catch (_) {
      return dateTime!.toIso8601String();
    }
  }
}

class _CustomerInfo {
  final String fullName;
  final String email;
  final String mobile;
  final String birthDate;
  final String birthPlace;
  final String birthProvince;
  final String street;
  final String num;
  final String city;
  final String zip;
  final String country;
  final String document;
  final String documentNumber;
  final String licenceType;
  final String issueBy;
  final String releaseDate;
  final String expiryDate;

  const _CustomerInfo({
    required this.fullName,
    required this.email,
    required this.mobile,
    required this.birthDate,
    required this.birthPlace,
    required this.birthProvince,
    required this.street,
    required this.num,
    required this.city,
    required this.zip,
    required this.country,
    required this.document,
    required this.documentNumber,
    required this.licenceType,
    required this.issueBy,
    required this.releaseDate,
    required this.expiryDate,
  });

  factory _CustomerInfo.fromMap(Map<String, dynamic> map) {
    final firstName =
        _ResolvedBookingConfirmation._string(map['firstName']).isNotEmpty
            ? _ResolvedBookingConfirmation._string(map['firstName'])
            : _ResolvedBookingConfirmation._string(map['Name']);

    final lastName =
        _ResolvedBookingConfirmation._string(map['lastName']).isNotEmpty
            ? _ResolvedBookingConfirmation._string(map['lastName'])
            : _ResolvedBookingConfirmation._string(map['Surname']);

    return _CustomerInfo(
      fullName: [firstName, lastName].where((e) => e.isNotEmpty).join(' '),
      email: _ResolvedBookingConfirmation._string(map['email']),
      mobile: _ResolvedBookingConfirmation._string(map['mobileNumber']),
      birthDate: _formatSimpleDate(
        _ResolvedBookingConfirmation._string(map['birthDate']),
      ),
      birthPlace: _ResolvedBookingConfirmation._string(map['birthPlace']),
      birthProvince: _ResolvedBookingConfirmation._string(map['birthProvince']),
      street: _ResolvedBookingConfirmation._string(map['street']),
      num: _ResolvedBookingConfirmation._string(map['num']),
      city: _ResolvedBookingConfirmation._string(map['city']),
      zip: _ResolvedBookingConfirmation._string(map['zip']),
      country: _ResolvedBookingConfirmation._string(map['country']),
      document: _ResolvedBookingConfirmation._string(map['document']),
      documentNumber:
          _ResolvedBookingConfirmation._string(map['documentNumber']),
      licenceType: _ResolvedBookingConfirmation._string(map['licenceType']),
      issueBy: _ResolvedBookingConfirmation._string(map['issueBy']),
      releaseDate: _formatSimpleDate(
        _ResolvedBookingConfirmation._string(map['releaseDate']),
      ),
      expiryDate: _formatSimpleDate(
        _ResolvedBookingConfirmation._string(map['expiryDate']),
      ),
    );
  }

  String get birthPlaceSummary {
    final parts = <String>[
      if (birthPlace.isNotEmpty) birthPlace,
      if (birthProvince.isNotEmpty) birthProvince,
    ];
    return parts.join(' • ');
  }

  String get addressSummary {
    final parts = <String>[
      if (street.isNotEmpty) street,
      if (num.isNotEmpty) num,
      if (zip.isNotEmpty) zip,
      if (city.isNotEmpty) city,
      if (country.isNotEmpty) country,
    ];
    return parts.join(' • ');
  }

  String get documentSummary {
    final parts = <String>[
      if (document.isNotEmpty) document,
      if (documentNumber.isNotEmpty) 'N. $documentNumber',
      if (licenceType.isNotEmpty) 'Patente $licenceType',
      if (issueBy.isNotEmpty) 'Rilasciata da $issueBy',
    ];
    return parts.join(' • ');
  }

  static String _formatSimpleDate(String raw) {
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    try {
      return DateFormat('dd/MM/yyyy', 'it_IT').format(dt);
    } catch (_) {
      return raw;
    }
  }
}

class _DriverInfo {
  final String roleLabel;
  final String displayName;
  final String note;

  const _DriverInfo({
    required this.roleLabel,
    required this.displayName,
    this.note = '',
  });
}

class _SelectedInsuranceInfo {
  final String tier;
  final String planLabel;
  final String amountLabel;

  const _SelectedInsuranceInfo({
    required this.tier,
    required this.planLabel,
    required this.amountLabel,
  });
}

class _DisplayLine {
  final String title;
  final String subtitle;
  final String amountLabel;
  final int sortOrder;

  const _DisplayLine({
    required this.title,
    required this.subtitle,
    required this.amountLabel,
    this.sortOrder = 0,
  });
}

class _NormalizedOptional {
  final String title;
  final String equipType;
  final int quantity;
  final bool includedInRate;
  final bool includedInEstTotal;
  final bool selected;
  final bool prepaid;
  final double amount;
  final String normalizedBlob;

  const _NormalizedOptional({
    required this.title,
    required this.equipType,
    required this.quantity,
    required this.includedInRate,
    required this.includedInEstTotal,
    required this.selected,
    required this.prepaid,
    required this.amount,
    required this.normalizedBlob,
  });

  factory _NormalizedOptional.fromDynamic(dynamic raw) {
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final charge = map['Charge'] is Map
        ? Map<String, dynamic>.from(map['Charge'] as Map)
        : <String, dynamic>{};
    final equip = map['Equipment'] is Map
        ? Map<String, dynamic>.from(map['Equipment'] as Map)
        : <String, dynamic>{};

    final title =
        _ResolvedBookingConfirmation._string(equip['Description']).isNotEmpty
            ? _ResolvedBookingConfirmation._string(equip['Description'])
            : _ResolvedBookingConfirmation._string(charge['Description']);

    final equipType = _ResolvedBookingConfirmation._string(
      equip['EquipType'] ?? equip['Code'],
    ).toUpperCase();

    final quantity = _ResolvedBookingConfirmation._int(
      equip['Quantity'] ?? map['Quantity'] ?? charge['Quantity'],
    );

    final includedInRate =
        _ResolvedBookingConfirmation._bool(charge['IncludedInRate']);
    final includedInEstTotal =
        _ResolvedBookingConfirmation._bool(charge['IncludedInEstTotalInd']);
    final selected = _ResolvedBookingConfirmation._bool(
      equip['Selected'] ?? map['Selected'] ?? charge['Selected'],
    );
    final prepaid = _ResolvedBookingConfirmation._bool(
      equip['Prepaid'] ?? map['Prepaid'] ?? charge['Prepaid'],
    );
    final amount = _ResolvedBookingConfirmation._double(charge['Amount']);

    final normalizedBlob = [
      title,
      equipType,
      _ResolvedBookingConfirmation._string(charge['Description']),
    ].join(' ').toUpperCase();

    return _NormalizedOptional(
      title: title,
      equipType: equipType,
      quantity: quantity,
      includedInRate: includedInRate,
      includedInEstTotal: includedInEstTotal,
      selected: selected,
      prepaid: prepaid,
      amount: amount,
      normalizedBlob: normalizedBlob,
    );
  }

  bool get isActive =>
      quantity > 0 ||
      selected ||
      prepaid ||
      includedInRate ||
      includedInEstTotal;

  bool get isInsurancePackage =>
      equipType == 'SILVER' || equipType == 'GOLD' || equipType == 'DIAMOND';

  bool get isInsurancePenalty =>
      equipType == 'TP_SILVER' ||
      equipType == 'TP_GOLD' ||
      equipType == 'TP_DIAMOND' ||
      equipType == 'CDW_SILVER' ||
      equipType == 'CDW_GOLD' ||
      equipType == 'CDW_DIAMOND';

  bool get isInsuranceSpecific => isInsurancePackage || isInsurancePenalty;

  String get insuranceTier {
    if (equipType.contains('DIAMOND') || normalizedBlob.contains('DIAMOND')) {
      return 'DIAMOND';
    }
    if (equipType.contains('GOLD') || normalizedBlob.contains('GOLD')) {
      return 'GOLD';
    }
    if (equipType.contains('SILVER') || normalizedBlob.contains('SILVER')) {
      return 'SILVER';
    }
    return '';
  }

  int get insuranceTierPriority {
    switch (insuranceTier) {
      case 'DIAMOND':
        return 3;
      case 'GOLD':
        return 2;
      case 'SILVER':
        return 1;
      default:
        return 0;
    }
  }

  String get insurancePlanLabel {
    switch (insuranceTier) {
      case 'DIAMOND':
        return 'DIAMOND';
      case 'GOLD':
        return 'GOLD';
      case 'SILVER':
        return 'SILVER';
      default:
        return title;
    }
  }

  String get displaySubtitle {
    final parts = <String>[];
    if (quantity > 0) {
      parts.add('Quantità: $quantity');
    } else if (includedInRate || includedInEstTotal) {
      parts.add('Incluso nella prenotazione');
    }
    return parts.join(' • ');
  }

  int get sortOrder {
    if (equipType == 'KM_ILL') return 10;
    if (equipType == 'CDW') return 20;
    if (equipType == 'TP') return 30;
    if (isInsurancePenalty) return 40;
    if (!isInsurancePackage && amount > 0) return 50;
    if (isInsurancePackage) return 60;
    if (amount <= 0) return 70;
    return 80;
  }
}

class _NoGlow extends ScrollBehavior {
  const _NoGlow();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

List<_PaymentRuleInfo> _parsePaymentRules(dynamic raw) {
  return _PaymentRuleInfo.fromRaw(raw);
}