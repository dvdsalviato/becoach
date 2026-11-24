import 'package:flutter/material.dart';

import '../../db.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../util.dart';
import '../common/progress_gauge.dart';
import '../common/widgets.dart';
import 'appointments_section.dart';
import 'gym_card.dart';
import 'join_coach.dart';
import 'workout_page.dart';

class TodayPage extends StatefulWidget {
  final AppUser me;
  final ScrollController? scroll;
  const TodayPage({super.key, required this.me, this.scroll});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  late Stream<List<Plan>> _plans;
  late Stream<List<Session>> _sessions;
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _plans = Db.plansForAthlete(widget.me.uid);
    _sessions = Db.sessionsForAthlete(widget.me.uid);
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      final ok = await joinCoachFlow(context, widget.me, _code.text);
      if (ok) _code.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  void _openWorkout(String id) {
    Navigator.push(
      context,
      pageRoute((_) => WorkoutPage(me: widget.me, sessionId: id)),
    );
  }

  Future<void> _start(Plan plan, int dayIndex, Session? live) async {
    if (live != null) {
      final ok = await confirm(context, 'Allenamento in corso',
          'Hai già un allenamento aperto (${live.dayName}). Vuoi riprenderlo?',
          ok: 'Riprendi');
      if (ok) _openWorkout(live.id);
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await Db.startSession(me: widget.me, plan: plan, dayIndex: dayIndex);
      if (mounted) _openWorkout(id);
    } catch (e) {
      if (mounted) toast(context, 'Errore: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final now = DateTime.now();
    return SafeArea(
      child: StreamBuilder<List<Plan>>(
        stream: _plans,
        builder: (context, ps) {
          return StreamBuilder<List<Session>>(
            stream: _sessions,
            builder: (context, ss) {
              if (ps.hasError) return ErrorBox(ps.error);
              if (!ps.hasData) return const Loading();
              final sessions = ss.data ?? [];
              final live = sessions.where((s) => s.isLive).firstOrNull;
              final plan = ps.data!
                  .where((p) => p.active && p.coachId == me.coachId)
                  .firstOrNull;
              final firstName = me.name.split(' ').first;

              return ListView(
                controller: widget.scroll,
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  PageHeader(overline: fmtDate(now), title: 'Ciao $firstName'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (me.gymCard != null) ...[
                          const SizedBox(height: 8),
                          GymCardPanel(key: ValueKey('gct-${me.gymCard?['code']}'), me: me, compact: true),
                        ],
                        if (me.hasCoach) AthleteAppointments(key: ValueKey(me.coachId), me: me),
                        if (live != null) ...[
                          const SizedBox(height: 16),
                          Panel(
                            color: BC.graphite,
                            borderColor: BC.graphite,
                            onTap: () => _openWorkout(live.id),
                            child: Row(
                              children: [
                                Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                        color: Color(0xFF9FB8CF), shape: BoxShape.circle)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Allenamento in corso · ${live.dayName}',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text('${live.doneSets} serie su ${live.totalSets}',
                                          style: const TextStyle(
                                              color: Color(0xFFC9D1DA), fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const Text('Riprendi',
                                    style: TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                        if (!me.hasCoach) ...[
                          const SizedBox(height: 16),
                          Panel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('Collega il tuo coach',
                                    style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 17, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                const Text(
                                    'Inserisci il codice che ti ha dato: vedrai qui la scheda che prepara per te.',
                                    style: TextStyle(color: BC.muted, height: 1.4, fontSize: 14)),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _code,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: const InputDecoration(hintText: 'Codice coach'),
                                ),
                                const SizedBox(height: 10),
                                FilledButton(
                                    onPressed: _busy ? null : _join, child: const Text('Collega')),
                              ],
                            ),
                          ),
                        ] else if (plan == null) ...[
                          const SizedBox(height: 40),
                          EmptyState(
                            icon: Icons.assignment_outlined,
                            title: 'Nessuna scheda attiva',
                            text:
                                '${me.coachName ?? 'Il tuo coach'} non ti ha ancora assegnato una scheda. La vedrai qui appena pronta.',
                          ),
                        ] else ...[
                          const SectionLabel('Scheda attiva'),
                          Text(plan.name,
                              style: const TextStyle(fontFamily: 'Space Grotesk', fontSize: 20, fontWeight: FontWeight.w700)),
                          if (plan.notes.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(plan.notes,
                                style: const TextStyle(
                                    fontSize: 14, color: BC.body, height: 1.4)),
                          ],
                          const SizedBox(height: 4),
                          for (var i = 0; i < plan.days.length; i++) ...[
                            const SizedBox(height: 10),
                            _DayCard(
                              day: plan.days[i],
                              last: _lastFor(sessions, plan, i),
                              busy: _busy,
                              onStart: () => _start(plan, i, live),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  if (me.hasCoach) ...[
                    const SizedBox(height: 28),
                    AthleteProgressHero(sessions: sessions, plan: plan),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  DateTime? _lastFor(List<Session> sessions, Plan plan, int day) {
    for (final s in sessions) {
      if (!s.isLive && s.planId == plan.id && s.dayIndex == day) return s.startedAt;
    }
    return null;
  }
}

class _DayCard extends StatelessWidget {
  final PlanDay day;
  final DateTime? last;
  final bool busy;
  final VoidCallback onStart;
  const _DayCard({required this.day, required this.last, required this.busy, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(day.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              if (last != null)
                Text('Ultima: ${relDay(last!)}', style: const TextStyle(fontSize: 12, color: BC.muted)),
            ],
          ),
          const SizedBox(height: 8),
          for (final e in day.exercises)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                      child: Text(e.name,
                          style: const TextStyle(fontSize: 14, color: BC.body))),
                  Text(e.target,
                      style: const TextStyle(fontSize: 13, color: BC.muted)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy || day.exercises.isEmpty ? null : onStart,
            child: const Text('Inizia allenamento'),
          ),
        ],
      ),
    );
  }
}
