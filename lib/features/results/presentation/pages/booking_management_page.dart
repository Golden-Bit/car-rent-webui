import 'dart:convert';

import 'package:car_rent_webui/app.dart';
import 'package:car_rent_webui/car_rent_sdk/sdk.dart';
import 'package:car_rent_webui/core/navigation/web_redirect.dart';
import 'package:car_rent_webui/core/widgets/top_nav_bar.dart';
import 'package:car_rent_webui/features/search/data/myrent_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

const String kBookingManagementHomeUrl = 'https://www.rentalpremium.it/';

const Color _kBrand = Color(0xFFFF5A1F);
const Color _kBrandDark = Color(0xFFE2470C);
const Color _kCard = Color(0xFFF7F7F8);
const Color _kStroke = Color(0xFFE6E6E6);
const Color _kTxtMuted = Color(0xFF6B6B6B);
const Color _kSuccessBg = Color(0xFFF0FFF7);
const Color _kSuccessBorder = Color(0xFFD7F2E1);
const Color _kSuccessText = Color(0xFF2E9E5B);
const Color _kInfoBg = Color(0xFFFFF7F2);
const Color _kInfoBorder = Color(0xFFFFD8C8);
const double _kRadius = 16;
const double _kGutter = 18;

class BookingManagementPage extends StatefulWidget {
  static const routeName = '/booking_management';

  const BookingManagementPage({super.key});

  @override
  State<BookingManagementPage> createState() => _BookingManagementPageState();
}

