import 'package:flutter/material.dart';

import '../../models.dart';
import '../../notifications.dart';
import '../../updates.dart';
import '../common/back_handler.dart';
import '../common/profile_page.dart';
import 'agenda_page.dart';
import 'clients_page.dart';
import 'home_page.dart';
import 'library_page.dart';

class CoachShell extends StatefulWidget {
  final AppUser me;
  const CoachShell({super.key, required this.me});

  @override
  State<CoachShell> createState() => _CoachShellState();
}

class _CoachShellState extends State<CoachShell> {
  int _tab = 0;
  final _homeScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Updates.checkOnStart(context);
      Notifs.setup().then((_) => backgroundCheck());
    });
  }

  @override
  void dispose() {
    _homeScroll.dispose();
    super.dispose();
  }

  void _setTab(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    return ShellBackHandler(
      tab: _tab,
      setTab: _setTab,
      homeScroll: _homeScroll,
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [
            CoachHomePage(me: me, scroll: _homeScroll, openTab: _setTab),
            ClientsPage(me: me),
            AgendaPage(me: me),
            LibraryPage(me: me),
            ProfilePage(key: ValueKey('c-${me.uid}-${me.coachInviteCode}'), me: me),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE2E4E7)))),
          child: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: _setTab,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Clienti'),
              NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'Agenda'),
              NavigationDestination(icon: Icon(Icons.description_outlined), label: 'Schede'),
              NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profilo'),
            ],
          ),
        ),
      ),
    );
  }
}
