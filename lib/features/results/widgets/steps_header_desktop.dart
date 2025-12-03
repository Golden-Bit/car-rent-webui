// steps_header_desktop.dart
import 'package:flutter/material.dart';
import 'steps_header.dart';

/// Versione DESKTOP: 4 colonne con riepilogo completo.
class StepsHeaderDesktop extends StatelessWidget {
  final int currentStep;
  final Color accent;
  final StepsHeaderData data;
  final void Function(int step)? onTapStep;

  const StepsHeaderDesktop({
    super.key,
    required this.currentStep,
    required this.accent,
    required this.data,
    this.onTapStep,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF5E9D2D);
    final accentLight = accent.withOpacity(.35);

    bool isDone(int n) => n < currentStep;
    bool isCurrent(int n) => n == currentStep;

    Widget vDivider() => const VerticalDivider(
          width: 1,
          thickness: 1,
          color: Color(0xFFE6E6E6),
        );

    // Badge numerato
    Widget stepBadge(int n) {
      late Color fill, border, text;
      if (isDone(n)) {
        fill = green;
        border = Colors.transparent;
        text = Colors.white;
      } else if (isCurrent(n)) {
        fill = Colors.white;
        border = green;
        text = green;
      } else {
        fill = const Color(0xFFBDBDBD);
        border = const Color(0xFFBDBDBD);
        text = Colors.white;
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
          style: TextStyle(
            color: text,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
    }

    // Titolo step + "MODIFICA"
    Widget stepHeaderRow(int n, String title) {
      final canEdit = isDone(n);
      return Row(
        children: [
          stepBadge(n),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: .25,
            ),
          ),
          const SizedBox(width: 12),
          if (canEdit)
            InkWell(
              onTap: () => onTapStep?.call(n),
              child: Text(
                'MODIFICA',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
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
          Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            (place ?? '—').toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: .2,
            ),
          ),
          const SizedBox(height: 6),
          if (when != null)
            Text(
              when,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12.5,
              ),
            ),
        ],
      );
    }

    // Thumb auto
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
          child: Icon(
            Icons.directions_car_filled_outlined,
            color: Colors.black26,
            size: 28,
          ),
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
      const n = 1;
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
                    Expanded(
                      child: locationBlock(
                        'Ritiro:',
                        data.step1Pickup,
                        data.step1Start,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: locationBlock(
                        'Consegna:',
                        data.step1Dropoff,
                        data.step1End,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // STEP 2
    Widget step2Box() {
      const n = 2;
      final tappable = isDone(n) || isCurrent(n);

      final hasCar = (data.step2Title?.trim().isNotEmpty == true) ||
          (data.step2Subtitle?.trim().isNotEmpty == true) ||
          (data.step2Thumb?.trim().isNotEmpty == true) ||
          (data.step2Price?.trim().isNotEmpty == true);

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
                            const Text(
                              'Auto:',
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (data.step2Title != null)
                              Text(
                                data.step2Title!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                  color: Colors.black87,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              (data.step2Subtitle ?? '—').toUpperCase(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                letterSpacing: .2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'o modello simile*',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                            if (data.step2Price != null &&
                                data.step2Price!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                data.step2Price!,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      carThumbLarge(data.step2Thumb),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // STEP 3 – assicurazione + extra
    Widget step3Box() {
      const n = 3;
      final tappable = isDone(n) || isCurrent(n);

      final extras = (data.step3Extras ?? const <String>[]);
      final hasExtras = extras.isNotEmpty;

      final hasInsurance =
          (data.step3InsuranceName?.trim().isNotEmpty == true) ||
              (data.step3InsuranceTotal?.trim().isNotEmpty == true);

      List<Widget> extrasWidgets() {
        const maxShow = 3;
        final shown = extras.take(maxShow).toList();
        final more = extras.length - shown.length;
        return [
          for (final e in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_circle,
                    size: 14,
                    color: Colors.black45,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      e,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          if (more > 0)
            Text(
              '+$more altro/i',
              style: const TextStyle(color: Colors.black54),
            ),
          if (data.step3ExtrasTotal != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Text(
                  'Totale extra:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 6),
                Text(
                  data.step3ExtrasTotal!,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ];
      }

      List<Widget> insuranceWidgets() {
        if (!hasInsurance) return const [];
        return [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 16,
                color: Colors.black45,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  (data.step3InsuranceName ?? '').toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (data.step3InsuranceTotal != null &&
              data.step3InsuranceTotal!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  const Text(
                    'Totale assicurazione:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    data.step3InsuranceTotal!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
        ];
      }

      return Expanded(
        child: InkWell(
          onTap: tappable ? () => onTapStep?.call(n) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                stepHeaderRow(n, 'Scelta extra'),
                if (hasInsurance || hasExtras) ...[
                  const SizedBox(height: 12),
                  ...insuranceWidgets(),
                  if (hasInsurance && hasExtras) const SizedBox(height: 8),
                  if (hasExtras) ...extrasWidgets(),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // STEP 4 – solo titolo (cliccabile se già svolto)
    Widget simpleStep(int n, String title) {
      final tappable = isDone(n) || isCurrent(n);
      return Expanded(
        child: InkWell(
          onTap: tappable ? () => onTapStep?.call(n) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Align(
              alignment: Alignment.topLeft,
              child: stepHeaderRow(n, title),
            ),
          ),
        ),
      );
    }

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
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                step1Box(),
                vDivider(),
                step2Box(),
                vDivider(),
                step3Box(),
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
