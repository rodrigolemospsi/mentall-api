import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';
import 'financeiro_page.dart';
import 'home_page.dart';
import 'pacientes_page.dart';

final _tabIndexProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final Set<int> _tabsConstruidas = {0};

  @override
  Widget build(BuildContext context) {
    final tabIndex = ref.watch(_tabIndexProvider);
    _tabsConstruidas.add(tabIndex);

    final termoPluralNavbar =
        ref.watch(perfilTermoPluralProvider).valueOrNull ?? 'Pacientes';

    return Scaffold(
      body: IndexedStack(
        index: tabIndex,
        children: [
          const HomePage(),
          _tabsConstruidas.contains(1)
              ? const PacientesPage()
              : const SizedBox.shrink(),
          _tabsConstruidas.contains(2)
              ? const FinanceiroPage()
              : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabIndex,
        onDestinationSelected: (i) =>
            ref.read(_tabIndexProvider.notifier).state = i,
        destinations: [
          Semantics(
            label: 'Inicio',
            child: const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Início',
            ),
          ),
          Semantics(
            label: termoPluralNavbar,
            child: NavigationDestination(
              icon: const Icon(Icons.people_outlined),
              selectedIcon: const Icon(Icons.people),
              label: termoPluralNavbar,
            ),
          ),
          Semantics(
            label: 'Financeiro',
            child: const NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments),
              label: 'Financeiro',
            ),
          ),
        ],
      ),
    );
  }
}
