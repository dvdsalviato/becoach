import 'package:flutter/material.dart';

import '../../db.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../util.dart';
import '../athlete/history_page.dart';
import '../common/body_map.dart' show weekStart;
import '../common/progress_gauge.dart';
import '../common/session_detail_page.dart';
import '../common/widgets.dart';
import 'contact_form.dart';
import 'plan_editor_page.dart';

class ClientDetailPage extends StatefulWidget {
  final AppUser me;
  final AppUser client;
  final Contact? contact;
  const ClientDetailPage({super.key, required this.me, required this.client, this.contact});

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> {
  late final Stream<List<Plan>> _plans = Db.plansForClient(widget.me.uid, widget.client.uid);
  late final Stream<List<Session>> _sessions =
      Db.sessionsForClient(widget.me.uid, widget.client.uid);

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    final sub = [
      if (c.age != null) '${c.age} anni',
      if (c.weightKg != null) '${fmtNum(c.weightKg)} kg',
      if (c.heightCm != null) '${fmtNum(c.heightCm)} cm',
    ].join(' · ');

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text('Cliente'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(120),
            child: Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    child: Row(
                      children: [
                        Avatar(c.initials, size: 52),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name,
                                  style: const TextStyle(
                                      fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                              const SizedBox(height: 3),
                              Text(sub.isEmpty ? c.email : sub,
                                  style: const TextStyle(fontSize: 13, color: BC.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: BC.ink,
                    unselectedLabelColor: BC.muted,
                    indicatorColor: BC.steel,
                    dividerColor: BC.border,
                    labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                    tabs: [
                      Tab(text: 'Panoramica'),
                      Tab(text: 'Schede'),
                      Tab(text: 'Storico'),
                      Tab(text: 'Anagrafica'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        body: StreamBuilder<List<Plan>>(
          stream: _plans,
          builder: (context, ps) {
            return StreamBuilder<List<Session>>(
              stream: _sessions,
              builder: (context, ss) {
                if (ps.hasError) return ErrorBox(ps.error);
                if (ss.hasError) return ErrorBox(ss.error);
                if (!ps.hasData || !ss.hasData) return const Loading();
                final plans = ps.data!;
                final sessions = ss.data!;
                return TabBarView(
                  children: [
                    _Overview(me: widget.me, client: c, plans: plans, sessions: sessions),
                    _PlansTab(me: widget.me, client: c, plans: plans),
                    HistoryView(me: widget.me, sessions: sessions),
                    ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                      children: [
                        ContactForm(
                          coachId: widget.me.uid,
                          contact: widget.contact ??
                              Contact(
                                firstName: c.firstName.isNotEmpty ? c.firstName : c.name,
                                lastName: c.lastName,
                                phone: c.phone,
                                email: c.email,
                                linkedUid: c.uid,
                              ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  final AppUser me;
  final AppUser client;
  final List<Plan> plans;
  final List<Session> sessions;
  const _Overview(
      {required this.me, required this.client, required this.plans, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final active = plans.where((p) => p.active).firstOrNull;
    final live = sessions.where((s) => s.isLive).firstOrNull;
    final planSessions = active == null
        ? <Session>[]
        : sessions.where((s) => s.planId == active.id && !s.isLive).toList();
    final lastReordered = sessions.where((s) => !s.isLive && s.reordered).firstOrNull;

    // grafico: primo esercizio della scheda attiva con dati
    String? chartName;
    List<double> chart = [];
    if (active != null) {
      outer:
      for (final d in active.days) {
        for (final e in d.exercises) {
          final series = bestSeries(sessions, e.exerciseId);
          if (series.length >= 2) {
            chartName = e.name;
            chart = series.length > 10 ? series.sublist(series.length - 10) : series;
            break outer;
          }
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        if (live != null) ...[
          Panel(
            color: BC.graphite,
            borderColor: BC.graphite,
            onTap: () => Navigator.push(
              context,
              pageRoute((_) => SessionDetailPage(me: me, sessionId: live.id)),
            ),
            child: Row(
              children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration:
                        const BoxDecoration(color: Color(0xFF9FB8CF), shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('In allenamento ora · ${live.dayName}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                          '${live.doneSets} serie su ${live.totalSets}${live.startedAt != null ? ' · iniziato alle ${fmtTime(live.startedAt!)}' : ''}',
                          style: const TextStyle(color: Color(0xFFC9D1DA), fontSize: 13)),
                    ],
                  ),
                ),
                const Text('Segui',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Builder(builder: (context) {
          final planned = (active?.days.length ?? 0) > 0 ? active!.days.length : 3;
          final w = weekStats(sessions, weekStart());
          return Panel(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('OBIETTIVO SETTIMANA',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.6, color: BC.muted)),
                    ),
                    Text('${w.done} di $planned', style: const TextStyle(fontSize: 12.5, color: BC.muted)),
                  ],
                ),
                SpeedGauge(value: w.done / planned, width: 230),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        Panel(
          child: active == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Nessuna scheda attiva',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text('Crea una scheda nella sezione Schede: il cliente la vedrà subito.',
                        style: TextStyle(fontSize: 13, color: BC.muted, height: 1.4)),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => newPlanFlow(context, me, client),
                      child: const Text('Crea scheda'),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Scheda attiva',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                        const Icon(Icons.lock_outline, size: 14, color: BC.muted),
                        const SizedBox(width: 4),
                        const Text('Bloccata per il cliente',
                            style: TextStyle(fontSize: 12, color: BC.muted)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${active.name} · ${active.days.length} giorni',
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: _progress(active, planSessions.length),
                        backgroundColor: BC.avatar,
                        color: BC.graphite,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                        '${planSessions.length} sessioni su ${active.weeks * active.days.length} previste (${active.weeks} settimane)',
                        style: const TextStyle(fontSize: 12, color: BC.muted)),
                    if (lastReordered != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: BC.subtle, borderRadius: BorderRadius.circular(3)),
                        child: Row(
                          children: [
                            const Icon(Icons.swap_vert, size: 16, color: BC.muted),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                  '${lastReordered.startedAt != null ? relDay(lastReordered.startedAt!) : 'Di recente'} ha cambiato l\'ordine degli esercizi (${lastReordered.dayName}).',
                                  style: const TextStyle(fontSize: 13, color: BC.body)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
        if (chartName != null) ...[
          const SizedBox(height: 12),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('$chartName · serie migliore',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                    Text(_delta(chart),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600, color: BC.steel)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(height: 64, child: _Bars(values: chart)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${fmtNum(chart.first)} kg',
                        style: const TextStyle(fontSize: 12, color: BC.muted)),
                    Text('${fmtNum(chart.last)} kg',
                        style: const TextStyle(fontSize: 12, color: BC.muted)),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _NotesPanel(coachId: me.uid, athleteId: client.uid),
        if (client.goal.isNotEmpty) ...[
          const SizedBox(height: 12),
          Panel(
            child: Row(
              children: [
                const Text('Obiettivo',
                    style: TextStyle(fontSize: 13, color: BC.muted, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(client.goal,
                        textAlign: TextAlign.right, style: const TextStyle(fontSize: 14))),
              ],
            ),
          ),
        ],
      ],
    );
  }

  double _progress(Plan p, int done) {
    final total = p.weeks * p.days.length;
    if (total <= 0) return 0;
    return (done / total).clamp(0.0, 1.0);
  }

  String _delta(List<double> v) {
    final d = v.last - v.first;
    final s = fmtNum(d.abs());
    if (d > 0) return '+$s kg';
    if (d < 0) return '−$s kg';
    return '=';
  }
}

class _Bars extends StatelessWidget {
  final List<double> values;
  const _Bars({required this.values});

  @override
  Widget build(BuildContext context) {
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < values.length; i++) ...[
          Expanded(
            child: Container(
              height: 16 + (values[i] - minV) / range * 48,
              decoration: BoxDecoration(
                color: i == values.length - 1 ? BC.steel : const Color(0xFFCBD5DF),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ),
          ),
          if (i < values.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _NotesPanel extends StatefulWidget {
  final String coachId;
  final String athleteId;
  const _NotesPanel({required this.coachId, required this.athleteId});

  @override
  State<_NotesPanel> createState() => _NotesPanelState();
}

class _NotesPanelState extends State<_NotesPanel> {
  late final Stream<String> _stream = Db.noteStream(widget.coachId, widget.athleteId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: _stream,
      builder: (context, s) {
        final text = s.data ?? '';
        return Panel(
          onTap: () async {
            final res = await askText(context,
                title: 'Appunti privati', initial: text, hint: 'Solo tu li vedi', maxLines: 6);
            if (res != null) await Db.saveNote(widget.coachId, widget.athleteId, res.trim());
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Text('Appunti privati',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  Tag('Visibili solo a te'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                text.isEmpty ? 'Tocca per scrivere note su infortuni, preferenze, motivazione…' : text,
                style: TextStyle(
                    fontSize: 14, height: 1.45, color: text.isEmpty ? BC.disabled : BC.body),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlansTab extends StatelessWidget {
  final AppUser me;
  final AppUser client;
  final List<Plan> plans;
  const _PlansTab({required this.me, required this.client, required this.plans});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        plans.isEmpty
            ? const EmptyState(
                icon: Icons.assignment_outlined,
                title: 'Nessuna scheda',
                text: 'Crea la prima scheda, da zero o partendo da un tuo modello.')
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
                itemCount: plans.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (c, i) {
                  final p = plans[i];
                  return Panel(
                    padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                    onTap: () => Navigator.push(
                      context,
                      pageRoute((_) => PlanEditorPage(
                            me: me, plan: p.copy(), isTemplate: false, clientName: client.name),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(p.name,
                                        style: const TextStyle(
                                            fontSize: 15, fontWeight: FontWeight.w600)),
                                  ),
                                  if (p.active) ...[
                                    const SizedBox(width: 8),
                                    const Tag.steel('Attiva'),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                  '${p.days.length} giorni · ${p.exerciseCount} esercizi${p.updatedAt != null ? ' · modificata ${fmtDate(p.updatedAt!)}' : ''}',
                                  style: const TextStyle(fontSize: 13, color: BC.muted)),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'active') {
                              await Db.setPlanActive(p);
                              if (context.mounted) toast(context, 'Scheda attivata');
                            } else if (v == 'template') {
                              final t = p.copy()
                                ..id = ''
                                ..athleteId = '';
                              await Db.saveTemplate(t);
                              if (context.mounted) toast(context, 'Salvata tra i modelli');
                            } else if (v == 'delete') {
                              if (await confirm(context, 'Elimina scheda',
                                  'La scheda "${p.name}" verrà eliminata. Lo storico degli allenamenti resta.',
                                  ok: 'Elimina', danger: true)) {
                                await Db.deletePlan(p.id);
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            if (!p.active)
                              const PopupMenuItem(value: 'active', child: Text('Imposta come attiva')),
                            const PopupMenuItem(value: 'template', child: Text('Salva come modello')),
                            const PopupMenuItem(value: 'delete', child: Text('Elimina')),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            heroTag: 'newPlan',
            onPressed: () => newPlanFlow(context, me, client),
            icon: const Icon(Icons.add),
            label: const Text('Nuova scheda'),
          ),
        ),
      ],
    );
  }
}

/// Chiede se partire da zero o da un modello, poi apre l'editor.
Future<void> newPlanFlow(BuildContext context, AppUser me, AppUser client) async {
  final templates = await Db.templatesRef(me.uid).get();
  final list = templates.docs.map(Plan.fromDoc).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  if (!context.mounted) return;

  final picked = await showModalBottomSheet<Plan>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.7),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            const Text('Nuova scheda',
                style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Panel(
              onTap: () => Navigator.pop(
                c,
                Plan(
                  coachId: me.uid,
                  athleteId: client.uid,
                  name: 'Nuova scheda',
                  days: [PlanDay(name: 'Giorno A')],
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add, color: BC.steel),
                  SizedBox(width: 12),
                  Text('Da zero', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SectionLabel('Dai tuoi modelli'),
            if (list.isEmpty)
              const Text('Non hai ancora modelli. Puoi crearli nella sezione Modelli.',
                  style: TextStyle(color: BC.muted, fontSize: 13)),
            for (final t in list) ...[
              Panel(
                onTap: () {
                  final p = t.copy()
                    ..id = ''
                    ..coachId = me.uid
                    ..athleteId = client.uid
                    ..active = true;
                  Navigator.pop(c, p);
                },
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, color: BC.muted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          Text('${t.days.length} giorni · ${t.exerciseCount} esercizi',
                              style: const TextStyle(fontSize: 12, color: BC.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  await Navigator.push(
    context,
    pageRoute((_) =>
          PlanEditorPage(me: me, plan: picked, isTemplate: false, clientName: client.name),
    ),
  );
}
