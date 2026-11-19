import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../db.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../util.dart';
import '../coach/clients_page.dart';
import 'session_detail_page.dart';
import 'widgets.dart';

/// Profilo: per il coach dati professionali e numeri dell'attività,
/// per l'allenato dati personali e collegamento al coach.
class ProfilePage extends StatelessWidget {
  final AppUser me;
  const ProfilePage({super.key, required this.me});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          PageHeader(overline: me.coachMode ? 'Coach' : 'Allenato', title: 'Profilo'),
          const SizedBox(height: 8),
          Row(
            children: [
              Avatar(me.initials, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(me.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      me.coachMode && me.businessName.isNotEmpty ? me.businessName : me.email,
                      style: const TextStyle(color: BC.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (me.coachMode) ...[
            const SectionLabel('La tua attività'),
            _CoachStats(me: me),
            const SectionLabel('Codice invito per i clienti'),
            _InviteCodePanel(me: me),
            _ContactsSection(me: me),
          ] else ...[
            const SectionLabel('Il tuo coach'),
            _CoachLink(me: me),
            const SectionLabel('Dati personali'),
            _AthleteForm(key: ValueKey('af-${me.uid}'), me: me),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              if (await confirm(context, 'Esci', 'Vuoi uscire dall\'account?', ok: 'Esci')) {
                await Db.signOut();
              }
            },
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Esci dall\'account'),
          ),
          const SizedBox(height: 12),
          _DevTools(me: me),
        ],
      ),
    );
  }
}

// ---------------- Coach ----------------

class _CoachStats extends StatefulWidget {
  final AppUser me;
  const _CoachStats({required this.me});

  @override
  State<_CoachStats> createState() => _CoachStatsState();
}

class _CoachStatsState extends State<_CoachStats> {
  late final Stream<List<AppUser>> _clients = Db.clientsStream(widget.me.uid);
  late final Stream<List<Session>> _sessions = Db.sessionsForCoach(widget.me.uid);
  late final Stream<List<Plan>> _plans = Db.plansForCoach(widget.me.uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: _clients,
      builder: (context, cs) => StreamBuilder<List<Session>>(
        stream: _sessions,
        builder: (context, ss) => StreamBuilder<List<Plan>>(
          stream: _plans,
          builder: (context, ps) {
            final clients = cs.data ?? [];
            final sessions = ss.data ?? [];
            final plans = ps.data ?? [];
            final weekAgo = DateTime.now().subtract(const Duration(days: 7));
            final monthAgo = DateTime.now().subtract(const Duration(days: 30));
            final week = sessions
                .where((s) => !s.isLive && s.startedAt != null && s.startedAt!.isAfter(weekAgo))
                .length;
            final activeIds = sessions
                .where((s) => s.startedAt != null && s.startedAt!.isAfter(monthAgo))
                .map((s) => s.athleteId)
                .toSet();
            final clientIds = clients.map((c) => c.uid).toSet();
            final withPlan =
                plans.where((p) => p.active && clientIds.contains(p.athleteId)).map((p) => p.athleteId).toSet();
            final noPlan = clients.where((c) => !withPlan.contains(c.uid)).length;
            final inactive = clients.where((c) => !activeIds.contains(c.uid)).length;
            final live = sessions.where((s) => s.isLive).length;

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _stat('Clienti', '${clients.length}', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(appBar: AppBar(), body: ClientsPage(me: widget.me)),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _stat('Allenamenti 7 gg', '$week', () {
                        _openSessions('Allenamenti degli ultimi 7 giorni', (s) =>
                            !s.isLive && s.startedAt != null && s.startedAt!.isAfter(weekAgo));
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _stat('Live ora', '$live', () {
                        _openSessions('In allenamento ora', (s) => s.isLive);
                      }),
                    ),
                  ],
                ),
                if (noPlan > 0 || inactive > 0) ...[
                  const SizedBox(height: 8),
                  Panel(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (noPlan > 0)
                          _alert(Icons.assignment_late_outlined,
                              '$noPlan ${noPlan == 1 ? 'cliente senza' : 'clienti senza'} scheda attiva'),
                        if (noPlan > 0 && inactive > 0) const SizedBox(height: 8),
                        if (inactive > 0)
                          _alert(Icons.schedule,
                              '$inactive ${inactive == 1 ? 'cliente non si allena' : 'clienti non si allenano'} da più di 30 giorni'),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _alert(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 18, color: BC.warnFg),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: BC.body))),
        ],
      );

  void _openSessions(String title, bool Function(Session) test) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CoachSessionsPage(me: widget.me, title: title, test: test),
      ),
    );
  }

  Widget _stat(String label, String value, VoidCallback onTap) => Panel(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w600, color: BC.muted, letterSpacing: 0.4)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                const Icon(Icons.chevron_right, size: 18, color: BC.muted),
              ],
            ),
          ],
        ),
      );
}

