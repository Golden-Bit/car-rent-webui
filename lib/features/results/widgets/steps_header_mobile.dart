// steps_header_mobile.dart
import 'package:flutter/material.dart';
import 'steps_header.dart';

/// Versione MOBILE/TABLET:
/// - barra arancione con pulsante INDIETRO + titolo step + pulsante RIEPILOGO
/// - pannello bianco espandibile con riepilogo step 1..currentStep (card sopraelevata)
class StepsHeaderMobile extends StatefulWidget {
  final int currentStep; // 1..4
  final Color accent;
  final StepsHeaderData data;
  final void Function(int step)? onTapStep;
  final VoidCallback? onBackTap;

  const StepsHeaderMobile({
    super.key,
    required this.currentStep,
    required this.accent,
    required this.data,
    this.onTapStep,
    this.onBackTap,
  });

  @override
  State<StepsHeaderMobile> createState() => _StepsHeaderMobileState();
}

class _StepsHeaderMobileState extends State<StepsHeaderMobile> {
  bool _showSummary = false;

  int get _currentStep => widget.currentStep;

  String get _stepTitle {
    switch (_currentStep) {
      case 1:
        return 'SCELTA LOCATION';
      case 2:
        return 'SCELTA AUTO';
      case 3:
        return 'SCELTA EXTRA';
      case 4:
      default:
        return 'TOTALE NOLEGGIO';
    }
  }

  void _handleBack() {
    if (widget.onBackTap != null) {
      widget.onBackTap!();
      return;
    }
    if (widget.onTapStep != null && _currentStep > 1) {
      widget.onTapStep!(_currentStep - 1);
    }
  }

  void _toggleSummary() {
    setState(() => _showSummary = !_showSummary);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;

    return Material(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // STRISCIA ARANCIONE SUPERIORE
          Container(
            width: double.infinity,
            color: accent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  // Pulsante INDIETRO
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _handleBack,
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                    ),
                    label: const Text(
                      'INDIETRO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .5,
                      ),
                    ),
                  ),

                  // Titolo step corrente
                  Expanded(
                    child: Center(
                      child: Text(
                        '${_currentStep.toString()}  $_stepTitle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                  ),

                  // Pulsante RIEPILOGO
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _toggleSummary,
                    icon: Icon(
                      _showSummary
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'RIEPILOGO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // PANNELLO RIEPILOGO ESPANDIBILE (CARD SOPRAELEVATA)
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              color: Colors
                  .transparent, // lascia vedere lo sfondo della pagina sotto
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: Material(
                elevation: 6, // <-- ombra per “sopraelevare” il riepilogo
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                shadowColor: Colors.black.withOpacity(0.50),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: _SummaryContent(
                    currentStep: _currentStep,
                    accent: accent,
                    data: widget.data,
                    onTapStep: widget.onTapStep,
                  ),
                ),
              ),
            ),
            crossFadeState: _showSummary
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

/// Contenuto del pannello riepilogo (step 1..currentStep).
class _SummaryContent extends StatelessWidget {
  final int currentStep;
  final Color accent;
  final StepsHeaderData data;
  final void Function(int step)? onTapStep;

  const _SummaryContent({
    required this.currentStep,
    required this.accent,
    required this.data,
    this.onTapStep,
  });

  bool get _showStep1 => currentStep >= 1;
  bool get _showStep2 => currentStep >= 2;
  bool get _showStep3 => currentStep >= 3;
  bool get _showStep4 => currentStep >= 4;

  @override
  Widget build(BuildContext context) {
    const divider = Divider(
      height: 20,
      thickness: 1,
      color: Color(0xFFE6E6E6),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showStep1) ...[
          _stepHeaderRow(1, 'Scelta location'),
          const SizedBox(height: 8),
          _step1Body(),
        ],
        if (_showStep2) ...[
          divider,
          _stepHeaderRow(2, 'Scelta auto'),
          const SizedBox(height: 8),
          _step2Body(),
        ],
        if (_showStep3) ...[
          divider,
          _stepHeaderRow(3, 'Scelta extra'),
          const SizedBox(height: 8),
          _step3Body(),
        ],
        if (_showStep4) ...[
          divider,
          _stepHeaderRow(4, 'Totale noleggio'),
          // eventuali info step 4 possono essere aggiunte qui
        ],
      ],
    );
  }

  Widget _stepHeaderRow(int n, String title) {
    final canEdit = n < currentStep;

    return Row(
      children: [
        _stepBadge(n),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: .25,
            ),
          ),
        ),
        if (canEdit)
          InkWell(
            onTap: () => onTapStep?.call(n),
            child: Text(
              'MODIFICA',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }

  Widget _stepBadge(int n) {
    const green = Color(0xFF5E9D2D);

    Color fill;
    Color border;
    Color text;

    if (n < currentStep) {
      fill = green;
      border = Colors.transparent;
      text = Colors.white;
    } else if (n == currentStep) {
      fill = Colors.white;
      border = green;
      text = green;
    } else {
      fill = const Color(0xFFBDBDBD);
      border = const Color(0xFFBDBDBD);
      text = Colors.white;
    }

    return Container(
      width: 20,
      height: 20,
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
          fontSize: 11,
        ),
      ),
    );
  }

