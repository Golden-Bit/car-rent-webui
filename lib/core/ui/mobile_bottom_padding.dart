import 'package:flutter/material.dart';

const double kMobileBottomPadBreakpoint = 768.0; // <-- soglia (modificala)
const double kMobileBottomPad = 100.0;

double mobileBottomPad(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  return (w < kMobileBottomPadBreakpoint) ? kMobileBottomPad : 0.0;
}
