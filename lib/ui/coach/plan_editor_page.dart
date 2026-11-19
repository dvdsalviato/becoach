import 'package:flutter/material.dart';

import '../../data/exercise_library.dart';
import '../../db.dart';
import '../../models.dart';
import '../../theme.dart';
import '../common/exercises_page.dart';
import '../common/widgets.dart';

/// Editor di schede (assegnate a un cliente) e modelli (area riservata).
class PlanEditorPage extends StatefulWidget {
  final AppUser me;
  final Plan plan;
  final bool isTemplate;
  final String? clientName;

  const PlanEditorPage({
    super.key,
    required this.me,
    required this.plan,
    required this.isTemplate,
    this.clientName,
  });

  @override
  State<PlanEditorPage> createState() => _PlanEditorPageState();
}

class _PlanEditorPageState extends State<PlanEditorPage> {
  late final Plan _p = widget.plan;
  late final _name = TextEditingController(text: _p.name);
  late final _notes = TextEditingController(text: _p.notes);
  Map<String, String> _videos = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (_p.days.isEmpty) _p.days.add(PlanDay(name: 'Giorno A'));
    Db.coachVideosMap(widget.me.uid).then((m) {
      if (mounted) setState(() => _videos = m);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _nextDayName() {
    const letters = 'ABCDEFGHIJ';
    final i = _p.days.length;
    return i < letters.length ? 'Giorno ${letters[i]}' : 'Giorno ${i + 1}';
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'Dai un nome alla scheda');
      return;
    }
    if (_p.exerciseCount == 0) {
      toast(context, 'Aggiungi almeno un esercizio');
      return;
    }
    _p.name = name;
    _p.notes = _notes.text.trim();
    setState(() => _busy = true);
    try {
      if (widget.isTemplate) {
        await Db.saveTemplate(_p);
      } else {
        await Db.savePlan(_p);
      }
      if (mounted) {
        toast(context, widget.isTemplate ? 'Modello salvato' : 'Scheda salvata');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) toast(context, 'Errore: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addExercise(PlanDay day) async {
    final ex = await Navigator.push<Exercise>(
      context,
      MaterialPageRoute(builder: (_) => ExercisesPage(me: widget.me, pick: true)),
    );
    if (ex == null || !mounted) return;
    final cardio = ex.muscle == 'Cardio';
    final pe = PlanExercise(
      exerciseId: ex.id,
      name: ex.name,
      machine: ex.machine,
      muscle: ex.muscle,
      mode: ex.timed ? 'time' : 'reps',
      sets: cardio ? 1 : 3,
      seconds: cardio ? 600 : 30,
      restSec: cardio ? 0 : (ex.timed ? 60 : 90),
      videoUrl: _videos[ex.id] ?? '',
    );
    setState(() => day.exercises.add(pe));
    _editExercise(pe);
  }

  Future<void> _editExercise(PlanExercise e) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (c) => _ExerciseSheet(e: e),
    );
    if (ok == true && mounted) setState(() {});
  }

  void _exerciseAction(PlanDay day, int i, String action) {
    setState(() {
      switch (action) {
        case 'up':
          if (i > 0) {
            final e = day.exercises.removeAt(i);
            day.exercises.insert(i - 1, e);
          }
          break;
        case 'down':
          if (i < day.exercises.length - 1) {
            final e = day.exercises.removeAt(i);
            day.exercises.insert(i + 1, e);
          }
          break;
        case 'dup':
          day.exercises.insert(i + 1, day.exercises[i].copy());
          break;
        case 'remove':
          day.exercises.removeAt(i);
          break;
        case 'superset':
          if (i < day.exercises.length - 1) {
            final a = day.exercises[i], b = day.exercises[i + 1];
            final g = a.group.isNotEmpty
                ? a.group
                : (b.group.isNotEmpty ? b.group : DateTime.now().microsecondsSinceEpoch.toString());
            final old = b.group;
            a.group = g;
            for (final x in day.exercises) {
              if (old.isNotEmpty && x.group == old) x.group = g;
            }
            b.group = g;
          }
          break;
        case 'unsuperset':
          day.exercises[i].group = '';
          break;
      }
      _cleanGroups(day);
    });
  }

  /// Un superset con un solo esercizio non ha senso: lo scioglie.
  void _cleanGroups(PlanDay day) {
    final count = <String, int>{};
    for (final x in day.exercises) {
      if (x.group.isNotEmpty) count[x.group] = (count[x.group] ?? 0) + 1;
    }
    for (final x in day.exercises) {
      if (x.group.isNotEmpty && (count[x.group] ?? 0) < 2) x.group = '';
    }
  }