  // ---------- BODY STEP 1 ----------
  Widget _step1Body() {
    Widget block(String label, String? place, String? when) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (place ?? '—').toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: .2,
            ),
          ),
          const SizedBox(height: 2),
          if (when != null)
            Text(
              when,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 11,
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        block('Ritiro:', data.step1Pickup, data.step1Start),
        const SizedBox(height: 8),
        block('Consegna:', data.step1Dropoff, data.step1End),
      ],
    );
  }

  // ---------- BODY STEP 2 ----------
  Widget _step2Body() {
    final hasCar = (data.step2Title?.trim().isNotEmpty == true) ||
        (data.step2Subtitle?.trim().isNotEmpty == true) ||
        (data.step2Price?.trim().isNotEmpty == true);

    if (!hasCar) {
      return const Text(
        'Nessuna auto selezionata',
        style: TextStyle(color: Colors.black54, fontSize: 12),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Auto:',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        if (data.step2Title != null)
          Text(
            data.step2Title!,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
            ),
          ),
        Text(
          (data.step2Subtitle ?? '—').toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: .2,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'o modello simile*',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 11,
          ),
        ),
        if (data.step2Price != null && data.step2Price!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            data.step2Price!,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  // ---------- BODY STEP 3 ----------
  Widget _step3Body() {
    final extras = (data.step3Extras ?? const <String>[]);
    final hasExtras = extras.isNotEmpty;

    final hasInsurance =
        (data.step3InsuranceName?.trim().isNotEmpty == true) ||
            (data.step3InsuranceTotal?.trim().isNotEmpty == true);

    final children = <Widget>[];

    if (hasInsurance) {
      children.add(
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
      );

      if (data.step3InsuranceTotal != null &&
          data.step3InsuranceTotal!.trim().isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Row(
              children: [
                const Text(
                  'Totale assicurazione:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  data.step3InsuranceTotal!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (hasExtras) {
      if (hasInsurance) {
        children.add(const SizedBox(height: 8));
      }

      const maxShow = 3;
      final shown = extras.take(maxShow).toList();
      final more = extras.length - shown.length;

      for (final e in shown) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
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
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (more > 0) {
        children.add(
          Text(
            '+$more altro/i',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11.5,
            ),
          ),
        );
      }

      if (data.step3ExtrasTotal != null) {
        children.add(const SizedBox(height: 4));
        children.add(
          Row(
            children: [
              const Text(
                'Totale extra:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                data.step3ExtrasTotal!,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }
    }

    if (children.isEmpty) {
      return const Text(
        'Nessun extra selezionato',
        style: TextStyle(color: Colors.black54, fontSize: 12),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
