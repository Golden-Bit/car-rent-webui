import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../widgets/location_dropdown.dart';
import '../pages/advanced_search_page.dart';

class HeroBanner extends StatelessWidget {
  const HeroBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Breakpoint: side-by-side (diagonale) → stacked (orizzontale)
    const double kStackBreakpoint = 1024.0;
    final bool isWide = size.width >= kStackBreakpoint;

    final double height = size.height; // ⬅️ ora usiamo TUTTA l’altezza disponibile
    final double width = size.width;

    // Geometria del pannello destro (solo wide)
    final double topLeftX = width * 0.70;
    final double bottomLeftX = width * 0.55;
    final double midLeftX = (topLeftX + bottomLeftX) / 2.0;

    // Larghezza reale del pannello destro alla quota centrale
    final double rightPanelWidthAtCenter =
        (width - midLeftX).clamp(280.0, width);

    // Larghezza utile della fascia sinistra (solo wide)
    final double leftBandWidth = (topLeftX + bottomLeftX) / 2;

    // Padding interno simmetrico del pannello destro
    const double kRightInnerPad = 28.0;

    // Larghezza massima del contenuto destro in funzione della diagonale (centrale)
    final double rightPanelContentMaxWidth =
        (rightPanelWidthAtCenter - kRightInnerPad * 2).clamp(280.0, 560.0);

    // Calcolo larghezza dinamica del blocco titolo+campo [260..520]
    double _computeFieldWidth(double available) =>
        available.clamp(260.0, 520.0);

    if (isWide) {
      // ===== LAYOUT SIDE-BY-SIDE (bordo diagonale a destra) =====
      return SizedBox(
        width: width,
        height: height, // ⬅️ prende tutta l’altezza dello schermo
        child: Stack(
          children: [
            // LAYER 1: sfondo arancione (sinistra)
            Container(height: height, color: kBrand),

            // LAYER 2: pannello destro scuro con bordo diagonale
            ClipPath(
              clipper: _RightHeroDiagonalClipper(),
              child: Container(
                height: height,
                color: kBrandDark,
                child: Align(
                  // ancoriamo a destra, ma poi centriamo dentro la larghezza reale del pannello
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: rightPanelWidthAtCenter, // larghezza del pannello alla quota centrale
                    height: height,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: kRightInnerPad),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: rightPanelContentMaxWidth),
                          child:
                              const _RightPanelContent(), // ora è davvero centrato nel pannello
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // LAYER 3: contenuti sinistra, centrati nella fascia sinistra
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                height: height,
                width: leftBandWidth,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final fw = _computeFieldWidth(c.maxWidth);
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment:
                                CrossAxisAlignment.start, // allinea a sinistra
                            children: [
                              // Titolo e campo condividono la stessa larghezza → bordi allineati
                              SizedBox(
                                width: fw,
                                child: Text(
                                  "Noleggia un'auto",
                                  style:
                                      Theme.of(context).textTheme.displayMedium,
                                  textAlign: TextAlign.left,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: fw,
                                child: LocationDropdown(
                                  hintText: 'Seleziona località di ritiro',
                                  onSelected: (loc) {
                                    Navigator.pushNamed(
                                      context,
                                      AdvancedSearchPage.routeName,
                                      arguments:
                                          AdvancedSearchArgs(pickup: loc),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),
                              // CTA sotto al campo, centrata rispetto al campo
                              SizedBox(
                                width: fw,
                                child: Center(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                          color: Colors.white, width: 1.4),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 22, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {},
                                    child:
                                        const Text('scopri le promozioni'),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // ===== LAYOUT STACKED (pannello destro sotto, separatore orizzontale) =====
      return SizedBox(
        width: width,
        height: height, // ⬅️ qui occupiamo tutta l’altezza schermata
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Sezione superiore arancione
            Expanded(
              flex: 3,
              child: Container(
                color: kBrand,
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final fw = _computeFieldWidth(c.maxWidth);
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: fw,
                              child: Text(
                                "Noleggia un'auto",
                                style: Theme.of(context)
                                    .textTheme
                                    .displayMedium,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: fw,
                              child: LocationDropdown(
                                hintText: 'Seleziona località di ritiro',
                                onSelected: (loc) {
                                  Navigator.pushNamed(
                                    context,
                                    AdvancedSearchPage.routeName,
                                    arguments:
                                        AdvancedSearchArgs(pickup: loc),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: fw,
                              child: Center(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: Colors.white, width: 1.4),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 22, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {},
                                  child:
                                      const Text('scopri le promozioni'),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // Pannello destro *sotto* (bordo orizzontale, niente diagonale)
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                color: kBrandDark,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: const _RightPanelContent(),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
              textStyle: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
            ),
            onPressed: () {},
            child: const Text('Vedi le offerte'),
          ),
        ],
      ),
    );
  }
}

/// Clipper per ottenere il pannello DESTRO con bordo diagonale (solo wide).
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
