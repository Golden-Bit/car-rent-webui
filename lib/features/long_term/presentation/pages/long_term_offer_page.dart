import 'dart:math';
import 'package:car_rent_webui/app.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ⬇️ Top bar dell'app (mostrata sopra al contenuto)
import '../../../../core/widgets/top_nav_bar.dart';

/// Brand colors (coerenti con l'app)
const kBrand = Color(0xFFFF5A19);
const kBrandDark = Color(0xFFE2470C);

/// Immagine principale (duplicata 4 volte per la gallery)
const _carImageUrl =
    'https://raw.githubusercontent.com/Golden-Bit/myrent-SDK/refs/heads/main/data/nuova-fiat-500-club-noleggio-lungo-termine.jpg';

class LongTermOfferPage extends StatefulWidget {
  static const routeName = '/long-term-offer';
  const LongTermOfferPage({super.key});

  @override
  State<LongTermOfferPage> createState() => _LongTermOfferPageState();
}

class _LongTermOfferPageState extends State<LongTermOfferPage> {
  // ----- Stato configurazione -----
  final List<String> _gallery = List.filled(4, _carImageUrl);
  int _imageIndex = 0;

  // Range continui
  static const int _kmMin = 10000;
  static const int _kmMax = 30000;
  static const int _durMin = 24;
  static const int _durMax = 60;

  int _kmPerYear = 10000; // slider continuo (1 km)
  int _durationMonths = 36; // slider 1 mese
  double _anticipo = 0; // 0..5000 step 500

  bool _optAutoSostitutiva = false;
  bool _optCambioGomme = false;
  bool _flagIvaInclusa = true;

  // Dati fittizi vettura
  final _brand = 'FIAT';
  final _model = '500';
  final _version = '1.0 70cv Hybrid';
  final _trim = 'Club';
  final _alimentazione = 'Benzina mild hybrid';
  final _cambio = 'Manuale';
  final _cv = 70;
  final _porte = 3;

  // Base price (€/mese) per 36 mesi, 10k/anno, anticipo 0, IVA esclusa
  static const double _baseMonthlyNet = 239.0;

