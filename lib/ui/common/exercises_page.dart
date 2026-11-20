import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/exercise_library.dart';
import '../../db.dart';
import '../../models.dart';
import '../../google.dart';
import '../../theme.dart';
import 'exercise_animation.dart';
import 'widgets.dart';

/// Libreria esercizi. In modalità [pick] restituisce l'esercizio scelto.
class ExercisesPage extends StatefulWidget {
  final AppUser me;
  final bool pick;
  final bool embedded;
  const ExercisesPage({super.key, required this.me, this.pick = false, this.embedded = false});

  @override
  State<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends State<ExercisesPage> {
  String _query = '';
  String? _machine;
  String? _muscle;
  Stream<List<Exercise>>? _custom;

  @override
  void initState() {
    super.initState();
    if (widget.me.coachMode) _custom = Db.customExercisesStream(widget.me.uid);
  }

  bool _match(Exercise e) {
    if (_machine != null && e.machine != _machine) return false;
    if (_muscle != null && e.muscle != _muscle) return false;
    final q = _query.toLowerCase().trim();
    if (q.isEmpty) return true;
    return q.split(RegExp(r'\s+')).every((w) =>
        e.name.toLowerCase().contains(w) ||
        e.muscle.toLowerCase().contains(w) ||
        e.machine.toLowerCase().contains(w));
  }

  Future<void> _createCustom() async {
    final ex = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (_) => _CustomExerciseSheet(initialName: _query.trim()),
    );
    if (ex == null || !mounted) return;
    try {
      final saved = await Db.addCustomExercise(widget.me.uid, ex);
      if (!mounted) return;
      if (widget.pick) {
        Navigator.pop(context, saved);
      } else {
        toast(context, 'Esercizio creato');
      }
    } catch (e) {
      if (mounted) toast(context, 'Errore: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = StreamBuilder<List<Exercise>>(
      stream: _custom,
      builder: (context, cs) {
        final custom = (cs.data ?? <Exercise>[]).where(_match).toList();
        final lib = exerciseLibrary.where(_match).toList();
        final all = [...custom, ...lib];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Cerca: es. "lat presa stretta", "cavi spalle"',
                  prefixIcon: Icon(Icons.search, color: BC.muted),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _chip('Tutti i muscoli', _muscle == null, () => setState(() => _muscle = null)),
                  for (final m in muscleGroups)
                    _chip(m, _muscle == m, () => setState(() => _muscle = _muscle == m ? null : m)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _chip('Ogni attrezzo', _machine == null, () => setState(() => _machine = null), small: true),
                  for (final m in machineTypes)
                    _chip(m, _machine == m, () => setState(() => _machine = _machine == m ? null : m),
                        small: true),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: all.length + (widget.me.coachMode ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (c, i) {
                  if (widget.me.coachMode && i == 0) {
                    return Panel(
                      onTap: _createCustom,
                      borderColor: BC.steelLight,
                      color: BC.steelTint,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.add, color: BC.steelDark),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              all.isEmpty && _query.trim().isNotEmpty
                                  ? 'Crea "${_query.trim()}"'
                                  : 'Crea esercizio personalizzato',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600, color: BC.steelDark),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final e = all[i - (widget.me.coachMode ? 1 : 0)];
                  return Panel(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    onTap: () {
                      if (widget.pick) {
                        Navigator.pop(context, e);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ExerciseDetailPage(me: widget.me, exercise: e)),
                        );
                      }
                    },
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          height: 42,
                          child: ExerciseAnimation(exerciseId: e.id, radius: 6, compact: true),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.name,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 3),
                              Text(
                                  [e.muscle, e.machine, if (e.timed) 'a tempo', if (e.custom) 'tuo']
                                      .join(' · '),
                                  style: const TextStyle(fontSize: 13, color: BC.muted)),
                            ],
                          ),
                        ),
                        if (e.custom && !widget.pick)
                          IconButton(
                            tooltip: 'Elimina',
                            icon: const Icon(Icons.delete_outline, color: BC.muted, size: 20),
                            onPressed: () async {
                              if (await confirm(context, 'Elimina esercizio',
                                  'Eliminare "${e.name}" dai tuoi esercizi? Le schede che lo usano restano invariate.',
                                  ok: 'Elimina', danger: true)) {
                                await Db.deleteCustomExercise(widget.me.uid, e.id);
                              }
                            },
                          )
                        else
                          Icon(widget.pick ? Icons.add_circle_outline : Icons.chevron_right,
                              color: widget.pick ? BC.steel : BC.muted),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );

    if (widget.pick) {
      return Scaffold(appBar: AppBar(title: const Text('Scegli esercizio')), body: body);
    }
    if (widget.embedded) {
      return Padding(padding: const EdgeInsets.only(top: 12), child: body);
    }
    return SafeArea(
      child: Column(
        children: [
          PageHeader(overline: '${exerciseLibrary.length} esercizi', title: 'Esercizi'),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap, {bool small = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        visualDensity: small ? VisualDensity.compact : null,
        labelStyle: TextStyle(
            color: sel ? Colors.white : BC.ink, fontWeight: FontWeight.w500, fontSize: small ? 12 : 13),
        selectedColor: small ? BC.steel : BC.ink,
        backgroundColor: Colors.white,
        side: BorderSide(color: sel ? (small ? BC.steel : BC.ink) : BC.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _CustomExerciseSheet extends StatefulWidget {
  final String initialName;
  const _CustomExerciseSheet({required this.initialName});

  @override
  State<_CustomExerciseSheet> createState() => _CustomExerciseSheetState();
}

class _CustomExerciseSheetState extends State<_CustomExerciseSheet> {
  late final _name = TextEditingController(text: widget.initialName);
  String _muscle = muscleGroups.first;
  String _machine = 'Macchina';
  bool _timed = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
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
            const Text('Nuovo esercizio',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Lo vedi solo tu e lo puoi usare in tutte le schede.',
                style: TextStyle(color: BC.muted, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: widget.initialName.isEmpty,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _muscle,
              decoration: const InputDecoration(labelText: 'Muscolo'),
              items: [for (final m in muscleGroups) DropdownMenuItem(value: m, child: Text(m))],
              onChanged: (v) => setState(() => _muscle = v ?? _muscle),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _machine,
              decoration: const InputDecoration(labelText: 'Attrezzo'),
              items: [for (final m in machineTypes) DropdownMenuItem(value: m, child: Text(m))],
              onChanged: (v) => setState(() => _machine = v ?? _machine),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Esercizio a tempo', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Si misura in secondi invece che in ripetizioni',
                  style: TextStyle(fontSize: 12, color: BC.muted)),
              value: _timed,
              onChanged: (v) => setState(() => _timed = v),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final n = _name.text.trim();
                if (n.isEmpty) return;
                Navigator.pop(context, Exercise('', n, _muscle, _machine, timed: _timed, custom: true));
              },
              child: const Text('Crea esercizio'),
            ),
          ],
        ),
      ),
    );
  }
}

class ExerciseDetailPage extends StatelessWidget {
  final AppUser me;
  final Exercise exercise;
  final String notes; // indicazioni del coach dalla scheda
  final String planVideoUrl;

