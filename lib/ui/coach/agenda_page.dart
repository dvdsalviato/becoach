import 'package:flutter/material.dart';

import '../../db.dart';
import '../../google.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../util.dart';
import '../common/widgets.dart';

// ---------------- Categorie ----------------

class ApptCategory {
  final String id;
  final String label;
  final Color color;
  final List<String> keywords;
  const ApptCategory(this.id, this.label, this.color, this.keywords);
}

const apptCategories = <ApptCategory>[
  ApptCategory('scheda', 'Scheda', Color(0xFF3F5F7F), ['scheda', 'programma', 'piano']),
  ApptCategory('personal', 'Personal', Color(0xFFB4532A),
      ['personal', ' pt ', 'pt ', 'sessione', 'allenamento', 'lezione', 'workout']),
  ApptCategory('check', 'Check', Color(0xFF2F7D6B),
      ['check', 'misure', 'controllo', 'valutazione', 'plicometria', 'pesata', 'foto', 'progressi']),
  ApptCategory('consulenza', 'Consulenza', Color(0xFF6E56A0),
      ['consulenza', 'call', 'videochiamata', 'colloquio', 'chiamata', 'incontro', 'anamnesi']),
  ApptCategory('prova', 'Prova', Color(0xFFA77A00), ['prova', 'trial', 'gratuit']),
  ApptCategory('altro', 'Altro', Color(0xFF8A9099), []),
];

ApptCategory categoryById(String id) =>
    apptCategories.firstWhere((c) => c.id == id, orElse: () => apptCategories.last);

/// Categoria scelta a mano, oppure dedotta dal testo dell'appuntamento.
ApptCategory categorize(String text, [String manual = '']) {
  if (manual.isNotEmpty) return categoryById(manual);
  final t = ' ${text.toLowerCase()} ';
  for (final c in apptCategories) {
    for (final k in c.keywords) {
      if (t.contains(k)) return c;
    }
  }
  return apptCategories.last;
}

// ---------------- Date ----------------

const _months = [
  'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
  'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
];
const _wdShort = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
const _wdLetter = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _weekStart(DateTime d) => _day(d).subtract(Duration(days: d.weekday - 1));
bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Voce mostrata in agenda: appuntamento di BeCoach o evento di Google Calendar.
class _Item {
  final Appointment? appt;
  final GoogleEvent? gEvent;
  _Item.appt(Appointment a)
      : appt = a,
        gEvent = null;
  _Item.google(GoogleEvent e)
      : appt = null,
        gEvent = e;

  DateTime get start => appt?.start ?? gEvent!.start;
  DateTime get end => appt?.end ?? gEvent!.end;
  String get title => appt?.title ?? gEvent!.title;
  String get subtitle => appt != null ? appt!.clientName : 'Google Calendar';
  bool get allDay => gEvent?.allDay ?? false;
  ApptCategory get category => appt != null
      ? categorize('${appt!.title} ${appt!.notes}', appt!.category)
      : categorize('${gEvent!.title} ${gEvent!.description}');
}

// ---------------- Pagina ----------------

class AgendaPage extends StatefulWidget {
  final AppUser me;
  const AgendaPage({super.key, required this.me});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  late final Stream<List<Appointment>> _appts = Db.appointmentsStream(widget.me.uid);
  late final Stream<List<AppUser>> _clients = Db.clientsStream(widget.me.uid);

  int _view = 2; // 0 giorno, 1 settimana, 2 mese
  DateTime _anchor = _day(DateTime.now());
  DateTime? _selected = _day(DateTime.now());
  final Set<String> _hidden = {};

  // eventi di Google Calendar per l'intervallo visibile
  List<GoogleEvent> _gEvents = [];
  String _gRange = '';
  bool _gLoading = false;

