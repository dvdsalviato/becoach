import 'package:flutter/material.dart';

import '../../db.dart';
import '../../models.dart';
import '../../theme.dart';
import '../common/widgets.dart';
import 'plan_editor_page.dart';

/// Area riservata del coach: modelli di schede riutilizzabili.
class TemplatesPage extends StatefulWidget {
  final AppUser me;
  const TemplatesPage({super.key, required this.me});

  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  late final Stream<List<Plan>> _stream = Db.templatesStream(widget.me.uid);

  void _open(Plan t) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => PlanEditorPage(me: widget.me, plan: t, isTemplate: true)),
    );
  }

  void _new() {
    _open(Plan(
      coachId: widget.me.uid,
      name: 'Nuovo modello',
      active: false,
      days: [PlanDay(name: 'Giorno A')],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<Plan>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return ErrorBox(snap.error);
          if (!snap.hasData) return const Loading();
          final list = snap.data!;
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  const PageHeader(overline: 'Area riservata', title: 'Modelli'),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, size: 14, color: BC.muted),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text('Visibili solo a te. Usali come base per le schede dei clienti.',
                              style: TextStyle(fontSize: 13, color: BC.muted)),
                        ),
                      ],
                    ),
                  ),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: EmptyState(
                        icon: Icons.description_outlined,
                        title: 'Nessun modello',
                        text:
                            'Crea le tue schede tipo (forza, ipertrofia, principianti…) e assegnale ai clienti in un attimo.',
                        action: FilledButton(onPressed: _new, child: const Text('Crea modello')),
                      ),
                    ),
                  for (final t in list) _tile(t),
                ],
              ),
              if (list.isNotEmpty)
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: FloatingActionButton.extended(
                    heroTag: 'newTemplate',
                    onPressed: _new,
                    icon: const Icon(Icons.add),
                    label: const Text('Nuovo modello'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(Plan t) {
    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Panel(
                        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                        onTap: () => _open(t.copy()),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.name,
                                      style: const TextStyle(
                                          fontSize: 15, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 3),
                                  Text(
                                      '${t.days.length} giorni · ${t.exerciseCount} esercizi · ${t.weeks} settimane',
                                      style: const TextStyle(fontSize: 13, color: BC.muted)),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'dup') {
                                  final c = t.copy()
                                    ..id = ''
                                    ..name = '${t.name} (copia)';
                                  await Db.saveTemplate(c);
                                } else if (v == 'delete') {
                                  if (await confirm(context, 'Elimina modello',
                                      'Eliminare "${t.name}"? Le schede già assegnate non cambiano.',
                                      ok: 'Elimina', danger: true)) {
                                    await Db.deleteTemplate(widget.me.uid, t.id);
                                  }
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'dup', child: Text('Duplica')),
                                PopupMenuItem(value: 'delete', child: Text('Elimina')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
  }
}
