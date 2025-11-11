import 'package:car_rent_webui/app.dart';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../core/widgets/top_nav_bar.dart';
import '../widgets/hero_banner.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppUiFlags.showAppBarOf(context) ? const TopNavBar() : null,
      body: const HeroBanner(),
    );
  }
}
