import 'package:flutter/material.dart';

import '../../gym/exports.dart';
import '../../gym/gym_db.dart';
import '../../gym/gym_models.dart';
import '../../theme.dart';
import '../common/widgets.dart';
import 'gym_shell.dart';
import 'gym_widgets.dart';

const _months = ['Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno', 'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'];

/// Prima nota: entrate e uscite del mese, totali per metodo, export per il commercialista.
class CashPage extends StatefulWidget {
  const CashPage({super.key});

  @override
  State<CashPage> createState() => _CashPageState();
}

class _CashPageState extends State<CashPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _day = false; // solo oggi
  Stream<List<Payment>>? _stream;
  String? _key;

  (DateTime, DateTime) get _range {
    if (_day) {
      final d = dayOnly(DateTime.now());
      return (d, d.add(const Duration(days: 1)));
    }
    return (_month, DateTime(_month.year, _month.month + 1));
  }

  void _load(String g) {
    final (a, b) = _range;
    final k = '$g-$a-$b';
    if (k == _key) return;
    _key = k;
    _stream = GymDb.paymentsBetween(g, a, b);
  }

  @override
  Widget build(BuildContext context) {
    final gym = GymScope.of(context).gym;
    _load(gym.id);
    final label = _day ? 'Oggi' : '${_months[_month.month - 1]} ${_month.year}';
    return SafeArea(
      child: StreamBuilder<List<Payment>>(
        stream: _stream,
        builder: (context, snap) {
          final list = snap.data ?? [];
          final inc = list.where((p) => p.isIncome).fold<double>(0, (a, p) => a + p.amount);
          final out = list.where((p) => !p.isIncome).fold<double>(0, (a, p) => a - p.amount);
          final byMethod = <String, double>{};
          for (final p in list.where((p) => p.isIncome)) {
            byMethod[p.method] = (byMethod[p.method] ?? 0) + p.amount;
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              PageHeader(
                overline: 'Prima nota',
                title: 'Cassa',
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'Esporta per il commercialista (Excel)',
                    icon: const Icon(Icons.download_outlined),
                    onPressed: list.isEmpty ? null : () => exportPayments(gym.name, label, list),
                  ),
                  FilledButton.icon(
                    onPressed: () => showMovementSheet(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Movimento'),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  IconButton(
                    onPressed: _day ? null : () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: BC.display, fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    onPressed: _day ? null : () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(label: const Text('Oggi'), selected: _day, onSelected: (v) => setState(() => _day = v)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(children: [
                  Expanded(child: StatBox(label: 'Entrate', value: euro(inc), color: okFg)),
                  const SizedBox(width: 8),
                  Expanded(child: StatBox(label: 'Uscite', value: euro(out), color: badFg)),
                  const SizedBox(width: 8),
                  Expanded(child: StatBox(label: 'Saldo', value: euro(inc - out))),
                ]),
              ),
              if (byMethod.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final e in byMethod.entries) Tag('${e.key}: ${euro(e.value)}', fg: BC.body),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SectionLabel('Movimenti · ${list.length}'),
              ),
              if (!snap.hasData)
                const Padding(padding: EdgeInsets.all(24), child: Loading())
              else if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Nessun movimento nel periodo.', style: TextStyle(color: BC.muted)),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Panel(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _MovementTile(p: list[i]),
                      ],
                    ]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final Payment p;
  const _MovementTile({required this.p});

  @override
  Widget build(BuildContext context) {
    final gym = GymScope.of(context).gym;
    return ListTile(
      leading: Icon(p.isIncome ? Icons.south_west : Icons.north_east, color: p.isIncome ? okFg : badFg),
      title: Text(p.memberName.isNotEmpty ? '${p.memberName} · ${p.description}' : (p.description.isEmpty ? p.category : p.description),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [dmy(p.date), p.method, if (p.category.isNotEmpty) p.category, if (p.receiptNo.isNotEmpty) 'ric. ${p.receiptNo}'].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(euro(p.amount),
          style: TextStyle(fontWeight: FontWeight.w700, color: p.isIncome ? BC.ink : badFg)),
      onTap: () => showSheet(
        context,
        (c) => Column(mainAxisSize: MainAxisSize.min, children: [
          if (p.isIncome)
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Ricevuta PDF'),
              onTap: () async {
                Navigator.pop(c);
                Member? m;
                if (p.memberId.isNotEmpty) {
                  final d = await GymDb.members(gym.id).doc(p.memberId).get();
                  if (d.exists) m = Member.fromDoc(d);
                }
                await shareReceipt(gym, p, m: m);
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: BC.danger),
            title: const Text('Elimina movimento', style: TextStyle(color: BC.danger)),
            subtitle: p.subscriptionId.isNotEmpty ? const Text('La rata dell\'abbonamento tornerà da incassare') : null,
            onTap: () async {
              Navigator.pop(c);
              if (await confirm(context, 'Elimina movimento', 'Eliminare ${euro(p.amount)} del ${dmy(p.date)}?', ok: 'Elimina', danger: true)) {
                await GymDb.deleteMovement(gym.id, p);
              }
            },
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}

Future<void> showMovementSheet(BuildContext context) {
  final scope = GymScope.of(context);
  return showSheet(context, (c) => GymScope(gym: scope.gym, me: scope.me, child: const _MovementSheet()));
}

class _MovementSheet extends StatefulWidget {
  const _MovementSheet();

  @override
  State<_MovementSheet> createState() => _MovementSheetState();
}

class _MovementSheetState extends State<_MovementSheet> {
  bool _income = false;
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  String _cat = expenseCategories.first;
  String _method = payMethods.first;
  DateTime _date = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = parseEuro(_amount.text);
    if (v == null || v <= 0) {
      setState(() => _error = 'Importo non valido');
      return;
    }
    final scope = GymScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await GymDb.addMovement(
        scope.gym.id,
        Payment(
          date: _date,
          amount: _income ? v : -v,
          method: _method,
          category: _cat,
          description: _desc.text.trim(),
          createdBy: scope.me.name,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = _income ? incomeCategories : expenseCategories;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        const Text('Nuovo movimento', style: TextStyle(fontFamily: BC.display, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Uscita'), icon: Icon(Icons.north_east)),
            ButtonSegment(value: true, label: Text('Entrata'), icon: Icon(Icons.south_west)),
          ],
          selected: {_income},
          onSelectionChanged: (s) => setState(() {
            _income = s.first;
            _cat = (_income ? incomeCategories : expenseCategories).first;
          }),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Importo €'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: DateField(label: 'Data', value: _date, onChanged: (d) => setState(() => _date = d ?? _date))),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: cats.contains(_cat) ? _cat : cats.first,
          decoration: const InputDecoration(labelText: 'Categoria'),
          items: [for (final c in cats) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (v) => setState(() => _cat = v ?? _cat),
        ),
        const SizedBox(height: 12),
        TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Descrizione (es. fornitore, n. fattura)')),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final m in payMethods) ChoiceChip(label: Text(m), selected: _method == m, onSelected: (_) => setState(() => _method = m)),
        ]),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: BC.danger)),
        ],
        const SizedBox(height: 16),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Registra')),
      ],
    );
  }
}
