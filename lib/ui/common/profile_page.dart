import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../db.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../util.dart';
import 'widgets.dart';

class ProfilePage extends StatefulWidget {
  final AppUser me;
  const ProfilePage({super.key, required this.me});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final _name = TextEditingController(text: widget.me.name);
  late final _birth = TextEditingController(text: widget.me.birthYear?.toString() ?? '');
  late final _height = TextEditingController(text: _n(widget.me.heightCm));
  late final _weight = TextEditingController(text: _n(widget.me.weightKg));
  late final _goal = TextEditingController(text: widget.me.goal);
  final _code = TextEditingController();
  bool _dirty = false;
  bool _busy = false;

  static String _n(double? v) => v == null ? '' : fmtNum(v);

  @override
  void dispose() {
    for (final c in [_name, _birth, _height, _weight, _goal, _code]) {
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

  Future<void> _setMode(bool coach) async {
    final data = <String, dynamic>{'coachMode': coach};
    if (coach) data['isCoach'] = true;
    await Db.updateUser(widget.me.uid, data);
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? kb, String? suffix}) {
    return TextField(
      controller: c,
      keyboardType: kb,
      onChanged: (_) {
        if (!_dirty) setState(() => _dirty = true);
      },
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
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
                    Text(me.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(me.email, style: const TextStyle(color: BC.muted, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SectionLabel('Dati personali'),
          _field(_name, 'Nome e cognome'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _field(_birth, 'Anno di nascita', kb: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(
                  child: _field(_height, 'Altezza',
                      kb: const TextInputType.numberWithOptions(decimal: true), suffix: 'cm')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _field(_weight, 'Peso',
                      kb: const TextInputType.numberWithOptions(decimal: true), suffix: 'kg')),
              const SizedBox(width: 10),
              Expanded(child: _field(_goal, 'Obiettivo')),
            ],
          ),
          if (_dirty) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: _busy ? null : _save, child: const Text('Salva profilo')),
          ],

          if (me.coachMode) ...[
            const SectionLabel('Codice invito per i clienti'),
            _InviteCodePanel(me: me),
          ] else ...[
            const SectionLabel('Il tuo coach'),
            if (me.hasCoach)
              Panel(
                child: Row(
                  children: [
                    Avatar(_initials(me.coachName ?? 'C')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(me.coachName ?? 'Coach',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                    const Tag.steel('Collegato'),
                  ],
                ),
              )
            else
              Panel(
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
              ),
          ],

          const SectionLabel('Modalità'),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Modalità coach',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              subtitle: Text(
                  me.coachMode
                      ? 'Stai usando l\'app come coach'
                      : 'Attivala per gestire dei clienti',
                  style: const TextStyle(fontSize: 13, color: BC.muted)),
              value: me.coachMode,
              onChanged: (v) => _setMode(v),
            ),
          ),
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
          const Center(
            child: Text('BeCoach 1.0.1', style: TextStyle(color: BC.disabled, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _initials(String n) {
    final p = n.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    if (p.length == 1) return p[0].substring(0, 1).toUpperCase();
    return (p[0].substring(0, 1) + p[1].substring(0, 1)).toUpperCase();
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
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 3)),
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
