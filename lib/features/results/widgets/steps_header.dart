// steps_header.dart
import 'package:flutter/material.dart';

import 'steps_header_desktop.dart';
import 'steps_header_mobile.dart';

/// Modello dati condiviso tra le due versioni (desktop/mobile) dello StepHeader.
class StepsHeaderData {
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

  // STEP 3 – extras
  final List<String>? step3Extras;      // Etichette extra selezionati
  final String? step3ExtrasTotal;       // Totale extra formattato

  // STEP 3 – assicurazione
  final String? step3InsuranceName;     // es. "GOLD"
  final String? step3InsuranceTotal;    // es. "€ 126,00"

  const StepsHeaderData({
    this.step1Pickup,
    this.step1Dropoff,
    this.step1Start,
    this.step1End,
    this.step2Title,
    this.step2Subtitle,
    this.step2Thumb,
    this.step2Price,
    this.step3Extras,
    this.step3ExtrasTotal,
    this.step3InsuranceName,
    this.step3InsuranceTotal,
  });
}

/// Widget pubblico usato dalle pagine (AdvancedSearch, Results, Extras, Confirm).
/// Decide automaticamente se usare layout desktop o mobile.
class StepsHeader extends StatelessWidget {
  final int currentStep; // 1..4
  final Color accent;    // arancione scuro (es. kBrandDark)

  // Dati condivisi
  final String? step1Pickup;
  final String? step1Dropoff;
  final String? step1Start;
  final String? step1End;

  final String? step2Title;
  final String? step2Subtitle;
  final String? step2Thumb;
  final String? step2Price;

  final List<String>? step3Extras;
  final String? step3ExtrasTotal;
  final String? step3InsuranceName;
  final String? step3InsuranceTotal;

  /// Callback generica per clic su uno specifico step (desktop + mobile summary).
  final void Function(int step)? onTapStep;

  /// Callback esplicito per il pulsante "INDIETRO" su mobile.
  /// Se non fornito, viene usato `onTapStep(currentStep - 1)` se possibile.
  final VoidCallback? onBackTap;

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
    this.step3Extras,
    this.step3ExtrasTotal,
    this.step3InsuranceName,
    this.step3InsuranceTotal,
    this.onTapStep,
    this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    const mobileBreakpoint = 1300.0;
    final width = MediaQuery.of(context).size.width;

    final data = StepsHeaderData(
      step1Pickup: step1Pickup,
      step1Dropoff: step1Dropoff,
      step1Start: step1Start,
      step1End: step1End,
      step2Title: step2Title,
      step2Subtitle: step2Subtitle,
      step2Thumb: step2Thumb,
      step2Price: step2Price,
      step3Extras: step3Extras,
      step3ExtrasTotal: step3ExtrasTotal,
      step3InsuranceName: step3InsuranceName,
      step3InsuranceTotal: step3InsuranceTotal,
    );

    if (width >= mobileBreakpoint) {
      // Versione DESKTOP (4 colonne)
      return StepsHeaderDesktop(
        currentStep: currentStep,
        accent: accent,
        data: data,
        onTapStep: onTapStep,
      );
    } else {
      // Versione MOBILE/TABLET: striscia arancione + pulsante riepilogo
      return StepsHeaderMobile(
        currentStep: currentStep,
        accent: accent,
        data: data,
        onTapStep: onTapStep,
        onBackTap: onBackTap,
      );
    }
  }
}
