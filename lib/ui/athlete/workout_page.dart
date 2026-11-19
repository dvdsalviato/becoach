import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/exercise_library.dart';

import '../../db.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../util.dart';
import '../common/exercise_animation.dart';
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
  bool _guided = true; // allenamento guidato serie per serie
  bool _dirty = false;
  bool _closing = false;
  Timer? _saveTimer;
  final Map<String, TextEditingController> _ctrls = {};

  // timer di recupero / esercizio a tempo
  Timer? _ticker;
  DateTime? _timerEnd;
  int _timerTotal = 0;
  String _timerTitle = '';
  bool _timerWork = false;
  VoidCallback? _timerDone;

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
    _ticker?.cancel();
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

  void _startTimer(int seconds, String title, {bool work = false, VoidCallback? onDone}) {
    if (seconds <= 0) return;
    _ticker?.cancel();
    setState(() {
      _timerTotal = seconds;
      _timerEnd = DateTime.now().add(Duration(seconds: seconds));
      _timerTitle = title;
      _timerWork = work;
      _timerDone = onDone;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (_remaining <= 0) {
        final cb = _timerDone;
        _stopTimer();
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
        cb?.call();
      } else {
        setState(() {});
      }
    });
  }

  void _stopTimer() {
    _ticker?.cancel();
    _ticker = null;
    if (mounted) {
      setState(() {
        _timerEnd = null;
        _timerDone = null;
      });
    }
  }

  int get _remaining {
    final end = _timerEnd;
    if (end == null) return 0;
    final ms = end.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  SessionExercise? _nextOf(SessionExercise e) {
    final s = _s!;
    final i = s.exercises.indexOf(e);
    return (i >= 0 && i < s.exercises.length - 1) ? s.exercises[i + 1] : null;
  }

  void _toggleDone(SessionExercise e, int i) {
    final set = e.sets[i];
    setState(() {
      set.done = !set.done;
      if (set.done && !e.isTimed && set.reps == null) {
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

    if (!set.done) return;
    // superset: niente recupero, si passa subito all'esercizio successivo del gruppo
    final next = _nextOf(e);
    if (e.group.isNotEmpty && next != null && next.group == e.group) {
      toast(context, 'Superset: ora ${next.name}');
      return;
    }
    if (e.restSec > 0) _startTimer(e.restSec, 'Recupero');
  }

  void _startWorkTimer(SessionExercise e, int i) {
    final set = e.sets[i];
    final secs = set.sec ?? e.targetSec;
    _startTimer(secs, '${e.name} · serie ${i + 1}', work: true, onDone: () {
      if (!mounted) return;
      set.sec ??= secs;
      if (!set.done) _toggleDone(e, i);
    });
  }

  Future<void> _changeMachine(SessionExercise e) async {
    var brand = e.brand;
    final model = TextEditingController(text: e.model);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.of(c).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Macchinario usato',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(e.name, style: const TextStyle(color: BC.muted)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: brand.isEmpty ? '' : (machineBrands.contains(brand) ? brand : 'Altro'),
                decoration: const InputDecoration(labelText: 'Marca'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Non specificata')),
                  for (final b in machineBrands) DropdownMenuItem(value: b, child: Text(b)),
                ],
                onChanged: (v) => setSheet(() => brand = v ?? ''),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: model,
                decoration: const InputDecoration(labelText: 'Modello (facoltativo)'),
              ),
              const SizedBox(height: 18),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Salva')),
            ],
          ),
        ),
      ),
    );
    if (ok == true && mounted) {
      setState(() {
        e.brand = brand;
        e.model = brand.isEmpty ? '' : model.text.trim();
      });
      _scheduleSave();
    }
    model.dispose();
  }

  void _addSet(SessionExercise e) {
    setState(() {
      final last = e.sets.isEmpty ? null : e.sets.last;
      e.sets.add(SetEntry(kg: last?.kg, sec: e.isTimed ? (last?.sec ?? e.targetSec) : null));
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
      _ctrls.remove('${e.key}#$i#sec')?.dispose();
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
          if (!_reorder)
            IconButton(
              tooltip: _guided ? 'Vista elenco' : 'Vista guidata',
              icon: Icon(_guided ? Icons.view_list_outlined : Icons.play_circle_outline),
              onPressed: () => setState(() => _guided = !_guided),
            ),
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
      body: _reorder ? _buildReorder(s) : (_guided ? _buildGuided(s) : _buildList(s)),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_timerEnd != null && (!_guided || _reorder)) _timerBar(),
            _bottomBar(done, total),
          ],
        ),
      ),
    );
  }

  Widget _timerBar() {
    final rem = _remaining;
    final progress = _timerTotal == 0 ? 0.0 : (1 - rem / _timerTotal).clamp(0.0, 1.0);
    return Container(
      color: _timerWork ? BC.steel : BC.graphite,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              color: Colors.white,
              backgroundColor: const Color(0x33FFFFFF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_timerTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFD5DDE6), fontSize: 12)),
                Text(fmtClock(rem),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ),
          ),
          if (!_timerWork)
            TextButton(
              onPressed: () {
                final end = _timerEnd;
                if (end == null) return;
                setState(() {
                  _timerEnd = end.add(const Duration(seconds: 15));
                  _timerTotal += 15;
                });
              },
              child: const Text('+15″', style: TextStyle(color: Colors.white)),
            ),
          TextButton(
            onPressed: _stopTimer,
            child: Text(_timerWork ? 'Stop' : 'Salta', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(int done, int total) {
    return Container(
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
        );
  }

  // ---------------- Allenamento guidato ----------------

  /// Ordine di esecuzione delle serie: nei superset alterna gli esercizi serie per serie.
  List<(int, int)> _queue(Session s) {
    final q = <(int, int)>[];
    var i = 0;
    while (i < s.exercises.length) {
      final g = s.exercises[i].group;
      var j = i + 1;
      if (g.isNotEmpty) {
        while (j < s.exercises.length && s.exercises[j].group == g) {
          j++;
        }
      }
      var maxSets = 0;
      for (var k = i; k < j; k++) {
        maxSets = math.max(maxSets, s.exercises[k].sets.length);
      }
      for (var n = 0; n < maxSets; n++) {
        for (var k = i; k < j; k++) {
          if (n < s.exercises[k].sets.length) q.add((k, n));
        }
      }
      i = j;
    }
    return q;
  }

  void _setKg(SessionExercise e, int i, double? v) {
    setState(() => e.sets[i].kg = v == null ? null : (v < 0 ? 0 : v));
    _ctrls['${e.key}#$i#kg']?.text = e.sets[i].kg == null ? '' : fmtKg(e.sets[i].kg);
    _scheduleSave();
  }

  void _setSecond(SessionExercise e, int i, int? v) {
    final val = v == null ? null : (v < 0 ? 0 : v);
    setState(() {
      if (e.isTimed) {
        e.sets[i].sec = val;
      } else {
        e.sets[i].reps = val;
      }
    });
    _ctrls['${e.key}#$i#${e.isTimed ? 'sec' : 'reps'}']?.text = val?.toString() ?? '';
    _scheduleSave();
  }

  void _completeGuided(SessionExercise e, int i) {
    final set = e.sets[i];
    if (set.done) return;
    if (!e.isTimed && set.reps == null) {
      final t = int.tryParse(e.targetReps.trim());
      if (t != null) set.reps = t;
    }
    _toggleDone(e, i);
  }

  Widget _buildGuided(Session s) {
    final q = _queue(s);
    final pending = q.where((p) => !s.exercises[p.$1].sets[p.$2].done).toList();
    if (pending.isEmpty) return _guidedDone(s);

    final resting = _timerEnd != null && !_timerWork;
    final working = _timerEnd != null && _timerWork;
    final (ei, si) = pending.first;
    final e = s.exercises[ei];
    final set = e.sets[si];
    final letters = _letters(s);
    final exIndex = ei + 1;

    if (resting) return _guidedRest(s, pending);

    final kgValue = set.kg;
    final second = e.isTimed ? (set.sec ?? e.targetSec) : set.reps;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Text('Esercizio $exIndex di ${s.exercises.length}',
                style: const TextStyle(fontSize: 12.5, color: BC.muted, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (e.group.isNotEmpty) Tag.steel('SUPERSET ${letters[e.group] ?? ''}'),
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => openExercise(context, widget.me,
              exerciseId: e.exerciseId, name: e.name, machine: e.machine, notes: e.notes, videoUrl: e.videoUrl),
          child: ExerciseAnimation(exerciseId: e.exerciseId, height: 190, radius: 12),
        ),
        const SizedBox(height: 14),
        Text(e.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
        const SizedBox(height: 4),
        Row(
          children: [
            Text('Serie ${si + 1} di ${e.sets.length}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: BC.steel)),
            const SizedBox(width: 10),
            Text('obiettivo ${e.isTimed ? fmtSec(e.targetSec) : '${e.targetReps} rip.'}',
                style: const TextStyle(fontSize: 13, color: BC.muted)),
          ],
        ),
        if (machineHasBrand(e.machine) || e.brand.isNotEmpty) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _changeMachine(e),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.precision_manufacturing_outlined, size: 16, color: BC.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      e.machineLabel.isEmpty ? '${e.machine} · indica la marca' : '${e.machine} · ${e.machineLabel}',
                      style: const TextStyle(fontSize: 13, color: BC.body),
                    ),
                  ),
                  const Icon(Icons.edit_outlined, size: 15, color: BC.muted),
                ],
              ),
            ),
          ),
        ],
        if (si < e.prev.length) ...[
          const SizedBox(height: 6),
          Text('La volta scorsa: ${e.prev[si]}', style: const TextStyle(fontSize: 13, color: BC.muted)),
        ],
        if (e.notes.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: BC.steelTint, borderRadius: BorderRadius.circular(8)),
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Coach: ', style: TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: e.notes),
              ]),
              style: const TextStyle(fontSize: 13, color: BC.steelDark, height: 1.35),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (working)
          Center(child: _ring(180, 'Tempo', BC.steel))
        else
          Row(
            children: [
              Expanded(
                child: _stepper(
                  label: 'Kg',
                  value: kgValue == null ? '—' : fmtKg(kgValue),
                  onMinus: () => _setKg(e, si, (kgValue ?? 0) - 2.5),
                  onPlus: () => _setKg(e, si, (kgValue ?? 0) + 2.5),
                  onEdit: () async {
                    final v = await askText(context,
                        title: 'Kg', initial: kgValue == null ? '' : fmtKg(kgValue),
                        keyboard: const TextInputType.numberWithOptions(decimal: true));
                    if (v != null) _setKg(e, si, parseNum(v));
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _stepper(
                  label: e.isTimed ? 'Secondi' : 'Ripetizioni',
                  value: second == null ? (int.tryParse(e.targetReps.trim())?.toString() ?? '—') : '$second',
                  onMinus: () => _setSecond(e, si,
                      (second ?? int.tryParse(e.targetReps.trim()) ?? 0) - (e.isTimed ? 5 : 1)),
                  onPlus: () => _setSecond(e, si,
                      (second ?? int.tryParse(e.targetReps.trim()) ?? 0) + (e.isTimed ? 5 : 1)),
                  onEdit: () async {
                    final v = await askText(context,
                        title: e.isTimed ? 'Secondi' : 'Ripetizioni',
                        initial: second?.toString() ?? '',
                        keyboard: TextInputType.number);
                    if (v != null) _setSecond(e, si, parseInt(v));
                  },
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        if (working)
          OutlinedButton(onPressed: _stopTimer, child: const Text('Ferma il timer'))
        else if (e.isTimed)
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
            onPressed: () => _startWorkTimer(e, si),
            icon: const Icon(Icons.timer_outlined),
            label: Text('Avvia ${fmtSec(second ?? e.targetSec)}'),
          )
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
            onPressed: () => _completeGuided(e, si),
            icon: const Icon(Icons.check),
            label: const Text('Serie completata'),
          ),
        if (e.isTimed && !working)
          TextButton(
            onPressed: () => _completeGuided(e, si),
            child: const Text('Segna come fatta senza timer'),
          ),
        if (pending.length > 1) ...[
          const SectionLabel('Dopo'),
          for (final p in pending.skip(1).take(3)) _upNext(s, p),
        ],
      ],
    );
  }

  Widget _guidedRest(Session s, List<(int, int)> pending) {
    final (ei, si) = pending.first;
    final e = s.exercises[ei];
    final set = e.sets[si];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        const Center(
          child: Text('Recupero',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: BC.muted, letterSpacing: 0.5)),
        ),
        const SizedBox(height: 14),
        Center(child: _ring(220, '', BC.graphite)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  final end = _timerEnd;
                  if (end == null) return;
                  setState(() {
                    _timerEnd = end.add(const Duration(seconds: 15));
                    _timerTotal += 15;
                  });
                },
                child: const Text('+15″'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(onPressed: _stopTimer, child: const Text('Salta recupero'))),
          ],
        ),
        const SectionLabel('Prossima serie'),
        Panel(
          child: Row(
            children: [
              SizedBox(width: 72, height: 54, child: ExerciseAnimation(exerciseId: e.exerciseId, radius: 8, compact: true)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      'Serie ${si + 1} di ${e.sets.length} · '
                      '${set.kg == null ? '' : '${fmtKg(set.kg)} kg · '}'
                      '${e.isTimed ? fmtSec(set.sec ?? e.targetSec) : '${set.reps ?? e.targetReps} rip.'}',
                      style: const TextStyle(fontSize: 13, color: BC.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _guidedDone(Session s) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
      children: [
        const Icon(Icons.emoji_events_outlined, size: 48, color: BC.steel),
        const SizedBox(height: 12),
        const Text('Allenamento completato',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('${s.doneSets} serie · ${fmtNum(s.volume.round())} kg sollevati',
            textAlign: TextAlign.center, style: const TextStyle(color: BC.muted)),
        const SizedBox(height: 24),
        FilledButton(onPressed: _finish, child: const Text('Salva e chiudi')),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _guided = false),
          child: const Text('Rivedi le serie'),
        ),
      ],
    );
  }

  Widget _upNext(Session s, (int, int) p) {
    final e = s.exercises[p.$1];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: BC.steelLight, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${e.name} · serie ${p.$2 + 1}',
                style: const TextStyle(fontSize: 13.5, color: BC.body)),
          ),
        ],
      ),
    );
  }

  Widget _ring(double size, String label, Color color) {
    final rem = _remaining;
    final progress = _timerTotal == 0 ? 0.0 : (rem / _timerTotal).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 9,
              color: color,
              backgroundColor: BC.border,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(fmtClock(rem),
                  style: TextStyle(
                      fontSize: size * 0.22,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              if (label.isNotEmpty) Text(label, style: const TextStyle(color: BC.muted, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepper({
    required String label,
    required String value,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    required VoidCallback onEdit,
  }) {
    return Panel(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Column(
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: BC.muted, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(onPressed: onMinus, icon: const Icon(Icons.remove), tooltip: 'Meno'),
              Expanded(
                child: InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(value,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()])),
                  ),
                ),
              ),
              IconButton(onPressed: onPlus, icon: const Icon(Icons.add), tooltip: 'Più'),
            ],
          ),
        ],
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
                      Text(e.target,
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

  Map<String, String> _letters(Session s) {
    final m = <String, String>{};
    for (final x in s.exercises) {
      if (x.group.isNotEmpty && !m.containsKey(x.group)) m[x.group] = String.fromCharCode(65 + m.length);
    }
    return m;
  }

  Widget _buildList(Session s) {
    final letters = _letters(s);
    final firstOpen = s.exercises.indexWhere((x) => !x.completed);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: s.exercises.length,
      itemBuilder: (c, idx) {
        final e = s.exercises[idx];
        final current = firstOpen == idx;
        final inGroup = e.group.isNotEmpty;
        final firstOfGroup = inGroup && (idx == 0 || s.exercises[idx - 1].group != e.group);
        final nextSame = inGroup && idx < s.exercises.length - 1 && s.exercises[idx + 1].group == e.group;
        final card = Panel(
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
                      SizedBox(
                        width: 56,
                        height: 42,
                        child: ExerciseAnimation(exerciseId: e.exerciseId, radius: 6, compact: true),
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
                                    decoration: e.completed ? TextDecoration.lineThrough : null,
                                    color: e.completed ? BC.muted : BC.ink)),
                            const SizedBox(height: 2),
                            Text(
                                [
                                  e.target,
                                  if (!nextSame && e.restSec > 0) 'recupero ${fmtSec(e.restSec)}',
                                  if (nextSame) 'poi subito il prossimo',
                                ].join(' · '),
                                style: const TextStyle(fontSize: 12, color: BC.muted)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: BC.muted),
                    ],
                  ),
                ),
              ),
              if (machineHasBrand(e.machine) || e.brand.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _changeMachine(e),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: BC.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.precision_manufacturing_outlined, size: 16, color: BC.muted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.machineLabel.isEmpty
                                  ? '${e.machine} · indica la marca usata'
                                  : '${e.machine} · ${e.machineLabel}',
                              style: TextStyle(
                                  fontSize: 12.5, color: e.machineLabel.isEmpty ? BC.muted : BC.body),
                            ),
                          ),
                          const Icon(Icons.edit_outlined, size: 15, color: BC.muted),
                        ],
                      ),
                    ),
                  ),
                ),
              if (e.notes.trim().isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: BC.steelTint, borderRadius: BorderRadius.circular(8)),
                  child: Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Coach: ', style: TextStyle(fontWeight: FontWeight.w600)),
                      TextSpan(text: e.notes),
                    ]),
                    style: const TextStyle(fontSize: 13, color: BC.steelDark, height: 1.35),
                  ),
                ),
              _headerRow(e.isTimed),
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
        );

        return Padding(
          padding: EdgeInsets.only(bottom: nextSame ? 4 : 12),
          child: inGroup
              ? Container(
                  padding: const EdgeInsets.only(left: 8),
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: BC.steel, width: 3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (firstOfGroup)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Tag.steel('SUPERSET ${letters[e.group] ?? ''}'),
                        ),
                      card,
                    ],
                  ),
                )
              : card,
        );
      },
    );
  }

  static const _hdr = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BC.muted);

  Widget _headerRow(bool timed) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
        child: Row(
          children: [
            const SizedBox(width: 34, child: Text('Serie', style: _hdr)),
            const Expanded(child: Text('Prima', style: _hdr)),
            const SizedBox(width: 64, child: Text('Kg', style: _hdr, textAlign: TextAlign.center)),
            const SizedBox(width: 6),
            SizedBox(
                width: 56,
                child: Text(timed ? 'Sec' : 'Rip.', style: _hdr, textAlign: TextAlign.center)),
            SizedBox(width: timed ? 100 : 52),
          ],
        ),
      );

  Widget _setRow(SessionExercise e, int i) {
    final set = e.sets[i];
    final kg = _ctrl('${e.key}#$i#kg', set.kg == null ? '' : fmtKg(set.kg));
    final second = e.isTimed
        ? _ctrl('${e.key}#$i#sec', set.sec?.toString() ?? '${e.targetSec}')
        : _ctrl('${e.key}#$i#reps', set.reps?.toString() ?? '');
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
          SizedBox(width: 34, child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(
            child: Text(i < e.prev.length ? e.prev[i] : '—',
                style: const TextStyle(fontSize: 13, color: BC.muted)),
          ),
          SizedBox(
            width: 64,
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
          const SizedBox(width: 6),
          SizedBox(
            width: 56,
            child: TextField(
              controller: second,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              decoration: deco(),
              onChanged: (v) {
                if (e.isTimed) {
                  set.sec = parseInt(v);
                } else {
                  set.reps = parseInt(v);
                }
                _scheduleSave();
              },
            ),
          ),
          const SizedBox(width: 8),
          if (e.isTimed) ...[
            _squareButton(
              icon: Icons.timer_outlined,
              filled: false,
              label: 'Avvia timer serie ${i + 1}',
              onTap: () => _startWorkTimer(e, i),
            ),
            const SizedBox(width: 6),
          ],
          _squareButton(
            icon: Icons.check,
            filled: set.done,
            label: 'Serie ${i + 1} fatta',
            onTap: () => _toggleDone(e, i),
          ),
        ],
      ),
    );
  }

  Widget _squareButton(
      {required IconData icon, required bool filled, required String label, required VoidCallback onTap}) {
    return SizedBox(
      width: 44,
      height: 40,
      child: Material(
        color: filled ? BC.steel : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: filled ? BC.steel : BC.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Icon(icon, size: 20, color: filled ? Colors.white : BC.muted, semanticLabel: label),
        ),
      ),
    );
  }
}

/// 75 -> 1:15
String fmtClock(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
