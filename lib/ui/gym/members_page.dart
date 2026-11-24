import 'package:flutter/material.dart';

import '../../gym/exports.dart';
import '../../gym/gym_db.dart';
import '../../gym/gym_models.dart';
import '../../theme.dart';
import '../common/widgets.dart';
import 'gym_shell.dart';
import 'gym_widgets.dart';
import 'member_detail_page.dart';
import 'member_form.dart';

enum MemberFilter { all, active, expired, expiring, cert, due, archived }

const _filterLabels = {
  MemberFilter.all: 'Tutti',
  MemberFilter.active: 'Attivi',
  MemberFilter.expiring: 'In scadenza',
  MemberFilter.expired: 'Scaduti',
  MemberFilter.cert: 'Certificato',
  MemberFilter.due: 'Da incassare',
  MemberFilter.archived: 'Archiviati',
};

bool memberMatches(Member m, MemberFilter f, int warnDays) {
  if (f == MemberFilter.archived) return m.archived;
  if (m.archived) return false;
  switch (f) {
    case MemberFilter.all:
      return true;
    case MemberFilter.active:
      return m.subActive;
    case MemberFilter.expiring:
      return m.subActive && ((m.subDaysLeft ?? 99) <= 7 || (m.subKind == 'entries' && m.entriesLeft <= 2));
    case MemberFilter.expired:
      return !m.subActive;
    case MemberFilter.cert:
      return m.certState(warnDays) != CertState.ok;
    case MemberFilter.due:
      return m.dueAmount > 0;
    case MemberFilter.archived:
      return m.archived;
  }
}

Future<void> openMember(BuildContext context, String id) =>
    Navigator.push(context, gymRoute(context, (_) => MemberDetailPage(memberId: id)));

Future<void> newMember(BuildContext context) async {
  final id = await Navigator.push<String>(context, gymRoute(context, (_) => const MemberFormPage()));
  if (id != null && context.mounted) await openMember(context, id);
}

class MembersPage extends StatefulWidget {
  final MemberFilter initial;
  const MembersPage({super.key, this.initial = MemberFilter.all});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  late MemberFilter _filter = widget.initial;
  String _q = '';
  Stream<List<Member>>? _stream;
  String? _gid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final g = GymScope.of(context).gym.id;
    if (g != _gid) {
      _gid = g;
      _stream = GymDb.membersStream(g);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gym = GymScope.of(context).gym;
    return SafeArea(
      child: StreamBuilder<List<Member>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return ErrorBox(friendlyError(snap.error!));
          if (!snap.hasData) return const Loading();
          final all = snap.data!;
          final q = _q.trim().toLowerCase();
          final list = all.where((m) {
            if (!memberMatches(m, _filter, gym.certWarnDays)) return false;
            if (q.isEmpty) return true;
            return m.fullName.toLowerCase().contains(q) ||
                '${m.lastName} ${m.firstName}'.toLowerCase().contains(q) ||
                m.cardNumber.toString() == q ||
                m.taxCode.toLowerCase().contains(q) ||
                m.phone.replaceAll(' ', '').contains(q.replaceAll(' ', '')) ||
                m.email.toLowerCase().contains(q);
          }).toList();
          return Readable(
            maxWidth: 1100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  overline: '${all.where((m) => !m.archived).length} soci',
                  title: 'Soci',
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Esporta elenco (Excel)',
                      icon: const Icon(Icons.download_outlined),
                      onPressed: () => exportMembers(gym.name, list),
                    ),
                    FilledButton.icon(
                      onPressed: () => newMember(context),
                      icon: const Icon(Icons.person_add_alt, size: 18),
                      label: const Text('Nuovo'),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    onChanged: (v) => setState(() => _q = v),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Nome, n. tessera, codice fiscale, telefono…',
                    ),
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                    children: [
                      for (final f in MemberFilter.values) ...[
                        ChoiceChip(
                          label: Text(
                              '${_filterLabels[f]} ${all.where((m) => memberMatches(m, f, gym.certWarnDays)).length}'),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? EmptyState(
                          icon: Icons.badge_outlined,
                          title: all.isEmpty ? 'Nessun socio' : 'Nessun risultato',
                          text: all.isEmpty
                              ? 'Aggiungi il primo socio: anagrafica, foto, certificato e abbonamento.'
                              : 'Prova a cambiare filtro o ricerca.',
                          action: all.isEmpty
                              ? FilledButton(onPressed: () => newMember(context), child: const Text('Nuovo socio'))
                              : null,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => MemberTile(m: list[i], warnDays: gym.certWarnDays),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class MemberTile extends StatelessWidget {
  final Member m;
  final int warnDays;
  final Widget? trailing;
  const MemberTile({super.key, required this.m, required this.warnDays, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = m.certState(warnDays);
    return Panel(
      onTap: () => openMember(context, m.id),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          MemberAvatar(m, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(m.fullName.isEmpty ? 'Senza nome' : m.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Text('n. ${m.cardNumber}', style: const TextStyle(fontSize: 12, color: BC.muted)),
                ]),
                const SizedBox(height: 5),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  subTag(m),
                  if (cs != CertState.ok) certTag(m, warnDays),
                  if (m.dueAmount > 0)
                    m.hasOverdue ? StatusTag.bad('Da incassare ${euro(m.dueAmount)}') : StatusTag.neutral('Rate ${euro(m.dueAmount)}'),
                ]),
              ],
            ),
          ),
          trailing ?? const Icon(Icons.chevron_right, color: BC.disabled),
        ],
      ),
    );
  }
}
