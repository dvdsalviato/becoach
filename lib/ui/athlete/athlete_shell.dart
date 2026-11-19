import 'package:flutter/material.dart';

import '../../models.dart';
import '../../updates.dart';
import '../common/back_handler.dart';
import '../common/exercises_page.dart';
import '../common/profile_page.dart';
import 'history_page.dart';
import 'today_page.dart';

class AthleteShell extends StatefulWidget {
  final AppUser me;
  const AthleteShell({super.key, required this.me});

  @override
  State<AthleteShell> createState() => _AthleteShellState();
}

class _AthleteShellState extends State<AthleteShell> {
  int _tab = 0;
  final _homeScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Updates.checkOnStart(context);
    });
  }

  @override
  void dispose() {
    _homeScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    return ShellBackHandler(
      tab: _tab,
      setTab: (i) => setState(() => _tab = i),
      homeScroll: _homeScroll,
      child: Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          TodayPage(me: me, scroll: _homeScroll),
          HistoryPage(me: me),
          ExercisesPage(me: me),
          ProfilePage(key: ValueKey('p-${me.uid}-${me.coachId}'), me: me),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE2E4E7)))),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Oggi'),
            NavigationDestination(icon: Icon(Icons.show_chart), label: 'Storico'),
            NavigationDestination(icon: Icon(Icons.format_list_bulleted), label: 'Esercizi'),
            NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profilo'),
          ],
        ),
      ),
      ),
    );
  }
}
