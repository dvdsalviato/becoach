import 'package:flutter/material.dart';

import '../../gym/exports.dart';
import '../../gym/gym_db.dart';
import '../../gym/gym_models.dart';
import '../../theme.dart';
import '../common/widgets.dart';
import 'gym_shell.dart';
import 'gym_widgets.dart';

Future<void> showSellSheet(BuildContext context, Member m) {
  final scope = GymScope.of(context);
  return showSheet(context, (c) => GymScope(gym: scope.gym, me: scope.me, child: _SellSheet(m: m)));
}

class _SellSheet extends StatefulWidget {
  final Member m;
  const _SellSheet({required this.m});

  @override
  State<_SellSheet> createState() => _SellSheetState();
}

class _SellSheetState extends State<_SellSheet> {
  Stream<List<PriceItem>>? _items;
  PriceItem? _item;
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _entries = TextEditingController(text: '10');
  final _notes = TextEditingController();
  String _kind = 'time';
  double _listPrice = 0;
  late DateTime _start = _defaultStart();
  DateTime? _end;
  int _rates = 1;
  bool _payNow = true;
  String _method = payMethods.first;
  bool _busy = false;
  String? _error;

  DateTime _defaultStart() {
    final m = widget.m;
    final today = dayOnly(DateTime.now());
    if (m.subActive && m.subKind == 'time' && m.subEnd != null) {
      return dayOnly(m.subEnd!).add(const Duration(days: 1)); // rinnovo: parte dal giorno dopo la scadenza
    }
    return today;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _items ??= GymDb.priceStream(GymScope.of(context).gym.id);
  }

