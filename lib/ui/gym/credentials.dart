import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../gym/gym_db.dart';
import '../../gym/gym_models.dart';
import '../../theme.dart';
import '../common/widgets.dart';
import 'gym_shell.dart';
import 'gym_widgets.dart';

const androidLink = 'https://github.com/dvdsalviato/becoach/releases/latest/download/BeCoach.apk';
const webLink = 'https://dvdsalviato.github.io/becoach/';

String tempPassword() {
  const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
  final r = Random.secure();
  final p = List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  return '${p.substring(0, 4)}-${p.substring(4)}';
}

String welcomeText(Gym g, Member m, String email, String? password) => [
      'Ciao ${m.firstName.trim()}, benvenuto in ${g.name}!',
      '',
      'Scarica l\'app BeCoach:',
      '• Android: $androidLink',
      '• iPhone e computer: $webLink',
      '',
      'Accedi con',
      'Email: $email',
      if (password != null) 'Password: $password',
      '',
      if (password != null) 'Al primo accesso puoi cambiarla da Profilo → Cambia password.',
      'All\'ingresso apri l\'app e avvicina il QR al lettore.',
    ].join('\n');

Future<void> sendByEmail(BuildContext context, String to, String subject, String body) async {
  final uri = Uri.parse('mailto:${Uri.encodeComponent(to)}?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
  if (!await launchUrl(uri) && context.mounted) toast(context, 'Nessuna app email trovata: usa "Copia testo"');
}

Future<void> sendByWhatsApp(BuildContext context, String phone, String body) async {
  var p = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (p.startsWith('+')) p = p.substring(1);
  if (p.startsWith('00')) p = p.substring(2);
  if (p.length == 10 && p.startsWith('3')) p = '39$p';
  final uri = Uri.parse('https://wa.me/$p?text=${Uri.encodeComponent(body)}');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Riquadro nella scheda iscritto: credenziali per l'app.
class AppAccessPanel extends StatelessWidget {
  final Member m;
  const AppAccessPanel({super.key, required this.m});

  @override
  Widget build(BuildContext context) {
    final scope = GymScope.of(context);
    if (m.linkedUid.isEmpty) {
      return Panel(
        onTap: () => showSheet(context, (c) => GymScope(gym: scope.gym, me: scope.me, child: _CreateAccountSheet(m: m))),
        child: const Row(children: [
          Icon(Icons.key_outlined, color: BC.steel),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Crea le credenziali per l\'app', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('Email e password temporanea, con il link per scaricare l\'app', style: TextStyle(fontSize: 13, color: BC.muted)),
            ]),
          ),
          Icon(Icons.chevron_right, color: BC.disabled),
        ]),
      );
    }
    final email = m.accountEmail.isNotEmpty ? m.accountEmail : m.email;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.verified_user_outlined, color: okFg),
          const SizedBox(width: 10),
          Expanded(child: Text('App collegata${email.isEmpty ? '' : ' · $email'}', style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (email.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                  if (context.mounted) toast(context, 'Email per reimpostare la password inviata a $email');
                } catch (e) {
                  if (context.mounted) toast(context, friendlyError(e));
                }
              },
              icon: const Icon(Icons.lock_reset, size: 18),
              label: const Text('Password dimenticata'),
            ),
          if (email.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => sendByEmail(context, email, 'La tua app ${scope.gym.name}', welcomeText(scope.gym, m, email, null)),
              icon: const Icon(Icons.mail_outline, size: 18),
              label: const Text('Rimanda link app'),
            ),
        ]),
      ]),
    );
  }
}

class _CreateAccountSheet extends StatefulWidget {
  final Member m;
  const _CreateAccountSheet({required this.m});

  @override
  State<_CreateAccountSheet> createState() => _CreateAccountSheetState();
}

class _CreateAccountSheetState extends State<_CreateAccountSheet> {
  late final _email = TextEditingController(text: widget.m.email);
  late final _pass = TextEditingController(text: tempPassword());
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final email = _email.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Email non valida');
      return;
    }
    if (_pass.text.length < 6) {
      setState(() => _error = 'La password deve avere almeno 6 caratteri');
      return;
    }
    final g = GymScope.of(context).gym;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await GymDb.createAccount(g.id, g.name, widget.m, email, _pass.text);
      if (widget.m.email.isEmpty) {
        widget.m.email = email;
        await GymDb.updateMember(g.id, widget.m);
      }
      setState(() => _done = true);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = GymScope.of(context).gym;
    final text = welcomeText(g, widget.m, _email.text.trim(), _pass.text);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(_done ? 'Account creato' : 'Credenziali per l\'app',
            style: const TextStyle(fontFamily: BC.display, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (!_done) ...[
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email dell\'iscritto'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            decoration: InputDecoration(
              labelText: 'Password temporanea',
              suffixIcon: IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() => _pass.text = tempPassword())),
            ),
          ),
          const SizedBox(height: 6),
          const Text('Ogni iscritto ha una password diversa: potrà cambiarla dall\'app.',
              style: TextStyle(fontSize: 12.5, color: BC.muted)),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: BC.danger)),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _create, child: const Text('Crea account')),
        ] else ...[
          const Text('Manda ora le credenziali all\'iscritto:', style: TextStyle(color: BC.body)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: BC.subtle, borderRadius: BorderRadius.circular(4), border: Border.all(color: BC.border)),
            child: SelectableText(text, style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => sendByEmail(context, _email.text.trim(), 'Benvenuto in ${g.name}: la tua app', text),
            icon: const Icon(Icons.mail_outline, size: 18),
            label: const Text('Invia per email'),
          ),
          const SizedBox(height: 8),
          if (widget.m.phone.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => sendByWhatsApp(context, widget.m.phone, text),
              icon: const Icon(Icons.chat_outlined, size: 18),
              label: const Text('Invia su WhatsApp'),
            ),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              toast(context, 'Testo copiato');
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copia testo'),
          ),
        ],
      ],
    );
  }
}