class _CoachSessionsPage extends StatefulWidget {
  final AppUser me;
  final String title;
  final bool Function(Session) test;
  const _CoachSessionsPage({required this.me, required this.title, required this.test});

  @override
  State<_CoachSessionsPage> createState() => _CoachSessionsPageState();
}

class _CoachSessionsPageState extends State<_CoachSessionsPage> {
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
            return const EmptyState(
                icon: Icons.history, title: 'Nessun allenamento', text: 'Qui non c\'è ancora niente.');
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
                MaterialPageRoute(builder: (_) => SessionDetailPage(me: widget.me, sessionId: list[i].id)),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------- Rubrica clienti ----------------

class _ContactsSection extends StatefulWidget {
  final AppUser me;
  const _ContactsSection({required this.me});

  @override
  State<_ContactsSection> createState() => _ContactsSectionState();
}

class _ContactsSectionState extends State<_ContactsSection> {
  late final Stream<List<Contact>> _stream = Db.contactsStream(widget.me.uid);
  String _q = '';

  void _edit([Contact? c]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (_) => _ContactSheet(coachId: widget.me.uid, contact: c ?? Contact()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Contact>>(
      stream: _stream,
      builder: (context, snap) {
        final all = snap.data ?? [];
        final q = _q.toLowerCase();
        final list = all
            .where((c) => q.isEmpty || c.fullName.toLowerCase().contains(q) || c.phone.contains(q))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel('Rubrica clienti · ${all.length}',
                trailing: TextButton(onPressed: () => _edit(), child: const Text('+ Aggiungi'))),
            if (all.length > 5)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: const InputDecoration(
                      hintText: 'Cerca in rubrica', prefixIcon: Icon(Icons.search, color: BC.muted)),
                ),
              ),
            if (all.isEmpty)
              Panel(
                onTap: () => _edit(),
                child: const Text(
                    'Salva qui nome, telefono e note dei tuoi clienti, anche di chi non usa ancora l\'app.',
                    style: TextStyle(fontSize: 14, color: BC.body, height: 1.35)),
              )
            else
              Panel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < list.length; i++)
                      InkWell(
                        onTap: () => _edit(list[i]),
                        child: Container(
                          decoration: BoxDecoration(
                            border: i == 0
                                ? null
                                : const Border(top: BorderSide(color: Color(0xFFECEEF0))),
                          ),
                          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                          child: Row(
                            children: [
                              Avatar(list[i].initials, size: 36),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(list[i].fullName.isEmpty ? 'Senza nome' : list[i].fullName,
                                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                                    if (list[i].phone.isNotEmpty || list[i].notes.isNotEmpty)
                                      Text(
                                        [list[i].phone, list[i].notes]
                                            .where((e) => e.isNotEmpty)
                                            .join(' · '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12.5, color: BC.muted),
                                      ),
                                  ],
                                ),
                              ),
                              if (list[i].phone.isNotEmpty)
                                IconButton(
                                  tooltip: 'Chiama',
                                  onPressed: () => openUrl(context, 'tel:${list[i].phone.replaceAll(' ', '')}'),
                                  icon: const Icon(Icons.call_outlined, color: BC.steel, size: 20),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ContactSheet extends StatefulWidget {
  final String coachId;
  final Contact contact;
  const _ContactSheet({required this.coachId, required this.contact});

  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet> {
  late final c = widget.contact;
  late final _first = TextEditingController(text: c.firstName);
  late final _last = TextEditingController(text: c.lastName);
  late final _phone = TextEditingController(text: c.phone);
  late final _email = TextEditingController(text: c.email);
  late final _notes = TextEditingController(text: c.notes);
  bool _busy = false;

  @override
  void dispose() {
    for (final t in [_first, _last, _phone, _email, _notes]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_first.text.trim().isEmpty && _last.text.trim().isEmpty) {
      toast(context, 'Scrivi almeno nome o cognome');
      return;
    }
    setState(() => _busy = true);
    c
      ..firstName = _first.text.trim()
      ..lastName = _last.text.trim()
      ..phone = _phone.text.trim()
      ..email = _email.text.trim()
      ..notes = _notes.text.trim();
    try {
      await Db.saveContact(widget.coachId, c);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, 'Errore: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(c.id.isEmpty ? 'Nuovo contatto' : 'Contatto',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                if (c.id.isNotEmpty)
                  IconButton(
                    tooltip: 'Elimina',
                    onPressed: () async {
                      if (await confirm(context, 'Elimina contatto', 'Eliminare ${c.fullName}?',
                          ok: 'Elimina', danger: true)) {
                        await Db.deleteContact(widget.coachId, c.id);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.delete_outline, color: BC.danger),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _first,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _last,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Cognome'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefono'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (facoltativa)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 4,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _save, child: const Text('Salva')),
          ],
        ),
      ),
    );
  }
}

class _InviteCodePanel extends StatefulWidget {
  final AppUser me;
  const _InviteCodePanel({required this.me});

  @override
  State<_InviteCodePanel> createState() => _InviteCodePanelState();
}

class _InviteCodePanelState extends State<_InviteCodePanel> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final code = widget.me.coachInviteCode;
    return Panel(
      child: code == null || code.isEmpty
          ? Row(
              children: [
                const Expanded(
                  child: Text('Crea un codice da dare ai tuoi clienti per collegarsi a te.',
                      style: TextStyle(fontSize: 14, color: BC.body, height: 1.35)),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            await Db.ensureInviteCode(widget.me);
                          } catch (e) {
                            if (context.mounted) toast(context, 'Errore: $e');
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  child: const Text('Crea'),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Text(code,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 3)),
                ),
                IconButton(
                  tooltip: 'Copia',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    toast(context, 'Codice copiato');
                  },
                  icon: const Icon(Icons.copy, color: BC.steel),
                ),
              ],
            ),
    );
  }
}

// ---------------- Allenato ----------------

class _CoachLink extends StatefulWidget {
  final AppUser me;
  const _CoachLink({required this.me});

