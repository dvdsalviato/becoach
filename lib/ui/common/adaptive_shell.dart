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
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: BC.border)),
            ),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => onTab(i),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(4, 9, 4, 10),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: i == tab ? BC.steel : Colors.transparent, width: 2.5),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(i == tab ? (items[i].selectedIcon ?? items[i].icon) : items[i].icon,
                                size: 23, color: i == tab ? BC.ink : BC.muted),
                            const SizedBox(height: 3),
                            Text(items[i].label,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: i == tab ? FontWeight.w700 : FontWeight.w500,
                                  color: i == tab ? BC.ink : BC.muted,
                                )),
                          ],
                        ),
                      ),
                    ),
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
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset('assets/logo.png', width: 44, height: 44),
                    ),
                    if (extended) ...[
                      const SizedBox(width: 12),
                      const Text('BeCoach', style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
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
