import 'package:flutter/widgets.dart';

/// Crea un pannello ancorato a destra con bordo sinistro inclinato.
/// [panelWidth] è la larghezza della colonna destra (mappa).
/// [insetTop] quanto "rientra" il bordo in alto (in px) per creare la diagonale.
class RightDiagonalPanelClipper extends CustomClipper<Path> {
  final double panelWidth;
  final double insetTop;

  const RightDiagonalPanelClipper({
    this.panelWidth = 560.0,
    this.insetTop = 120.0,
  });

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;

    // x della “spalla” sinistra in alto (rientro per la diagonale)
    final leftTopX = (w - panelWidth + insetTop).clamp(0.0, w);
    // x della base sinistra in basso (chiusura diagonale)
    final leftBottomX = (w - panelWidth).clamp(0.0, w);

    final p = Path()
      ..moveTo(w, 0)                 // in alto a destra
      ..lineTo(leftTopX, 0)          // bordo superiore verso sinistra
      ..lineTo(leftBottomX, h)       // diagonale verso il basso
      ..lineTo(w, h)                 // bordo inferiore a destra
      ..close();

    return p;
  }

  @override
  bool shouldReclip(covariant RightDiagonalPanelClipper oldClipper) {
    return oldClipper.panelWidth != panelWidth || oldClipper.insetTop != insetTop;
  }
}
