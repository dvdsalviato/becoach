import 'package:flutter/material.dart';

import '../../gym/gym_db.dart';
import '../../gym/gym_models.dart';
import '../../theme.dart';
import '../../util.dart';
import '../common/widgets.dart';
import 'expiring_page.dart';
import 'gym_shell.dart';
import 'gym_widgets.dart';
import 'kiosk_page.dart';
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
  String? _gid;
  String _q = '';
  final _search = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final g = GymScope.of(context).gym.id;
    if (g != _gid) {
      _gid = g;
      _members = GymDb.membersStream(g);
      _today = GymDb.checkinsSince(g, dayOnly(DateTime.now()));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(Widget page) => Navigator.push(context, gymRoute(context, (_) => page));

  @override
  Widget build(BuildContext context) {
    final gym = GymScope.of(context).gym;
    final now = DateTime.now();
    return SafeArea(
      child: StreamBuilder<List<Member>>(
        stream: _members,
        builder: (context, ms) {
          if (ms.hasError) return ErrorBox(friendlyError(ms.error!));
          final members = (ms.data ?? []).where((m) => !m.archived).toList();
          final active = members.where((m) => m.subActive).length;
          final today = dayOnly(now);
          final week = today.add(const Duration(days: 7));
          bool soon(DateTime? d) => d != null && !dayOnly(d).isBefore(today) && !dayOnly(d).isAfter(week);
          final expSubs = members.where((m) => soon(m.subEnd)).length;
          final expEnroll = members.where((m) => soon(m.enrollEnd)).length;
          final expCert = members.where((m) => soon(m.cert.expiry)).length;
          return ListView(
            controller: widget.scroll,
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              PageHeader(overline: fmtDate(now), title: gym.name),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  StreamBuilder<List<Checkin>>(
                    stream: _today,
                    builder: (context, cs) {
                      final ins = (cs.data ?? []).where((c) => c.ok).toList();
                      final unique = ins.map((c) => c.memberId).toSet().length;
                      return Row(children: [
                        Expanded(
                          child: StatBox(
                            label: 'Iscritti',
                            value: '${members.length}',
                            sub: '$active con abbonamento attivo',
                            onTap: () => widget.openTab(1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatBox(
                            label: 'Entrati oggi',
                            value: '$unique',
                            sub: ins.isEmpty ? 'nessuno ancora' : 'ultimo alle ${fmtTime(ins.first.at)}',
                            onTap: () => widget.openTab(2),
                          ),
                        ),
                      ]);
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.icon(
                      onPressed: () => newMember(context),
                      icon: const Icon(Icons.person_add_alt, size: 18),
                      label: const Text('Nuovo iscritto'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _open(const ExpiringPage()),
                      icon: const Icon(Icons.event_busy_outlined, size: 18),
                      label: const Text('Scadenze'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _open(const KioskPage()),
                      icon: const Icon(Icons.sensor_door_outlined, size: 18),
                      label: const Text('Postazione ingresso'),
                    ),
                  ]),
                  const SectionLabel('Verifica stato iscritto'),
                  TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _q = v),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Nome, cognome o numero tessera',
                      suffixIcon: _q.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() {
                                _q = '';
                                _search.clear();
                              })),
                    ),
                  ),
                  ..._statusResults(members, gym),
                  SectionLabel('Scadenze dei prossimi 7 giorni',
                      trailing: TextButton(onPressed: () => _open(const ExpiringPage()), child: const Text('Scegli periodo'))),
                  Row(children: [
                    Expanded(
                      child: StatBox(
                        label: 'Abbonamenti',
                        value: '$expSubs',
                        onTap: () => _open(const ExpiringPage(initial: ExpKind.sub)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatBox(
                        label: 'Iscrizioni',
                        value: '$expEnroll',
                        onTap: () => _open(const ExpiringPage(initial: ExpKind.enroll)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatBox(
                        label: 'Certificati',
                        value: '$expCert',
                        onTap: () => _open(const ExpiringPage(initial: ExpKind.cert)),
                      ),
                    ),
                  ]),
                  StreamBuilder<List<Checkin>>(
                    stream: _today,
                    builder: (context, cs) {
                      final list = (cs.data ?? []).toList();
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        SectionLabel('Entrati oggi',
                            trailing: list.length > 12
                                ? TextButton(onPressed: () => widget.openTab(2), child: const Text('Vedi tutti'))
                                : null),
                        if (list.isEmpty)
                          const Text('Ancora nessun ingresso oggi.', style: TextStyle(color: BC.muted))
                        else
                          Panel(
                            padding: EdgeInsets.zero,
                            child: Column(children: [
                              for (var i = 0; i < list.length && i < 12; i++) ...[
                                if (i > 0) const Divider(height: 1),
                                ListTile(
                                  dense: true,
                                  onTap: () => openMember(context, list[i].memberId),
                                  leading: Icon(list[i].ok ? Icons.login : Icons.warning_amber_rounded,
                                      size: 20, color: list[i].ok ? okFg : badFg),
                                  title: Text(list[i].memberName),
                                  trailing: Text(fmtTime(list[i].at), style: const TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ]),
                          ),
                      ]);
                    },
                  ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _statusResults(List<Member> members, Gym gym) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final res = members
        .where((m) =>
            m.fullName.toLowerCase().contains(q) ||
            '${m.lastName} ${m.firstName}'.toLowerCase().contains(q) ||
            m.cardNumber.toString() == q)
        .take(5)
        .toList();
    if (res.isEmpty) {
      return const [
        Padding(padding: EdgeInsets.only(top: 10), child: Text('Nessun iscritto trovato.', style: TextStyle(color: BC.muted)))
      ];
    }
    return [for (final m in res) Padding(padding: const EdgeInsets.only(top: 8), child: MemberStatusCard(m: m, gym: gym))];
  }
}

/// Stato completo di un iscritto: iscrizione, abbonamento, certificato e se può entrare.
class MemberStatusCard extends StatelessWidget {
  final Member m;
  final Gym gym;
  const MemberStatusCard({super.key, required this.m, required this.gym});

  @override
  Widget build(BuildContext context) {
    final c = checkAccess(m, gym);
    Widget line(IconData icon, String label, String value, Color color) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            SizedBox(width: 92, child: Text(label, style: const TextStyle(fontSize: 13, color: BC.muted))),
            Expanded(child: Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: color))),
          ]),
        );
    final today = dayOnly(DateTime.now());
    Color col(bool ok, DateTime? d) {
      if (!ok) return badFg;
      if (d != null && dayOnly(d).difference(today).inDays <= 7) return BC.warnFg;
      return okFg;
    }

    final cs = m.certState(gym.certWarnDays);
    final certColor = cs == CertState.ok
        ? okFg
        : (cs == CertState.expiring || cs == CertState.toVerify ? BC.warnFg : badFg);
    return Panel(
      onTap: () => openMember(context, m.id),
      borderColor: c.ok ? okFg.withValues(alpha: 0.5) : badFg.withValues(alpha: 0.5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          MemberAvatar(m, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text(m.cardLabel, style: const TextStyle(fontSize: 12.5, color: BC.muted)),
            ]),
          ),
          c.ok ? const StatusTag.ok('Può entrare') : const StatusTag.bad('Non può entrare'),
        ]),
        const SizedBox(height: 4),
        line(Icons.badge_outlined, 'Iscrizione',
            m.enrollEnd == null ? 'mancante' : '${m.enrollActive ? 'scade' : 'scaduta'} il ${dmy(m.enrollEnd)}',
            m.enrollEnd == null ? (gym.requireEnrollment ? badFg : BC.muted) : col(m.enrollActive, m.enrollEnd)),
        line(
            Icons.event_available_outlined,
            'Abbonamento',
            m.subEnd == null
                ? 'nessuno'
                : '${m.subName} · ${m.subActive ? 'scade' : 'scaduto'} il ${dmy(m.subEnd)}'
                    '${m.subKind == 'entries' ? ' · ${m.entriesLeft} ingressi' : ''}',
            m.subEnd == null ? badFg : col(m.subActive, m.subEnd)),
        line(
            Icons.medical_information_outlined,
            'Certificato',
            !m.cert.present
                ? 'mancante'
                : '${m.cert.expired ? 'scaduto' : 'scade'} il ${dmy(m.cert.expiry)}${m.cert.verified ? ' · verificato' : ' · da verificare'}',
            certColor),
        if (m.dueAmount > 0) line(Icons.euro, 'Rate', 'da incassare ${euro(m.dueAmount)}', m.hasOverdue ? badFg : BC.muted),
      ]),
    );
  }
}
