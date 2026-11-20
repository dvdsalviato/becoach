import 'package:flutter/material.dart';

import '../../theme.dart';
import 'widgets.dart';

class ShellItem {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final Widget page;
  final bool fullWidth; // su desktop usa tutta la larghezza (es. agenda, clienti)
  const ShellItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
    required this.page,
    this.fullWidth = false,
  });
}

/// Telefono: menu in basso. Schermo largo (PC, tablet in orizzontale): menu laterale.
class AdaptiveShell extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTab;
  final List<ShellItem> items;
  const AdaptiveShell({super.key, required this.tab, required this.onTab, required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= wideBreakpoint;
      final stack = IndexedStack(
        index: tab,
        children: [
          for (final it in items) wide && !it.fullWidth ? Readable(child: it.page) : it.page,
        ],
      );
      if (!wide) {
        return Scaffold(
          body: stack,
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: BC.border))),
            child: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: onTab,
              destinations: [
                for (final it in items)
                  NavigationDestination(
                    icon: Icon(it.icon),
                    selectedIcon: it.selectedIcon == null ? null : Icon(it.selectedIcon),
                    label: it.label,
                  ),
              ],
            ),
          ),
        );
      }
      final extended = c.maxWidth >= 1200;
      return Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NavigationRail(
              selectedIndex: tab,
              onDestinationSelected: onTab,
              extended: extended,
              minExtendedWidth: 220,
              labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(8, 20, 8, 24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset('assets/logo.png', width: 44, height: 44),
                    ),
                    if (extended) ...[
                      const SizedBox(width: 12),
                      const Text('BeCoach', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ),
              destinations: [
                for (final it in items)
                  NavigationRailDestination(
                    icon: Icon(it.icon),
                    selectedIcon: Icon(it.selectedIcon ?? it.icon),
                    label: Text(it.label),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1, color: BC.border),
            Expanded(child: stack),
          ],
        ),
      );
    });
  }
}