class _BookingManagementPageState extends State<BookingManagementPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _bookingCodeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _reservationDateController =
      TextEditingController();

  late final MyrentRepository _repository;

  bool _submitted = false;
  bool _isLoading = false;

  String? _friendlyMessage;
  String? _errorMessage;
  ReservationFullDetailsResponse? _result;

  @override
  void initState() {
    super.initState();
    _repository = MyrentRepository();
  }

  @override
  void dispose() {
    _bookingCodeController.dispose();
    _emailController.dispose();
    _reservationDateController.dispose();
    _repository.close();
    super.dispose();
  }

  Future<void> _pickReservationDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(primary: _kBrandDark),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    final yyyy = picked.year.toString().padLeft(4, '0');
    final mm = picked.month.toString().padLeft(2, '0');
    final dd = picked.day.toString().padLeft(2, '0');

    _reservationDateController.text = '$yyyy-$mm-$dd';
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _submitted = true;
      _isLoading = true;
      _friendlyMessage = null;
      _errorMessage = null;
      _result = null;
    });

    try {
      final response = await _repository.getReservationByCode(
        reservationCode: _bookingCodeController.text.trim(),
        customerEmail: _emailController.text.trim(),
        reservationDate: _reservationDateController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _result = response;
        _friendlyMessage = 'Prenotazione trovata con successo.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      final message = _extractApiMessage(e);

      setState(() {
        _isLoading = false;
        _result = null;

        if (_looksLikeNotFound(e, message)) {
          _friendlyMessage =
              'Nessuna prenotazione trovata con i dati inseriti. Verifica riferimento, email e data prenotazione.';
          _errorMessage = null;
        } else {
          _friendlyMessage = null;
          _errorMessage = message;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _result = null;
        _friendlyMessage = null;
        _errorMessage =
            'Si è verificato un errore durante il recupero della prenotazione.\n$e';
      });
    }
  }

  void _onNewSearch() {
    setState(() {
      _submitted = false;
      _isLoading = false;
      _friendlyMessage = null;
      _errorMessage = null;
      _result = null;
      _bookingCodeController.clear();
      _emailController.clear();
      _reservationDateController.clear();
    });
  }

  bool _looksLikeNotFound(ApiException e, String message) {
    final raw = '${e.body} $message'.toLowerCase();

    return e.statusCode == 404 ||
        raw.contains('reservation non trovata') ||
        raw.contains('prenotazione non trovata') ||
        raw.contains('nessuna reservation') ||
        raw.contains('nessuna prenotazione') ||
        raw.contains('not found');
  }

  String _extractApiMessage(ApiException e) {
    try {
      final decoded = jsonDecode(e.body);

      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }

        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }

        final error = decoded['error'];
        if (error is String && error.trim().isNotEmpty) {
          return error.trim();
        }

        final errors = decoded['errors'];
        if (errors is Map<String, dynamic>) {
          final err = errors['Error'];
          if (err is Map<String, dynamic>) {
            final shortText = err['ShortText'];
            if (shortText is String && shortText.trim().isNotEmpty) {
              return shortText.trim();
            }
          }
        }

        return const JsonEncoder.withIndent('  ').convert(decoded);
      }

      return e.body;
    } catch (_) {
      return e.body.isNotEmpty
          ? e.body
          : 'Errore API (${e.statusCode}) durante il recupero della prenotazione.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final showTopBar = AppUiFlags.showAppBarOf(context);
    final resolved = _result == null
        ? null
        : _ResolvedManagedBooking.fromResponse(_result!);

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
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSearchCard(context),
                      if (_submitted) ...[
                        const SizedBox(height: 18),
                        _buildSearchFeedback(context),
                      ],
                      if (resolved != null) ...[
                        const SizedBox(height: 18),
                        _buildResultHero(context, resolved),
                        const SizedBox(height: 18),
                        _buildResponsiveSectionGrid(
                          constraints.maxWidth,
                          [
                            _buildOverviewSection(context, resolved),
                            _buildPickupSection(context, resolved),
                            _buildDropoffSection(context, resolved),
                            _buildVehicleSection(context, resolved),
                            _buildAmountsSection(context, resolved),
                            _buildCustomerSection(context, resolved),
                            _buildDriversSection(context, resolved),
                            _buildSelectedExtrasSection(context, resolved),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _onNewSearch,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Nuova ricerca'),
                            style: TextButton.styleFrom(
                              foregroundColor: _kBrandDark,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildSearchCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kStroke),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            color: Color(0x08000000),
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gestione prenotazioni',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Inserisci riferimento prenotazione, email del cliente e data prenotazione per recuperare i dettagli del noleggio.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _kTxtMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 960;
                final medium = constraints.maxWidth >= 640;

                if (wide) {
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildBookingCodeField()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildEmailField()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildReservationDateField()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isLoading ? null : _onSubmit,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.search),
                              label: Text(
                                _isLoading
                                    ? 'Ricerca in corso...'
                                    : 'Recupera dettagli prenotazione',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: _kBrandDark,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                if (medium) {
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildBookingCodeField()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildEmailField()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildReservationDateField(),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _onSubmit,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.search),
                          label: Text(
                            _isLoading
                                ? 'Ricerca in corso...'
                                : 'Recupera dettagli prenotazione',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _kBrandDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle:
                                const TextStyle(fontWeight: FontWeight.w700),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    _buildBookingCodeField(),
                    const SizedBox(height: 16),
                    _buildEmailField(),
                    const SizedBox(height: 16),
                    _buildReservationDateField(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _onSubmit,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.search),
                        label: Text(
                          _isLoading
                              ? 'Ricerca in corso...'
                              : 'Recupera dettagli prenotazione',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _kBrandDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.w700),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCodeField() {
    return TextFormField(
      controller: _bookingCodeController,
      decoration: _fieldDecoration(
        labelText: 'Riferimento prenotazione',
        hintText: 'Es. SUL 6398 TESTDOGMA',
        icon: Icons.confirmation_number_outlined,
      ),
      textInputAction: TextInputAction.next,
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) {
          return 'Inserisci il riferimento prenotazione.';
        }
        if (text.length < 5) {
          return 'Il riferimento sembra troppo corto.';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: _fieldDecoration(
        labelText: 'Email cliente',
        hintText: 'esempio@email.com',
        icon: Icons.email_outlined,
      ),
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) {
          return 'Inserisci l’email del cliente.';
        }
        final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
        if (!emailRegex.hasMatch(text)) {
          return 'Inserisci un indirizzo email valido.';
        }
        return null;
      },
    );
  }

  Widget _buildReservationDateField() {
    return TextFormField(
      controller: _reservationDateController,
      readOnly: true,
      onTap: _pickReservationDate,
      decoration: _fieldDecoration(
        labelText: 'Data prenotazione',
        hintText: 'YYYY-MM-DD',
        icon: Icons.calendar_today_outlined,
      ).copyWith(
        suffixIcon: IconButton(
          onPressed: _pickReservationDate,
          icon: const Icon(Icons.date_range),
        ),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) {
          return 'Seleziona la data prenotazione.';
        }
        final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
        if (!dateRegex.hasMatch(text)) {
          return 'La data deve essere nel formato YYYY-MM-DD.';
        }
        return null;
      },
    );
  }

  InputDecoration _fieldDecoration({
    required String labelText,
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kStroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kStroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kBrandDark, width: 1.5),
      ),
    );
  }

  Widget _buildSearchFeedback(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sto cercando la prenotazione corrispondente ai dati inseriti...',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    if (_friendlyMessage != null && _result == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.amber.shade800),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _friendlyMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.amber.shade900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null && _result == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.red.shade900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildResultHero(
    BuildContext context,
    _ResolvedManagedBooking booking,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kSuccessBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kSuccessBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: _kSuccessText, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Prenotazione trovata',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                ),
              ),
              _statusBadge(booking.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Di seguito trovi il riepilogo completo della prenotazione con sezioni espandibili. Puoi aprire solo quelle che ti interessano.',
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
                value: booking.bookingId,
              ),
              _heroChip(
                icon: Icons.calendar_month_outlined,
                label: 'Periodo',
                value: booking.periodLabel,
              ),
              _heroChip(
                icon: Icons.euro_outlined,
                label: 'Totale',
                value: booking.money.totalFormatted,
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
                  backgroundColor: _kBrandDark,
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
                  booking.bookingId,
                  success: 'Riferimento prenotazione copiato',
                ),
                icon: const Icon(Icons.copy),
                label: const Text('Copia riferimento'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                onPressed: _onNewSearch,
                icon: const Icon(Icons.refresh),
                label: const Text('Nuova ricerca'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSection(
    BuildContext context,
    _ResolvedManagedBooking booking,
  ) {
    return _sectionCard(
      id: 'overview',
      title: 'Riepilogo del noleggio',
      icon: Icons.receipt_long_outlined,
      subtitle: 'Informazioni essenziali sulla prenotazione confermata.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;
          final itemWidth =
              isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;

          final items = [
            _overviewTile(
              'Società di noleggio',
              booking.rentalCompany.isEmpty ? '-' : booking.rentalCompany,
              Icons.storefront_outlined,
            ),
            _overviewTile(
              'Durata',
              '${booking.rentalDays} ${booking.rentalDays == 1 ? 'giorno' : 'giorni'}',
              Icons.timelapse_outlined,
            ),
            _overviewTile(
              'Veicolo',
              booking.vehicle.shortLabel.isEmpty
                  ? '-'
                  : booking.vehicle.shortLabel,
              Icons.directions_car_outlined,
            ),
            _overviewTile(
              'Importo totale',
              booking.money.totalFormatted,
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
    _ResolvedManagedBooking booking,
  ) {
    return _sectionCard(
      id: 'pickup',
      title: 'Ritiro',
      icon: Icons.login_rounded,
      subtitle: 'Luogo e data di inizio noleggio.',
      child: _buildLocationContent(context, booking.pickup),
    );
  }

  Widget _buildDropoffSection(
    BuildContext context,
    _ResolvedManagedBooking booking,
  ) {
    return _sectionCard(
      id: 'dropoff',
      title: 'Riconsegna',
      icon: Icons.logout_rounded,
      subtitle: 'Luogo e data di fine noleggio.',
      child: _buildLocationContent(context, booking.dropoff),
    );
  }

  Widget _buildLocationContent(
    BuildContext context,
    _ManagedLocationInfo location,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          location.title.isEmpty ? '-' : location.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        if (location.address.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            location.address,
            style: const TextStyle(
              color: _kTxtMuted,
              height: 1.45,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kStroke),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule, color: _kBrandDark, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  location.dateTimeFormatted.isEmpty
                      ? '-'
                      : location.dateTimeFormatted,
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
    _ResolvedManagedBooking booking,
  ) {
    final vehicle = booking.vehicle;

    return _sectionCard(
      id: 'vehicle',
      title: 'Veicolo assegnato',
      icon: Icons.directions_car_filled_outlined,
      subtitle: 'Dettagli del veicolo risultante in prenotazione.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (vehicle.displayName.isNotEmpty)
            Text(
              vehicle.displayName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          if (vehicle.subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              vehicle.subtitle,
              style: const TextStyle(color: _kTxtMuted, height: 1.45),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (vehicle.transmission.isNotEmpty)
                _specChip(Icons.settings, vehicle.transmission),
              if (vehicle.fuel.isNotEmpty)
                _specChip(Icons.local_gas_station_outlined, vehicle.fuel),
              if (vehicle.seats.isNotEmpty)
                _specChip(
                  Icons.event_seat_outlined,
                  '${vehicle.seats} posti',
                ),
              if (vehicle.km.isNotEmpty)
                _specChip(Icons.speed_outlined, '${vehicle.km} km'),
            ],
          ),
          const SizedBox(height: 16),
          if (vehicle.code.isNotEmpty) _infoRow('Codice veicolo', vehicle.code),
          if (vehicle.plateNo.isNotEmpty) _infoRow('Targa', vehicle.plateNo),
          if (vehicle.color.isNotEmpty) _infoRow('Colore', vehicle.color),
          if (vehicle.version.isNotEmpty && vehicle.version != vehicle.model)
            _infoRow('Versione', vehicle.version),
        ],
      ),
    );
  }

  Widget _buildAmountsSection(
    BuildContext context,
    _ResolvedManagedBooking booking,
  ) {
    final money = booking.money;

    return _sectionCard(
      id: 'amounts',
      title: 'Importi',
      icon: Icons.payments_outlined,
      subtitle: 'Totale e dettagli economici disponibili.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kInfoBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kInfoBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Totale prenotazione',
                  style: TextStyle(
                    color: _kTxtMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  money.totalFormatted,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: _kBrandDark,
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
    _ResolvedManagedBooking booking,
  ) {
    final customer = booking.customer;

    return _sectionCard(
      id: 'customer',
      title: 'Intestatario prenotazione',
      icon: Icons.person_outline,
      subtitle: 'Dati anagrafici e recapiti associati alla prenotazione.',
      child: customer == null
          ? const Text(
              'Le informazioni dell’intestatario non sono disponibili.',
              style: TextStyle(color: _kTxtMuted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.fullName.isEmpty ? '-' : customer.fullName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 14),
                if (customer.email.isNotEmpty) _infoRow('E-mail', customer.email),
                if (customer.mobile.isNotEmpty)
                  _infoRow('Telefono', customer.mobile),
                if (customer.birthDate.isNotEmpty)
                  _infoRow('Data di nascita', customer.birthDate),
                if (customer.birthPlaceSummary.isNotEmpty)
                  _infoRow('Luogo di nascita', customer.birthPlaceSummary),
                if (customer.addressSummary.isNotEmpty)
                  _infoRow('Indirizzo', customer.addressSummary),
                if (customer.documentSummary.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Documento e patente',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  _infoRow('Dettagli', customer.documentSummary),
                  if (customer.releaseDate.isNotEmpty)
                    _infoRow('Rilascio', customer.releaseDate),
                  if (customer.expiryDate.isNotEmpty)
                    _infoRow('Scadenza', customer.expiryDate),
                ],
              ],
            ),
    );
  }

  Widget _buildDriversSection(
    BuildContext context,
    _ResolvedManagedBooking booking,
  ) {
    return _sectionCard(
      id: 'drivers',
      title: 'Guidatori',
      icon: Icons.badge_outlined,
      subtitle: 'Guidatore principale ed eventuali guidatori aggiuntivi.',
      child: booking.drivers.isEmpty
          ? const Text(
              'Non risultano guidatori aggiuntivi o dettagli specifici dei guidatori.',
              style: TextStyle(color: _kTxtMuted),
            )
          : Column(
              children: booking.drivers
                  .map(
                    (driver) => Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kStroke),
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
                            driver.displayName.isEmpty ? '-' : driver.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (driver.note.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              driver.note,
                              style: const TextStyle(
                                color: _kTxtMuted,
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
    _ResolvedManagedBooking booking,
  ) {
    final insurance = booking.selectedInsurance;

    return _sectionCard(
      id: 'selected_extras',
      title: 'Extra richiesti',
      icon: Icons.add_shopping_cart_outlined,
      subtitle: 'Servizi risultanti attivi nella prenotazione.',
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
          if (booking.displayedExtras.isEmpty)
            const Text(
              'Non risultano extra attivi nella prenotazione.',
              style: TextStyle(color: _kTxtMuted),
            )
          else
            ...booking.displayedExtras.map(
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
    final cardWidth = useTwoColumns ? (width - _kGutter) / 2 : width;

    return Wrap(
      spacing: _kGutter,
      runSpacing: _kGutter,
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
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: _kStroke),
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
          key: PageStorageKey<String>('booking_mgmt_section_$id'),
          initiallyExpanded: false,
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
              color: _kTxtMuted,
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
        border: Border.all(color: _kStroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _kBrandDark),
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
        color: emphasize ? _kInfoBg : _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: emphasize ? _kInfoBorder : _kStroke,
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
              border: Border.all(color: _kStroke),
            ),
            child: Icon(
              icon,
              color: emphasize ? _kBrandDark : Colors.black87,
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
                    color: _kTxtMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: emphasize ? _kBrandDark : Colors.black87,
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
        color: _kCard,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kStroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _kBrandDark),
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
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kStroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: _kBrandDark, size: 18),
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
                    style: const TextStyle(color: _kTxtMuted, height: 1.35),
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
        color: _kBrand.withOpacity(.10),
        shape: BoxShape.circle,
        border: Border.all(color: _kStroke),
      ),
      child: Icon(icon, color: _kBrandDark),
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
          color: isConfirmed ? const Color(0xFF2E9E5B) : _kBrandDark,
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
                color: _kTxtMuted,
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
    if (kBookingManagementHomeUrl.trim().isNotEmpty) {
      await redirectToUrlSameTab(kBookingManagementHomeUrl);
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

class _ResolvedManagedBooking {
  final String bookingId;
  final String status;
  final String rentalCompany;
  final int rentalDays;
  final String periodLabel;
  final _ManagedLocationInfo pickup;
  final _ManagedLocationInfo dropoff;
  final _ManagedVehicleInfo vehicle;
  final _ManagedMoneyInfo money;
  final _ManagedCustomerInfo? customer;
  final List<_ManagedDriverInfo> drivers;
  final _SelectedInsuranceInfo? selectedInsurance;
  final List<_ManagedDisplayLine> displayedExtras;

  const _ResolvedManagedBooking({
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

  factory _ResolvedManagedBooking.fromResponse(
    ReservationFullDetailsResponse response,
  ) {
    final root = response.toJson();
    final bookingMap = _map(root['booking_detail']) ?? <String, dynamic>{};
    final rawBooking = _map(bookingMap['raw']) ?? <String, dynamic>{};

    final vehicleMap = _resolveVehicleMap(bookingMap, rawBooking);
    final locationDetails = _resolveLocationDetails(bookingMap, rawBooking);
    final optionals = _resolveOptionals(bookingMap, rawBooking);

    final pickupLoc = _findLocationByContext(locationDetails, 'pickup');
    final returnLoc = _findLocationByContext(locationDetails, 'return');

    final pickupRaw = _string(
      bookingMap['pick_up_date_time'] ?? rawBooking['PickUpDateTime'],
    );
    final dropoffRaw = _string(
      bookingMap['return_date_time'] ?? rawBooking['ReturnDateTime'],
    );

    final pickupDate = _parseDateTime(pickupRaw);
    final dropoffDate = _parseDateTime(dropoffRaw);
    final rentalDays = _computeDays(pickupDate, dropoffDate);

    final customerMap = _resolveCustomerMap(root, bookingMap, rawBooking);
    final customer =
        customerMap == null ? null : _ManagedCustomerInfo.fromMap(customerMap);

    final money = _ManagedMoneyInfo.fromMaps(bookingMap, rawBooking);
    final selectedInsurance =
        _resolveSelectedInsurance(optionals, money.currencyCode);

    return _ResolvedManagedBooking(
      bookingId: _string(root['booking_id']).isNotEmpty
          ? _string(root['booking_id'])
          : _string(bookingMap['id']),
      status: _string(bookingMap['status']).isNotEmpty
          ? _string(bookingMap['status'])
          : 'Confermato',
      rentalCompany: _string(bookingMap['vendor']).isNotEmpty
          ? _string(bookingMap['vendor'])
          : _string(rawBooking['Vendor']),
      rentalDays: rentalDays,
      periodLabel: _buildPeriodLabel(pickupDate, dropoffDate),
      pickup: _ManagedLocationInfo(
        title: _string(pickupLoc?['Name']).isNotEmpty
            ? _string(pickupLoc?['Name'])
            : _string(bookingMap['pick_up_location']),
        address: _formatLocationAddress(pickupLoc),
        dateTimeFormatted: _formatDateTime(pickupDate),
      ),
      dropoff: _ManagedLocationInfo(
        title: _string(returnLoc?['Name']).isNotEmpty
            ? _string(returnLoc?['Name'])
            : _string(bookingMap['return_location']),
        address: _formatLocationAddress(returnLoc),
        dateTimeFormatted: _formatDateTime(dropoffDate),
      ),
      vehicle: _ManagedVehicleInfo.fromMap(
        vehicleMap,
        fallbackCode: _string(bookingMap['vehicle_code']),
        fallbackMakeModel: _string(bookingMap['vehicle_make_model']),
        fallbackBrand: _string(bookingMap['vehicle_brand']),
        fallbackModel: _string(bookingMap['vehicle_model']),
        fallbackPlate: _string(bookingMap['vehicle_plate_no']),
      ),
      money: money,
      customer: customer,
      drivers: _extractDrivers(root),
      selectedInsurance: selectedInsurance,
      displayedExtras: _buildDisplayedExtras(
        optionals: optionals,
        currencyCode: money.currencyCode,
        selectedInsuranceTier: selectedInsurance?.tier ?? '',
      ),
    );
  }

  static Map<String, dynamic> _resolveVehicleMap(
    Map<String, dynamic> bookingMap,
    Map<String, dynamic> rawBooking,
  ) {
    final lower = _map(bookingMap['vehicle']);
    if (lower != null) return lower;

    final upper = _map(rawBooking['Vehicle']);
    if (upper != null) return upper;

    return <String, dynamic>{};
  }

  static List<dynamic> _resolveLocationDetails(
    Map<String, dynamic> bookingMap,
    Map<String, dynamic> rawBooking,
  ) {
    final lower = _list(bookingMap['location_details']);
    if (lower != null) return lower;

    final upper = _list(rawBooking['LocationDetails']);
    if (upper != null) return upper;

    return const <dynamic>[];
  }

  static List<dynamic> _resolveOptionals(
    Map<String, dynamic> bookingMap,
    Map<String, dynamic> rawBooking,
  ) {
    final lower = _list(bookingMap['optionals']);
    if (lower != null) return lower;

    final upper = _list(rawBooking['optionals']);
    if (upper != null) return upper;

    return const <dynamic>[];
  }

  static Map<String, dynamic>? _resolveCustomerMap(
    Map<String, dynamic> root,
    Map<String, dynamic> bookingMap,
    Map<String, dynamic> rawBooking,
  ) {
    final rootCustomer = _map(root['customer']);
    if (rootCustomer != null && rootCustomer.isNotEmpty) {
      return rootCustomer;
    }

    final detailCustomer = _map(bookingMap['customer']);
    if (detailCustomer != null && detailCustomer.isNotEmpty) {
      return detailCustomer;
    }

    final rawCustomer = _map(rawBooking['customer']);
    if (rawCustomer != null && rawCustomer.isNotEmpty) {
      return rawCustomer;
    }

    return null;
  }

  static List<_ManagedDriverInfo> _extractDrivers(Map<String, dynamic> root) {
    final out = <_ManagedDriverInfo>[];

    final usedCustomerAsDriver1 = _bool(root['used_customer_as_driver1']);
    final driverSetup = _map(root['set_customer_as_driver1_result']);
    final customerName = [
      _string(root['customer_first_name']),
      _string(root['customer_last_name']),
    ].where((e) => e.isNotEmpty).join(' ');

    final driver1 = _string(root['driver1']).isNotEmpty
        ? _string(root['driver1'])
        : _string(driverSetup?['driver1']);
    final driver2 = _string(root['driver2']).isNotEmpty
        ? _string(root['driver2'])
        : _string(driverSetup?['driver2']);
    final driver3 = _string(root['driver3']).isNotEmpty
        ? _string(root['driver3'])
        : _string(driverSetup?['driver3']);

    if (usedCustomerAsDriver1 || driver1.isNotEmpty) {
      out.add(
        _ManagedDriverInfo(
          roleLabel: 'Guidatore principale',
          displayName: driver1.isNotEmpty
              ? _normalizeDriverLabel(driver1)
              : (customerName.isNotEmpty
                  ? customerName
                  : 'Coincide con l’intestatario'),
          note: usedCustomerAsDriver1
              ? 'Il guidatore principale coincide con l’intestatario della prenotazione.'
              : '',
        ),
      );
    }

    if (driver2.isNotEmpty) {
      out.add(
        _ManagedDriverInfo(
          roleLabel: 'Guidatore aggiuntivo 2',
          displayName: _normalizeDriverLabel(driver2),
        ),
      );
    }

    if (driver3.isNotEmpty) {
      out.add(
        _ManagedDriverInfo(
          roleLabel: 'Guidatore aggiuntivo 3',
          displayName: _normalizeDriverLabel(driver3),
        ),
      );
    }

    return out;
  }

  static String _normalizeDriverLabel(String raw) {
    final cleaned =
        raw.replaceAll('/', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isEmpty ? '-' : cleaned;
  }

  static _SelectedInsuranceInfo? _resolveSelectedInsurance(
    List<dynamic> optionals,
    String currencyCode,
  ) {
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

    if (chosen == null) return null;

    return _SelectedInsuranceInfo(
      tier: chosen.insuranceTier,
      planLabel: chosen.insurancePlanLabel,
      amountLabel: chosen.amount > 0
          ? _formatMoney(chosen.amount, currencyCode)
          : '',
    );
  }

  static List<_ManagedDisplayLine> _buildDisplayedExtras({
    required List<dynamic> optionals,
    required String currencyCode,
    required String selectedInsuranceTier,
  }) {
    final lines = <_ManagedDisplayLine>[];

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
        _ManagedDisplayLine(
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

class _ManagedLocationInfo {
  final String title;
  final String address;
  final String dateTimeFormatted;

  const _ManagedLocationInfo({
    required this.title,
    required this.address,
    required this.dateTimeFormatted,
  });
}

class _ManagedVehicleInfo {
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

  const _ManagedVehicleInfo({
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

  factory _ManagedVehicleInfo.fromMap(
    Map<String, dynamic> map, {
    required String fallbackCode,
    required String fallbackMakeModel,
    required String fallbackBrand,
    required String fallbackModel,
    required String fallbackPlate,
  }) {
    final makeModelRaw = map['VehMakeModel'];
    String displayName = '';

    if (makeModelRaw is Map) {
      displayName = _ResolvedManagedBooking._string(makeModelRaw['Name']);
    } else if (makeModelRaw is List &&
        makeModelRaw.isNotEmpty &&
        makeModelRaw.first is Map) {
      displayName = _ResolvedManagedBooking._string(
        (makeModelRaw.first as Map)['Name'],
      );
    }

    final brand = _ResolvedManagedBooking._string(map['brand']).isNotEmpty
        ? _ResolvedManagedBooking._string(map['brand'])
        : fallbackBrand;
    final model = _ResolvedManagedBooking._string(map['model']).isNotEmpty
        ? _ResolvedManagedBooking._string(map['model'])
        : fallbackModel;
    final version = _ResolvedManagedBooking._string(map['version']);
    final fuelType = _ResolvedManagedBooking._string(map['fuelType']);
    final fuel = fuelType.isNotEmpty
        ? fuelType
        : _ResolvedManagedBooking._string(map['fuel']);

    if (displayName.isEmpty) {
      displayName = fallbackMakeModel;
    }

    final subtitleParts = <String>[
      if (brand.isNotEmpty) brand,
      if (model.isNotEmpty) model,
      if (version.isNotEmpty && version != model) version,
    ];

    final shortLabel = displayName.isNotEmpty
        ? displayName
        : (model.isNotEmpty ? model : brand);

    return _ManagedVehicleInfo(
      code: _ResolvedManagedBooking._string(map['Code']).isNotEmpty
          ? _ResolvedManagedBooking._string(map['Code'])
          : fallbackCode,
      brand: brand,
      model: model,
      version: version,
      plateNo: _ResolvedManagedBooking._string(map['plate_no']).isNotEmpty
          ? _ResolvedManagedBooking._string(map['plate_no'])
          : fallbackPlate,
      color: _ResolvedManagedBooking._string(map['color']),
      transmission: _ResolvedManagedBooking._string(map['transmission']),
      fuel: fuel,
      seats: _ResolvedManagedBooking._string(map['seats']),
      km: _ResolvedManagedBooking._string(map['km']),
      displayName: displayName,
      subtitle: subtitleParts.join(' • '),
      shortLabel: shortLabel,
    );
  }
}

class _ManagedMoneyInfo {
  final String currencyCode;
  final double total;
  final double vat;
  final double net;

  const _ManagedMoneyInfo({
    required this.currencyCode,
    required this.total,
    required this.vat,
    required this.net,
  });

  factory _ManagedMoneyInfo.fromMaps(
    Map<String, dynamic> bookingMap,
    Map<String, dynamic> rawBooking,
  ) {
    final estimated = _ResolvedManagedBooking._double(
      bookingMap['estimated_total_amount'] ??
          _map(bookingMap['total_charge'])?['EstimatedTotalAmount'] ??
          _map(rawBooking['TotalCharge'])?['EstimatedTotalAmount'],
    );

    final rateTotal = _ResolvedManagedBooking._double(
      bookingMap['rate_total_amount'] ??
          _map(bookingMap['total_charge'])?['RateTotalAmount'] ??
          _map(rawBooking['TotalCharge'])?['RateTotalAmount'],
    );

    final rentalRate =
        _ResolvedManagedBooking._map(bookingMap['rental_rate']) ??
            _ResolvedManagedBooking._map(rawBooking['RentalRate']) ??
            <String, dynamic>{};

    final taxAmounts =
        _ResolvedManagedBooking._map(rentalRate['TaxAmounts']) ??
            <String, dynamic>{};
    final taxAmount =
        _ResolvedManagedBooking._map(taxAmounts['TaxAmount']) ??
            <String, dynamic>{};

    final vat = _ResolvedManagedBooking._double(taxAmount['Total']);
    final taxInclusive =
        _ResolvedManagedBooking._bool(rentalRate['TaxInclusive']);
    final amountFromRentalRate =
        _ResolvedManagedBooking._double(rentalRate['Amount']);

    final total = estimated > 0
        ? estimated
        : (rateTotal > 0 ? rateTotal : amountFromRentalRate);

    final net = total > 0
        ? (taxInclusive
            ? (total - vat).clamp(0, double.infinity).toDouble()
            : total)
        : 0.0;

    final bookingCurrency =
        _ResolvedManagedBooking._string(bookingMap['currency_code']);
    final rateCurrency =
        _ResolvedManagedBooking._string(rentalRate['CurrencyCode']);
    final currencyCode =
        bookingCurrency.isNotEmpty ? bookingCurrency : rateCurrency;

    return _ManagedMoneyInfo(
      currencyCode: currencyCode,
      total: total,
      vat: vat,
      net: net,
    );
  }

  String get currencyLabel =>
      _ResolvedManagedBooking._currencySymbol(currencyCode);

  String get totalFormatted =>
      _ResolvedManagedBooking._formatMoney(total, currencyCode);

  String get vatFormatted =>
      _ResolvedManagedBooking._formatMoney(vat, currencyCode);

  String get netFormatted =>
      _ResolvedManagedBooking._formatMoney(net, currencyCode);

  static Map<String, dynamic>? _map(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }
}

class _ManagedCustomerInfo {
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

  const _ManagedCustomerInfo({
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

  factory _ManagedCustomerInfo.fromMap(Map<String, dynamic> map) {
    final firstName =
        _ResolvedManagedBooking._string(map['firstName']).isNotEmpty
            ? _ResolvedManagedBooking._string(map['firstName'])
            : _ResolvedManagedBooking._string(map['Name']);

    final lastName =
        _ResolvedManagedBooking._string(map['lastName']).isNotEmpty
            ? _ResolvedManagedBooking._string(map['lastName'])
            : _ResolvedManagedBooking._string(map['Surname']);

    return _ManagedCustomerInfo(
      fullName: [firstName, lastName].where((e) => e.isNotEmpty).join(' '),
      email: _ResolvedManagedBooking._string(map['email']),
      mobile: _ResolvedManagedBooking._string(map['mobileNumber']),
      birthDate: _formatSimpleDate(
        _ResolvedManagedBooking._string(map['birthDate']),
      ),
      birthPlace: _ResolvedManagedBooking._string(map['birthPlace']),
      birthProvince: _ResolvedManagedBooking._string(map['birthProvince']),
      street: _ResolvedManagedBooking._string(map['street']),
      num: _ResolvedManagedBooking._string(map['num']),
      city: _ResolvedManagedBooking._string(map['city']),
      zip: _ResolvedManagedBooking._string(map['zip']),
      country: _ResolvedManagedBooking._string(map['country']),
      document: _ResolvedManagedBooking._string(map['document']),
      documentNumber:
          _ResolvedManagedBooking._string(map['documentNumber']),
      licenceType: _ResolvedManagedBooking._string(map['licenceType']),
      issueBy: _ResolvedManagedBooking._string(map['issueBy']),
      releaseDate: _formatSimpleDate(
        _ResolvedManagedBooking._string(map['releaseDate']),
      ),
      expiryDate: _formatSimpleDate(
        _ResolvedManagedBooking._string(map['expiryDate']),
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

class _ManagedDriverInfo {
  final String roleLabel;
  final String displayName;
  final String note;

  const _ManagedDriverInfo({
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

class _ManagedDisplayLine {
  final String title;
  final String subtitle;
  final String amountLabel;
  final int sortOrder;

  const _ManagedDisplayLine({
    required this.title,
    required this.subtitle,
    required this.amountLabel,
    required this.sortOrder,
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

    final title = _ResolvedManagedBooking._string(equip['Description']).isNotEmpty
        ? _ResolvedManagedBooking._string(equip['Description'])
        : _ResolvedManagedBooking._string(charge['Description']);

    final equipType = _ResolvedManagedBooking._string(
      equip['EquipType'] ?? equip['Code'],
    ).toUpperCase();

    final quantity = _ResolvedManagedBooking._int(
      equip['Quantity'] ?? map['Quantity'] ?? charge['Quantity'],
    );

    final includedInRate =
        _ResolvedManagedBooking._bool(charge['IncludedInRate']);
    final includedInEstTotal =
        _ResolvedManagedBooking._bool(charge['IncludedInEstTotalInd']);
    final selected = _ResolvedManagedBooking._bool(
      equip['Selected'] ?? map['Selected'] ?? charge['Selected'],
    );
    final prepaid = _ResolvedManagedBooking._bool(
      equip['Prepaid'] ?? map['Prepaid'] ?? charge['Prepaid'],
    );
    final amount = _ResolvedManagedBooking._double(charge['Amount']);

    final normalizedBlob = [
      title,
      equipType,
      _ResolvedManagedBooking._string(charge['Description']),
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
      quantity > 0 || selected || prepaid || includedInRate || includedInEstTotal;

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

  bool get isBaseIncluded =>
      equipType == 'KM_ILL' || equipType == 'CDW' || equipType == 'TP';

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