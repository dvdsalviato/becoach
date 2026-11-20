import 'package:flutter/material.dart';

import '../../db.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../util.dart';
import '../common/session_detail_page.dart';
import '../common/widgets.dart';
import 'agenda_page.dart';
import 'clients_page.dart';

/// Home del coach: la giornata, chi si sta allenando, cosa c'è da fare.
class CoachHomePage extends StatefulWidget {
  final AppUser me;
  final ScrollController scroll;
  final ValueChanged<int> openTab;
  const CoachHomePage({super.key, required this.me, required this.scroll, required this.openTab});

  @override
  State<CoachHomePage> createState() => _CoachHomePageState();
}

class _CoachHomePageState extends State<CoachHomePage> {
  late final Stream<List<AppUser>> _clients = Db.clientsStream(widget.me.uid);
  late final Stream<List<Contact>> _contacts = Db.contactsStream(widget.me.uid);
  late final Stream<List<Session>> _sessions = Db.sessionsForCoach(widget.me.uid);
  late final Stream<List<Plan>> _plans = Db.plansForCoach(widget.me.uid);
  late final Stream<List<Appointment>> _appts = Db.appointmentsStream(widget.me.uid);
  late final Stream<List<AppointmentRequest>> _requests = Db.requestsStream(widget.me.uid);

