import 'package:flutter/material.dart';

class StepsHeader extends StatelessWidget {
  final int currentStep; // 1..4
  final Color accent;    // arancione scuro (es. kBrandDark)

  // STEP 1 – location & date (già formattate fuori)
  final String? step1Pickup;   // es. "BARI AEROPORTO"
  final String? step1Dropoff;  // es. "BARI AEROPORTO"
  final String? step1Start;    // es. "ott 5, 2025 08:00"
  final String? step1End;      // es. "ott 8, 2025 08:00"

  // STEP 2 – car info (riempito solo se selezionata)
  final String? step2Title;     // es. "Gruppo A1" o "ECONOMY"
  final String? step2Subtitle;  // es. "HYUNDAI I10"
  final String? step2Thumb;     // url immagine
  final String? step2Price;     // es. "€ 124,64"

  final void Function(int step)? onTapStep;

  const StepsHeader({
    super.key,
    required this.currentStep,
    required this.accent,
    this.step1Pickup,
    this.step1Dropoff,
    this.step1Start,
    this.step1End,
    this.step2Title,
    this.step2Subtitle,
    this.step2Thumb,
    this.step2Price,
    this.onTapStep,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF5E9D2D);
    final accentLight = accent.withOpacity(.35);

    // Divider verticale adattivo
    Widget vDivider() => const VerticalDivider(
          width: 1,
          thickness: 1,
          color: Color(0xFFE6E6E6),
        );

    // Stato step
    bool isDone(int n) => n < currentStep;
    bool isCurrent(int n) => n == currentStep;

    // Badge numerato
    Widget stepBadge(int n) {
      late Color fill, border, text;
      if (isDone(n)) {
        fill = green; border = Colors.transparent; text = Colors.white;
      } else if (isCurrent(n)) {
        fill = Colors.white; border = green; text = green;
      } else {
        fill = const Color(0xFFBDBDBD); border = const Color(0xFFBDBDBD); text = Colors.white;
      }
      return Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: border, width: 2),
        ),
        child: Text(
          '$n',
          style: TextStyle(color: text, fontWeight: FontWeight.w700, fontSize: 12),
        ),
      );
    }

    // Titolo step + "MODIFICA" (solo se step completato)
    Widget stepHeaderRow(int n, String title) {
      final canEdit = isDone(n);
      return Row(
        children: [
          stepBadge(n),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: .25),
          ),
          const SizedBox(width: 12),
          if (canEdit)
            InkWell(
              onTap: () => onTapStep?.call(n),
              child: Text(
                'MODIFICA',
                style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
        ],
      );
    }

    // Blocco location (label + nome + data)
    Widget locationBlock(String label, String? place, String? when) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            (place ?? '—').toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: .2),
          ),
          const SizedBox(height: 6),
          if (when != null)
            Text(when, style: const TextStyle(color: Colors.black54, fontSize: 12.5)),
        ],
      );
    }

    // Thumb auto grande
    Widget carThumbLarge(String? url) {
      const w = 180.0;
      const h = 110.0;

      final ph = Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEAEAEA)),
        ),
        child: const Center(
          child: Icon(Icons.directions_car_filled_outlined, color: Colors.black26, size: 28),
        ),
      );

      if (url == null || url.trim().isEmpty) return ph;

      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEAEAEA)),
        ),
        padding: const EdgeInsets.all(6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => ph,
          ),
        ),
      );
    }

    // STEP 1
    Widget step1Box() {
      final n = 1;
      final tappable = isDone(n) || isCurrent(n);
      return Expanded(
        child: InkWell(
          onTap: tappable ? () => onTapStep?.call(n) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                stepHeaderRow(n, 'Scelta location'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: locationBlock('Ritiro:', step1Pickup, step1Start)),
                    const SizedBox(width: 18),
                    Expanded(child: locationBlock('Consegna:', step1Dropoff, step1End)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // STEP 2 – contenuto solo se selezionata
    Widget step2Box() {
      final n = 2;
      final tappable = isDone(n) || isCurrent(n);

      final hasCar = (step2Title?.trim().isNotEmpty == true) ||
          (step2Subtitle?.trim().isNotEmpty == true) ||
          (step2Thumb?.trim().isNotEmpty == true) ||
          (step2Price?.trim().isNotEmpty == true);

      return Expanded(
        child: InkWell(
          onTap: tappable ? () => onTapStep?.call(n) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                stepHeaderRow(n, 'Scelta auto'),
                if (hasCar) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Testi a sinistra
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Auto:',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                )),
                            const SizedBox(height: 8),
                            if (step2Title != null)
                              Text(step2Title!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5,
                                      color: Colors.black87)),
                            const SizedBox(height: 2),
                            Text(
                              (step2Subtitle ?? '—').toUpperCase(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                letterSpacing: .2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text('o modello simile*',
                                style: TextStyle(color: Colors.black54, fontSize: 12)),
                            if (step2Price != null && step2Price!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(step2Price!,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Immagine a destra
                      carThumbLarge(step2Thumb),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // STEP 3/4 – solo titolo (ma la card resta cliccabile se già svolto)
    Widget simpleStep(int n, String title) {
      final tappable = isDone(n) || isCurrent(n);
      return Expanded(
        child: InkWell(
          onTap: tappable ? () => onTapStep?.call(n) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Align(alignment: Alignment.topLeft, child: stepHeaderRow(n, title)),
          ),
        ),
      );
    }

    // Barra progresso segmentata
    Widget progressBar() {
      const h = 6.0;
      return SizedBox(
        height: h,
        child: Row(
          children: List.generate(4, (i) {
            final idx = i + 1;
            final color = (idx <= currentStep) ? accent : accentLight;
            return Expanded(child: Container(color: color));
          }),
        ),
      );
    }

    return Material(
      color: Colors.white,
      child: Column(
        children: [
          // Altezza adattiva
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                step1Box(),
                vDivider(),
                step2Box(),
                vDivider(),
                simpleStep(3, 'Scelta extra'),
                vDivider(),
                simpleStep(4, 'Totale noleggio'),
              ],
            ),
          ),
          progressBar(),
        ],
      ),
    );
  }
}