  (DateTime, DateTime) get _range {
    switch (_view) {
      case 0:
        return (_anchor, _anchor.add(const Duration(days: 1)));
      case 1:
        final s = _weekStart(_anchor);
        return (s, s.add(const Duration(days: 7)));
      default:
        final first = DateTime(_anchor.year, _anchor.month, 1);
        final s = _weekStart(first);
        return (s, s.add(const Duration(days: 42)));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGoogle());
  }

  @override
  void didUpdateWidget(covariant AgendaPage old) {
    super.didUpdateWidget(old);
    if (!old.me.googleCalendar && widget.me.googleCalendar) _loadGoogle(force: true);
  }

  Future<void> _loadGoogle({bool force = false}) async {
    if (!widget.me.googleCalendar) return;
    final (from, to) = _range;
    final key = '${from.toIso8601String()}-${to.toIso8601String()}';
    if (!force && key == _gRange) return;
    setState(() => _gLoading = true);
    try {
      final ev = await Google.listEvents(from, to);
      if (mounted) {
        setState(() {
          _gEvents = ev;
          _gRange = key;
        });
      }
    } catch (e) {
      if (mounted) toast(context, 'Google Calendar: $e');
    } finally {
      if (mounted) setState(() => _gLoading = false);
    }
  }

  void _move(int dir) {
    setState(() {
      switch (_view) {
        case 0:
          _anchor = _anchor.add(Duration(days: dir));
          _selected = _anchor;
          break;
        case 1:
          _anchor = _anchor.add(Duration(days: 7 * dir));
          break;
        default:
          _anchor = DateTime(_anchor.year, _anchor.month + dir, 1);
      }
    });
    _loadGoogle();
  }

  String get _rangeLabel {
    switch (_view) {
      case 0:
        return '${_wdShort[_anchor.weekday - 1]} ${_anchor.day} ${_months[_anchor.month - 1]}';
      case 1:
        final s = _weekStart(_anchor);
        final e = s.add(const Duration(days: 6));
        return s.month == e.month
            ? '${s.day}–${e.day} ${_months[s.month - 1]}'
            : '${s.day} ${_months[s.month - 1].substring(0, 3)} – ${e.day} ${_months[e.month - 1].substring(0, 3)}';
      default:
        return '${_months[_anchor.month - 1]} ${_anchor.year}';
    }
  }

  Future<void> _connectGoogle() async {
    try {
      final email = await Google.connectCalendar();
      await Db.updateUser(widget.me.uid, {'googleCalendar': true, 'googleCalendarEmail': email});
      if (mounted) toast(context, 'Google Calendar collegato');
    } catch (e) {
      if (mounted) toast(context, 'Collegamento non riuscito: $e');
    }
  }

  Future<void> _disconnectGoogle() async {
    if (!await confirm(context, 'Scollega Google Calendar',
        'Gli appuntamenti restano in BeCoach ma non verranno più copiati sul calendario Google.',
        ok: 'Scollega')) {
      return;
    }
    await Db.updateUser(widget.me.uid, {'googleCalendar': false});
    setState(() {
      _gEvents = [];
      _gRange = '';
    });
  }

