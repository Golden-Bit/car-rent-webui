import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Orange brand palette (no fuchsia as requested)
const Color kBrand = Color(0xFFFF5A19); // primary orange
const Color kBrandDark = Color(0xFFE2470C);
const Color kBrandLight = Color(0xFFFFB48A);
const Color kCanvasPinkish = Color(0xFFFFF2EA); // very light warm bg
const kCtaGreen = Color(0xFF2DB974);

ThemeData buildAppTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: kBrand,
      primary: kBrand,
      secondary: const Color(0xFF111111),
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );

  return base.copyWith(
    scaffoldBackgroundColor: Colors.white,
    textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.poppins(
        fontSize: 54, fontWeight: FontWeight.w700, color: Colors.white),
      displayMedium: GoogleFonts.poppins(
        fontSize: 40, fontWeight: FontWeight.w700, color: Colors.white),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kBrand,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: TextStyle(color: Colors.grey.shade500),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: kBrand,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white, width: 1.2),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      ),
    ),
  );
}

class DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width * 0.72, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
