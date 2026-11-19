import 'package:flutter/material.dart';

import '../../db.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../util.dart';
import '../common/widgets.dart';

/// Anagrafica / anamnesi del cliente.
class ContactForm extends StatefulWidget {
  final String coachId;
  final Contact contact;
  final ValueChanged<Contact>? onSaved;
  final bool showDelete;
  const ContactForm({
    super.key,
    required this.coachId,
    required this.contact,
    this.onSaved,
    this.showDelete = false,
  });

  @override
  State<ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<ContactForm> {
  late final c = widget.contact;
  late final _first = TextEditingController(text: c.firstName);
  late final _last = TextEditingController(text: c.lastName);
  late final _age = TextEditingController(text: c.age?.toString() ?? '');
  late final _phone = TextEditingController(text: c.phone);
  late final _email = TextEditingController(text: c.email);
  late final _goal = TextEditingController(text: c.goal);
  late final _anam = TextEditingController(text: c.anamnesis);
  late final _notes = TextEditingController(text: c.notes);
  late String _type = c.planType;
  bool _busy = false;

  @override
  void dispose() {
    for (final t in [_first, _last, _age, _phone, _email, _goal, _anam, _notes]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_first.text.trim().isEmpty && _last.text.trim().isEmpty) {
      toast(context, 'Scrivi almeno nome o cognome');
      return;
    }
    setState(() => _busy = true);
    c
      ..firstName = _first.text.trim()
      ..lastName = _last.text.trim()
      ..age = parseInt(_age.text)
      ..phone = _phone.text.trim()
      ..email = _email.text.trim()
      ..planType = _type
      ..goal = _goal.text.trim()
      ..anamnesis = _anam.text.trim()
      ..notes = _notes.text.trim();
    try {
      await Db.saveContact(widget.coachId, c);
      if (!mounted) return;
      toast(context, 'Anagrafica salvata');
      widget.onSaved?.call(c);
    } catch (e) {
      if (mounted) toast(context, 'Errore: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _f(TextEditingController t, String label,
          {TextInputType? kb, int lines = 1, String? hint, TextCapitalization cap = TextCapitalization.sentences}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: t,
          keyboardType: kb,
          maxLines: lines,
          minLines: 1,
          textCapitalization: cap,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.linked)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: const [
                Icon(Icons.phone_iphone, size: 16, color: BC.steel),
                SizedBox(width: 6),
                Text('Usa l\'app BeCoach', style: TextStyle(fontSize: 13, color: BC.steel, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        const SectionLabel('Dati'),
        Row(
          children: [
            Expanded(child: _f(_first, 'Nome', cap: TextCapitalization.words)),
            const SizedBox(width: 10),
            Expanded(child: _f(_last, 'Cognome', cap: TextCapitalization.words)),
          ],
        ),
        Row(
          children: [
            SizedBox(width: 100, child: _f(_age, 'Età', kb: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: _f(_phone, 'Telefono', kb: TextInputType.phone)),
          ],
        ),
        _f(_email, 'Email', kb: TextInputType.emailAddress, cap: TextCapitalization.none),
        const SectionLabel('Percorso'),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            value: planTypes.contains(_type) ? _type : '',
            decoration: const InputDecoration(labelText: 'Tipologia scheda'),
            items: [
              const DropdownMenuItem(value: '', child: Text('Da definire')),
              for (final t in planTypes) DropdownMenuItem(value: t, child: Text(t)),
            ],
            onChanged: (v) => setState(() => _type = v ?? ''),
          ),
        ),
        _f(_goal, 'Obiettivo', hint: 'Es. -5 kg entro giugno, prima gara di powerlifting'),
        const SectionLabel('Anamnesi'),
        _f(_anam, 'Infortuni, patologie, limitazioni', lines: 4,
            hint: 'Es. ernia L5-S1, spalla dx sensibile sopra i 90°'),
        _f(_notes, 'Note', lines: 4, hint: 'Disponibilità, preferenze, motivazione…'),
        const SizedBox(height: 4),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Salva anagrafica')),
        if (widget.showDelete && c.id.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              if (await confirm(context, 'Elimina cliente',
                  'Eliminare ${c.fullName} dalla rubrica?${c.linked ? ' L\'account nell\'app resta collegato a te.' : ''}',
                  ok: 'Elimina', danger: true)) {
                await Db.deleteContact(widget.coachId, c.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Elimina dalla rubrica', style: TextStyle(color: BC.danger)),
          ),
        ],
      ],
    );
  }
}

/// Pagina "Nuovo cliente" / anagrafica di un cliente in rubrica. Restituisce il contatto salvato.
class ContactFormPage extends StatelessWidget {
  final String coachId;
  final Contact contact;
  const ContactFormPage({super.key, required this.coachId, required this.contact});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(contact.id.isEmpty ? 'Nuovo cliente' : contact.fullName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          ContactForm(
            coachId: coachId,
            contact: contact,
            showDelete: true,
            onSaved: (c) => Navigator.pop(context, c),
          ),
        ],
      ),
    );
  }
}