  @override
  State<_CoachLink> createState() => _CoachLinkState();
}

class _CoachLinkState extends State<_CoachLink> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      final err = await Db.joinCoach(widget.me, _code.text);
      if (!mounted) return;
      if (err != null) {
        toast(context, err);
      } else {
        _code.clear();
        toast(context, 'Collegato al coach');
      }
    } catch (e) {
      if (mounted) toast(context, 'Errore: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    if (me.hasCoach) {
      final name = me.coachName ?? 'Coach';
      final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
      final ini = parts.isEmpty
          ? '?'
          : (parts.length == 1 ? parts[0][0] : parts[0][0] + parts[1][0]).toUpperCase();
      return Panel(
        child: Row(
          children: [
            Avatar(ini),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            const Tag.steel('Collegato'),
          ],
        ),
      );
    }
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Inserisci il codice che ti ha dato il coach',
              style: TextStyle(fontSize: 14, color: BC.body)),
          const SizedBox(height: 10),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'Es. K7P2QX'),
          ),
          const SizedBox(height: 10),
          FilledButton(onPressed: _busy ? null : _join, child: const Text('Collega')),
        ],
      ),
    );
  }
}

class _AthleteForm extends StatefulWidget {
  final AppUser me;
  const _AthleteForm({super.key, required this.me});

  @override
  State<_AthleteForm> createState() => _AthleteFormState();
}

class _AthleteFormState extends State<_AthleteForm> {
  late final _name = TextEditingController(text: widget.me.name);
  late final _birth = TextEditingController(text: widget.me.birthYear?.toString() ?? '');
  late final _height = TextEditingController(text: _n(widget.me.heightCm));
  late final _weight = TextEditingController(text: _n(widget.me.weightKg));
  late final _goal = TextEditingController(text: widget.me.goal);
  bool _dirty = false;
  bool _busy = false;

  static String _n(double? v) => v == null ? '' : fmtNum(v);

