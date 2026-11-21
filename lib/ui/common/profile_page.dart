import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../db.dart';
import '../../google.dart';
import '../../updates.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../util.dart';
import '../athlete/join_coach.dart';
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
                    Text(me.name, style: const TextStyle(fontFamily: 'Space Grotesk', fontSize: 18, fontWeight: FontWeight.w700)),
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
            const SectionLabel('Codice invito per i clienti'),
            _InviteCodePanel(me: me),
            const SectionLabel('La tua attività'),
            _CoachForm(key: ValueKey('cf-${me.uid}'), me: me),
            if (!kIsWeb) ...[
              const SectionLabel('Collegamenti'),
              _GoogleCalendarPanel(me: me),
            ],
          ] else ...[
            const SectionLabel('Il tuo coach'),
            _CoachLink(me: me),
            const SectionLabel('Dati personali'),
            _AthleteForm(key: ValueKey('af-${me.uid}'), me: me),
          ],
          if (!kIsWeb) ...[
            const SectionLabel('App'),
            const _AppPanel(),
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
                      style: const TextStyle(fontFamily: 'Space Grotesk', fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 3)),
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
      final ok = await joinCoachFlow(context, widget.me, _code.text);
      if (ok) _code.clear();
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
              child: Text('BeCoach 1.7.1', style: TextStyle(color: BC.disabled, fontSize: 12)),
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


// ---------------- Coach: attività, collegamenti ----------------

class _CoachForm extends StatefulWidget {
  final AppUser me;
  const _CoachForm({super.key, required this.me});

  @override
  State<_CoachForm> createState() => _CoachFormState();
}

class _CoachFormState extends State<_CoachForm> {
  late final _name = TextEditingController(text: widget.me.name);
  late final _business = TextEditingController(text: widget.me.businessName);
  late final _gyms = TextEditingController(text: widget.me.gyms);
  late final _phone = TextEditingController(text: widget.me.phone);
  bool _dirty = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _business, _gyms, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await Db.updateUser(widget.me.uid, {
        'name': _name.text.trim().isEmpty ? widget.me.name : _name.text.trim(),
        'businessName': _business.text.trim(),
        'gyms': _gyms.text.trim(),
        'phone': _phone.text.trim(),
      });
      if (mounted) {
        setState(() => _dirty = false);
        toast(context, 'Dati salvati');
      }
    } catch (e) {
      if (mounted) toast(context, 'Errore: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _f(TextEditingController c, String label, {String? hint, TextInputType? kb}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          keyboardType: kb,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) {
            if (!_dirty) setState(() => _dirty = true);
          },
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _f(_name, 'Nome e cognome'),
        _f(_business, 'Nome dell\'attività', hint: 'Es. Salviato Personal Training'),
        _f(_gyms, 'Palestre', hint: 'Dove segui i clienti'),
        _f(_phone, 'Telefono di lavoro', kb: TextInputType.phone),
        if (_dirty) FilledButton(onPressed: _busy ? null : _save, child: const Text('Salva')),
      ],
    );
  }
}

class _GoogleCalendarPanel extends StatefulWidget {
  final AppUser me;
  const _GoogleCalendarPanel({required this.me});

  @override
  State<_GoogleCalendarPanel> createState() => _GoogleCalendarPanelState();
}

class _GoogleCalendarPanelState extends State<_GoogleCalendarPanel> {
  bool _busy = false;

  Future<void> _toggle() async {
    setState(() => _busy = true);
    try {
      if (widget.me.googleCalendar) {
        await Db.updateUser(widget.me.uid, {'googleCalendar': false});
      } else {
        final email = await Google.connectCalendar();
        await Db.updateUser(widget.me.uid, {'googleCalendar': true, 'googleCalendarEmail': email});
      }
    } catch (e) {
      if (mounted) toast(context, 'Collegamento non riuscito: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.me.googleCalendar;
    return Panel(
      child: Row(
        children: [
          Icon(on ? Icons.event_available : Icons.event_outlined, color: on ? BC.steel : BC.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Google Calendar', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                Text(
                  on
                      ? (widget.me.googleCalendarEmail.isEmpty ? 'Collegato' : 'Collegato · ${widget.me.googleCalendarEmail}')
                      : 'Non collegato',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: BC.muted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _busy ? null : _toggle,
            child: Text(on ? 'Scollega' : 'Collega'),
          ),
        ],
      ),
    );
  }
}

class _AppPanel extends StatefulWidget {
  const _AppPanel();

  @override
  State<_AppPanel> createState() => _AppPanelState();
}

class _AppPanelState extends State<_AppPanel> {
  late final Future<(String, int)> _ver = Updates.current();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Row(
        children: [
          const Icon(Icons.system_update_outlined, color: BC.muted),
          const SizedBox(width: 12),
          Expanded(
            child: FutureBuilder<(String, int)>(
              future: _ver,
              builder: (c, s) => Text(
                s.hasData ? 'Versione ${s.data!.$1} (build ${s.data!.$2})' : 'Versione',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await Updates.checkManually(context);
                    if (mounted) setState(() => _busy = false);
                  },
            child: const Text('Cerca aggiornamenti'),
          ),
        ],
      ),
    );
  }
}
