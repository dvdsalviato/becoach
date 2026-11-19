import 'package:flutter/material.dart';

import '../../db.dart';
import '../../models.dart';
import '../../theme.dart';
import '../common/widgets.dart';

/// Collegamento al coach: controlla il codice, poi chiede nome, cognome, telefono
/// ed email (obbligatori), che il coach ritrova nella sua rubrica.
Future<bool> joinCoachFlow(BuildContext context, AppUser me, String code) async {
  String coachId, coachName;
  try {
    (coachId, coachName) = await Db.checkInvite(me, code);
  } catch (e) {
    if (context.mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
    return false;
  }
  if (!context.mounted) return false;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    builder: (_) => _JoinSheet(me: me, code: code, coachId: coachId, coachName: coachName),
  );
  return ok == true;
}

class _JoinSheet extends StatefulWidget {
  final AppUser me;
  final String code;
  final String coachId;
  final String coachName;
  const _JoinSheet({required this.me, required this.code, required this.coachId, required this.coachName});

  @override
  State<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends State<_JoinSheet> {
  late final List<String> _parts = widget.me.name.trim().split(RegExp(r'\s+'));
  late final _first = TextEditingController(
      text: widget.me.firstName.isNotEmpty ? widget.me.firstName : (_parts.isEmpty ? '' : _parts.first));
  late final _last = TextEditingController(
      text: widget.me.lastName.isNotEmpty
          ? widget.me.lastName
          : (_parts.length > 1 ? _parts.sublist(1).join(' ') : ''));
  late final _phone = TextEditingController(text: widget.me.phone);
  late final _email = TextEditingController(text: widget.me.email);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_first, _last, _phone, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _confirm() async {
    final first = _first.text.trim(), last = _last.text.trim();
    final phone = _phone.text.trim(), email = _email.text.trim();
    if (first.isEmpty || last.isEmpty || phone.isEmpty || email.isEmpty) {
      setState(() => _error = 'Compila tutti i campi');
      return;
    }
    if (phone.replaceAll(RegExp(r'[^0-9]'), '').length < 6) {
      setState(() => _error = 'Numero di telefono non valido');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Email non valida');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Db.joinCoach(widget.me,
          code: widget.code,
          coachId: widget.coachId,
          coachName: widget.coachName,
          firstName: first,
          lastName: last,
          phone: phone,
          email: email);
      if (!mounted) return;
      Navigator.pop(context, true);
      toast(context, 'Collegato a ${widget.coachName}');
    } catch (e) {
      if (mounted) setState(() => _error = 'Errore: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Coach: ${widget.coachName}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Per completare il collegamento servono i tuoi dati: li vedrà solo il tuo coach.',
                style: TextStyle(color: BC.muted, fontSize: 13, height: 1.35)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _first,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nome *'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _last,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Cognome *'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefono *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email *'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: BC.danger, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _confirm, child: const Text('Conferma e collegati')),
          ],
        ),
      ),
    );
  }
}
