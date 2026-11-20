import 'package:flutter/material.dart';

import '../../models.dart';
import '../../notifications.dart';
import '../../updates.dart';
import '../common/adaptive_shell.dart';
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
      Notifs.setup().then((_) => backgroundCheck());
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
      child: AdaptiveShell(
        tab: _tab,
        onTab: (i) => setState(() => _tab = i),
        items: [
          ShellItem(icon: Icons.fitness_center, label: 'Oggi', page: TodayPage(me: me, scroll: _homeScroll)),
          ShellItem(icon: Icons.show_chart, label: 'Storico', page: HistoryPage(me: me)),
          ShellItem(icon: Icons.format_list_bulleted, label: 'Esercizi', page: ExercisesPage(me: me)),
          ShellItem(
              icon: Icons.person_outline,
              label: 'Profilo',
              page: ProfilePage(key: ValueKey('p-${me.uid}-${me.coachId}'), me: me)),
        ],
      ),
    );
  }
}