  @override
  void dispose() {
    for (final c in [_name, _price, _entries, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _choose(PriceItem? p) {
    setState(() {
      _item = p;
      if (p != null) {
        _name.text = p.name;
        _kind = p.kind;
        _listPrice = p.price;
        _price.text = euroInput(p.price);
        _entries.text = '${p.entries}';
        _end = p.kind == 'other' ? null : p.endFrom(_start);
      } else {
        _listPrice = 0;
        _end ??= addMonths(_start, 1).subtract(const Duration(days: 1));
      }
    });
  }

  List<Installment> _plan(double total) {
    final n = _rates;
    final base = (total / n * 100).floorToDouble() / 100;
    final out = <Installment>[];
    for (var i = 0; i < n; i++) {
      final amount = i == n - 1 ? double.parse((total - base * (n - 1)).toStringAsFixed(2)) : base;
      out.add(Installment(amount: amount, due: i == 0 ? dayOnly(DateTime.now()) : addMonths(_start, i)));
    }
    return out;
  }

  Future<void> _save() async {
    final scope = GymScope.of(context);
    final price = parseEuro(_price.text);
    if (_name.text.trim().isEmpty) { setState(() => _error = 'Scegli dal listino o scrivi il nome'); return; }
    if (price == null || price < 0) { setState(() => _error = 'Prezzo non valido'); return; }
    final isAccess = _kind != 'other';
    if (isAccess && (_end == null || _end!.isBefore(_start))) { setState(() => _error = 'Controlla le date'); return; }
    final entries = int.tryParse(_entries.text) ?? 0;
    if (_kind == 'entries' && entries <= 0) { setState(() => _error = 'Numero ingressi non valido'); return; }
    final inst = _plan(price);
    if (_payNow && inst.isNotEmpty && price > 0) {
      inst.first
        ..paidAt = DateTime.now()
        ..method = _method;
    }
    if (price == 0) inst.clear();
    final s = Subscription(
      memberId: widget.m.id,
      memberName: widget.m.fullName,
      itemId: _item?.id ?? '',
      name: _name.text.trim(),
      kind: _kind,
      start: _start,
      end: isAccess ? _end! : _start,
      entriesTotal: _kind == 'entries' ? entries : 0,
      listPrice: _listPrice > 0 ? _listPrice : price,
      price: price,
      installments: inst,
      notes: _notes.text.trim(),
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await GymDb.sellSubscription(scope.gym.id, s, by: scope.me.uid, byName: scope.me.name);
      if (mounted) Navigator.pop(context);
      if (_payNow && price > 0) {
        final pays = await GymDb.payments(scope.gym.id).where('subscriptionId', isEqualTo: id).get();
        if (pays.docs.isNotEmpty) {
          final p = Payment.fromDoc(pays.docs.first);
          await shareReceipt(scope.gym, p, m: widget.m);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = parseEuro(_price.text) ?? 0;
    final inst = _plan(price);
    return StreamBuilder<List<PriceItem>>(
      stream: _items,
      builder: (context, snap) {
        final items = (snap.data ?? []).where((p) => p.active).toList();
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text('Vendita a ${widget.m.fullName}',
                style: const TextStyle(fontFamily: BC.display, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (items.isEmpty && snap.hasData)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('Il listino è vuoto: puoi compilarlo da Altro → Listino, oppure inserire qui a mano.',
                    style: TextStyle(fontSize: 13, color: BC.muted)),
              ),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final p in items)
                ChoiceChip(
                  label: Text('${p.name} · ${euro(p.price)}'),
                  selected: _item?.id == p.id,
                  onSelected: (_) => _choose(p),
                ),
              ChoiceChip(label: const Text('Personalizzato'), selected: _item == null && _name.text.isNotEmpty, onSelected: (_) {
                _name.clear();
                _choose(null);
              }),
            ]),
            const SizedBox(height: 14),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Descrizione'), onChanged: (_) => setState(() {})),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'time', label: Text('A tempo')),
                ButtonSegment(value: 'entries', label: Text('Ingressi')),
                ButtonSegment(value: 'other', label: Text('Prodotto')),
              ],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() {
                _kind = v.first;
                if (_kind != 'other') _end ??= addMonths(_start, 1).subtract(const Duration(days: 1));
              }),
            ),
            const SizedBox(height: 12),
            if (_kind != 'other')
              Row(children: [
                Expanded(
                  child: DateField(
                    label: 'Inizio',
                    value: _start,
                    onChanged: (d) => setState(() {
                      if (d == null) return;
                      _start = d;
                      if (_item != null && _item!.kind != 'other') _end = _item!.endFrom(d);
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: DateField(label: 'Fine', value: _end, onChanged: (d) => setState(() => _end = d))),
              ]),
            if (_kind == 'entries') ...[
              const SizedBox(height: 12),
              TextField(controller: _entries, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Numero ingressi')),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Prezzo €',
                    helperText: _listPrice > 0 && price < _listPrice
                        ? 'Sconto ${euro(_listPrice - price)} (${((1 - price / _listPrice) * 100).round()}%)'
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _rates,
                  decoration: const InputDecoration(labelText: 'Pagamento'),
                  items: [
                    for (final n in [1, 2, 3, 4, 6, 12])
                      DropdownMenuItem(value: n, child: Text(n == 1 ? 'Unica soluzione' : '$n rate mensili')),
                  ],
                  onChanged: (v) => setState(() => _rates = v ?? 1),
                ),
              ),
            ]),
            if (_rates > 1 && price > 0) ...[
              const SizedBox(height: 8),
              Text(
                inst.map((i) => '${euro(i.amount)} il ${dmy(i.due)}').join('  ·  '),
                style: const TextStyle(fontSize: 12.5, color: BC.muted),
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              value: _payNow,
              onChanged: (v) => setState(() => _payNow = v),
              contentPadding: EdgeInsets.zero,
              title: Text(_rates > 1 ? 'Incassa ora la prima rata' : 'Incassa ora'),
              subtitle: _payNow && price > 0 ? Text(euro(inst.isEmpty ? 0 : inst.first.amount)) : null,
            ),
            if (_payNow)
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final m in payMethods)
                  ChoiceChip(label: Text(m), selected: _method == m, onSelected: (_) => setState(() => _method = m)),
              ]),
            const SizedBox(height: 12),
            TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Note (facoltative)')),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: BC.danger)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_payNow && price > 0 ? 'Vendi e incassa ${euro(inst.isEmpty ? 0 : inst.first.amount)}' : 'Vendi'),
            ),
          ],
        );
      },
    );
  }
}
