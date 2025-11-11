import 'package:car_rent_webui/features/long_term/presentation/pages/long_term_offer_page.dart';
import 'package:flutter/material.dart';

class TopNavBar extends StatelessWidget implements PreferredSizeWidget {
  const TopNavBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  void _goToLongTerm(BuildContext context) {
    // Usa la route statica definita nella pagina:
    Navigator.pushNamed(context, LongTermOfferPage.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: primary,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: preferredSize.height,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              // Simulated wordmark
              Text(
                'Rentall',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ).copyWith(letterSpacing: 0.5),
              ),
              const SizedBox(width: 16),
              const Text('premium',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),

              const Spacer(),

              // Link di navigazione (non cliccabili in questo esempio)
              const _NavLink(title: 'Le nostre filiali'),
              const _NavLink(title: 'Noleggio Auto', hasChevron: true),
              const _NavLink(title: 'Noleggio Furgoni', hasChevron: true),
              const _NavLink(title: 'Noleggio Business', hasChevron: true),

              // 🔶 Pulsante richiesto: porta alla pagina Lungo Termine
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                onPressed: () => _goToLongTerm(context),
                child: const Text('Noleggio Lungo Termine'),
              ),

              const SizedBox(width: 16),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                onPressed: () {
                  // TODO: apri pagina contatti
                },
                child: const Text('Contattaci'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String title;
  final bool hasChevron;
  const _NavLink({required this.title, this.hasChevron = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Text(title, style: const TextStyle(color: Colors.white)),
          if (hasChevron)
            const Padding(
              padding: EdgeInsets.only(left: 4.0),
              child: Icon(Icons.expand_more, color: Colors.white70, size: 18),
            ),
        ],
      ),
    );
  }
}
