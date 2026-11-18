import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../db.dart';
import '../../models.dart';
import '../../theme.dart';
import '../common/widgets.dart';
import 'client_detail_page.dart';

class ClientsPage extends StatefulWidget {
  final AppUser me;
  const ClientsPage({super.key, required this.me});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  late final Stream<List<AppUser>> _clients = Db.clientsStream(widget.me.uid);
  late final Stream<List<Session>> _live = Db.liveSessionsForCoach(widget.me.uid);
  String _query = '';
  bool _onlyLive = false;

  Future<void> _invite() async {
    String code;
    try {
      code = await Db.ensureInviteCode(widget.me);
    } catch (e) {
      if (mounted) toast(context, 'Errore: $e');
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Aggiungi un cliente',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
                'Il cliente installa BeCoach, si registra come allenato e inserisce questo codice.',
                style: TextStyle(color: BC.muted, height: 1.4)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                  color: BC.subtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BC.border)),
              alignment: Alignment.center,
              child: Text(code,
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: 6)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(
                    text:
                        'Scarica BeCoach e collegati a me con il codice $code'));
                Navigator.pop(c);
                toast(context, 'Messaggio con il codice copiato');
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copia messaggio di invito'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<AppUser>>(
        stream: _clients,
        builder: (context, cs) {
          return StreamBuilder<List<Session>>(
            stream: _live,
            builder: (context, ls) {
              final liveIds = {for (final s in ls.data ?? <Session>[]) s.athleteId};
              final all = cs.data ?? [];
              final q = _query.toLowerCase();
              final list = all.where((c) {
                if (_onlyLive && !liveIds.contains(c.uid)) return false;
                return q.isEmpty || c.name.toLowerCase().contains(q);
              }).toList()
                ..sort((a, b) {
                  final la = liveIds.contains(a.uid), lb = liveIds.contains(b.uid);
                  if (la != lb) return la ? -1 : 1;
                  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                });

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeader(
                    overline: 'BeCoach · Coach',
                    title: 'Clienti',
                    trailing: SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton.filled(
                        tooltip: 'Aggiungi cliente',
                        style: IconButton.styleFrom(
                          backgroundColor: BC.graphite,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _invite,
                        icon: const Icon(Icons.person_add_alt, color: Colors.white),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'Cerca cliente',
                        prefixIcon: Icon(Icons.search, color: BC.muted),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Row(
                      children: [
                        _chip('Tutti · ${all.length}', !_onlyLive,
                            () => setState(() => _onlyLive = false)),
                        const SizedBox(width: 8),
                        _chip('In allenamento · ${liveIds.length}', _onlyLive,
                            () => setState(() => _onlyLive = true)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: cs.hasError
                        ? ErrorBox(cs.error)
                        : !cs.hasData
                            ? const Loading()
                            : all.isEmpty
                                ? EmptyState(
                                    icon: Icons.groups_outlined,
                                    title: 'Nessun cliente',
                                    text:
                                        'Invita i tuoi clienti con il codice: compariranno qui appena si collegano.',
                                    action: FilledButton(
                                        onPressed: _invite, child: const Text('Invita un cliente')),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                                    itemCount: list.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                                    itemBuilder: (c, i) {
                                      final cl = list[i];
                                      final live = liveIds.contains(cl.uid);
                                      return Panel(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 12),
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ClientDetailPage(me: widget.me, client: cl),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Avatar(cl.initials),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(cl.name,
                                                      style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w600)),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                      cl.goal.isNotEmpty ? cl.goal : cl.email,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 13, color: BC.muted)),
                                                ],
                                              ),
                                            ),
                                            if (live) const LiveTag(),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.chevron_right, color: BC.muted),
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
        },
      ),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) => ChoiceChip(
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
      );
}
