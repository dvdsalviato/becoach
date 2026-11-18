import 'dart:async';

import 'package:flutter/material.dart';

import '../../db.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../util.dart';
import '../common/exercises_page.dart';
import '../common/widgets.dart';

/// Allenamento in corso: tabella serie, carichi, riordino esercizi.
class WorkoutPage extends StatefulWidget {
  final AppUser me;
  final String sessionId;
  const WorkoutPage({super.key, required this.me, required this.sessionId});

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  Session? _s;
  Object? _error;
  bool _reorder = false;
  bool _dirty = false;
  bool _closing = false;
  Timer? _saveTimer;
  final Map<String, TextEditingController> _ctrls = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Db.sessions.doc(widget.sessionId).get();
      if (!mounted) return;
      setState(() => _s = d.exists ? Session.fromDoc(d) : null);
      if (!d.exists) setState(() => _error = 'Allenamento non trovato');
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (_dirty && _s != null && !_closing) {
      Db.saveSessionExercises(_s!);
    }
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(String key, String initial) =>
      _ctrls.putIfAbsent(key, () => TextEditingController(text: initial));

  void _scheduleSave() {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _saveNow);
  }

  Future<void> _saveNow() async {
    final s = _s;
    if (s == null) return;
    try {
      await Db.saveSessionExercises(s);
      _dirty = false;
    } catch (e) {
      if (mounted) toast(context, 'Non salvato: controlla la connessione');
    }
  }

  void _toggleDone(SessionExercise e, int i) {
    final set = e.sets[i];
    setState(() {
      set.done = !set.done;
      if (set.done && set.reps == null) {
        // se le ripetizioni sono un numero preciso, le propone come fatte
        final target = int.tryParse(e.targetReps.trim());
        if (target != null) {
          set.reps = target;
          _ctrls['${e.key}#$i#reps']?.text = '$target';
        }
      }
      // propone lo stesso carico nella serie successiva se vuota
      if (set.done && set.kg != null && i + 1 < e.sets.length && e.sets[i + 1].kg == null) {
        e.sets[i + 1].kg = set.kg;
        _ctrls['${e.key}#${i + 1}#kg']?.text = fmtKg(set.kg);
      }
    });
    _saveTimer?.cancel();
    _saveNow();
  }

  void _addSet(SessionExercise e) {
    setState(() {
      final last = e.sets.isEmpty ? null : e.sets.last;
      e.sets.add(SetEntry(kg: last?.kg));
    });
    _scheduleSave();
  }

  void _removeSet(SessionExercise e) {
    if (e.sets.isEmpty) return;
    final i = e.sets.length - 1;
    setState(() {
      e.sets.removeLast();
      _ctrls.remove('${e.key}#$i#kg')?.dispose();
      _ctrls.remove('${e.key}#$i#reps')?.dispose();
    });
    _scheduleSave();
  }

  Future<void> _finish() async {
    final s = _s;
    if (s == null) return;
    final ok = await confirm(
      context,
      'Termina allenamento',
      s.doneSets == 0
          ? 'Non hai segnato nessuna serie come fatta. Vuoi terminare lo stesso?'
          : 'Hai completato ${s.doneSets} serie su ${s.totalSets}. Salvare e chiudere?',
      ok: 'Termina',
    );
    if (!ok) return;
    _saveTimer?.cancel();
    _closing = true;
    try {
      await Db.finishSession(s);
      if (mounted) {
        toast(context, 'Allenamento salvato');
        Navigator.pop(context);
      }
    } catch (e) {
      _closing = false;
      if (mounted) toast(context, 'Errore: $e');
    }
  }

  Future<void> _discard() async {
    final s = _s;
    if (s == null) return;
    final ok = await confirm(context, 'Annulla allenamento',
        'L\'allenamento verrà eliminato e non comparirà nello storico.',
        ok: 'Elimina', danger: true);
    if (!ok) return;
    _saveTimer?.cancel();
    _closing = true;
    await Db.deleteSession(s.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error != null ? ErrorBox(_error) : const Loading(),
      );
    }
    final total = s.exercises.length;
    final done = s.exercises.where((e) => e.completed).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.dayName),
        actions: [
          IconButton(
            tooltip: _reorder ? 'Fine riordino' : 'Riordina esercizi',
            icon: Icon(_reorder ? Icons.check : Icons.swap_vert),
            onPressed: () => setState(() => _reorder = !_reorder),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'discard') _discard();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'discard', child: Text('Annulla allenamento')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Row(
              children: [
                for (var i = 0; i < total; i++) ...[
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: s.exercises[i].completed
                            ? BC.graphite
                            : (s.exercises[i].doneSets > 0 ? BC.steelLight : BC.border),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (i < total - 1) const SizedBox(width: 4),
                ],
              ],
            ),
          ),
        ),
      ),
      body: _reorder ? _buildReorder(s) : _buildList(s),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: BC.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text('$done di $total esercizi completati',
                    style: const TextStyle(fontSize: 13, color: BC.muted)),
              ),
              FilledButton(onPressed: _finish, child: const Text('Termina')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReorder(Session s) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: BC.steelTint, borderRadius: BorderRadius.circular(10)),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: BC.steelDark),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                    'Tieni premuto e trascina per cambiare l\'ordine, per esempio se un macchinario è occupato. Il coach vedrà la modifica.',
                    style: TextStyle(fontSize: 13, color: BC.steelDark, height: 1.35)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: s.exercises.length,
            onReorder: (oldI, newI) {
              setState(() {
                if (newI > oldI) newI -= 1;
                final e = s.exercises.removeAt(oldI);
                s.exercises.insert(newI, e);
                s.reordered = true;
              });
              _scheduleSave();
            },
            itemBuilder: (c, i) {
              final e = s.exercises[i];
              return Padding(
                key: ValueKey(e.key),
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.drag_indicator, color: BC.disabled),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(e.name,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: e.completed ? BC.muted : BC.ink)),
                      ),
                      Text('${e.targetSets} × ${e.targetReps}',
                          style: const TextStyle(fontSize: 12, color: BC.muted)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildList(Session s) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: s.exercises.length,
      itemBuilder: (c, idx) {
        final e = s.exercises[idx];
        final current = !e.completed &&
            s.exercises.indexWhere((x) => !x.completed) == idx;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            padding: EdgeInsets.zero,
            borderColor: current ? BC.steel : BC.border,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: () => openExercise(context, widget.me,
                      exerciseId: e.exerciseId,
                      name: e.name,
                      machine: e.machine,
                      notes: e.notes,
                      videoUrl: e.videoUrl),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 40,
                          decoration: BoxDecoration(
                              color: BC.graphite, borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.name,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      decoration:
                                          e.completed ? TextDecoration.lineThrough : null,
                                      color: e.completed ? BC.muted : BC.ink)),
                              const SizedBox(height: 2),
                              Text(
                                  '${e.targetSets} × ${e.targetReps} · recupero ${e.restSec}″${e.machine.isNotEmpty ? ' · ${e.machine}' : ''}',
                                  style: const TextStyle(fontSize: 12, color: BC.muted)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: BC.muted),
                      ],
                    ),
                  ),
                ),
                if (e.notes.trim().isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: BC.steelTint, borderRadius: BorderRadius.circular(8)),
                    child: Text.rich(
                      TextSpan(children: [
                        const TextSpan(
                            text: 'Coach: ', style: TextStyle(fontWeight: FontWeight.w600)),
                        TextSpan(text: e.notes),
                      ]),
                      style: const TextStyle(fontSize: 13, color: BC.steelDark, height: 1.35),
                    ),
                  ),
                _headerRow(),
                for (var i = 0; i < e.sets.length; i++) _setRow(e, i),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _addSet(e),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Serie'),
                      ),
                      if (e.sets.length > 1)
                        TextButton.icon(
                          onPressed: () => _removeSet(e),
                          icon: const Icon(Icons.remove, size: 18, color: BC.muted),
                          label: const Text('Togli', style: TextStyle(color: BC.muted)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static const _hdr = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BC.muted);

  Widget _headerRow() => const Padding(
        padding: EdgeInsets.fromLTRB(14, 4, 14, 4),
        child: Row(
          children: [
            SizedBox(width: 34, child: Text('Serie', style: _hdr)),
            Expanded(child: Text('Prima', style: _hdr)),
            SizedBox(width: 72, child: Text('Kg', style: _hdr, textAlign: TextAlign.center)),
            SizedBox(width: 8),
            SizedBox(width: 56, child: Text('Rip.', style: _hdr, textAlign: TextAlign.center)),
            SizedBox(width: 52),
          ],
        ),
      );

  Widget _setRow(SessionExercise e, int i) {
    final set = e.sets[i];
    final kg = _ctrl('${e.key}#$i#kg', set.kg == null ? '' : fmtKg(set.kg));
    final reps = _ctrl('${e.key}#$i#reps', set.reps?.toString() ?? '');
    final fill = set.done ? BC.subtle : Colors.white;
    InputDecoration deco() => InputDecoration(
          isDense: true,
          filled: true,
          fillColor: fill,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        );
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFECEEF0)))),
      padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
      child: Row(
        children: [
          SizedBox(
              width: 34,
              child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(
            child: Text(i < e.prev.length ? e.prev[i] : '—',
                style: const TextStyle(fontSize: 13, color: BC.muted)),
          ),
          SizedBox(
            width: 72,
            child: TextField(
              controller: kg,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              decoration: deco(),
              onChanged: (v) {
                set.kg = parseNum(v);
                _scheduleSave();
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: TextField(
              controller: reps,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              decoration: deco(),
              onChanged: (v) {
                set.reps = parseInt(v);
                _scheduleSave();
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            height: 40,
            child: Material(
              color: set.done ? BC.steel : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: set.done ? BC.steel : BC.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _toggleDone(e, i),
                child: Icon(Icons.check,
                    size: 20, color: set.done ? Colors.white : BC.disabled,
                    semanticLabel: 'Serie ${i + 1} fatta'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
