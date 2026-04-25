import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../breakpoints.dart';

class AdaptiveScaffold extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  final List<NavigationDestination> destinations;

  const AdaptiveScaffold({
    super.key,
    required this.navigationShell,
    required this.destinations,
  });

  @override
  State<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends State<AdaptiveScaffold> {
  bool _isExtended = false;

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
    final title = _getTitle(widget.navigationShell.currentIndex);

    if (screenType == ScreenType.compact) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: widget.navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: (index) =>
              widget.navigationShell.goBranch(index),
          destinations: widget.destinations,
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: _isExtended,
            labelType: _isExtended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.none,
            minExtendedWidth: 200,
            selectedIndex: widget.navigationShell.currentIndex,
            onDestinationSelected: (index) =>
                widget.navigationShell.goBranch(index),
            leading: Column(
              children: [
                const SizedBox(height: 8),
                IconButton(
                  icon: Icon(_isExtended ? Icons.menu_open : Icons.menu),
                  onPressed: () => setState(() => _isExtended = !_isExtended),
                ),
                if (_isExtended) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'EXCESS BUDGET',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            destinations: widget.destinations
                .map(
                  (dest) => NavigationRailDestination(
                    icon: dest.icon,
                    selectedIcon: dest.selectedIcon,
                    label: Text(dest.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Scaffold(
              appBar: AppBar(title: Text(title), centerTitle: false),
              body: widget.navigationShell,
            ),
          ),
        ],
      ),
    );
  }
}
