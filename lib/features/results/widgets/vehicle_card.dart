import 'package:flutter/material.dart';
import '../models/offer_adapter.dart';

class VehicleCard extends StatefulWidget {
  /// Altezza fissa per la griglia
  static const double cardHeight = 300;

  final Offer offer;
  final Color accent;
  final List<String> includeItems;
  final List<String> excludeItems;
  final VoidCallback onChoose;

  const VehicleCard({
    super.key,
    required this.offer,
    required this.accent,
    required this.includeItems,
    required this.excludeItems,
    required this.onChoose,
  });

  @override
  State<VehicleCard> createState() => _VehicleCardState();
}

class _VehicleCardState extends State<VehicleCard> {
  bool _showInfo = false;

  // Hover (web / desktop)
  bool _hover = false;

  // Misure immagine
  static const double _imgWidth = 300;
  static const double _imgHeight = 160;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        elevation: 1.5,
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        child: SizedBox(
          height: VehicleCard.cardHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Contenuto base
                _summaryContent(context),

                // Overlay hover (radiale dal centro)
                Positioned.fill(
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      tween: Tween<double>(
                        begin: 0.001,
                        end: _hover ? 1.15 : 0.001,
                      ),
                      builder: (context, radius, _) {
                        final t = (radius / 1.15).clamp(0.0, 1.0);
                        final alpha = 0.10 * t; // max 10% opacità
                        return Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: radius,
                              colors: [
                                Colors.black.withOpacity(alpha),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 1.0],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // INFO (top-right)
                Positioned(
                  top: 12,
                  right: 16,
                  child: InkWell(
                    onTap: () => setState(() => _showInfo = true),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'INFO',
                        style: TextStyle(
                          color: widget.accent,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .2,
                        ),
                      ),
                    ),
                  ),
                ),

                // SCEGLI / NON DISPONIBILE (bottom-right, sempre una riga)
                Positioned(
                  right: 16,
                  bottom: 12,
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(minHeight: 40, minWidth: 128),
                    child: ElevatedButton(
                      onPressed: widget.offer.status == 'Unavailable'
                          ? null
                          : widget.onChoose,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade400,
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                      ),
                      child: Text(
                        widget.offer.status == 'Unavailable'
                            ? 'non disponibile'
                            : 'scegli',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ),
                ),

                // Overlay INFO (include / non include)
                if (_showInfo) Positioned.fill(child: _infoContent(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryContent(BuildContext context) {
    final o = widget.offer;

    return Row(
      children: [
        // Colonna sinistra: testi
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (o.group != null)
                  Text(
                    'Gruppo ${o.group!}',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  o.name ?? 'Modello',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                _feature(Icons.local_gas_station, o.fuel),
                _feature(
                  Icons.people_alt_outlined,
                  (o.seats == null || o.seats! <= 0) ? null : '${o.seats}',
                ),
                _feature(
                  Icons.meeting_room_outlined,
                  (o.doors == null || o.doors! <= 0) ? null : '${o.doors} porte',
                ),
                _feature(Icons.settings, o.transmission),
                _feature(Icons.event, o.days == null ? null : '${o.days} giorni'),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      o.pricePerDay != null
                          ? '€ ${o.pricePerDay!.toStringAsFixed(2)}'
                          : (o.total != null
                              ? '€ ${o.total!.toStringAsFixed(2)}'
                              : '—'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      o.pricePerDay != null ? '/ giorno' : '',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
                if (o.days != null && o.total != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '€ ${o.total!.toStringAsFixed(2)} Totale per ${o.days} giorni',
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Colonna destra: immagine con padding di 16px dal bordo destro della card
        SizedBox(
          width: _imgWidth + 16, // includo il padding destro
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: _CarImage.card(
                url: o.imageUrl,
                width: _imgWidth,
                height: _imgHeight,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoContent(BuildContext context) {
    final accent = widget.accent;

    Widget title(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(t,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        );

    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 16, color: Colors.black87),
              const SizedBox(width: 8),
              Expanded(child: Text(text)),
            ],
          ),
        );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(),
              InkWell(
                onTap: () => setState(() => _showInfo = false),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'CHIUDI',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title('Include'),
                        for (final s in widget.includeItems) line(Icons.check, s),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title('Non include'),
                        for (final s in widget.excludeItems)
                          line(Icons.close, s),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _feature(IconData icon, String? text) {
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}

/* ------------------ immagine con placeholder ------------------ */

class _CarImage extends StatelessWidget {
  final String? url;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const _CarImage._({
    required this.url,
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  factory _CarImage.card({
    required String? url,
    double width = 300,
    double height = 160,
  }) =>
      _CarImage._(
        url: url,
        width: width,
        height: height,
        borderRadius: BorderRadius.circular(8),
      );

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F4F4),
            borderRadius: borderRadius,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.image_not_supported, color: Colors.black38, size: 18),
              SizedBox(width: 6),
              Text('Nessuna immagine', style: TextStyle(color: Colors.black38)),
            ],
          ),
        );

    if (url == null || url!.isEmpty) return placeholder();

    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        url!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder(),
      ),
    );
  }
}
