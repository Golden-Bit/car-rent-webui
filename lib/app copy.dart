import 'package:car_rent_webui/features/long_term/presentation/pages/long_term_offer_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_theme.dart';
import 'features/search/presentation/pages/home_page.dart';
import 'features/search/presentation/pages/advanced_search_page.dart';
import 'features/results/presentation/pages/results_page.dart';

class MyrentBookingApp extends StatelessWidget {
  const MyrentBookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Myrent – Prenotazione',
      theme: buildAppTheme(),
      routes: {
        '/': (_) => const HomePage(),
        AdvancedSearchPage.routeName: (_) => const AdvancedSearchPage(),
        ResultsPage.routeName: (ctx) => const ResultsPage(),
        LongTermOfferPage.routeName: (_) => const LongTermOfferPage(),
      },
    );
  }
}
