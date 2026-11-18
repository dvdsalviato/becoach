import 'package:flutter/material.dart';

import '../../models.dart';
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

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          TodayPage(me: me),
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
    );
  }
}
