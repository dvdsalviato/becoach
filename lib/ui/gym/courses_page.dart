import 'package:flutter/material.dart';

import '../../gym/gym_db.dart';
import '../../gym/gym_models.dart';
import '../../theme.dart';
import '../../util.dart';
import '../common/widgets.dart';
import 'gym_shell.dart';
import 'gym_widgets.dart';
import 'members_page.dart';

String lessonDay(DateTime d) {
  final today = dayOnly(DateTime.now());
  final dd = dayOnly(d);
  if (dd == today) return 'Oggi';
  if (dd == today.add(const Duration(days: 1))) return 'Domani';
  return '${weekdayNames[d.weekday - 1]} ${d.day}/${d.month}';
}

/// Corsi di gruppo: orario settimanale, posti, prenotazioni.
class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key});

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  Stream<List<Course>>? _courses;
  Stream<Map<String, int>>? _counts;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final g = GymScope.of(context).gym.id;
    _courses ??= GymDb.coursesStream(g);
    _counts ??= GymDb.lessonCounts(g, dayOnly(DateTime.now()));
  }

  void _edit(Course c) {
    final s = GymScope.of(context);
    showSheet(context, (_) => GymScope(gym: s.gym, me: s.me, child: _CourseSheet(course: c)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Corsi'),
          bottom: const TabBar(tabs: [Tab(text: 'Prossime lezioni'), Tab(text: 'Orario settimanale')]),
          actions: [IconButton(tooltip: 'Nuovo corso', icon: const Icon(Icons.add), onPressed: () => _edit(Course()))],
        ),
        body: StreamBuilder<List<Course>>(
          stream: _courses,
          builder: (context, snap) {
            if (snap.hasError) return ErrorBox(friendlyError(snap.error!));
            if (!snap.hasData) return const Loading();
            final courses = snap.data!;
            if (courses.isEmpty) {
              return EmptyState(
                icon: Icons.groups_2_outlined,
                title: 'Nessun corso',
                text: 'Inserisci i corsi di gruppo (pilates, spinning, functional…) con giorno, ora e posti: '
                    'gli iscritti li prenotano dall\'app.',
                action: FilledButton(onPressed: () => _edit(Course()), child: const Text('Aggiungi corso')),
              );
            }
            final lessons = [for (final c in courses.where((c) => c.active)) ...c.upcoming(8)]
              ..sort((a, b) => a.start.compareTo(b.start));
            return TabBarView(children: [
              StreamBuilder<Map<String, int>>(
                stream: _counts,
                builder: (context, cs) {
                  final counts = cs.data ?? {};
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      for (var i = 0; i < lessons.length; i++) ...[
                        if (i == 0 || dayOnly(lessons[i].start) != dayOnly(lessons[i - 1].start))
                          SectionLabel(lessonDay(lessons[i].start)),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _LessonTile(lesson: lessons[i], count: counts[lessons[i].id] ?? 0),
                        ),
                      ],
                    ],
                  );
                },
              ),
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  for (var d = 1; d <= 7; d++)
                    if (courses.any((c) => c.weekday == d)) ...[
                      SectionLabel(weekdayNames[d - 1]),
                      for (final c in courses.where((c) => c.weekday == d))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Panel(
                            onTap: () => _edit(c),
                            child: Row(children: [
                              SizedBox(
                                width: 56,
                                child: Text(c.timeLabel,
                                    style: TextStyle(fontFamily: BC.display, fontSize: 17, fontWeight: FontWeight.w700, color: c.active ? BC.ink : BC.disabled)),
                              ),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(c.name, style: TextStyle(fontWeight: FontWeight.w600, color: c.active ? BC.ink : BC.disabled)),
                                  Text(
                                    [
                                      '${c.minutes} min',
                                      '${c.capacity} posti',
                                      if (c.instructor.isNotEmpty) c.instructor,
                                      if (c.room.isNotEmpty) c.room,
                                      if (!c.active) 'sospeso',
                                    ].join(' · '),
                                    style: const TextStyle(fontSize: 12.5, color: BC.muted),
                                  ),
                                ]),
                              ),
                              const Icon(Icons.edit_outlined, size: 18, color: BC.disabled),
                            ]),
                          ),
                        ),
                    ],
                ],
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final Lesson lesson;
  final int count;
  const _LessonTile({required this.lesson, required this.count});

  @override
  Widget build(BuildContext context) {
    final c = lesson.course;
    final full = count >= c.capacity;
    return Panel(
      onTap: () => Navigator.push(context, gymRoute(context, (_) => LessonPage(lesson: lesson))),
      child: Row(children: [
        SizedBox(
          width: 56,
          child: Text(c.timeLabel, style: const TextStyle(fontFamily: BC.display, fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text([if (c.instructor.isNotEmpty) c.instructor, if (c.room.isNotEmpty) c.room, '${c.minutes} min'].join(' · '),
                style: const TextStyle(fontSize: 12.5, color: BC.muted)),
          ]),
        ),
        full ? StatusTag.bad('$count/${c.capacity}') : StatusTag.neutral('$count/${c.capacity}'),
      ]),
    );
  }
}

/// Partecipanti di una lezione; la reception può aggiungere o togliere.
class LessonPage extends StatelessWidget {
  final Lesson lesson;
  const LessonPage({super.key, required this.lesson});

