import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../db.dart';
import '../../gym/gym_db.dart';
import '../../gym/gym_models.dart';
import '../../theme.dart';
import '../../updates.dart';
import '../common/widgets.dart';
import '../../gym/exports.dart';
import 'courses_page.dart';
import 'gym_shell.dart';
import 'import_page.dart';
import 'stats_page.dart';
import 'gym_widgets.dart';

class GymMorePage extends StatelessWidget {
  const GymMorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = GymScope.of(context);
    final g = scope.gym, me = scope.me;
    final owner = g.isOwner(me.uid);
    Widget item(IconData icon, String title, String sub, Widget page) => Panel(
          onTap: () => Navigator.push(context, gymRoute(context, (_) => page)),
          child: Row(children: [
            Icon(icon, color: BC.steel),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                Text(sub, style: const TextStyle(fontSize: 13, color: BC.muted)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: BC.disabled),
          ]),
        );
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          PageHeader(overline: owner ? 'Titolare' : 'Staff', title: 'Altro'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              item(Icons.groups_2_outlined, 'Corsi', 'Orario settimanale, posti e prenotazioni', const CoursesPage()),
              const SizedBox(height: 8),
              if (g.canSeeCash(me.uid)) ...[
                item(Icons.bar_chart, 'Statistiche', 'Incassi per mese, affluenza per giorno e ora, vendite', const StatsPage()),
                const SizedBox(height: 8),
              ],
              item(Icons.upload_file, 'Importa iscritti', 'Dal vecchio gestionale, con un file CSV di Excel', const ImportPage()),
              const SizedBox(height: 8),
              item(Icons.sell_outlined, 'Listino', 'Iscrizione, abbonamenti, pacchetti ingressi e prodotti', const PriceListPage()),
              const SizedBox(height: 8),
              item(Icons.storefront_outlined, 'Dati della palestra', 'Ragione sociale, P. IVA, indirizzo per le ricevute', const GymInfoPage()),
              const SizedBox(height: 8),
              item(Icons.badge_outlined, 'Staff', 'Codice staff, richieste di accesso', const StaffPage()),
              if (owner) ...[
                const SizedBox(height: 8),
                Panel(
                  onTap: () async {
                    final list = await GymDb.subsSince(g.id, DateTime(2000));
                    await exportSubscriptions(g.name, list);
                  },
                  child: const Row(children: [
                    Icon(Icons.download_outlined, color: BC.steel),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Esporta tutti gli abbonamenti', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                        Text('File Excel con vendite, pagato e da incassare', style: TextStyle(fontSize: 13, color: BC.muted)),
                      ]),
                    ),
                  ]),
                ),
              ],
              const SectionLabel('Account'),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('${me.name} · ${me.email}', style: const TextStyle(fontSize: 13.5, color: BC.body)),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Db.updateUser(me.uid, {'gymMode': false}),
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Passa a BeCoach coach/allenato'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => Updates.checkManually(context),
                    icon: const Icon(Icons.system_update_outlined, size: 18),
                    label: const Text('Controlla aggiornamenti'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => Db.signOut(), child: const Text('Esci', style: TextStyle(color: BC.danger))),
                ]),
              ),
              const SizedBox(height: 16),
              const Center(child: Text('BeCoach 2.0 · Gestionale', style: TextStyle(color: BC.disabled, fontSize: 12))),
            ]),
          ),
        ],
      ),
    );
  }
}

// ---------------- listino ----------------

class PriceListPage extends StatelessWidget {
  const PriceListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final g = GymScope.of(context).gym;
    return Scaffold(
      appBar: AppBar(title: const Text('Listino'), actions: [
        IconButton(icon: const Icon(Icons.add), tooltip: 'Nuova voce', onPressed: () => _edit(context, PriceItem())),
      ]),
      body: StreamBuilder<List<PriceItem>>(
        stream: GymDb.priceStream(g.id),
        builder: (context, snap) {
          if (snap.hasError) return ErrorBox(friendlyError(snap.error!));
          if (!snap.hasData) return const Loading();
          final list = snap.data!;
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.sell_outlined,
              title: 'Listino vuoto',
              text: 'Inserisci gli abbonamenti che vendi: mensile, trimestrale, annuale, pacchetti da 10 ingressi…',
              action: Column(children: [
                FilledButton(onPressed: () => _edit(context, PriceItem()), child: const Text('Aggiungi una voce')),
                TextButton(onPressed: () => _seed(g.id), child: const Text('Crea un listino di esempio')),
              ]),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final p = list[i];
              return Panel(
                onTap: () => _edit(context, p),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name,
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: p.active ? BC.ink : BC.disabled)),
                      Text(p.durationLabel + (p.active ? '' : ' · non in vendita'), style: const TextStyle(fontSize: 13, color: BC.muted)),
                    ]),
                  ),
                  Text(euro(p.price), style: const TextStyle(fontFamily: BC.display, fontSize: 17, fontWeight: FontWeight.w700)),
                ]),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _seed(String g) async {
    final items = [
      PriceItem(name: 'Iscrizione annuale (tessera)', kind: 'enroll', months: 12, price: 30),
      PriceItem(name: 'Mensile', kind: 'time', months: 1, price: 50),
      PriceItem(name: 'Trimestrale', kind: 'time', months: 3, price: 135),
      PriceItem(name: 'Semestrale', kind: 'time', months: 6, price: 250),
      PriceItem(name: 'Annuale', kind: 'time', months: 12, price: 450),
      PriceItem(name: '10 ingressi', kind: 'entries', entries: 10, months: 3, price: 80),
      PriceItem(name: 'Ingresso singolo', kind: 'entries', entries: 1, months: 0, days: 1, price: 10),
      PriceItem(name: 'Personal training (1 h)', kind: 'other', price: 35),
    ];
    for (final p in items) {
      await GymDb.savePrice(g, p);
    }
  }

  void _edit(BuildContext context, PriceItem p) {
    final scope = GymScope.of(context);
    showSheet(context, (c) => GymScope(gym: scope.gym, me: scope.me, child: _PriceSheet(item: p)));
  }
}

