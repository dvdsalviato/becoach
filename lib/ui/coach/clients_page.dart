import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../db.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../util.dart';
import '../common/widgets.dart';
import 'client_detail_page.dart';
import 'contact_form.dart';

/// Cliente come lo vede il coach: anagrafica in rubrica e/o account nell'app.
class ClientEntry {
  final Contact? contact;
  final AppUser? user;
  ClientEntry(this.contact, this.user);

  String get name {
    final n = contact?.fullName ?? '';
    return n.isNotEmpty ? n : (user?.name ?? 'Senza nome');
  }

  String get initials => contact != null && contact!.fullName.isNotEmpty ? contact!.initials : (user?.initials ?? '?');
  String get email => (contact?.email.isNotEmpty ?? false) ? contact!.email : (user?.email ?? '');
  String get phone => (contact?.phone.isNotEmpty ?? false) ? contact!.phone : (user?.phone ?? '');
  bool get inApp => user != null;
}

/// Unisce rubrica e clienti dell'app in un'unica lista.
List<ClientEntry> mergeClients(List<Contact> contacts, List<AppUser> users) {
  final byUid = {for (final u in users) u.uid: u};
  final used = <String>{};
  final out = <ClientEntry>[];
  for (final c in contacts) {
    final u = c.linked ? byUid[c.linkedUid] : null;
    if (u != null) used.add(u.uid);
    out.add(ClientEntry(c, u));
  }
  for (final u in users) {
    if (!used.contains(u.uid)) out.add(ClientEntry(null, u));
  }
  out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return out;
}

/// Apre la scheda giusta per il cliente: dettaglio completo se usa l'app, altrimenti anagrafica.
void openClient(BuildContext context, AppUser me, ClientEntry e) {
  if (e.user != null) {
    Navigator.push(
      context,
      pageRoute((_) => ClientDetailPage(me: me, client: e.user!, contact: e.contact)),
    );
  } else {
    Navigator.push(
      context,
      pageRoute((_) => ContactFormPage(coachId: me.uid, contact: e.contact!)),
    );
  }
}

Future<void> showInviteSheet(BuildContext context, AppUser me) async {
  String code;
  try {
    code = await Db.ensureInviteCode(me);
  } catch (e) {
    if (context.mounted) toast(context, 'Errore: $e');
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Invita nell\'app', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
              'Il cliente installa BeCoach, si registra come allenato e inserisce questo codice. '
              'Comparirà da solo nella tua rubrica con nome, telefono ed email.',
              style: TextStyle(color: BC.muted, height: 1.4)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
                color: BC.subtle, borderRadius: BorderRadius.circular(12), border: Border.all(color: BC.border)),
            alignment: Alignment.center,
            child: Text(code, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: 6)),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'Scarica BeCoach e collegati a me con il codice $code'));
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

Future<Contact?> newClientFlow(BuildContext context, AppUser me, {String name = ''}) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  return Navigator.push<Contact>(
    context,
    pageRoute((_) => ContactFormPage(
        coachId: me.uid,
        contact: Contact(
          firstName: parts.isEmpty ? '' : parts.first,
          lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
        ),
      ),
    ),
  );
}

class ClientsPage extends StatefulWidget {
  final AppUser me;
  final ScrollController? scroll;
  const ClientsPage({super.key, required this.me, this.scroll});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  late final Stream<List<AppUser>> _clients = Db.clientsStream(widget.me.uid);
  late final Stream<List<Contact>> _contacts = Db.contactsStream(widget.me.uid);
  late final Stream<List<Session>> _sessions = Db.sessionsForCoach(widget.me.uid);
  final _search = TextEditingController();
  String _query = '';
  int _filter = 0; // 0 tutti, 1 in allenamento, 2 nell'app, 3 solo rubrica
  final Set<String> _syncing = {};
  String? _selKey; // cliente aperto nel pannello a destra (solo schermi larghi)

