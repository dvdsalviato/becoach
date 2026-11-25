import 'package:flutter/material.dart';

import '../../gym/gym_db.dart';
import '../../gym/gym_models.dart';
import '../../theme.dart';
import '../common/widgets.dart';
import 'gym_shell.dart';
import 'gym_widgets.dart';

/// Nuovo iscritto o modifica dell'anagrafica.
class MemberFormPage extends StatefulWidget {
  final Member? member;
  const MemberFormPage({super.key, this.member});

  @override
  State<MemberFormPage> createState() => _MemberFormPageState();
}

class _MemberFormPageState extends State<MemberFormPage> {
  late final Member m = widget.member ?? Member(consentAt: DateTime.now());
  late final _first = TextEditingController(text: m.firstName);
  late final _last = TextEditingController(text: m.lastName);
  late final _cf = TextEditingController(text: m.taxCode);
  late final _place = TextEditingController(text: m.birthPlace);
  late final _phone = TextEditingController(text: m.phone);
  late final _email = TextEditingController(text: m.email);
  late final _addr = TextEditingController(text: m.address);
  late final _zip = TextEditingController(text: m.zip);
  late final _city = TextEditingController(text: m.city);
  late final _notes = TextEditingController(text: m.notes);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_first, _last, _cf, _place, _phone, _email, _addr, _zip, _city, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) {
      setState(() => _error = 'Nome e cognome sono obbligatori');
      return;
    }
    final cf = _cf.text.trim().toUpperCase();
    if (cf.isNotEmpty && !RegExp(r'^[A-Z0-9]{16}$').hasMatch(cf)) {
      setState(() => _error = 'Il codice fiscale deve avere 16 caratteri');
      return;
    }
    if (!m.privacy) {
      setState(() => _error = 'Serve il consenso al trattamento dei dati (privacy)');
      return;
    }
    m
      ..firstName = _first.text
      ..lastName = _last.text
      ..taxCode = cf
      ..birthPlace = _place.text
      ..phone = _phone.text
      ..email = _email.text
      ..address = _addr.text
      ..zip = _zip.text
      ..city = _city.text
      ..notes = _notes.text;
    setState(() {
      _busy = true;
      _error = null;
    });
    final g = GymScope.of(context).gym.id;
    try {
      if (m.id.isEmpty) {
        final id = await GymDb.createMember(g, m);
        if (mounted) Navigator.pop(context, id);
      } else {
        await GymDb.updateMember(g, m);
        if (mounted) Navigator.pop(context, m.id);
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: children[i]),
            ],
          ],
        ),
      );

  Widget _field(TextEditingController c, String label,
          {TextInputType? kb, TextCapitalization cap = TextCapitalization.none, int lines = 1}) =>
      TextField(
        controller: c,
        keyboardType: kb,
        textCapitalization: cap,
        maxLines: lines,
        decoration: InputDecoration(labelText: label),
      );

  Widget _consent(String title, String text, bool value, ValueChanged<bool> onChanged, {bool required = false}) {
    return CheckboxListTile(
      value: value,
      onChanged: (v) => setState(() {
        onChanged(v == true);
        m.consentAt = DateTime.now();
      }),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text('$title${required ? ' *' : ''}', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
      subtitle: Text(text, style: const TextStyle(fontSize: 12.5, color: BC.muted, height: 1.3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const words = TextCapitalization.words;
    return Scaffold(
      appBar: AppBar(title: Text(m.id.isEmpty ? 'Nuovo iscritto' : 'Modifica iscritto')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SectionLabel('Dati anagrafici'),
          _row([_field(_first, 'Nome *', cap: words), _field(_last, 'Cognome *', cap: words)]),
          _row([
            DropdownButtonFormField<String>(
              value: m.gender.isEmpty ? null : m.gender,
              decoration: const InputDecoration(labelText: 'Sesso'),
              items: const [
                DropdownMenuItem(value: 'M', child: Text('M')),
                DropdownMenuItem(value: 'F', child: Text('F')),
                DropdownMenuItem(value: 'X', child: Text('Altro')),
              ],
              onChanged: (v) => setState(() => m.gender = v ?? ''),
            ),
            DateField(
              label: 'Data di nascita',
              value: m.birthDate,
              onChanged: (d) => setState(() => m.birthDate = d),
            ),
          ]),
          _row([_field(_place, 'Luogo di nascita', cap: words), _field(_cf, 'Codice fiscale', cap: TextCapitalization.characters)]),
          const SectionLabel('Contatti'),
          _row([_field(_phone, 'Telefono', kb: TextInputType.phone), _field(_email, 'Email', kb: TextInputType.emailAddress)]),
          _row([_field(_addr, 'Indirizzo', cap: TextCapitalization.sentences)]),
          _row([_field(_zip, 'CAP', kb: TextInputType.number), _field(_city, 'Città', cap: words)]),
          const SectionLabel('Consensi'),
          _consent('Privacy', 'Informativa letta e consenso al trattamento dei dati personali per la gestione dell\'iscrizione.',
              m.privacy, (v) => m.privacy = v, required: true),
          _consent('Dati sanitari', 'Consenso al trattamento del certificato medico e di eventuali dati sulla salute.',
              m.healthData, (v) => m.healthData = v),
          _consent('Foto', 'Consenso all\'uso della foto per il riconoscimento all\'ingresso.', m.photoConsent,
              (v) => m.photoConsent = v),
          _consent('Comunicazioni', 'Consenso a ricevere comunicazioni promozionali.', m.marketing, (v) => m.marketing = v),
          const SectionLabel('Note'),
          _field(_notes, 'Note interne', lines: 3, cap: TextCapitalization.sentences),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: BC.danger)),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(m.id.isEmpty ? 'Crea iscritto e tessera' : 'Salva'),
          ),
        ],
      ),
    );
  }
}
