import 'package:flutter/material.dart';

import '../../models.dart';
import '../../theme.dart';
import '../common/exercises_page.dart';
import '../common/widgets.dart';
import 'templates_page.dart';

/// Area riservata del coach: modelli di schede ed esercizi.
class LibraryPage extends StatelessWidget {
  final AppUser me;
  const LibraryPage({super.key, required this.me});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(overline: 'Area riservata', title: 'Schede'),
            const TabBar(
              labelColor: BC.ink,
              unselectedLabelColor: BC.muted,
              indicatorColor: BC.steel,
              dividerColor: BC.border,
              labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              tabs: [Tab(text: 'Modelli'), Tab(text: 'Esercizi')],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  TemplatesPage(me: me, embedded: true),
                  ExercisesPage(me: me, embedded: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
