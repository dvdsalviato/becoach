import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../db.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../util.dart';
import 'exercises_page.dart';
import 'widgets.dart';

/// Riepilogo di un allenamento, visibile sia al coach sia all'allenato.
class SessionDetailPage extends StatelessWidget {
  final AppUser me;
  final String sessionId;
  const SessionDetailPage({super.key, required this.me, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Session?>(
      stream: Db.sessionStream(sessionId),
      builder: (context, snap) {
        if (snap.hasError) return Scaffold(appBar: AppBar(), body: ErrorBox(snap.error));
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: snap.connectionState == ConnectionState.waiting
                ? const Loading()
                : const EmptyState(
                    icon: Icons.delete_outline,
                    title: 'Allenamento eliminato',
                    text: 'Questo allenamento non esiste più.'),
          );
        }
        final s = snap.data!;
        final isMine = s.athleteId == me.uid;
        return Scaffold(
          appBar: AppBar(
            title: Text(s.dayName),
            actions: [
              if (isMine && !s.isLive)
                IconButton(
                  tooltip: 'Elimina',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirm(context, 'Elimina allenamento',
                        'L\'allenamento verrà cancellato anche per il coach.',
                        ok: 'Elimina', danger: true)) {
                      await Db.deleteSession(s.id);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Text(
                [
                  if (!isMine) s.athleteName,
                  s.planName,
                  if (s.startedAt != null) '${fmtDate(s.startedAt!)} · ${fmtTime(s.startedAt!)}',
                ].where((e) => e.isNotEmpty).join(' · '),
                style: const TextStyle(color: BC.muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _stat('Serie', '${s.doneSets}/${s.totalSets}')),
                  const SizedBox(width: 8),
                  Expanded(child: _stat('Volume', '${fmtNum(s.volume.round())} kg')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _stat('Durata',
                          s.isLive ? 'in corso' : (s.duration == null ? '—' : fmtDuration(s.duration!)))),
                ],
              ),
              if (s.reordered) ...[
                const SizedBox(height: 10),
                Panel(
                  color: BC.subtle,
                  padding: const EdgeInsets.all(12),
                  child: const Row(
                    children: [
                      Icon(Icons.swap_vert, size: 18, color: BC.muted),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('L\'ordine degli esercizi è stato cambiato durante l\'allenamento.',
                            style: TextStyle(fontSize: 13, color: BC.body)),
                      ),
                    ],
                  ),
                ),
              ],
              for (final e in s.exercises) ...[
                const SizedBox(height: 10),
                Panel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        onTap: () => openExercise(context, me,
                            exerciseId: e.exerciseId,
                            name: e.name,
                            machine: e.machine,
                            notes: e.notes,
                            videoUrl: e.videoUrl),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.name,
                                        style: const TextStyle(
                                            fontSize: 15, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text('Obiettivo ${e.targetSets} × ${e.targetReps}',
                                        style: const TextStyle(fontSize: 12, color: BC.muted)),
                                  ],
                                ),
                              ),
                              Text('${e.doneSets}/${e.sets.length}',
                                  style: const TextStyle(fontSize: 12, color: BC.muted)),
                            ],
                          ),
                        ),
                      ),
                      for (var i = 0; i < e.sets.length; i++)
                        Container(
                          decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: Color(0xFFECEEF0)))),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          child: Row(
                            children: [
                              SizedBox(
                                  width: 28,
                                  child: Text('${i + 1}',
                                      style: const TextStyle(fontWeight: FontWeight.w600))),
                              Expanded(
                                child: Text(e.sets[i].done ? e.sets[i].label : 'non fatta',
                                    style: TextStyle(
                                        color: e.sets[i].done ? BC.ink : BC.disabled,
                                        fontFeatures: const [FontFeature.tabularFigures()])),
                              ),
                              if (i < e.prev.length)
                                Text('prima ${e.prev[i]}',
                                    style: const TextStyle(fontSize: 12, color: BC.muted)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
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
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

/// Riga riassuntiva di un allenamento nelle liste dello storico.
class SessionTile extends StatelessWidget {
  final Session s;
  final VoidCallback onTap;
  const SessionTile({super.key, required this.s, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.dayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  '${s.startedAt == null ? '' : relDay(s.startedAt!)} · ${s.doneSets} serie · ${fmtNum(s.volume.round())} kg',
                  style: const TextStyle(fontSize: 13, color: BC.muted),
                ),
              ],
            ),
          ),
          if (s.isLive) const LiveTag(),
          if (!s.isLive && s.reordered) const Icon(Icons.swap_vert, size: 18, color: BC.muted),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: BC.muted),
        ],
      ),
    );
  }
}
