import 'package:flutter/material.dart';

import '../../gym/gym_db.dart';
import '../../gym/gym_models.dart';
import '../../theme.dart';
import '../../util.dart';
import '../common/widgets.dart';
import 'cash_page.dart';
import 'gym_shell.dart';
import 'gym_widgets.dart';
import 'members_page.dart';

class GymHomePage extends StatefulWidget {
  final ScrollController? scroll;
  final ValueChanged<int> openTab;
  const GymHomePage({super.key, this.scroll, required this.openTab});

  @override
  State<GymHomePage> createState() => _GymHomePageState();
}

class _GymHomePageState extends State<GymHomePage> {
  Stream<List<Member>>? _members;
  Stream<List<Checkin>>? _today;
  Stream<List<Payment>>? _monthPays;
  String? _gid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final g = GymScope.of(context).gym.id;
    if (g != _gid) {
      _gid = g;
      final now = DateTime.now();
      _members = GymDb.membersStream(g);
      _today = GymDb.checkinsSince(g, dayOnly(now));
      _monthPays = GymDb.paymentsBetween(g, DateTime(now.year, now.month), DateTime(now.year, now.month + 1));
    }
  }

  void _openFiltered(MemberFilter f, String title) {
    Navigator.push(
      context,
      gymRoute(context, (_) => Scaffold(appBar: AppBar(title: Text(title)), body: MembersPage(initial: f))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = GymScope.of(context);
    final gym = scope.gym;
    final now = DateTime.now();
    return SafeArea(
      child: StreamBuilder<List<Member>>(
        stream: _members,
        builder: (context, ms) {
          if (ms.hasError) return ErrorBox(friendlyError(ms.error!));
          final members = (ms.data ?? []).where((m) => !m.archived).toList();
          final active = members.where((m) => m.subActive).length;
          final expiring = members
              .where((m) => m.subActive && ((m.subDaysLeft ?? 99) <= 7 || (m.subKind == 'entries' && m.entriesLeft <= 2)))
              .toList()
            ..sort((a, b) => (a.subEnd ?? now).compareTo(b.subEnd ?? now));
          final certIssues = members.where((m) => m.subActive && m.certState(gym.certWarnDays) != CertState.ok).toList();
          final dues = members.where((m) => m.hasOverdue).toList()..sort((a, b) => b.dueAmount.compareTo(a.dueAmount));
          final dueTotal = dues.fold<double>(0, (a, m) => a + m.dueAmount);
          return ListView(
            controller: widget.scroll,
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              PageHeader(overline: fmtDate(now), title: gym.name),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: StreamBuilder<List<Payment>>(
                  stream: _monthPays,
                  builder: (context, ps) {
                    final pays = ps.data ?? [];
                    final today = dayOnly(now);
                    final incToday = pays.where((p) => p.isIncome && !p.date.isBefore(today)).fold<double>(0, (a, p) => a + p.amount);
                    final incMonth = pays.where((p) => p.isIncome).fold<double>(0, (a, p) => a + p.amount);
                    return StreamBuilder<List<Checkin>>(
                      stream: _today,
                      builder: (context, cs) {
                        final ins = (cs.data ?? []).where((c) => c.ok).length;
                        final boxes = [
                          StatBox(label: 'Soci attivi', value: '$active', sub: 'su ${members.length} iscritti', onTap: () => widget.openTab(1)),
                          StatBox(label: 'Ingressi oggi', value: '$ins', onTap: () => widget.openTab(2)),
                          StatBox(label: 'Incassato oggi', value: euro(incToday), onTap: () => widget.openTab(3)),
                          StatBox(label: 'Incassato mese', value: euro(incMonth), onTap: () => widget.openTab(3)),
                        ];
                        return LayoutBuilder(builder: (context, c) {
                          final cols = c.maxWidth >= 640 ? 4 : 2;
                          final w = (c.maxWidth - (cols - 1) * 8) / cols;
                          return Wrap(spacing: 8, runSpacing: 8, children: [for (final b in boxes) SizedBox(width: w, child: b)]);
                        });
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.icon(
                    onPressed: () => newMember(context),
                    icon: const Icon(Icons.person_add_alt, size: 18),
                    label: const Text('Nuovo socio'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => widget.openTab(2),
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('Ingressi'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showMovementSheet(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Movimento di cassa'),
                  ),
                ]),
              ),
              _section(
                'Abbonamenti in scadenza · ${expiring.length}',
                expiring,
                gym,
                onMore: () => _openFiltered(MemberFilter.expiring, 'In scadenza'),
                empty: 'Nessun abbonamento in scadenza nei prossimi 7 giorni.',
              ),
              _section(
                'Rate da incassare · ${euro(dueTotal)}',
                dues,
                gym,
                onMore: () => _openFiltered(MemberFilter.due, 'Da incassare'),
                empty: 'Nessuna rata scaduta.',
              ),
              _section(
                'Certificati da sistemare · ${certIssues.length}',
                certIssues,
                gym,
                onMore: () => _openFiltered(MemberFilter.cert, 'Certificati'),
                empty: 'Tutti i soci attivi hanno il certificato in regola.',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String title, List<Member> list, Gym gym, {required VoidCallback onMore, required String empty}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionLabel(title,
            trailing: list.length > 5 ? TextButton(onPressed: onMore, child: const Text('Vedi tutti')) : null),
        if (list.isEmpty)
          Text(empty, style: const TextStyle(color: BC.muted))
        else
          for (final m in list.take(5))
            Padding(padding: const EdgeInsets.only(bottom: 8), child: MemberTile(m: m, warnDays: gym.certWarnDays)),
      ]),
    );
  }
}
