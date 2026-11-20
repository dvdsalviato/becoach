import 'package:flutter/material.dart';

import '../../db.dart';
import '../../models.dart';
import '../../theme.dart';
import '../common/body_map.dart';
import '../common/session_detail_page.dart';
import '../common/widgets.dart';

class HistoryPage extends StatefulWidget {
  final AppUser me;
  const HistoryPage({super.key, required this.me});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final Stream<List<Session>> _stream = Db.sessionsForAthlete(widget.me.uid);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<Session>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return ErrorBox(snap.error);
          if (!snap.hasData) return const Loading();
          final sessions = snap.data!;
          return HistoryView(me: widget.me, sessions: sessions, header: true);
        },
      ),
    );
  }
}

/// Storico + record personali. Usato anche dal coach nella scheda cliente.
class HistoryView extends StatelessWidget {
  final AppUser me;
  final List<Session> sessions;
  final bool header;
  const HistoryView({super.key, required this.me, required this.sessions, this.header = false});

  @override
  Widget build(BuildContext context) {
    final done = sessions.where((s) => !s.isLive).toList();
    final records = computeRecords(done);
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final thisWeek = done.where((s) => s.startedAt != null && s.startedAt!.isAfter(weekAgo)).length;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (header) const PageHeader(overline: 'I tuoi progressi', title: 'Storico'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _stat('Allenamenti', '${done.length}')),
                  const SizedBox(width: 8),
                  Expanded(child: _stat('Ultimi 7 giorni', '$thisWeek')),
                ],
              ),
              const SizedBox(height: 8),
              WeeklyBodyMap(sessions: sessions),
              if (records.isNotEmpty) ...[
                const SectionLabel('Migliori carichi'),
                Panel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < records.length && i < 8; i++)
                        Container(
                          decoration: BoxDecoration(
                            border: i == 0
                                ? null
                                : const Border(top: BorderSide(color: Color(0xFFECEEF0))),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(records[i].name,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              ),
                              Text('${fmtKg(records[i].kg)} kg × ${records[i].reps}',
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w600, color: BC.steel)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SectionLabel('Allenamenti'),
              if (sessions.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: EmptyState(
                      icon: Icons.history,
                      title: 'Ancora nessun allenamento',
                      text: 'Gli allenamenti completati compariranno qui.'),
                ),
              for (final s in sessions) ...[
                SessionTile(
                  s: s,
                  onTap: () => Navigator.push(
                    context,
                    pageRoute((_) => SessionDetailPage(me: me, sessionId: s.id)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, String value) => Panel(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: BC.muted, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontFamily: 'Space Grotesk', fontSize: 20, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class ExerciseRecord {
  final String exerciseId;
  final String name;
  final double kg;
  final int reps;
  final DateTime? date;
  ExerciseRecord(this.exerciseId, this.name, this.kg, this.reps, this.date);
}

List<ExerciseRecord> computeRecords(List<Session> sessions) {
  final best = <String, ExerciseRecord>{};
  for (final s in sessions) {
    for (final e in s.exercises) {
      for (final set in e.sets) {
        if (!set.done || set.kg == null) continue;
        final cur = best[e.exerciseId];
        final reps = set.reps ?? 0;
        if (cur == null || set.kg! > cur.kg || (set.kg! == cur.kg && reps > cur.reps)) {
          best[e.exerciseId] = ExerciseRecord(e.exerciseId, e.name, set.kg!, reps, s.startedAt);
        }
      }
    }
  }
  final list = best.values.toList()
    ..sort((a, b) => (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));
  return list;
}

/// Serie migliore per un esercizio in ogni allenamento, dal più vecchio al più recente.
List<double> bestSeries(List<Session> sessions, String exerciseId) {
  final out = <double>[];
  for (final s in sessions.reversed) {
    if (s.isLive) continue;
    for (final e in s.exercises) {
      if (e.exerciseId == exerciseId && e.bestKg != null) {
        out.add(e.bestKg!);
        break;
      }
    }
  }
  return out;
}

