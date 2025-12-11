import 'package:car_rent_webui/app.dart'; // per kBrand, kBrandDark, AppUiFlags
import 'package:car_rent_webui/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/top_nav_bar.dart';

class BookingManagementPage extends StatefulWidget {
  static const routeName = '/booking_management';

  const BookingManagementPage({super.key});

  @override
  State<BookingManagementPage> createState() => _BookingManagementPageState();
}

class _BookingManagementPageState extends State<BookingManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _referenceController = TextEditingController();

  String? _currentReference;   // riferimento “cercato”
  bool _submitted = false;     // indica se è stato premuto il tasto “Visualizza stato”

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitted = true;
      _currentReference = _referenceController.text.trim();
    });

    // QUI in futuro aggancerai il backend per recuperare lo stato:
    // es: MyrentRepository().getBookingStatus(_currentReference!);
  }

  void _onNewSearch() {
    setState(() {
      _submitted = false;
      _currentReference = null;
      _referenceController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = kBrandDark; // colore di brand già usato negli step

    final showTopBar = AppUiFlags.showAppBarOf(context);

    return Scaffold(
      appBar: showTopBar ? const TopNavBar() : null,
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Titolo e descrizione
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Gestione prenotazioni',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Inserisci il riferimento della tua prenotazione per '
                        'visualizzarne lo stato.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // FORM
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _referenceController,
                            decoration: InputDecoration(
                              labelText: 'Riferimento prenotazione',
                              hintText: 'Es. ABC12345',
                              prefixIcon: const Icon(
                                Icons.confirmation_number_outlined,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: accent, width: 2),
                              ),
                            ),
                            textInputAction: TextInputAction.search,
                            onFieldSubmitted: (_) => _onSubmit(),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return 'Inserisci un riferimento valido.';
                              }
                              if (text.length < 5) {
                                return 'Il riferimento sembra troppo corto.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.search),
                              label: const Text('Visualizza stato'),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                backgroundColor: accent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _onSubmit,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // SEZIONE STATO PRENOTAZIONE (solo UI, placeholder)
                    if (_submitted) ...[
                      Divider(color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Stato prenotazione',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey[300]!,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_currentReference != null) ...[
                              Text(
                                'Riferimento: $_currentReference',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              // Testo fittizio: solo UI, nessun backend
                              'Lo stato della prenotazione verrà mostrato qui '
                              'non appena sarà integrata la logica di recupero.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Inserisci un nuovo riferimento'),
                          style: TextButton.styleFrom(
                            foregroundColor: accent,
                          ),
                          onPressed: _onNewSearch,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
