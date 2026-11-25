import 'package:flutter/material.dart';

import '../../gym/gym_db.dart';
import '../../gym/gym_models.dart';
import '../../theme.dart';
import '../common/widgets.dart';
import 'gym_shell.dart';
import 'gym_widgets.dart';

const _mesi = ['Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'];
const _giorni = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

class _Data {
  final List<Payment> pays;
  final List<Checkin> ins;
  final List<Subscription> subs;
  final List<Member> members;
  _Data(this.pays, this.ins, this.subs, this.members);
}

/// Statistiche: incassi per mese, affluenza per giorno e ora, vendite, iscritti.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  Future<_Data>? _f;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _f ??= _load(GymScope.of(context).gym.id);
  }

  Future<_Data> _load(String g) async {
    final now = DateTime.now();
    final from12 = DateTime(now.year, now.month - 11);
    final from30 = dayOnly(now).subtract(const Duration(days: 30));
    final r = await Future.wait([
      GymDb.paymentsSince(g, from12),
      GymDb.checkinsFrom(g, from30),
      GymDb.subsSince(g, from12),
      GymDb.membersStream(g).first,
    ]);
    return _Data(r[0] as List<Payment>, r[1] as List<Checkin>, r[2] as List<Subscription>, r[3] as List<Member>);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistiche'), actions: [
        IconButton(
          tooltip: 'Aggiorna',
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(() => _f = _load(GymScope.of(context).gym.id)),
        ),
      ]),
      body: FutureBuilder<_Data>(
        future: _f,
        builder: (context, snap) {
          if (snap.hasError) return ErrorBox(friendlyError(snap.error!));
          if (!snap.hasData) return const Loading();
          final d = snap.data!;
          final now = DateTime.now();
          // incassi per mese (ultimi 12)
          final months = [for (var i = 11; i >= 0; i--) DateTime(now.year, now.month - i)];
          final inc = [
            for (final m in months)
              d.pays.where((p) => p.isIncome && p.date.year == m.year && p.date.month == m.month).fold<double>(0, (a, p) => a + p.amount)
          ];
          final out = [
            for (final m in months)
              d.pays.where((p) => !p.isIncome && p.date.year == m.year && p.date.month == m.month).fold<double>(0, (a, p) => a - p.amount)
          ];
          // affluenza
          final ok = d.ins.where((c) => c.ok).toList();
          final byDay = List<double>.filled(7, 0);
          final byHour = List<double>.filled(24, 0);
          for (final c in ok) {
            byDay[c.at.weekday - 1]++;
            byHour[c.at.hour]++;
          }
          final hours = [for (var h = 6; h <= 23; h++) h];
          // vendite per tipo
          final sales = <String, (int, double)>{};
          for (final s in d.subs.where((s) => !s.cancelled)) {
            final v = sales[s.name] ?? (0, 0.0);
            sales[s.name] = (v.$1 + 1, v.$2 + s.price);
          }
          final salesSorted = sales.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));
          final members = d.members.where((m) => !m.archived).toList();
          final active = members.where((m) => m.subActive).length;
          final newThisMonth = members.where((m) => m.createdAt != null && m.createdAt!.year == now.year && m.createdAt!.month == now.month).length;
          final renewRate = () {
            final ended = members.where((m) => m.subEnd != null && m.subEnd!.isBefore(now) && m.subEnd!.isAfter(now.subtract(const Duration(days: 60))));
            return ended.length;
          }();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                SizedBox(width: 160, child: StatBox(label: 'Iscritti', value: '${members.length}')),
                SizedBox(width: 160, child: StatBox(label: 'Abbonamenti attivi', value: '$active')),
                SizedBox(width: 160, child: StatBox(label: 'Nuovi questo mese', value: '$newThisMonth')),
                SizedBox(width: 160, child: StatBox(label: 'Non rinnovati (60 gg)', value: '$renewRate', color: renewRate > 0 ? BC.warnFg : null)),
                SizedBox(width: 160, child: StatBox(label: 'Ingressi 30 gg', value: '${ok.length}', sub: '${(ok.length / 30).toStringAsFixed(1)} al giorno')),
              ]),
              const SectionLabel('Incassi ultimi 12 mesi'),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Bars(values: inc, labels: [for (final m in months) _mesi[m.month - 1]], color: BC.steel, format: (v) => euro(v)),
                  const SizedBox(height: 8),
                  Text(
                    'Totale ${euro(inc.fold<double>(0, (a, b) => a + b))} · uscite ${euro(out.fold<double>(0, (a, b) => a + b))}',
                    style: const TextStyle(fontSize: 12.5, color: BC.muted),
                  ),
                ]),
              ),
              const SectionLabel('Affluenza per giorno (ultimi 30 giorni)'),
              Panel(child: Bars(values: byDay, labels: _giorni, color: BC.graphite, format: (v) => v.toStringAsFixed(0))),
              const SectionLabel('Affluenza per ora'),
              Panel(
                child: Bars(
                  values: [for (final h in hours) byHour[h]],
                  labels: [for (final h in hours) '$h'],
                  color: BC.graphite,
                  format: (v) => v.toStringAsFixed(0),
                ),
              ),
              const SectionLabel('Vendite ultimi 12 mesi'),
              if (salesSorted.isEmpty)
                const Text('Nessuna vendita.', style: TextStyle(color: BC.muted))
              else
                Panel(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (var i = 0; i < salesSorted.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        dense: true,
                        title: Text(salesSorted[i].key),
                        subtitle: Text('${salesSorted[i].value.$1} venduti'),
                        trailing: Text(euro(salesSorted[i].value.$2), style: const TextStyle(fontWeight: FontWeight.w700)),
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

/// Istogramma semplice a barre verticali.
class Bars extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color color;
  final String Function(double) format;
  const Bars({super.key, required this.values, required this.labels, required this.color, required this.format});

  @override
  Widget build(BuildContext context) {
    final max = values.fold<double>(0, (a, b) => b > a ? b : a);
    final best = max == 0 ? -1 : values.indexOf(max);
    return SizedBox(
      height: 150,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Tooltip(
              message: '${labels[i]}: ${format(values[i])}',
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (i == best)
                  Text(format(values[i]), maxLines: 1, overflow: TextOverflow.visible, softWrap: false,
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700)),
                Container(
                  height: max == 0 ? 2 : 2 + 110 * values[i] / max,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(color: i == best ? color : color.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 4),
                Text(labels[i], maxLines: 1, style: const TextStyle(fontSize: 9.5, color: BC.muted)),
              ]),
            ),
          ),
      ]),
    );
  }
}
