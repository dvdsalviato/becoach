import 'package:flutter/material.dart';

import '../../gym/gym_db.dart';
import '../../gym/gym_models.dart';
import '../../models.dart';
import '../../notifications.dart';
import '../../theme.dart';
import '../common/widgets.dart';
import '../gym/courses_page.dart' show lessonDay;
import '../gym/gym_widgets.dart';

/// Corsi della palestra nell'app dell'iscritto: prenota e annulla.
class GymCoursesPage extends StatefulWidget {
  final AppUser me;
  const GymCoursesPage({super.key, required this.me});

  @override
  State<GymCoursesPage> createState() => _GymCoursesPageState();
}

class _GymCoursesPageState extends State<GymCoursesPage> {
  late final String _g = widget.me.gymCard?['gymId'] as String? ?? '';
  late final String _mid = widget.me.gymCard?['memberId'] as String? ?? '';
  late final _courses = GymDb.coursesStream(_g);
  late final _counts = GymDb.lessonCounts(_g, dayOnly(DateTime.now()));
  late final _mine = GymDb.myBookings(_g, widget.me.uid);
  late final _member = GymDb.memberStream(_g, _mid);
  final _busy = <String>{};

  int _notifId(String lessonId) => 930000 + (lessonId.hashCode & 0xFFFF);

  Future<void> _toggle(Lesson l, bool booked, Member? m) async {
    setState(() => _busy.add(l.id));
    try {
      if (booked) {
        await GymDb.cancelBooking(_g, l.id, _mid);
        await Notifs.cancel(_notifId(l.id));
      } else {
        if (m != null && !m.subActive) throw 'Serve un abbonamento attivo per prenotare';
        await GymDb.book(_g, l, memberId: _mid, memberName: m?.fullName ?? widget.me.name, uid: widget.me.uid);
        await Notifs.scheduleAt(_notifId(l.id), l.start.subtract(const Duration(hours: 1)), 'Tra un\'ora: ${l.course.name}',
            '${l.course.timeLabel}${l.course.room.isNotEmpty ? ' · ${l.course.room}' : ''}');
        if (mounted) toast(context, 'Prenotato: ${l.course.name} ${lessonDay(l.start).toLowerCase()} alle ${l.course.timeLabel}');
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy.remove(l.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<Member?>(
        stream: _member,
        builder: (context, ms) {
          final m = ms.data;
          return StreamBuilder<List<Course>>(
            stream: _courses,
            builder: (context, cs) {
              if (cs.hasError) return ErrorBox(friendlyError(cs.error!));
              if (!cs.hasData) return const Loading();
              final lessons = [for (final c in cs.data!.where((c) => c.active)) ...c.upcoming(8)]
                ..sort((a, b) => a.start.compareTo(b.start));
              return StreamBuilder<Map<String, int>>(
                stream: _counts,
                builder: (context, cn) {
                  final counts = cn.data ?? {};
                  return StreamBuilder<List<Booking>>(
                    stream: _mine,
                    builder: (context, bs) {
                      final mine = (bs.data ?? []).map((b) => b.lessonId).toSet();
                      return ListView(
                        padding: const EdgeInsets.only(bottom: 32),
                        children: [
                          PageHeader(overline: widget.me.gymCard?['gymName'] as String? ?? 'Palestra', title: 'Corsi'),
                          if (lessons.isEmpty)
                            const EmptyState(
                              icon: Icons.groups_2_outlined,
                              title: 'Nessun corso in programma',
                              text: 'Quando la palestra pubblica l\'orario dei corsi lo trovi qui e prenoti il posto.',
                            ),
                          if (m != null && !m.subActive && lessons.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                              child: Text('Per prenotare serve un abbonamento attivo.', style: TextStyle(color: BC.danger)),
                            ),
                          for (var i = 0; i < lessons.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                if (i == 0 || dayOnly(lessons[i].start) != dayOnly(lessons[i - 1].start))
                                  SectionLabel(lessonDay(lessons[i].start)),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _tile(lessons[i], counts[lessons[i].id] ?? 0, mine.contains(lessons[i].id), m),
                                ),
                              ]),
                            ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _tile(Lesson l, int count, bool booked, Member? m) {
    final c = l.course;
    final left = c.capacity - count;
    final busy = _busy.contains(l.id);
    return Panel(
      borderColor: booked ? BC.steel : null,
      color: booked ? BC.steelTint : null,
      child: Row(children: [
        SizedBox(
          width: 56,
          child: Text(c.timeLabel, style: const TextStyle(fontFamily: BC.display, fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            Text(
              [if (c.instructor.isNotEmpty) c.instructor, '${c.minutes} min', booked ? 'prenotato' : (left <= 0 ? 'al completo' : '$left posti liberi')]
                  .join(' · '),
              style: TextStyle(fontSize: 12.5, color: left <= 0 && !booked ? badFg : BC.muted),
            ),
          ]),
        ),
        if (busy)
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
        else if (booked)
          OutlinedButton(onPressed: () => _toggle(l, true, m), child: const Text('Annulla'))
        else
          FilledButton(onPressed: left <= 0 ? null : () => _toggle(l, false, m), child: const Text('Prenota')),
      ]),
    );
  }
}