  @override
  Widget build(BuildContext context) {
    // Calcolo prezzi
    final net = _computeMonthlyNet();
    final display = _flagIvaInclusa ? net * 1.22 : net;

    return Scaffold(
      // ✅ Mostra la tua TopNavBar (niente freccia indietro)
      appBar: AppUiFlags.showAppBarOf(context) ? const TopNavBar() : null,
      body: LayoutBuilder(
        builder: (context, c) {
          final maxW = c.maxWidth;
          final isNarrow = maxW < 1100;
          final maxBodyW = min(1280.0, maxW);

          final sideW = min(430.0, max(360.0, maxBodyW * 0.34));
          const gap = 24.0;
          final leftW = isNarrow ? maxBodyW : (maxBodyW - sideW - gap);

          return Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints.tightFor(width: maxBodyW),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ====== HERO + CONFIGURATORE ======
                    if (!isNarrow)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: leftW, child: _buildGallery()),
                          const SizedBox(width: 24),
                          SizedBox(width: sideW, child: _buildConfigurator(display, net)),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGallery(),
                          const SizedBox(height: 18),
                          _buildConfigurator(display, net),
                        ],
                      ),

                    const SizedBox(height: 24),

                    // ====== SPECIFICHE ======
                    _SpecsBlock(
                      brand: _brand,
                      model: _model,
                      trim: _trim,
                      alimentazione: _alimentazione,
                      cambio: _cambio,
                      cv: _cv,
                      porte: _porte,
                    ),

                    const SizedBox(height: 24),

                    // ====== SERVIZI INCLUSI ======
                    _IncludedServicesBlock(ivaInclusa: _flagIvaInclusa),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /* ================== UI blocchi ================== */

  Widget _buildGallery() {
    const mainH = 320.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$_brand $_model $_trim',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Colors.black54)),
        const SizedBox(height: 8),
        Container(
          height: mainH,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE6E6E6)),
          ),
          alignment: Alignment.center,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _gallery[_imageIndex],
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.image_not_supported_outlined,
                size: 64,
                color: Colors.black26,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        // Thumbnails
        Wrap(
          spacing: 12,
          children: List.generate(_gallery.length, (i) {
            final selected = i == _imageIndex;
            return GestureDetector(
              onTap: () => setState(() => _imageIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 120,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? kBrandDark : const Color(0xFFE6E6E6),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ColorFiltered(
                    colorFilter: selected
                        ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                        : const ColorFilter.mode(Colors.black26, BlendMode.saturation),
                    child: Image.network(
                      _gallery[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.image_not_supported_outlined,
                        size: 36,
                        color: Colors.black26,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildConfigurator(double displayMonthly, double netMonthly) {
    final priceBig = NumberFormat.currency(
      locale: 'it_IT',
      symbol: '€',
      decimalDigits: 0,
    ).format(displayMonthly);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header brand + modello
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _brand,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .2,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '$_model\n$_trim',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87),
              children: [
                TextSpan(
                  text: priceBig.replaceAll(',00', ''),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: kBrandDark,
                    height: 1.0,
                  ),
                ),
                const TextSpan(
                  text: '/mese',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: kBrandDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(_version, style: const TextStyle(color: Colors.black87)),
          Text(_alimentazione, style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 4),
          Text('Anticipo ${_currency(_anticipo)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {},
            child: const Text(
              'È possibile versare un anticipo personalizzabile per abbattere la rata mensile.',
              style: TextStyle(
                color: kBrandDark,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Slider Anticipo (0..5000, step 500)
          _LabeledSlider(
            label: 'Anticipo',
            value: _anticipo,
            min: 0,
            max: 5000,
            divisions: 10, // 500€
            valueBuilder: (v) => _currency(v),
            onChanged: (v) => setState(() => _anticipo = v),
          ),
          const SizedBox(height: 8),

          // Slider KM/anno – continuo (1 km)
          _LabeledSlider(
            label: 'Chilometri/anno',
            value: _kmPerYear.toDouble(),
            min: _kmMin.toDouble(),
            max: _kmMax.toDouble(),
            // niente divisions -> slider continuo; arrotondo a intero
            valueBuilder: (v) => NumberFormat.decimalPattern('it_IT').format(v.round()),
            onChanged: (v) => setState(() => _kmPerYear = v.round()),
          ),
          // footer "ancore" come nello screenshot
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('10.000'), Text('20.000'), Text('30.000'),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Slider Durata (1 mese)
          _LabeledSlider(
            label: 'Durata mesi',
            value: _durationMonths.toDouble(),
            min: _durMin.toDouble(),
            max: _durMax.toDouble(),
            divisions: _durMax - _durMin, // step 1 mese
            valueBuilder: (v) => '${v.round()}',
            onChanged: (v) => setState(() => _durationMonths = v.round()),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('24'), Text('36'), Text('48'), Text('60'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Opzioni (ChoiceChip stile "pallino")
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ToggleDot(
                label: 'Auto Sostitutiva',
                value: _optAutoSostitutiva,
                onChanged: (v) => setState(() => _optAutoSostitutiva = v),
              ),
              _ToggleDot(
                label: 'Cambio gomme',
                value: _optCambioGomme,
                onChanged: (v) => setState(() => _optCambioGomme = v),
              ),
              _ToggleDot(
                label: 'IVA inclusa',
                value: _flagIvaInclusa,
                onChanged: (v) => setState(() => _flagIvaInclusa = v),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            _flagIvaInclusa
                ? 'Rata stimata IVA inclusa: ${_money(displayMonthly)}'
                : 'Rata stimata IVA esclusa: ${_money(netMonthly)}',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),

          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrandDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              onPressed: () {
                final conf = StringBuffer()
                  ..writeln('Richiesta preventivo:')
                  ..writeln('- Km/anno: $_kmPerYear')
                  ..writeln('- Durata: $_durationMonths mesi')
                  ..writeln('- Anticipo: ${_currency(_anticipo)}')
                  ..writeln('- Auto sostitutiva: ${_optAutoSostitutiva ? 'sì' : 'no'}')
                  ..writeln('- Cambio gomme: ${_optCambioGomme ? 'sì' : 'no'}')
                  ..writeln('- IVA inclusa: ${_flagIvaInclusa ? 'sì' : 'no'}')
                  ..writeln('- Rata stimata: ${_money(displayMonthly)} / mese');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(conf.toString())),
                );
              },
              child: const Text('RICHIEDI UN PREVENTIVO'),
            ),
          ),
        ],
      ),
    );
  }

  /* ================== Logica prezzo (continua) ================== */

  double _computeMonthlyNet() {
    var price = _baseMonthlyNet;

    // 🔸 Surcharge km (continuo):
    // 10k inclusi; 10k→20k: +3€/1000; 20k→30k: +4€/1000
    final extra = max(0, _kmPerYear - 10000);
    final first10k = min(extra, 10000);
    final second10k = max(0, extra - 10000);
    price += (first10k / 1000.0) * 3.0;
    price += (second10k / 1000.0) * 4.0;

    // 🔸 Durata: interpolazione lineare sugli ancoraggi:
    // 24 -> +30, 36 -> 0, 48 -> -15, 60 -> -25
    double adj(int m) {
      double lerp(int aM, double aV, int bM, double bV) =>
          aV + (bV - aV) * ((m - aM) / (bM - aM));
      if (m <= 24) return 30;
      if (m <= 36) return lerp(24, 30, 36, 0);
      if (m <= 48) return lerp(36, 0, 48, -15);
      if (m <= 60) return lerp(48, -15, 60, -25);
      return -25;
    }
    price += adj(_durationMonths);

    // 🔸 Anticipo: -€12/mese per ogni 1.000€
    price -= (_anticipo / 1000.0) * 12.0;

    // 🔸 Opzioni
    if (_optAutoSostitutiva) price += 9;
    if (_optCambioGomme) price += 14;

    // 🔸 Salvaguardia
    price = max(price, 99.0);
    return price;
  }

  /* ================== Helpers ================== */

  static String _money(num v) =>
      NumberFormat.currency(locale: 'it_IT', symbol: '€', decimalDigits: 0).format(v);

  String _currency(num v) =>
      NumberFormat.currency(locale: 'it_IT', symbol: '€').format(v);
}

/* ----------------------------------------------------
 * COMPONENTI UI DI SUPPORTO
 * --------------------------------------------------*/

class _LabeledSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double) valueBuilder;
  final ValueChanged<double> onChanged;

  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.valueBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(valueBuilder(value),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: kBrandDark,
            thumbColor: kBrandDark,
            overlayColor: kBrand.withOpacity(.12),
            inactiveTrackColor: const Color(0xFFE5E5E5),
            valueIndicatorColor: kBrandDark,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions, // null -> continuo
            label: valueBuilder(value),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// “Pallino” selezionabile (come nello screenshot)
class _ToggleDot extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleDot({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: value ? kBrandDark : Colors.black38, width: 2),
        color: value ? kBrandDark : Colors.white,
      ),
    );

    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            dot,
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/* ------------------ Blocchi inferiori ------------------ */

class _SpecsBlock extends StatelessWidget {
  final String brand;
  final String model;
  final String trim;
  final String alimentazione;
  final String cambio;
  final int cv;
  final int porte;

  const _SpecsBlock({
    required this.brand,
    required this.model,
    required this.trim,
    required this.alimentazione,
    required this.cambio,
    required this.cv,
    required this.porte,
  });

  @override
  Widget build(BuildContext context) {
    Widget row(String l, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 180,
                child: Text(l.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.black54,
                    )),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFE6E6E6)),
                  ),
                  child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 28),
        Text(
          'SPECIFICHE $brand $model $trim',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: .2,
          ),
        ),
        const SizedBox(height: 12),
        row('Modello', '$brand $model $trim'),
        row('Alimentazione', alimentazione),
        row('Cambio', cambio),
        row('Potenza', '$cv CV'),
        row('Porte', '$porte'),
      ],
    );
  }
}

