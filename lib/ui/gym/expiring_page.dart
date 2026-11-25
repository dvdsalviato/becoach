import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../gym/exports.dart';
import '../../gym/gym_db.dart';
import '../../gym/gym_models.dart';
import '../../theme.dart';
import '../common/widgets.dart';
import 'credentials.dart';
import 'gym_shell.dart';
import 'gym_widgets.dart';
import 'members_page.dart';

enum ExpKind { sub, enroll, cert }

const _kindLabels = {ExpKind.sub: 'Abbonamenti', ExpKind.enroll: 'Iscrizioni', ExpKind.cert: 'Certificati'};

DateTime? expiryOf(Member m, ExpKind k) {
  switch (k) {
    case ExpKind.sub:
      return m.subEnd;
    case ExpKind.enroll:
      return m.enrollEnd;
    case ExpKind.cert:
      return m.cert.expiry;
  }
}

/// Scadenze in un periodo a scelta, con estratto dei nomi.
class ExpiringPage extends StatefulWidget {
  final ExpKind initial;
  const ExpiringPage({super.key, this.initial = ExpKind.sub});

  @override
  State<ExpiringPage> createState() => _ExpiringPageState();
}

class _ExpiringPageState extends State<ExpiringPage> {
  late ExpKind _kind = widget.initial;
  late DateTime _from = dayOnly(DateTime.now());
  late DateTime _to = _from.add(const Duration(days: 7));
  String _preset = '7';
  Stream<List<Member>>? _stream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= GymDb.membersStream(GymScope.of(context).gym.id);
  }

  void _setPreset(String p) {
    final today = dayOnly(DateTime.now());
    setState(() {
      _preset = p;
      switch (p) {
        case 'past':
          _from = today.subtract(const Duration(days: 30));
          _to = today.subtract(const Duration(days: 1));
        case 'today':
          _from = today;
          _to = today;
        default:
          _from = today;
          _to = today.add(Duration(days: int.parse(p)));
      }
    });
  }

  Future<void> _custom() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      locale: const Locale('it'),
    );
    if (r != null) {
      setState(() {
        _preset = 'custom';
        _from = dayOnly(r.start);
        _to = dayOnly(r.end);
      });
    }
  }

  String _reminder(Gym g, Member m, DateTime d) {
    final past = d.isBefore(dayOnly(DateTime.now()));
    final what = switch (_kind) {
      ExpKind.sub => past ? 'il tuo abbonamento è scaduto' : 'il tuo abbonamento scade',
      ExpKind.enroll => past ? 'la tua iscrizione è scaduta' : 'la tua iscrizione scade',
      ExpKind.cert => past ? 'il tuo certificato medico è scaduto' : 'il tuo certificato medico scade',
    };
    final action = _kind == ExpKind.cert ? 'Portane uno nuovo in reception' : 'Passa in reception per il rinnovo';
    return 'Ciao ${m.firstName.trim()}, ti ricordiamo che $what il ${dmy(d)}. $action, ti aspettiamo! – ${g.name}';
  }

  @override
  Widget build(BuildContext context) {
    final gym = GymScope.of(context).gym;
    final period = '${dmy(_from)}-${dmy(_to)}';
    return Scaffold(
      appBar: AppBar(title: const Text('Scadenze')),
      body: StreamBuilder<List<Member>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return ErrorBox(friendlyError(snap.error!));
          if (!snap.hasData) return const Loading();
          final rows = <(Member, DateTime)>[];
          for (final m in snap.data!) {
            if (m.archived) continue;
            final d = expiryOf(m, _kind);
            if (d == null) continue;
            final dd = dayOnly(d);
            if (dd.isBefore(_from) || dd.isAfter(_to)) continue;
            rows.add((m, dd));
          }
          rows.sort((a, b) => a.$2.compareTo(b.$2));
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              SegmentedButton<ExpKind>(
                segments: [for (final k in ExpKind.values) ButtonSegment(value: k, label: Text(_kindLabels[k]!))],
                selected: {_kind},
                onSelectionChanged: (v) => setState(() => _kind = v.first),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final p in const [('past', 'Già scaduti (30 gg)'), ('today', 'Oggi'), ('7', '7 giorni'), ('15', '15 giorni'), ('30', '30 giorni'), ('60', '60 giorni')])
                  ChoiceChip(label: Text(p.$2), selected: _preset == p.$1, onSelected: (_) => _setPreset(p.$1)),
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 18),
                  label: Text(_preset == 'custom' ? 'Dal ${dmy(_from)} al ${dmy(_to)}' : 'Scegli date…'),
                  onPressed: _custom,
                ),
              ]),
              const SizedBox(height: 6),
              SectionLabel(
                '${_kindLabels[_kind]} in scadenza dal ${dmy(_from)} al ${dmy(_to)} · ${rows.length}',
                trailing: rows.isEmpty
                    ? null
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          tooltip: 'Copia elenco',
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () {
                            final text = rows
                                .map((r) => '${dmy(r.$2)}  ${r.$1.fullName}${r.$1.phone.isEmpty ? '' : '  ${r.$1.phone}'}')
                                .join('\n');
                            Clipboard.setData(ClipboardData(text: text));
                            toast(context, 'Elenco copiato (${rows.length} nomi)');
                          },
                        ),
                        IconButton(
                          tooltip: 'Esporta (Excel)',
                          icon: const Icon(Icons.download_outlined, size: 20),
                          onPressed: () => exportExpiring(gym.name, _kindLabels[_kind]!, period, rows),
                        ),
                      ]),
              ),
              if (rows.isEmpty)
                const Text('Nessuna scadenza nel periodo.', style: TextStyle(color: BC.muted))
              else
                Panel(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        onTap: () => openMember(context, rows[i].$1.id),
                        leading: MemberAvatar(rows[i].$1, size: 36),
                        title: Text(rows[i].$1.fullName),
                        subtitle: Text([
                          'n. ${rows[i].$1.cardNumber}',
                          if (rows[i].$1.phone.isNotEmpty) rows[i].$1.phone,
                          if (_kind == ExpKind.sub && rows[i].$1.subName.isNotEmpty) rows[i].$1.subName,
                        ].join(' · ')),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(dmy(rows[i].$2),
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: rows[i].$2.isBefore(dayOnly(DateTime.now())) ? badFg : BC.ink)),
                          PopupMenuButton<String>(
                            tooltip: 'Invia promemoria',
                            icon: const Icon(Icons.notifications_active_outlined, size: 20),
                            onSelected: (v) {
                              final m = rows[i].$1;
                              final text = _reminder(gym, m, rows[i].$2);
                              if (v == 'wa') sendByWhatsApp(context, m.phone, text);
                              if (v == 'mail') sendByEmail(context, m.email, 'Promemoria da ${gym.name}', text);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'wa', enabled: rows[i].$1.phone.isNotEmpty, child: const Text('Promemoria su WhatsApp')),
                              PopupMenuItem(value: 'mail', enabled: rows[i].$1.email.isNotEmpty, child: const Text('Promemoria per email')),
                            ],
                          ),
                        ]),
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