  void _openEditor(List<AppUser> clients, {Appointment? appt, DateTime? day}) {
    final base = day ?? _selected ?? _anchor;
    final now = DateTime.now();
    final a = appt ??
        Appointment(
          coachId: widget.me.uid,
          title: '',
          start: DateTime(base.year, base.month, base.day, _same(base, now) ? (now.hour + 1).clamp(6, 22).toInt() : 9),
        );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (_) => _AppointmentSheet(me: widget.me, appt: a, clients: clients),
    );
  }

  void _showGoogleEvent(GoogleEvent e) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(e.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text(
          '${e.allDay ? 'Tutto il giorno' : '${fmtTime(e.start)} – ${fmtTime(e.end)}'}\nDa Google Calendar'
          '${e.description.isNotEmpty ? '\n\n${e.description}' : ''}',
          style: const TextStyle(color: BC.body, height: 1.4),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Chiudi'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<AppUser>>(
        stream: _clients,
        builder: (context, cs) {
          final clients = cs.data ?? [];
          return StreamBuilder<List<Appointment>>(
            stream: _appts,
            builder: (context, snap) {
              final appts = snap.data ?? [];
              final ids = appts.map((a) => a.googleEventId).where((e) => e.isNotEmpty).toSet();
              final items = <_Item>[
                ...appts.map(_Item.appt),
                ..._gEvents.where((g) => !ids.contains(g.id)).map(_Item.google),
              ].where((i) => !_hidden.contains(i.category.id)).toList()
                ..sort((a, b) => a.start.compareTo(b.start));

              List<_Item> itemsOf(DateTime d) => items.where((i) => _same(i.start, d)).toList();

              return Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.only(bottom: 96),
                    children: [
                      PageHeader(
                        overline: '${_months[DateTime.now().month - 1]} ${DateTime.now().year}',
                        title: 'Agenda',
                        trailing: _gLoading
                            ? const SizedBox(
                                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _googleBar(),
                            const SizedBox(height: 12),
                            SegmentedButton<int>(
                              segments: const [
                                ButtonSegment(value: 0, label: Text('Giorno')),
                                ButtonSegment(value: 1, label: Text('Settimana')),
                                ButtonSegment(value: 2, label: Text('Mese')),
                              ],
                              selected: {_view},
                              showSelectedIcon: false,
                              style: SegmentedButton.styleFrom(
                                selectedBackgroundColor: BC.steelTint,
                                selectedForegroundColor: BC.steelDark,
                              ),
                              onSelectionChanged: (v) {
                                setState(() {
                                  _view = v.first;
                                  if (_view == 0) _anchor = _selected ?? _anchor;
                                });
                                _loadGoogle();
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                IconButton(
                                    onPressed: () => _move(-1),
                                    icon: const Icon(Icons.chevron_left),
                                    tooltip: 'Precedente'),
                                Expanded(
                                  child: Text(_rangeLabel,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                ),
                                IconButton(
                                    onPressed: () => _move(1),
                                    icon: const Icon(Icons.chevron_right),
                                    tooltip: 'Successivo'),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _anchor = _day(DateTime.now());
                                      _selected = _anchor;
                                    });
                                    _loadGoogle();
                                  },
                                  child: const Text('Oggi'),
                                ),
                              ],
                            ),
                            _filters(),
                            const SizedBox(height: 10),
                            if (_view == 2) _month(items, itemsOf, clients),
                            if (_view == 1) _week(itemsOf, clients),
                            if (_view == 0) _dayList(itemsOf(_anchor), clients, _anchor),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    right: 20,
                    bottom: 20,
                    child: FloatingActionButton.extended(
                      heroTag: 'newAppt',
                      onPressed: () => _openEditor(clients),
                      icon: const Icon(Icons.add),
                      label: const Text('Appuntamento'),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _googleBar() {
    final me = widget.me;
    if (!me.googleCalendar) {
      return Panel(
        onTap: _connectGoogle,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: const Row(
          children: [
            Icon(Icons.event_available_outlined, color: BC.steel),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Collega Google Calendar',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  SizedBox(height: 2),
                  Text('Copia qui gli appuntamenti e manda inviti e promemoria ai clienti',
                      style: TextStyle(fontSize: 12, color: BC.muted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: BC.muted),
          ],
        ),
      );
    }
    return Row(
      children: [
        const Icon(Icons.check_circle, size: 16, color: BC.steel),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Google Calendar collegato${me.googleCalendarEmail.isNotEmpty ? ' · ${me.googleCalendarEmail}' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: BC.body),
          ),
        ),
        IconButton(
          tooltip: 'Aggiorna',
          visualDensity: VisualDensity.compact,
          onPressed: () => _loadGoogle(force: true),
          icon: const Icon(Icons.refresh, size: 20, color: BC.muted),
        ),
        IconButton(
          tooltip: 'Scollega',
          visualDensity: VisualDensity.compact,
          onPressed: _disconnectGoogle,
          icon: const Icon(Icons.link_off, size: 20, color: BC.muted),
        ),
      ],
    );
  }

  Widget _filters() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final c in apptCategories)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: !_hidden.contains(c.id),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                backgroundColor: Colors.white,
                selectedColor: Colors.white,
                side: BorderSide(color: _hidden.contains(c.id) ? BC.border : c.color.withAlpha(120)),
                avatar: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _hidden.contains(c.id) ? BC.border : c.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                label: Text(c.label,
                    style: TextStyle(
                        fontSize: 12.5, color: _hidden.contains(c.id) ? BC.disabled : BC.ink)),
                onSelected: (_) => setState(() {
                  if (!_hidden.remove(c.id)) _hidden.add(c.id);
                }),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- Vista mese ----------

  Widget _month(List<_Item> items, List<_Item> Function(DateTime) itemsOf, List<AppUser> clients) {
    final (start, _) = _range;
    final today = _day(DateTime.now());
    final sel = _selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final l in _wdLetter)
              Expanded(
                child: Center(
                  child: Text(l,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BC.muted)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var w = 0; w < 6; w++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(
                    child: Builder(builder: (_) {
                      final day = start.add(Duration(days: w * 7 + d));
                      final inMonth = day.month == _anchor.month;
                      final dayItems = itemsOf(day);
                      final isSel = sel != null && _same(day, sel);
                      final isToday = _same(day, today);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Material(
                          color: isSel ? BC.graphite : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: isToday && !isSel ? BC.steel : BC.border),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setState(() => _selected = isSel ? null : day),
                            child: SizedBox(
                              height: 52,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('${day.day}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                                        color: isSel
                                            ? Colors.white
                                            : (inMonth ? BC.ink : BC.disabled),
                                      )),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      for (final it in dayItems.take(3))
                                        Container(
                                          width: 10,
                                          height: 4,
                                          margin: const EdgeInsets.symmetric(horizontal: 1),
                                          decoration: BoxDecoration(
                                            color: it.category.color,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      if (dayItems.length > 3)
                                        Text('+',
                                            style: TextStyle(
                                                fontSize: 10,
                                                height: 0.6,
                                                color: isSel ? Colors.white : BC.muted)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
              ],
            ),
          ),
        if (sel != null) ...[
          SectionLabel(
            '${_wdShort[sel.weekday - 1]} ${sel.day} ${_months[sel.month - 1]}',
            trailing: TextButton(
              onPressed: () => _openEditor(clients, day: sel),
              child: const Text('+ Aggiungi'),
            ),
          ),
          _itemsColumn(itemsOf(sel), clients),
        ],
      ],
    );
  }

  // ---------- Vista settimana ----------

  Widget _week(List<_Item> Function(DateTime) itemsOf, List<AppUser> clients) {
    final start = _weekStart(_anchor);
    final today = _day(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 7; i++)
          Builder(builder: (_) {
            final day = start.add(Duration(days: i));
            final dayItems = itemsOf(day);
            final open = _selected != null && _same(_selected!, day);
            final isToday = _same(day, today);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                padding: EdgeInsets.zero,
                borderColor: isToday ? BC.steel : BC.border,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _selected = open ? null : day),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 44,
                              child: Column(
                                children: [
                                  Text(_wdShort[i],
                                      style: const TextStyle(fontSize: 11.5, color: BC.muted)),
                                  Text('${day.day}',
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: isToday ? BC.steel : BC.ink)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: dayItems.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.only(top: 10),
                                      child: Text('Nessun appuntamento',
                                          style: TextStyle(fontSize: 13, color: BC.disabled)),
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        for (final it in (open ? <_Item>[] : dayItems.take(3)))
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 3,
                                                  height: 16,
                                                  decoration: BoxDecoration(
                                                    color: it.category.color,
                                                    borderRadius: BorderRadius.circular(2),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(it.allDay ? 'giorno' : fmtTime(it.start),
                                                    style: const TextStyle(
                                                        fontSize: 12.5,
                                                        fontWeight: FontWeight.w600,
                                                        color: BC.body)),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(it.title,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontSize: 13)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (!open && dayItems.length > 3)
                                          Text('+${dayItems.length - 3} altri',
                                              style: const TextStyle(fontSize: 12, color: BC.muted)),
                                        if (open)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 10),
                                            child: Text(
                                                '${dayItems.length} ${dayItems.length == 1 ? 'appuntamento' : 'appuntamenti'}',
                                                style: const TextStyle(fontSize: 13, color: BC.muted)),
                                          ),
                                      ],
                                    ),
                            ),
                            Icon(open ? Icons.expand_less : Icons.expand_more, color: BC.muted),
                          ],
                        ),
                      ),
                    ),
                    if (open)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _itemsColumn(dayItems, clients),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: () => _openEditor(clients, day: day),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Aggiungi in questo giorno'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // ---------- Vista giorno ----------

  Widget _dayList(List<_Item> items, List<AppUser> clients, DateTime day) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: EmptyState(
          icon: Icons.event_outlined,
          title: 'Giornata libera',
          text: 'Nessun appuntamento per questo giorno.',
          action: OutlinedButton(
            onPressed: () => _openEditor(clients, day: day),
            child: const Text('Aggiungi appuntamento'),
          ),
        ),
      );
    }
    return _itemsColumn(items, clients);
  }

  Widget _itemsColumn(List<_Item> items, List<AppUser> clients) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Nessun appuntamento', style: TextStyle(color: BC.disabled, fontSize: 13)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ItemCard(
              item: it,
              onTap: () {
                if (it.appt != null) {
                  _openEditor(clients, appt: it.appt);
                } else {
                  _showGoogleEvent(it.gEvent!);
                }
              },
            ),
          ),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  final _Item item;
  final VoidCallback onTap;
  const _ItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = item.category;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: BC.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: c.color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.allDay ? 'Tutto' : fmtTime(item.start),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            Text(item.allDay ? 'il giorno' : fmtTime(item.end),
                                style: const TextStyle(fontSize: 12, color: BC.muted)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                            if (item.subtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(item.subtitle,
                                  style: const TextStyle(fontSize: 12.5, color: BC.muted)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.color.withAlpha(28),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(c.label,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.color)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Editor appuntamento ----------------

class _AppointmentSheet extends StatefulWidget {
  final AppUser me;
  final Appointment appt;
  final List<AppUser> clients;
  const _AppointmentSheet({required this.me, required this.appt, required this.clients});

  @override
  State<_AppointmentSheet> createState() => _AppointmentSheetState();
}

class _AppointmentSheetState extends State<_AppointmentSheet> {
  late final Appointment a = widget.appt;
  late final _title = TextEditingController(text: a.title);
  late final _notes = TextEditingController(text: a.notes);
  late DateTime _date = DateTime(a.start.year, a.start.month, a.start.day);
  late TimeOfDay _time = TimeOfDay(hour: a.start.hour, minute: a.start.minute);
  late int _minutes = a.minutes;
  late String _clientId = a.clientId;
  late String _category = a.category;
  bool _invite = true;
  bool _busy = false;

  static const _durations = [15, 30, 45, 60, 75, 90, 120, 180];

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  AppUser? get _client {
    for (final c in widget.clients) {
      if (c.uid == _clientId) return c;
    }
    return null;
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      toast(context, 'Scrivi un titolo, es. "Sessione personal"');
      return;
    }
    setState(() => _busy = true);
    final client = _client;
    a
      ..title = title
      ..notes = _notes.text.trim()
      ..start = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute)
      ..minutes = _minutes
      ..clientId = client?.uid ?? ''
      ..clientName = client?.name ?? (_clientId.isEmpty ? '' : a.clientName)
      ..clientEmail = client?.email ?? ''
      ..category = _category;
    String? googleError;
    if (widget.me.googleCalendar) {
      try {
        final desc = [
          if (a.clientName.isNotEmpty) 'Cliente: ${a.clientName}',
          if (a.notes.isNotEmpty) a.notes,
          'Creato con BeCoach',
        ].join('\n');
        final attendee = _invite ? a.clientEmail : null;
        if (a.googleEventId.isEmpty) {
          a.googleEventId = await Google.createEvent(
              title: a.title, description: desc, start: a.start, end: a.end, attendeeEmail: attendee);
        } else {
          await Google.updateEvent(a.googleEventId,
              title: a.title, description: desc, start: a.start, end: a.end, attendeeEmail: attendee);
        }
      } catch (e) {
        googleError = '$e';
      }
    }
    try {
      await Db.saveAppointment(a);
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, googleError == null ? 'Appuntamento salvato' : 'Salvato in BeCoach, ma non su Google: $googleError');
    } catch (e) {
      if (mounted) toast(context, 'Errore: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Elimina appuntamento', 'Eliminare "${a.title}"?',
        ok: 'Elimina', danger: true)) {
      return;
    }
    if (a.googleEventId.isNotEmpty && widget.me.googleCalendar) {
      try {
        await Google.deleteEvent(a.googleEventId);
      } catch (_) {}
    }
    await Db.deleteAppointment(a);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final auto = categorize('${_title.text} ${_notes.text}');
    final client = _client;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(a.id.isEmpty ? 'Nuovo appuntamento' : 'Appuntamento',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                if (a.id.isNotEmpty)
                  IconButton(
                    tooltip: 'Elimina',
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline, color: BC.danger),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                  labelText: 'Titolo', hintText: 'Es. Sessione personal, Check mensile, Nuova scheda'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: widget.clients.any((c) => c.uid == _clientId) ? _clientId : '',
              decoration: const InputDecoration(labelText: 'Cliente'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Nessuno')),
                for (final c in widget.clients) DropdownMenuItem(value: c.uid, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _clientId = v ?? ''),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setState(() => _date = d);
                    },
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(fmtDate(_date)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final t = await showTimePicker(context: context, initialTime: _time);
                      if (t != null) setState(() => _time = t);
                    },
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text('${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _durations.contains(_minutes) ? _minutes : 60,
                    decoration: const InputDecoration(labelText: 'Durata'),
                    items: [
                      for (final m in _durations)
                        DropdownMenuItem(value: m, child: Text(m < 60 ? '$m min' : fmtDuration(Duration(minutes: m)))),
                    ],
                    onChanged: (v) => setState(() => _minutes = v ?? 60),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: [
                      DropdownMenuItem(value: '', child: Text('Auto · ${auto.label}')),
                      for (final c in apptCategories) DropdownMenuItem(value: c.id, child: Text(c.label)),
                    ],
                    onChanged: (v) => setState(() => _category = v ?? ''),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Note'),
            ),
            if (widget.me.googleCalendar && client != null && client.email.isNotEmpty) ...[
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _invite,
                onChanged: (v) => setState(() => _invite = v),
                title: const Text('Invia invito e promemoria al cliente', style: TextStyle(fontSize: 14)),
                subtitle: Text('Google Calendar scrive a ${client.email}',
                    style: const TextStyle(fontSize: 12, color: BC.muted)),
              ),
            ],
            if (!widget.me.googleCalendar)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Collega Google Calendar in Agenda per copiarlo sul tuo calendario.',
                    style: TextStyle(fontSize: 12, color: BC.muted)),
              ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Salvataggio…' : 'Salva')),
          ],
        ),
      ),
    );
  }
}
