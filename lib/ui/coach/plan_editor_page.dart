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
    final pe = PlanExercise(
      exerciseId: ex.id,
      name: ex.name,
      machine: ex.machine,
      videoUrl: _videos[ex.id] ?? '',
    );
    setState(() => day.exercises.add(pe));
    _editExercise(pe);
  }

  Future<void> _editExercise(PlanExercise e) async {
    final sets = TextEditingController(text: '${e.sets}');
    final reps = TextEditingController(text: e.reps);
    final rest = TextEditingController(text: '${e.restSec}');
    final notes = TextEditingController(text: e.notes);
    final video = TextEditingController(text: e.videoUrl);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(e.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              if (e.machine.isNotEmpty)
                Text(e.machine, style: const TextStyle(color: BC.muted)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: sets,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Serie'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: reps,
                      decoration: const InputDecoration(labelText: 'Ripetizioni', hintText: '10 o 8-10'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: rest,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Recupero', suffixText: 's'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Indicazioni per il cliente',
                    hintText: 'Es. gomiti verso i fianchi, ritorno in 2 secondi'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: video,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                    labelText: 'Link video (facoltativo)',
                    hintText: 'Vuoto = video standard o il tuo video salvato'),
              ),
              const SizedBox(height: 18),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Fatto')),
            ],
          ),
        ),
      ),
    );
    if (ok == true && mounted) {
      setState(() {
        e.sets = (int.tryParse(sets.text.trim()) ?? e.sets).clamp(1, 20).toInt();
        e.reps = reps.text.trim().isEmpty ? e.reps : reps.text.trim();
        e.restSec = (int.tryParse(rest.text.trim()) ?? e.restSec).clamp(0, 900).toInt();
        e.notes = notes.text.trim();
        e.videoUrl = video.text.trim();
      });
    }
    for (final c in [sets, reps, rest, notes, video]) {
      c.dispose();
    }
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
      }
    });
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
            for (var i = 0; i < day.exercises.length; i++)
              InkWell(
                onTap: () => _editExercise(day.exercises[i]),
                child: Container(
                  decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFECEEF0)))),
                  padding: const EdgeInsets.fromLTRB(14, 10, 0, 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text('${i + 1}',
                            style: const TextStyle(color: BC.muted, fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(day.exercises[i].name,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              [
                                day.exercises[i].target,
                                '${day.exercises[i].restSec}″',
                                if (day.exercises[i].notes.isNotEmpty) 'con indicazioni',
                                if (day.exercises[i].videoUrl.isNotEmpty) 'video tuo',
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
                          if (i > 0) const PopupMenuItem(value: 'up', child: Text('Sposta su')),
                          if (i < day.exercises.length - 1)
                            const PopupMenuItem(value: 'down', child: Text('Sposta giù')),
                          const PopupMenuItem(value: 'dup', child: Text('Duplica')),
                          const PopupMenuItem(value: 'remove', child: Text('Rimuovi')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
}
