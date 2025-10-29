import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../widgets/location_dropdown.dart';
import '../pages/advanced_search_page.dart';

class HeroBanner extends StatelessWidget {
  const HeroBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final height = size.height * 0.76;
    final width = size.width;

    // Geometria del pannello destro (stessa usata dal Clipper)
    final topLeftX = width * 0.70;
    final bottomLeftX = width * 0.55;

    // Larghezza "utile" della fascia sinistra al centro verticale:
    // coord. x del bordo diagonale a metà altezza
    final leftBandWidth = (topLeftX + bottomLeftX) / 2;

    return Stack(
      children: [
        // LAYER 1: sfondo arancione primario (SINISTRA)
        Container(height: height, color: kBrand),

        // LAYER 2: pannello DESTRO più scuro con bordo diagonale orientato come in figura
        ClipPath(
          clipper: _RightHeroDiagonalClipper(),
          child: Container(
            height: height,
            color: kBrandDark,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: const _RightPanelContent(),
                ),
              ),
            ),
          ),
        ),

        // LAYER 3: BLOCCO SINISTRO – centrato V+H rispetto ALLA FASCIA SINISTRA
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: height,
            width: leftBandWidth, // <-- limitiamo la larghezza al solo lato sinistro
            child: Center( // <-- centra orizzontalmente e verticalmente dentro la fascia
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Titolo allineato al bordo del campo
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Noleggia un'auto",
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Riga CENTRATA con campo località + tile furgone
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: LocationDropdown(
                              hintText: 'Seleziona località di ritiro',
                              onSelected: (loc) {
                                Navigator.pushNamed(
                                  context,
                                  AdvancedSearchPage.routeName,
                                  arguments: AdvancedSearchArgs(pickup: loc),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 24),
                          const _SecondaryTile(
                            icon: Icons.airport_shuttle_rounded,
                            label: 'Noleggia un furgone',
                            onTap: _noop,
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),
                      // Icone decorative auto
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.directions_car_filled_rounded,
                              size: 72, color: Colors.white),
                          SizedBox(width: 12),
                          Icon(Icons.more_horiz, color: Colors.white54),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // LAYER 4: “scopri le promozioni” + freccia CENTRATI IN BASSO
        Align(
          alignment: const Alignment(0, 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white, width: 1.4),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {},
                child: const Text('scopri le promozioni'),
              ),
              const SizedBox(height: 8),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 1.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.expand_more,
                    color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RightPanelContent extends StatelessWidget {
  const _RightPanelContent();

  @override
  Widget build(BuildContext context) {
    final headline = Theme.of(context)
        .textTheme
        .displaySmall
        ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700);
    final sub = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Devi acquistare una nuova auto?',
            style: sub,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Scopri i vantaggi del noleggio a\nlungo termine',
            style: headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kBrandDark,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            onPressed: () {},
            child: const Text('Vedi le offerte'),
          ),
        ],
      ),
    );
  }
}

class _SecondaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SecondaryTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: Colors.white, width: 1.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              label,
              style:
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Clipper per ottenere il pannello DESTRO con bordo diagonale
/// orientato come nello screenshot (il bordo sinistro del pannello
/// scende da ~70% in alto a ~55% in basso).
class _RightHeroDiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final topLeftX = size.width * 0.70;
    final bottomLeftX = size.width * 0.55;

    return Path()
      ..moveTo(size.width, 0) // top-right
      ..lineTo(size.width, size.height) // bottom-right
      ..lineTo(bottomLeftX, size.height) // bottom-left del pannello scuro
      ..lineTo(topLeftX, 0) // top-left del pannello scuro
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

void _noop() {}