  const ExerciseDetailPage({
    super.key,
    required this.me,
    required this.exercise,
    this.notes = '',
    this.planVideoUrl = '',
  });

  String? get _coachId => me.coachMode ? me.uid : me.coachId;

  @override
  Widget build(BuildContext context) {
    final coachId = _coachId;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          ExerciseAnimation(exerciseId: exercise.id, height: 220, radius: 12),
          const SizedBox(height: 16),
          Text(exercise.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          Text(exercise.muscle, style: const TextStyle(color: BC.muted, fontSize: 14)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _info('Attrezzo', exercise.machine)),
              const SizedBox(width: 8),
              Expanded(child: _info('Muscolo', exercise.muscle)),
            ],
          ),
          if (coachId != null && coachId.isNotEmpty)
            StreamBuilder<String?>(
              stream: Db.coachVideoStream(coachId, exercise.id),
              builder: (c, s) {
                final coachUrl = planVideoUrl.isNotEmpty ? planVideoUrl : (s.data ?? '');
                if (coachUrl.isEmpty && !me.coachMode) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionLabel('Video del coach'),
                    if (coachUrl.isNotEmpty)
                      _videoTile(context, me.coachMode ? 'Il tuo video' : 'Video del coach',
                          'Tocca per guardarlo', coachUrl,
                          primary: true),
                    if (me.coachMode) ...[
                      if (coachUrl.isNotEmpty) const SizedBox(height: 8),
                      _CoachVideoButtons(me: me, exercise: exercise, hasVideo: (s.data ?? '').isNotEmpty),
                    ],
                  ],
                );
              },
            ),
          if (notes.trim().isNotEmpty) ...[
            const SectionLabel('Indicazioni del coach'),
            Panel(
              child: Text(notes,
                  style: const TextStyle(fontSize: 14, height: 1.45, color: BC.body)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _info(String label, String value) => Panel(
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

  Widget _videoTile(BuildContext context, String title, String sub, String url,
      {bool primary = false}) {
    return Panel(
      onTap: () => openUrl(context, url),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 48,
            decoration: BoxDecoration(
                color: primary ? BC.graphite : const Color(0xFF5C6068),
                borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: BC.muted)),
              ],
            ),
          ),
          const Icon(Icons.open_in_new, size: 18, color: BC.muted),
        ],
      ),
    );
  }
}

