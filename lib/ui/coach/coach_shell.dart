import 'package:flutter/material.dart';

import '../../models.dart';
import '../common/exercises_page.dart';
import '../common/profile_page.dart';
import 'agenda_page.dart';
import 'clients_page.dart';
import 'templates_page.dart';

class CoachShell extends StatefulWidget {
  final AppUser me;
  const CoachShell({super.key, required this.me});

  @override
  State<CoachShell> createState() => _CoachShellState();
}

class _CoachShellState extends State<CoachShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          ClientsPage(me: me),
          AgendaPage(me: me),
          TemplatesPage(me: me),
          ExercisesPage(me: me),
          ProfilePage(key: ValueKey('c-${me.uid}-${me.coachInviteCode}'), me: me),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE2E4E7)))),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Clienti'),
            NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'Agenda'),
            NavigationDestination(icon: Icon(Icons.description_outlined), label: 'Modelli'),
            NavigationDestination(icon: Icon(Icons.format_list_bulleted), label: 'Esercizi'),
            NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profilo'),
          ],
        ),
      ),
    );
  }
}