  void _openSessions(String title, bool Function(Session) test) {
    Navigator.push(
      context,
      pageRoute((_) => CoachSessionsPage(me: widget.me, title: title, test: test)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final first = me.firstName.isNotEmpty ? me.firstName : me.name.split(' ').first;
    return SafeArea(
      child: StreamBuilder<List<AppUser>>(
        stream: _clients,
        builder: (context, us) => StreamBuilder<List<Contact>>(
          stream: _contacts,
          builder: (context, cs) => StreamBuilder<List<Session>>(
            stream: _sessions,
            builder: (context, ss) => StreamBuilder<List<Plan>>(
              stream: _plans,
              builder: (context, ps) => StreamBuilder<List<Appointment>>(
                stream: _appts,
                builder: (context, aps) => StreamBuilder<List<AppointmentRequest>>(
                stream: _requests,
                builder: (context, rqs) {
                  final pendingReq = (rqs.data ?? []).where((r) => r.pending).toList();
                  final users = us.data ?? [];
                  final entries = mergeClients(cs.data ?? [], users);
                  final sessions = ss.data ?? [];
                  final plans = ps.data ?? [];
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final weekAgo = now.subtract(const Duration(days: 7));
                  final monthAgo = now.subtract(const Duration(days: 30));
                  final todayAppts = (aps.data ?? [])
                      .where((a) => !a.start.isBefore(today) && a.start.isBefore(today.add(const Duration(days: 1))))
                      .toList();
                  final live = sessions.where((s) => s.isLive).toList();
                  final week = sessions
                      .where((s) => !s.isLive && s.startedAt != null && s.startedAt!.isAfter(weekAgo))
                      .length;
                  final withPlan = plans.where((p) => p.active).map((p) => p.athleteId).toSet();
                  final noPlan = users.where((u) => !withPlan.contains(u.uid)).toList();
                  final activeIds = sessions
                      .where((s) => s.startedAt != null && s.startedAt!.isAfter(monthAgo))
                      .map((s) => s.athleteId)
                      .toSet();
                  final inactive = users.where((u) => !activeIds.contains(u.uid)).toList();

                  return ListView(
                    controller: widget.scroll,
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      PageHeader(overline: fmtDate(now), title: 'Ciao $first'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: _stat('Clienti', '${entries.length}', () => widget.openTab(1))),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _stat('Allenamenti 7 gg', '$week', () {
                                    _openSessions('Allenamenti degli ultimi 7 giorni', (s) =>
                                        !s.isLive && s.startedAt != null && s.startedAt!.isAfter(weekAgo));
                                  }),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _stat('Live ora', '${live.length}',
                                      () => _openSessions('In allenamento ora', (s) => s.isLive)),
                                ),
                              ],
                            ),
                            if (pendingReq.isNotEmpty) ...[
                              SectionLabel('Richieste di appuntamento · ${pendingReq.length}'),
                              for (final r in pendingReq) _requestCard(r, entries),
                            ],
                            SectionLabel('Oggi in agenda',
                                trailing: TextButton(onPressed: () => widget.openTab(2), child: const Text('Agenda'))),
                            if (todayAppts.isEmpty)
                              Panel(
                                onTap: () => widget.openTab(2),
                                child: const Text('Nessun appuntamento oggi.',
                                    style: TextStyle(fontSize: 14, color: BC.muted)),
                              )
                            else
                              for (final a in todayAppts) _apptRow(a),
                            if (live.isNotEmpty) ...[
                              const SectionLabel('In allenamento ora'),
                              for (final s in live)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: SessionTile(
                                    s: s,
                                    showAthlete: true,
                                    onTap: () => Navigator.push(
                                      context,
                                      pageRoute((_) => SessionDetailPage(me: me, sessionId: s.id)),
                                    ),
                                  ),
                                ),
                            ],
                            if (noPlan.isNotEmpty || inactive.isNotEmpty) ...[
                              const SectionLabel('Da fare'),
                              if (noPlan.isNotEmpty)
                                _todo(Icons.assignment_late_outlined,
                                    '${noPlan.length} ${noPlan.length == 1 ? 'cliente senza' : 'clienti senza'} scheda attiva',
                                    noPlan.map((u) => u.name).take(4).join(', '), entries, noPlan),
                              if (inactive.isNotEmpty)
                                _todo(Icons.schedule,
                                    '${inactive.length} ${inactive.length == 1 ? 'cliente fermo' : 'clienti fermi'} da più di 30 giorni',
                                    inactive.map((u) => u.name).take(4).join(', '), entries, inactive),
                            ],
                            const SectionLabel('Azioni rapide'),
                            Row(
                              children: [
                                Expanded(
                                  child: _action(Icons.person_add_alt, 'Nuovo cliente',
                                      () => newClientFlow(context, me)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _action(Icons.qr_code_2, 'Invita', () => showInviteSheet(context, me)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _action(Icons.event_outlined, 'Appuntamento', () => widget.openTab(2)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _approve(AppointmentRequest r, List<ClientEntry> entries) async {
    final entry = entries.firstWhere((e) => e.user?.uid == r.athleteId,
        orElse: () => ClientEntry(Contact(firstName: r.athleteName), null));
    final now = DateTime.now();
    final appt = Appointment(
      coachId: widget.me.uid,
      title: r.type,
      notes: [if (r.availability.isNotEmpty) 'Disponibilità: ${r.availability}', if (r.note.isNotEmpty) r.note].join('\n'),
      start: DateTime(now.year, now.month, now.day + 1, 9),
      clientId: r.athleteId,
      contactId: entry.contact?.id ?? '',
      clientName: entry.name,
      clientEmail: entry.email,
    );
    await openAppointmentEditor(context, widget.me, entries, appt, onSaved: (a) {
      Db.updateRequest(r, {'status': 'approved', 'appointmentId': a.id});
    });
  }

  Widget _requestCard(AppointmentRequest r, List<ClientEntry> entries) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        borderColor: BC.steelLight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.event_note_outlined, color: BC.steel, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${r.athleteName} chiede: ${r.type}',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            if (r.availability.isNotEmpty || r.note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                [if (r.availability.isNotEmpty) 'Disponibilità: ${r.availability}', if (r.note.isNotEmpty) r.note]
                    .join('\n'),
                style: const TextStyle(fontSize: 13, color: BC.body, height: 1.35),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      if (await confirm(context, 'Rifiuta richiesta', 'Rifiutare la richiesta di ${r.athleteName}?',
                          ok: 'Rifiuta', danger: true)) {
                        await Db.updateRequest(r, {'status': 'declined'});
                      }
                    },
                    child: const Text('Rifiuta'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(onPressed: () => _approve(r, entries), child: const Text('Fissa data')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _apptRow(Appointment a) {
    final c = categorize('${a.title} ${a.notes}', a.category);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), side: const BorderSide(color: BC.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.openTab(2),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: c.color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 50,
                          child: Text(fmtTime(a.start),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                              if (a.clientName.isNotEmpty)
                                Text(a.clientName, style: const TextStyle(fontSize: 12.5, color: BC.muted)),
                            ],
                          ),
                        ),
                        Text(c.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.color)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _todo(IconData icon, String title, String names, List<ClientEntry> entries, List<AppUser> users) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        onTap: () {
          if (users.length == 1) {
            final e = entries.firstWhere((x) => x.user?.uid == users.first.uid,
                orElse: () => ClientEntry(null, users.first));
            openClient(context, widget.me, e);
          } else {
            widget.openTab(1);
          }
        },
        child: Row(
          children: [
            Icon(icon, color: BC.warnFg),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(names, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: BC.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: BC.muted),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) => Panel(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: BC.steel),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _stat(String label, String value, VoidCallback onTap) => Panel(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: BC.muted, letterSpacing: 0.4)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                const Icon(Icons.chevron_right, size: 18, color: BC.muted),
              ],
            ),
          ],
        ),
      );
}

class CoachSessionsPage extends StatefulWidget {
  final AppUser me;
  final String title;
  final bool Function(Session) test;
  const CoachSessionsPage({super.key, required this.me, required this.title, required this.test});

  @override
  State<CoachSessionsPage> createState() => _CoachSessionsPageState();
}

class _CoachSessionsPageState extends State<CoachSessionsPage> {
  late final Stream<List<Session>> _stream = Db.sessionsForCoach(widget.me.uid);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: StreamBuilder<List<Session>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return ErrorBox(snap.error);
          if (!snap.hasData) return const Loading();
          final list = snap.data!.where(widget.test).toList();
          if (list.isEmpty) {
            return const EmptyState(icon: Icons.history, title: 'Nessun allenamento', text: 'Qui non c\'è ancora niente.');
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (c, i) => SessionTile(
              s: list[i],
              showAthlete: true,
              onTap: () => Navigator.push(
                context,
                pageRoute((_) => SessionDetailPage(me: widget.me, sessionId: list[i].id)),
              ),
            ),
          );
        },
      ),
    );
  }
}
