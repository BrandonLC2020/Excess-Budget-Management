import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../breakpoints.dart';

class AdaptiveScaffold extends StatefulWidget {
  final Widget navigationShell;
  final int currentIndex;
  final List<NavigationDestination> destinations;
  final ValueChanged<int> onDestinationSelected;

  const AdaptiveScaffold({
    super.key,
    required this.navigationShell,
    required this.currentIndex,
    required this.destinations,
    required this.onDestinationSelected,
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
        return 'Transactions';
      case 2:
        return 'Accounts';
      case 3:
        return 'Budget';
      case 4:
        return 'Goals';
      default:
        return 'Excess Budget';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenType = context.screenType;
    final title = _getTitle(widget.currentIndex);

    if (screenType == ScreenType.compact) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline),
              onPressed: () => context.push('/profile'),
              tooltip: 'Profile Settings',
            ),
          ],
        ),
        body: widget.navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.currentIndex,
          onDestinationSelected: widget.onDestinationSelected,
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
            selectedIndex: widget.currentIndex,
            onDestinationSelected: widget.onDestinationSelected,
            leading: _isExtended
                ? SizedBox(
                    width: 200,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.menu_open),
                            onPressed: () =>
                                setState(() => _isExtended = false),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'EXCESS BUDGET',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => setState(() => _isExtended = true),
                    ),
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
              appBar: AppBar(
                title: Text(title),
                centerTitle: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.person_outline),
                    onPressed: () => context.push('/profile'),
                    tooltip: 'Profile Settings',
                  ),
                ],
              ),
              body: widget.navigationShell,
            ),
          ),
        ],
      ),
    );
  }
}