class _PriceSheet extends StatefulWidget {
  final PriceItem item;
  const _PriceSheet({required this.item});

  @override
  State<_PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends State<_PriceSheet> {
  late final p = widget.item;
  late final _name = TextEditingController(text: p.name);
  late final _price = TextEditingController(text: p.price == 0 ? '' : euroInput(p.price));
  late final _months = TextEditingController(text: '${p.months}');
  late final _days = TextEditingController(text: '${p.days}');
  late final _entries = TextEditingController(text: '${p.entries}');
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _price, _months, _days, _entries]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final price = parseEuro(_price.text);
    if (_name.text.trim().isEmpty || price == null) {
      setState(() => _error = 'Nome e prezzo sono obbligatori');
      return;
    }
    p
      ..name = _name.text
      ..price = price
      ..months = int.tryParse(_months.text) ?? 0
      ..days = int.tryParse(_days.text) ?? 0
      ..entries = int.tryParse(_entries.text) ?? 0;
    if (p.kind != 'other' && p.months == 0 && p.days == 0) {
      setState(() => _error = 'Indica la durata (mesi o giorni)');
      return;
    }
    try {
      await GymDb.savePrice(GymScope.of(context).gym.id, p);
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
        Text(p.id.isEmpty ? 'Nuova voce di listino' : 'Modifica voce',
            style: const TextStyle(fontFamily: BC.display, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'time', label: Text('A tempo')),
            ButtonSegment(value: 'entries', label: Text('Ingressi')),
            ButtonSegment(value: 'enroll', label: Text('Iscrizione')),
            ButtonSegment(value: 'other', label: Text('Prodotto')),
          ],
          selected: {p.kind},
          onSelectionChanged: (v) => setState(() => p.kind = v.first),
        ),
        const SizedBox(height: 12),
        TextField(controller: _name, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nome')),
        const SizedBox(height: 12),
        TextField(
          controller: _price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Prezzo €'),
        ),
        if (p.kind != 'other') ...[
          const SizedBox(height: 12),
          Row(children: [
            if (p.kind == 'entries') ...[
              Expanded(
                child: TextField(controller: _entries, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ingressi')),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: TextField(
                controller: _months,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: p.kind == 'entries' ? 'Validità mesi' : 'Mesi'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(controller: _days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '+ giorni')),
            ),
          ]),
        ],
        SwitchListTile(
          value: p.active,
          onChanged: (v) => setState(() => p.active = v),
          contentPadding: EdgeInsets.zero,
          title: const Text('In vendita'),
        ),
        if (_error != null) Text(_error!, style: const TextStyle(color: BC.danger)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _save, child: const Text('Salva')),
        if (p.id.isNotEmpty)
          TextButton(
            onPressed: () async {
              final g = GymScope.of(context).gym.id;
              await GymDb.deletePrice(g, p.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Elimina', style: TextStyle(color: BC.danger)),
          ),
      ],
    );
  }
}

// ---------------- dati palestra ----------------

class GymInfoPage extends StatefulWidget {
  const GymInfoPage({super.key});

  @override
  State<GymInfoPage> createState() => _GymInfoPageState();
}

class _GymInfoPageState extends State<GymInfoPage> {
  final _c = <String, TextEditingController>{};
  bool _busy = false;
  bool? _req;
  bool? _cash;

