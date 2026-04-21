import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../breakpoints.dart';

class AdaptiveScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final List<NavigationDestination> destinations;

  const AdaptiveScaffold({
    super.key,
    required this.navigationShell,
    required this.destinations,
  });

  String _getTitle(int index) {
    switch (index) {
      case 0:
        return 'Overview';
      case 1:
        return 'Accounts';
      case 2:
        return 'Budget';
      case 3:
        return 'Goals';
      case 4:
        return 'Profile';
      default:
        return 'Excess Budget';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenType = context.screenType;
    final title = _getTitle(navigationShell.currentIndex);

    if (screenType == ScreenType.compact) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(index),
          destinations: destinations,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      drawer: NavigationDrawer(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(index);
          Navigator.pop(context);
        },
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Text(
              'Excess Budget',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...destinations.map(
            (dest) => NavigationDrawerDestination(
              icon: dest.icon,
              selectedIcon: dest.selectedIcon,
              label: Text(dest.label),
            ),
          ),
        ],
      ),
      body: navigationShell,
    );
  }
}