  @override
  void dispose() {
    for (final c in [_name, _birth, _height, _weight, _goal]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await Db.updateUser(widget.me.uid, {
        'name': _name.text.trim().isEmpty ? widget.me.name : _name.text.trim(),
        'birthYear': parseInt(_birth.text),
        'heightCm': parseNum(_height.text),
        'weightKg': parseNum(_weight.text),
        'goal': _goal.text.trim(),
      });
      if (mounted) {
        setState(() => _dirty = false);
        toast(context, 'Profilo salvato');
      }
    } catch (e) {
      if (mounted) toast(context, 'Errore: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController c, String label, {TextInputType? kb, String? suffix}) => TextField(
        controller: c,
        keyboardType: kb,
        onChanged: (_) {
          if (!_dirty) setState(() => _dirty = true);
        },
        decoration: InputDecoration(labelText: label, suffixText: suffix),
      );

  @override
  Widget build(BuildContext context) {
    const dec = TextInputType.numberWithOptions(decimal: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(_name, 'Nome e cognome'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _field(_birth, 'Anno di nascita', kb: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: _field(_height, 'Altezza', kb: dec, suffix: 'cm')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _field(_weight, 'Peso', kb: dec, suffix: 'kg')),
            const SizedBox(width: 10),
            Expanded(child: _field(_goal, 'Obiettivo')),
          ],
        ),
        if (_dirty) ...[
          const SizedBox(height: 12),
          FilledButton(onPressed: _busy ? null : _save, child: const Text('Salva profilo')),
        ],
      ],
    );
  }
}

// ---------------- Strumenti di test (nascosti) ----------------

/// Tocca 7 volte la versione per mostrare gli strumenti di test.
class _DevTools extends StatefulWidget {
  final AppUser me;
  const _DevTools({required this.me});

  @override
  State<_DevTools> createState() => _DevToolsState();
}

class _DevToolsState extends State<_DevTools> {
  static bool _unlocked = false; // resta sbloccato finché l'app è aperta
  int _taps = 0;
  bool _busy = false;

  void _tap() {
    if (_unlocked) return;
    _taps++;
    if (_taps >= 7) {
      setState(() => _unlocked = true);
      toast(context, 'Strumenti di test attivati');
    } else if (_taps >= 4) {
      toast(context, 'Ancora ${7 - _taps} tocchi');
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) toast(context, done);
    } catch (e) {
      if (mounted) toast(context, 'Errore: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switchAccount() async {
    setState(() => _busy = true);
    try {
      await Db.signOut();
      await Db.signInWithGoogle();
    } catch (_) {
      // se annulla, resta nella schermata di accesso
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: GestureDetector(
            onTap: _tap,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text('BeCoach 1.2', style: TextStyle(color: BC.disabled, fontSize: 12)),
            ),
          ),
        ),
        if (_unlocked) ...[
          const SectionLabel('Strumenti di test'),
          Panel(
            color: BC.subtle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Account: ${me.email}\nRuolo attuale: ${me.coachMode ? 'coach' : 'allenato'}'
                    '${me.hasCoach ? '\nCollegato al coach: ${me.coachName ?? me.coachId}' : ''}',
                    style: const TextStyle(fontSize: 13, color: BC.body, height: 1.4)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _switchAccount,
                  icon: const Icon(Icons.switch_account_outlined, size: 18),
                  label: const Text('Cambia account Google'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(
                            () => Db.updateUser(me.uid, {
                              'coachMode': !me.coachMode,
                              if (!me.coachMode) 'isCoach': true,
                            }),
                            me.coachMode ? 'Ora sei allenato' : 'Ora sei coach',
                          ),
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: Text(me.coachMode ? 'Passa ad allenato' : 'Passa a coach'),
                ),
                if (me.hasCoach) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            if (await confirm(context, 'Scollega dal coach',
                                'Questo account non sarà più cliente di ${me.coachName ?? 'questo coach'}.',
                                ok: 'Scollega', danger: true)) {
                              await _run(
                                () => Db.updateUser(me.uid, {
                                  'coachId': null,
                                  'coachName': null,
                                  'joinedWithCode': null,
                                }),
                                'Scollegato dal coach',
                              );
                            }
                          },
                    icon: const Icon(Icons.link_off, size: 18),
                    label: const Text('Scollega dal coach'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