  TextEditingController _ctl(String k, String v) => _c.putIfAbsent(k, () => TextEditingController(text: v));

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = GymScope.of(context).gym;
    _req ??= g.requireEnrollment;
    final fields = {
      'name': ('Nome della palestra', g.name),
      'legalName': ('Ragione sociale', g.legalName),
      'vat': ('Partita IVA', g.vat),
      'taxCode': ('Codice fiscale', g.taxCode),
      'address': ('Indirizzo completo', g.address),
      'phone': ('Telefono', g.phone),
      'email': ('Email', g.email),
      'receiptNote': ('Nota in fondo alle ricevute', g.receiptNote),
      'certWarnDays': ('Avvisa scadenza certificato (giorni prima)', '${g.certWarnDays}'),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Dati della palestra')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          for (final e in fields.entries) ...[
            TextField(
              controller: _ctl(e.key, e.value.$2),
              maxLines: e.key == 'receiptNote' ? 3 : 1,
              keyboardType: e.key == 'certWarnDays' ? TextInputType.number : null,
              decoration: InputDecoration(labelText: e.value.$1),
            ),
            const SizedBox(height: 12),
          ],
          if (g.isOwner(GymScope.of(context).me.uid))
            SwitchListTile(
              value: _cash ?? g.staffSeesCash,
              onChanged: (v) => setState(() => _cash = v),
              contentPadding: EdgeInsets.zero,
              title: const Text('Lo staff vede cassa e statistiche'),
              subtitle: const Text('Se spento, solo il titolare vede incassi, prima nota e statistiche'),
            ),
          SwitchListTile(
            value: _req!,
            onChanged: (v) => setState(() => _req = v),
            contentPadding: EdgeInsets.zero,
            title: const Text('Per entrare serve l\'iscrizione valida'),
            subtitle: const Text('Oltre ad abbonamento e certificato, controlla la tessera di iscrizione annuale'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      final data = <String, dynamic>{
                        for (final k in fields.keys) if (k != 'certWarnDays') k: _c[k]!.text.trim(),
                        'certWarnDays': int.tryParse(_c['certWarnDays']!.text) ?? 30,
                        'requireEnrollment': _req ?? true,
                        if (_cash != null) 'staffSeesCash': _cash,
                      };
                      await GymDb.updateGym(g.id, data);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) toast(context, friendlyError(e));
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }
}

// ---------------- staff ----------------

class StaffPage extends StatelessWidget {
  const StaffPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = GymScope.of(context);
    final g = scope.gym;
    final owner = g.isOwner(scope.me.uid);
    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Codice staff', style: TextStyle(fontSize: 13, color: BC.muted)),
              Row(children: [
                Expanded(
                  child: SelectableText(g.joinCode,
                      style: const TextStyle(fontFamily: BC.display, fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: 3)),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: g.joinCode));
                    toast(context, 'Codice copiato');
                  },
                ),
              ]),
              const Text(
                'Chi lavora in reception installa BeCoach, sceglie "Gestisco una palestra" e inserisce questo codice. '
                'Poi tu approvi la richiesta qui sotto.',
                style: TextStyle(fontSize: 13, color: BC.muted, height: 1.4),
              ),
            ]),
          ),
          if (owner)
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: GymDb.staffRequestsStream(g.id),
              builder: (context, snap) {
                final reqs = snap.data ?? [];
                if (reqs.isEmpty) return const SizedBox.shrink();
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SectionLabel('Richieste di accesso'),
                  for (final r in reqs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Panel(
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${r['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('${r['email'] ?? ''}', style: const TextStyle(fontSize: 13, color: BC.muted)),
                            ]),
                          ),
                          TextButton(
                            onPressed: () => GymDb.rejectStaff(g.id, r['uid'] as String),
                            child: const Text('Rifiuta', style: TextStyle(color: BC.muted)),
                          ),
                          FilledButton(
                            onPressed: () => GymDb.approveStaff(g.id, r['uid'] as String, '${r['name'] ?? ''}'),
                            child: const Text('Approva'),
                          ),
                        ]),
                      ),
                    ),
                ]);
              },
            ),
          const SectionLabel('Persone con accesso'),
          for (final uid in g.staff)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                child: Row(children: [
                  Avatar((g.staffNames[uid] ?? '?').isEmpty ? '?' : (g.staffNames[uid] ?? '?')[0].toUpperCase(), size: 36),
                  const SizedBox(width: 12),
                  Expanded(child: Text(g.staffNames[uid] ?? uid, style: const TextStyle(fontWeight: FontWeight.w600))),
                  if (uid == g.owner)
                    const StatusTag.neutral('Titolare')
                  else if (owner)
                    TextButton(
                      onPressed: () async {
                        if (await confirm(context, 'Rimuovi', 'Togliere l\'accesso a ${g.staffNames[uid] ?? 'questa persona'}?',
                            ok: 'Rimuovi', danger: true)) {
                          await GymDb.removeStaff(g.id, uid);
                        }
                      },
                      child: const Text('Rimuovi', style: TextStyle(color: BC.danger)),
                    ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