/// Apre il dettaglio di un esercizio partendo dal suo id (anche se non è in libreria).
void openExercise(BuildContext context, AppUser me,
    {required String exerciseId,
    required String name,
    String machine = '',
    String notes = '',
    String videoUrl = ''}) {
  final ex = exerciseById(exerciseId) ?? Exercise(exerciseId, name, '—', machine.isEmpty ? '—' : machine);
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          ExerciseDetailPage(me: me, exercise: ex, notes: notes, planVideoUrl: videoUrl),
    ),
  );
}


/// Il coach carica il suo video dalla galleria (va sul suo Google Drive) o incolla un link.
class _CoachVideoButtons extends StatefulWidget {
  final AppUser me;
  final Exercise exercise;
  final bool hasVideo;
  const _CoachVideoButtons({required this.me, required this.exercise, required this.hasVideo});

  @override
  State<_CoachVideoButtons> createState() => _CoachVideoButtonsState();
}

class _CoachVideoButtonsState extends State<_CoachVideoButtons> {
  bool _busy = false;
  String _status = '';

  Future<void> _fromGallery() async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    setState(() {
      _busy = true;
      _status = 'Caricamento su Google Drive…';
    });
    try {
      final bytes = await file.readAsBytes();
      final mb = bytes.length / (1024 * 1024);
      if (mb > 200) throw GoogleException('Il video supera 200 MB');
      final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'mp4';
      final mime = ext == 'mov' ? 'video/quicktime' : (ext == 'webm' ? 'video/webm' : 'video/mp4');
      final url = await Google.uploadVideo(bytes, 'BeCoach - ${widget.exercise.name}.$ext', mime: mime);
      await Db.setCoachVideo(widget.me.uid, widget.exercise.id, url);
      if (mounted) toast(context, 'Video caricato');
    } catch (e) {
      if (mounted) toast(context, 'Caricamento non riuscito: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = '';
        });
      }
    }
  }

  Future<void> _link() async {
    final url = await askText(context,
        title: 'Link del video', hint: 'YouTube, Drive…', keyboard: TextInputType.url);
    if (url == null) return;
    await Db.setCoachVideo(widget.me.uid, widget.exercise.id, url);
    if (mounted) toast(context, url.trim().isEmpty ? 'Video rimosso' : 'Video salvato');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!kIsWeb) FilledButton.icon(
          onPressed: _busy ? null : _fromGallery,
          icon: _busy
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.video_library_outlined, size: 18),
          label: Text(_busy ? _status : (widget.hasVideo ? 'Sostituisci con un video dalla galleria' : 'Carica un video dalla galleria')),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _busy ? null : _link,
                child: const Text('Oppure incolla un link'),
              ),
            ),
            if (widget.hasVideo)
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        await Db.setCoachVideo(widget.me.uid, widget.exercise.id, '');
                        if (context.mounted) toast(context, 'Video rimosso');
                      },
                child: const Text('Rimuovi', style: TextStyle(color: BC.danger)),
              ),
          ],
        ),
        const Text('Il video viene salvato sul tuo Google Drive e lo vedono solo i tuoi clienti con il link.',
            style: TextStyle(fontSize: 12, color: BC.muted, height: 1.35)),
      ],
    );
  }
}
