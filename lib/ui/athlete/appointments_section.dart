import 'package:flutter/material.dart';

import '../../calendar_export.dart';
import '../../db.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../util.dart';
import '../common/widgets.dart';

/// Appuntamenti con il coach e richieste, nella Home dell'allenato.
class AthleteAppointments extends StatefulWidget {
  final AppUser me;
  const AthleteAppointments({super.key, required this.me});

  @override
  State<AthleteAppointments> createState() => _AthleteAppointmentsState();
}

class _AthleteAppointmentsState extends State<AthleteAppointments> {
  late final Stream<List<Appointment>> _appts = Db.appointmentsForClient(widget.me.coachId!, widget.me.uid);
  late final Stream<List<AppointmentRequest>> _reqs = Db.myRequests(widget.me.coachId!, widget.me.uid);

  Future<void> _request() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (_) => _RequestSheet(me: widget.me),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Appointment>>(
      stream: _appts,
      builder: (context, aps) => StreamBuilder<List<AppointmentRequest>>(
        stream: _reqs,
        builder: (context, rs) {
          final err = aps.error ?? rs.error;
          if (err != null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionLabel('Appuntamenti'),
                Panel(
                  color: BC.warnBg,
                  borderColor: const Color(0xFFF1D9BC),
                  child: Text(friendlyError(err), style: const TextStyle(fontSize: 13, color: BC.warnFg)),
                ),
              ],
            );
          }
          final now = DateTime.now();
          final upcoming =
              (aps.data ?? []).where((a) => a.end.isAfter(now)).toList()..sort((a, b) => a.start.compareTo(b.start));
          final reqs = (rs.data ?? [])
              .where((r) =>
                  r.pending ||
                  (r.status == 'declined' &&
                      r.createdAt != null &&
                      now.difference(r.createdAt!) < const Duration(days: 7)))
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionLabel('Appuntamenti',
                  trailing: TextButton(onPressed: _request, child: const Text('+ Richiedi'))),
              if (upcoming.isEmpty && reqs.isEmpty)
                Panel(
                  onTap: _request,
                  child: const Row(
                    children: [
                      Icon(Icons.event_outlined, color: BC.steel),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('Richiedi un appuntamento al tuo coach: check, nuova scheda, personal…',
                            style: TextStyle(fontSize: 13.5, color: BC.body, height: 1.35)),
                      ),
                    ],
                  ),
                ),
              for (final a in upcoming.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Panel(
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(color: BC.steelTint, borderRadius: BorderRadius.circular(3)),
                          child: Column(
                            children: [
                              Text('${a.start.day}',
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.w700, color: BC.steelDark)),
                              Text(fmtDate(a.start).split(' ').last,
                                  style: const TextStyle(fontSize: 11, color: BC.steelDark)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Appuntamento: ${a.title}',
                                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('${relDay(a.start)} · ${fmtTime(a.start)}–${fmtTime(a.end)}',
                                  style: const TextStyle(fontSize: 13, color: BC.muted)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Aggiungi al mio calendario',
                          onPressed: () => addToCalendar(context, a, who: widget.me.coachName ?? 'Coach'),
                          icon: const Icon(Icons.edit_calendar_outlined, color: BC.steel),
                        ),
                      ],
                    ),
                  ),
                ),
              for (final r in reqs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Panel(
                    color: r.pending ? Colors.white : BC.subtle,
                    padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                    child: Row(
                      children: [
                        Icon(r.pending ? Icons.hourglass_top : Icons.event_busy,
                            size: 20, color: r.pending ? BC.steel : BC.muted),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Richiesta: ${r.type}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              Text(r.pending ? 'In attesa di conferma del coach' : 'Il coach non ha confermato',
                                  style: const TextStyle(fontSize: 12.5, color: BC.muted)),
                            ],
                          ),
                        ),
                        if (r.pending)
                          IconButton(
                            tooltip: 'Annulla richiesta',
                            onPressed: () async {
                              if (await confirm(context, 'Annulla richiesta', 'Annullare la richiesta di ${r.type}?',
                                  ok: 'Annulla richiesta', danger: true)) {
                                await Db.deleteRequest(r);
                              }
                            },
                            icon: const Icon(Icons.close, color: BC.muted),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RequestSheet extends StatefulWidget {
  final AppUser me;
  const _RequestSheet({required this.me});

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  String _type = requestTypes.first;
  final _avail = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _avail.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Db.createRequest(AppointmentRequest(
        coachId: widget.me.coachId!,
        athleteId: widget.me.uid,
        athleteName: widget.me.name,
        type: _type,
        availability: _avail.text.trim(),
        note: _note.text.trim(),
      ));
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, 'Richiesta inviata a ${widget.me.coachName ?? 'il coach'}');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
            const Text('Richiedi un appuntamento', style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Il coach sceglie data e ora: lo vedrai qui appena confermato.',
                style: TextStyle(fontSize: 13, color: BC.muted)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in requestTypes)
                  ChoiceChip(
                    label: Text(t),
                    selected: _type == t,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _type = t),
                    labelStyle: TextStyle(color: _type == t ? Colors.white : BC.ink, fontSize: 13),
                    selectedColor: BC.graphite,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: _type == t ? BC.graphite : BC.border),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _avail,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Le tue disponibilità (facoltativo)', hintText: 'Es. martedì o giovedì dopo le 18'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note (facoltative)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: BC.danger, fontSize: 13, height: 1.35)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _send,
              child: Text(_busy ? 'Invio…' : 'Invia richiesta'),
            ),
          ],
        ),
      ),
    );
  }
}