class _IncludedServicesBlock extends StatelessWidget {
  final bool ivaInclusa;
  const _IncludedServicesBlock({required this.ivaInclusa});

  @override
  Widget build(BuildContext context) {
    Widget item(IconData ic, String title, String sub) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(ic, color: kBrandDark, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: .2,
                      )),
                  Text(sub, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 28),
        const Text(
          'SERVIZI INCLUSI NEL NOLEGGIO',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: .2,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 28,
          runSpacing: 18,
          children: [
            SizedBox(
              width: 340,
              child: item(Icons.handyman_outlined, 'MANUTENZIONE',
                  'Manutenzione ordinaria e straordinaria'),
            ),
            SizedBox(
              width: 340,
              child: item(Icons.support_agent_outlined, 'ASSISTENZA H24',
                  'Assistenza telefonica 24/7'),
            ),
            SizedBox(
              width: 340,
              child: item(Icons.local_taxi_outlined, 'SOCCORSO STRADALE',
                  'Intervento tempestivo e vettura sostitutiva (a richiesta)'),
            ),
            SizedBox(
              width: 340,
              child: item(Icons.shield_outlined, 'ASSICURAZIONE',
                  'RCA, kasko + danni, copertura furto/incendio e tutela infortuni conducente'),
            ),
            SizedBox(
              width: 340,
              child: item(Icons.receipt_long_outlined, 'IVA',
                  ivaInclusa ? 'IVA inclusa' : 'IVA esclusa'),
            ),
          ],
        ),
      ],
    );
  }
}