  Future<void> _add(BuildContext context, List<Booking> current) async {
    final g = GymScope.of(context).gym.id;
    final m = await pickMember(context, exclude: current.map((b) => b.memberId).toSet());
    if (m == null) return;
    try {
      await GymDb.book(g, lesson, memberId: m.id, memberName: m.fullName, uid: m.linkedUid);
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = GymScope.of(context).gym.id;
    final c = lesson.course;
    return Scaffold(
      appBar: AppBar(title: Text(c.name)),
      body: StreamBuilder<List<Booking>>(
        stream: GymDb.lessonBookings(g, lesson.id),
        builder: (context, snap) {
          final list = snap.data ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text('${lessonDay(lesson.start)} · ${c.timeLabel} – ${fmtTime(lesson.end)}',
                  style: const TextStyle(fontFamily: BC.display, fontSize: 20, fontWeight: FontWeight.w700)),
              Text([if (c.instructor.isNotEmpty) c.instructor, if (c.room.isNotEmpty) c.room].join(' · '),
                  style: const TextStyle(color: BC.muted)),
              SectionLabel('Prenotati · ${list.length} su ${c.capacity}',
                  trailing: list.length < c.capacity
                      ? TextButton.icon(
                          onPressed: () => _add(context, list),
                          icon: const Icon(Icons.person_add_alt, size: 18),
                          label: const Text('Aggiungi'),
                        )
                      : null),
              if (list.isEmpty)
                const Text('Nessuna prenotazione.', style: TextStyle(color: BC.muted))
              else
                Panel(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (var i = 0; i < list.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        title: Text(list[i].memberName),
                        subtitle: Text(list[i].uid.isEmpty ? 'aggiunto dalla reception' : 'prenotato dall\'app'),
                        onTap: () => openMember(context, list[i].memberId),
                        trailing: IconButton(
                          tooltip: 'Togli',
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => GymDb.cancelBooking(g, lesson.id, list[i].memberId),
                        ),
                      ),
                    ],
                  ]),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Scelta di un iscritto con ricerca.
Future<Member?> pickMember(BuildContext context, {Set<String> exclude = const {}}) {
  final s = GymScope.of(context);
  return showSheet<Member>(context, (c) => GymScope(gym: s.gym, me: s.me, child: _MemberPicker(exclude: exclude)));
}

class _MemberPicker extends StatefulWidget {
  final Set<String> exclude;
  const _MemberPicker({required this.exclude});

  @override
  State<_MemberPicker> createState() => _MemberPickerState();
}

class _MemberPickerState extends State<_MemberPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final g = GymScope.of(context).gym.id;
    return StreamBuilder<List<Member>>(
      stream: GymDb.membersStream(g),
      builder: (context, snap) {
        final res = (snap.data ?? [])
            .where((m) => !m.archived && !widget.exclude.contains(m.id) && memberMatchesQuery(m, _q))
            .take(30)
            .toList();
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cerca iscritto'),
            ),
          ),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final m in res)
                ListTile(
                  leading: MemberAvatar(m, size: 36),
                  title: Text(m.fullName),
                  subtitle: Text('n. ${m.cardNumber}'),
                  onTap: () => Navigator.pop(context, m),
                ),
            ]),
          ),
          const SizedBox(height: 12),
        ]);
      },
    );
  }
}

class _CourseSheet extends StatefulWidget {
  final Course course;
  const _CourseSheet({required this.course});

  @override
  State<_CourseSheet> createState() => _CourseSheetState();
}

class _CourseSheetState extends State<_CourseSheet> {
  late final c = widget.course;
  late final _name = TextEditingController(text: c.name);
  late final _instr = TextEditingController(text: c.instructor);
  late final _room = TextEditingController(text: c.room);
  late final _min = TextEditingController(text: '${c.minutes}');
  late final _cap = TextEditingController(text: '${c.capacity}');
  String? _error;

  @override
  void dispose() {
    for (final x in [_name, _instr, _room, _min, _cap]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Scrivi il nome del corso');
      return;
    }
    c
      ..name = _name.text
      ..instructor = _instr.text
      ..room = _room.text
      ..minutes = int.tryParse(_min.text) ?? 60
      ..capacity = int.tryParse(_cap.text) ?? 20;
    try {
      await GymDb.saveCourse(GymScope.of(context).gym.id, c);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(c.id.isEmpty ? 'Nuovo corso' : 'Modifica corso',
            style: const TextStyle(fontFamily: BC.display, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextField(controller: _name, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nome (es. Pilates)')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: c.weekday,
              decoration: const InputDecoration(labelText: 'Giorno'),
              items: [for (var d = 1; d <= 7; d++) DropdownMenuItem(value: d, child: Text(weekdayNames[d - 1]))],
              onChanged: (v) => setState(() => c.weekday = v ?? c.weekday),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: c.hour, minute: c.minute));
                if (t != null) setState(() {
                  c.hour = t.hour;
                  c.minute = t.minute;
                });
              },
              child: InputDecorator(decoration: const InputDecoration(labelText: 'Ora'), child: Text(c.timeLabel)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _min, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Durata (min)'))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _cap, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Posti'))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _instr, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Istruttore'))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _room, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Sala'))),
        ]),
        SwitchListTile(
          value: c.active,
          onChanged: (v) => setState(() => c.active = v),
          contentPadding: EdgeInsets.zero,
          title: const Text('Attivo'),
          subtitle: const Text('Se spento non compare agli iscritti'),
        ),
        if (_error != null) Text(_error!, style: const TextStyle(color: BC.danger)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _save, child: const Text('Salva')),
        if (c.id.isNotEmpty)
          TextButton(
            onPressed: () async {
              if (await confirm(context, 'Elimina corso', 'Eliminare ${c.name} dall\'orario?', ok: 'Elimina', danger: true)) {
                if (!context.mounted) return;
                await GymDb.deleteCourse(GymScope.of(context).gym.id, c.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Elimina corso', style: TextStyle(color: BC.danger)),
          ),
      ],
    );
  }
}
