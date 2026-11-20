import 'package:flutter/material.dart';

import '../../models.dart';
import '../../notifications.dart';
import '../../updates.dart';
import '../common/adaptive_shell.dart';
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
      child: AdaptiveShell(
        tab: _tab,
        onTab: _setTab,
        items: [
          ShellItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'Home',
              page: CoachHomePage(me: me, scroll: _homeScroll, openTab: _setTab)),
          ShellItem(icon: Icons.groups_outlined, label: 'Clienti', page: ClientsPage(me: me), fullWidth: true),
          ShellItem(icon: Icons.calendar_month_outlined, label: 'Agenda', page: AgendaPage(me: me), fullWidth: true),
          ShellItem(icon: Icons.description_outlined, label: 'Schede', page: LibraryPage(me: me)),
          ShellItem(
              icon: Icons.person_outline,
              label: 'Profilo',
              page: ProfilePage(key: ValueKey('c-${me.uid}-${me.coachInviteCode}'), me: me)),
        ],
      ),
    );
  }
}