  /// Lettera del superset (A, B, …) per ogni gruppo, in ordine di comparsa.
  Map<String, String> _groupLetters(PlanDay day) {
    final m = <String, String>{};
    for (final x in day.exercises) {
      if (x.group.isNotEmpty && !m.containsKey(x.group)) {
        m[x.group] = String.fromCharCode(65 + m.length);
      }
    }
    return m;
  }

  Future<void> _dayAction(int i, String action) async {
    final day = _p.days[i];
    switch (action) {
      case 'rename':
        final n = await askText(context, title: 'Nome del giorno', initial: day.name);
        if (n != null && n.trim().isNotEmpty) setState(() => day.name = n.trim());
        break;
      case 'dup':
        setState(() => _p.days.insert(i + 1, day.copy()..name = '${day.name} (copia)'));
        break;
      case 'remove':
        if (await confirm(context, 'Elimina giorno', 'Eliminare "${day.name}" e i suoi esercizi?',
            ok: 'Elimina', danger: true)) {
          setState(() => _p.days.removeAt(i));
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isTemplate
        ? (_p.id.isEmpty ? 'Nuovo modello' : 'Modello')
        : (_p.id.isEmpty ? 'Nuova scheda' : 'Scheda');
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: _busy ? null : _save,
              child: const Text('Salva'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          if (widget.clientName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Per ${widget.clientName}',
                  style: const TextStyle(color: BC.muted, fontSize: 13)),
            ),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notes,
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Note generali (facoltative)'),
          ),
          const SizedBox(height: 10),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                const Expanded(
                    child: Text('Durata', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                IconButton(
                  onPressed: _p.weeks > 1 ? () => setState(() => _p.weeks--) : null,
                  icon: const Icon(Icons.remove),
                ),
                Text('${_p.weeks} settimane',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                IconButton(
                  onPressed: _p.weeks < 52 ? () => setState(() => _p.weeks++) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          if (!widget.isTemplate) ...[
            const SizedBox(height: 10),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Scheda attiva',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: const Text('È quella che il cliente vede in "Oggi"',
                    style: TextStyle(fontSize: 12, color: BC.muted)),
                value: _p.active,
                onChanged: (v) => setState(() => _p.active = v),
              ),
            ),
          ],
          for (var d = 0; d < _p.days.length; d++) _dayPanel(d),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => setState(() => _p.days.add(PlanDay(name: _nextDayName()))),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Aggiungi giorno'),
          ),
        ],
      ),
    );
  }

  Widget _dayPanel(int d) {
    final day = _p.days[d];
    final letters = _groupLetters(day);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Panel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 0, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(day.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  Text('${day.exercises.length} esercizi',
                      style: const TextStyle(fontSize: 12, color: BC.muted)),
                  PopupMenuButton<String>(
                    onSelected: (v) => _dayAction(d, v),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'rename', child: Text('Rinomina')),
                      const PopupMenuItem(value: 'dup', child: Text('Duplica')),
                      if (_p.days.length > 1)
                        const PopupMenuItem(value: 'remove', child: Text('Elimina')),
                    ],
                  ),
                ],
              ),
            ),
            for (var i = 0; i < day.exercises.length; i++) _exerciseRow(day, i, letters),
            Container(
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFECEEF0)))),
              child: TextButton.icon(
                onPressed: () => _addExercise(day),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Aggiungi esercizio'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exerciseRow(PlanDay day, int i, Map<String, String> letters) {
    final e = day.exercises[i];
    final inGroup = e.group.isNotEmpty;
    final firstOfGroup = inGroup && (i == 0 || day.exercises[i - 1].group != e.group);
    final nextSame = i < day.exercises.length - 1 && day.exercises[i + 1].group == e.group && inGroup;
    return InkWell(
      onTap: () => _editExercise(e),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: firstOfGroup || !inGroup ? const Color(0xFFECEEF0) : Colors.transparent),
            left: BorderSide(color: inGroup ? BC.steel : Colors.transparent, width: 3),
          ),
          color: inGroup ? const Color(0xFFF8FAFC) : null,
        ),
        padding: const EdgeInsets.fromLTRB(11, 10, 0, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (firstOfGroup)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Tag.steel('SUPERSET ${letters[e.group] ?? ''}'),
              ),
            Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text('${i + 1}', style: const TextStyle(color: BC.muted, fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          e.target,
                          if (!nextSame) 'rec. ${fmtSec(e.restSec)}',
                          if (e.machineLabel.isNotEmpty) e.machineLabel,
                          if (e.notes.isNotEmpty) 'con indicazioni',
                          if (e.videoUrl.isNotEmpty) 'video tuo',
                        ].join(' · '),
                        style: const TextStyle(fontSize: 12, color: BC.muted),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: BC.muted, size: 20),
                  onSelected: (v) => _exerciseAction(day, i, v),
                  itemBuilder: (_) => [
                    if (i < day.exercises.length - 1 && !nextSame)
                      const PopupMenuItem(value: 'superset', child: Text('Superset con il successivo')),
                    if (inGroup) const PopupMenuItem(value: 'unsuperset', child: Text('Togli dal superset')),
                    if (i > 0) const PopupMenuItem(value: 'up', child: Text('Sposta su')),
                    if (i < day.exercises.length - 1)
                      const PopupMenuItem(value: 'down', child: Text('Sposta giù')),
                    const PopupMenuItem(value: 'dup', child: Text('Duplica')),
                    const PopupMenuItem(value: 'remove', child: Text('Rimuovi')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseSheet extends StatefulWidget {
  final PlanExercise e;
  const _ExerciseSheet({required this.e});

  @override
  State<_ExerciseSheet> createState() => _ExerciseSheetState();
}

class _ExerciseSheetState extends State<_ExerciseSheet> {
  late final PlanExercise e = widget.e;
  late String _mode = e.mode;
  late String _brand = e.brand;
  late final _sets = TextEditingController(text: '${e.sets}');
  late final _reps = TextEditingController(text: e.reps);
  late final _secs = TextEditingController(text: '${e.seconds}');
  late final _rest = TextEditingController(text: '${e.restSec}');
  late final _notes = TextEditingController(text: e.notes);
  late final _video = TextEditingController(text: e.videoUrl);
  late final _model = TextEditingController(text: e.model);

  @override
  void dispose() {
    for (final c in [_sets, _reps, _secs, _rest, _notes, _video, _model]) {
      c.dispose();
    }
    super.dispose();
  }

  void _apply() {
    e.mode = _mode;
    e.sets = (int.tryParse(_sets.text.trim()) ?? e.sets).clamp(1, 20).toInt();
    if (_reps.text.trim().isNotEmpty) e.reps = _reps.text.trim();
    e.seconds = (int.tryParse(_secs.text.trim()) ?? e.seconds).clamp(1, 7200).toInt();
    e.restSec = (int.tryParse(_rest.text.trim()) ?? e.restSec).clamp(0, 900).toInt();
    e.notes = _notes.text.trim();
    e.videoUrl = _video.text.trim();
    e.brand = _brand;
    e.model = _brand.isEmpty ? '' : _model.text.trim();
  }

  @override
  Widget build(BuildContext context) {
    final timed = _mode == 'time';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(e.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            if (e.machine.isNotEmpty) Text(e.machine, style: const TextStyle(color: BC.muted)),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'reps', label: Text('Ripetizioni'), icon: Icon(Icons.repeat, size: 18)),
                ButtonSegment(value: 'time', label: Text('A tempo'), icon: Icon(Icons.timer_outlined, size: 18)),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: BC.steelTint,
                selectedForegroundColor: BC.steelDark,
              ),
              onSelectionChanged: (v) => setState(() => _mode = v.first),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sets,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Serie'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: timed
                      ? TextField(
                          controller: _secs,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Durata', suffixText: 's'),
                        )
                      : TextField(
                          controller: _reps,
                          decoration: const InputDecoration(labelText: 'Ripetizioni', hintText: '10 o 8-10'),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _rest,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Recupero', suffixText: 's'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _brand.isEmpty ? '' : (machineBrands.contains(_brand) ? _brand : 'Altro'),
              decoration: InputDecoration(
                labelText: 'Marca del macchinario',
                helperText: machineHasBrand(e.machine) ? null : 'Facoltativa per questo attrezzo',
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('Qualsiasi')),
                for (final b in machineBrands) DropdownMenuItem(value: b, child: Text(b)),
              ],
              onChanged: (v) => setState(() => _brand = v ?? ''),
            ),
            if (_brand.isNotEmpty) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _model,
                decoration: const InputDecoration(
                    labelText: 'Modello (facoltativo)', hintText: 'Es. Pure Strength, Selection 700'),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Indicazioni per il cliente',
                  hintText: 'Es. gomiti verso i fianchi, ritorno in 2 secondi'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _video,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                  labelText: 'Link video (facoltativo)',
                  hintText: 'Vuoto = video standard o il tuo video salvato'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                _apply();
                Navigator.pop(context, true);
              },
              child: const Text('Fatto'),
            ),
          ],
        ),
      ),
    );
  }
}