  static String keyOf(ClientEntry e) => e.user?.uid ?? 'c:${e.contact?.id ?? ''}';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _maybeSync(List<AppUser> users, List<Contact> contacts) {
    final linked = contacts.map((c) => c.linkedUid).toSet();
    final missing = users.where((u) => !linked.contains(u.uid) && !_syncing.contains(u.uid)).toList();
    if (missing.isEmpty) return;
    _syncing.addAll(missing.map((u) => u.uid));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Db.syncClientsToContacts(widget.me.uid, missing).catchError((_) {});
    });
  }

  Future<void> _add() async {
    final choice = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Aggiungi cliente', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Panel(
              onTap: () => Navigator.pop(c, 1),
              child: const Row(
                children: [
                  Icon(Icons.person_add_alt, color: BC.steel),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nuovo cliente', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        Text('Anagrafica e anamnesi in rubrica', style: TextStyle(fontSize: 12.5, color: BC.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Panel(
              onTap: () => Navigator.pop(c, 2),
              child: const Row(
                children: [
                  Icon(Icons.qr_code_2, color: BC.steel),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Invita nell\'app', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        Text('Con il tuo codice si collega e riceve le schede',
                            style: TextStyle(fontSize: 12.5, color: BC.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 1) await newClientFlow(context, widget.me);
    if (choice == 2 && mounted) await showInviteSheet(context, widget.me);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<AppUser>>(
        stream: _clients,
        builder: (context, us) => StreamBuilder<List<Contact>>(
          stream: _contacts,
          builder: (context, cs) => StreamBuilder<List<Session>>(
            stream: _sessions,
            builder: (context, ss) {
              final users = us.data ?? [];
              final contacts = cs.data ?? [];
              if (us.hasData && cs.hasData) _maybeSync(users, contacts);
              final sessions = ss.data ?? <Session>[];
              final liveIds = {for (final s in sessions) if (s.isLive) s.athleteId};
              final lastBy = <String, DateTime>{};
              for (final s in sessions) {
                if (s.isLive || s.startedAt == null) continue;
                final cur = lastBy[s.athleteId];
                if (cur == null || s.startedAt!.isAfter(cur)) lastBy[s.athleteId] = s.startedAt!;
              }
              final all = mergeClients(contacts, users);
              final q = _query.toLowerCase().trim();
              final list = all.where((e) {
                switch (_filter) {
                  case 1:
                    if (e.user == null || !liveIds.contains(e.user!.uid)) return false;
                    break;
                  case 2:
                    if (!e.inApp) return false;
                    break;
                  case 3:
                    if (e.inApp) return false;
                    break;
                }
                return q.isEmpty || e.name.toLowerCase().contains(q) || e.phone.contains(q);
              }).toList()
                ..sort((a, b) {
                  final la = a.user != null && liveIds.contains(a.user!.uid);
                  final lb = b.user != null && liveIds.contains(b.user!.uid);
                  if (la != lb) return la ? -1 : 1;
                  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                });

              final listView = ListView(
                controller: widget.scroll,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  PageHeader(
                    overline: 'Rubrica · ${all.length}',
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
                        onPressed: _add,
                        icon: const Icon(Icons.person_add_alt, color: Colors.white),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                    child: TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Cerca per nome o telefono',
                        prefixIcon: const Icon(Icons.search, color: BC.muted),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close, color: BC.muted),
                                onPressed: () => setState(() {
                                  _search.clear();
                                  _query = '';
                                }),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        _chip('Tutti · ${all.length}', 0),
                        _chip('In allenamento · ${liveIds.length}', 1),
                        _chip('Nell\'app · ${all.where((e) => e.inApp).length}', 2),
                        _chip('Solo rubrica · ${all.where((e) => !e.inApp).length}', 3),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!us.hasData || !cs.hasData)
                    const Padding(padding: EdgeInsets.only(top: 60), child: Loading())
                  else if (all.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: EmptyState(
                        icon: Icons.groups_outlined,
                        title: 'Nessun cliente',
                        text: 'Aggiungi la prima anagrafica o invita un cliente nell\'app con il tuo codice.',
                        action: FilledButton(onPressed: _add, child: const Text('Aggiungi cliente')),
                      ),
                    )
                  else
                    for (final e in list)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: _row(e, liveIds, lastBy),
                      ),
                ],
              );
              return LayoutBuilder(builder: (context, c) {
                if (c.maxWidth < wideBreakpoint - 100) return listView;
                ClientEntry? sel;
                for (final e in all) {
                  if (keyOf(e) == _selKey) sel = e;
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 420, child: listView),
                    const VerticalDivider(width: 1, thickness: 1, color: BC.border),
                    Expanded(child: _detail(sel)),
                  ],
                );
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _detail(ClientEntry? sel) {
    if (sel == null) {
      return const EmptyState(
        icon: Icons.person_search_outlined,
        title: 'Seleziona un cliente',
        text: 'Scegli un cliente dall\'elenco per vedere scheda, storico e anagrafica.',
      );
    }
    if (sel.user != null) {
      return ClientDetailPage(key: ValueKey(keyOf(sel)), me: widget.me, client: sel.user!, contact: sel.contact);
    }
    return Scaffold(
      key: ValueKey(keyOf(sel)),
      appBar: AppBar(title: Text(sel.name), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [ContactForm(coachId: widget.me.uid, contact: sel.contact!, showDelete: false)],
      ),
    );
  }

  Widget _row(ClientEntry e, Set<String> liveIds, Map<String, DateTime> lastBy) {
    final selected = _selKey == keyOf(e) && isWide(context);
    final live = e.user != null && liveIds.contains(e.user!.uid);
    final last = e.user == null ? null : lastBy[e.user!.uid];
    final sub = [
      if ((e.contact?.planType ?? '').isNotEmpty) e.contact!.planType,
      if (e.inApp) last == null ? 'mai allenato' : 'ultimo: ${relDay(last).toLowerCase()}',
      if (!e.inApp) 'non usa l\'app',
    ].join(' · ');
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: selected ? BC.steelTint : null,
      borderColor: selected ? BC.steel : null,
      onTap: () {
        if (isWide(context)) {
          setState(() => _selKey = keyOf(e));
        } else {
          openClient(context, widget.me, e);
        }
      },
      child: Row(
        children: [
          Avatar(e.initials),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(e.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                    if (e.inApp) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.phone_iphone, size: 14, color: BC.steel),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: BC.muted)),
              ],
            ),
          ),
          if (live) const LiveTag(),
          if (e.phone.isNotEmpty)
            IconButton(
              tooltip: 'Chiama',
              visualDensity: VisualDensity.compact,
              onPressed: () => openUrl(context, 'tel:${e.phone.replaceAll(' ', '')}'),
              icon: const Icon(Icons.call_outlined, color: BC.steel, size: 20),
            ),
          const Icon(Icons.chevron_right, color: BC.muted),
        ],
      ),
    );
  }

  Widget _chip(String label, int value) {
    final sel = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => setState(() => _filter = value),
        showCheckmark: false,
        labelStyle: TextStyle(color: sel ? Colors.white : BC.ink, fontWeight: FontWeight.w500, fontSize: 13),
        selectedColor: BC.ink,
        backgroundColor: Colors.white,
        side: BorderSide(color: sel ? BC.ink : BC.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
