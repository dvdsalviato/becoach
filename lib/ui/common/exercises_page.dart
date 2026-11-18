import 'package:flutter/material.dart';

import '../../data/exercise_library.dart';
import '../../db.dart';
import '../../models.dart';
import '../../theme.dart';
import 'widgets.dart';

/// Libreria esercizi. In modalità [pick] restituisce l'esercizio scelto.
class ExercisesPage extends StatefulWidget {
  final AppUser me;
  final bool pick;
  const ExercisesPage({super.key, required this.me, this.pick = false});

  @override
  State<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends State<ExercisesPage> {
  String _query = '';
  String? _machine;

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final list = exerciseLibrary.where((e) {
      if (_machine != null && e.machine != _machine) return false;
      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q) || e.muscle.toLowerCase().contains(q);
    }).toList();

    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Cerca esercizio o muscolo',
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
              _chip('Tutti', _machine == null, () => setState(() => _machine = null)),
              for (final m in machineTypes)
                _chip(m, _machine == m, () => setState(() => _machine = m)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'Nessun esercizio',
                  text: 'Prova con un altro nome o un altro macchinario.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (c, i) {
                    final e = list[i];
                    return Panel(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      onTap: () {
                        if (widget.pick) {
                          Navigator.pop(context, e);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ExerciseDetailPage(me: widget.me, exercise: e)),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.name,
                                    style: const TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 3),
                                Text('${e.muscle} · ${e.machine}',
                                    style: const TextStyle(fontSize: 13, color: BC.muted)),
                              ],
                            ),
                          ),
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

    if (widget.pick) {
      return Scaffold(appBar: AppBar(title: const Text('Scegli esercizio')), body: body);
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

  Widget _chip(String label, bool sel, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        labelStyle: TextStyle(
            color: sel ? Colors.white : BC.ink, fontWeight: FontWeight.w500, fontSize: 13),
        selectedColor: BC.ink,
        backgroundColor: Colors.white,
        side: BorderSide(color: sel ? BC.ink : BC.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          Text(exercise.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          Text(exercise.muscle, style: const TextStyle(color: BC.muted, fontSize: 14)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _info('Macchinario', exercise.machine)),
              const SizedBox(width: 8),
              Expanded(child: _info('Muscolo', exercise.muscle)),
            ],
          ),
          const SectionLabel('Video'),
          if (coachId == null || coachId.isEmpty)
            _videoTile(context, 'Video standard', 'Esecuzione corretta su YouTube',
                exercise.standardVideoUrl, primary: true)
          else
            StreamBuilder<String?>(
              stream: Db.coachVideoStream(coachId, exercise.id),
              builder: (c, s) {
                final coachUrl =
                    planVideoUrl.isNotEmpty ? planVideoUrl : (s.data ?? '');
                return Column(
                  children: [
                    if (coachUrl.isNotEmpty) ...[
                      _videoTile(context, 'Video del coach', coachUrl, coachUrl, primary: true),
                      const SizedBox(height: 8),
                    ],
                    _videoTile(context, 'Video standard', 'Esecuzione corretta su YouTube',
                        exercise.standardVideoUrl,
                        primary: coachUrl.isEmpty),
                    if (me.coachMode) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final url = await askText(context,
                              title: 'Tuo video per ${exercise.name}',
                              initial: s.data ?? '',
                              hint: 'Link YouTube, Drive…',
                              keyboard: TextInputType.url);
                          if (url == null) return;
                          await Db.setCoachVideo(me.uid, exercise.id, url);
                          if (context.mounted) {
                            toast(context,
                                url.trim().isEmpty ? 'Video rimosso' : 'Video salvato');
                          }
                        },
                        icon: const Icon(Icons.link, size: 18),
                        label: Text((s.data ?? '').isEmpty
                            ? 'Aggiungi il tuo video'
                            : 'Cambia il tuo video'),
                      ),
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
