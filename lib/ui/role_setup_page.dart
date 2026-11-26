import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../db.dart';
import '../theme.dart';
import 'common/widgets.dart';

class RoleSetupPage extends StatefulWidget {
  final User user;
  const RoleSetupPage({super.key, required this.user});

  @override
  State<RoleSetupPage> createState() => _RoleSetupPageState();
}

class _RoleSetupPageState extends State<RoleSetupPage> {
  late final TextEditingController _name =
      TextEditingController(text: widget.user.displayName ?? '');
  String? _role; // coach, athlete, gym
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_name.text.trim().isEmpty || _role == null) {
      toast(context, 'Scrivi il nome e scegli il ruolo');
      return;
    }
    setState(() => _busy = true);
    try {
      await Db.createUser(
        uid: widget.user.uid,
        name: _name.text.trim(),
        email: widget.user.email ?? '',
        isCoach: _role == 'coach',
        gym: _role == 'gym',
      );
    } catch (e) {
      if (mounted) toast(context, 'Errore: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _choice(String role, IconData icon, String title, String text) {
    final sel = _role == role;
    return Panel(
      onTap: () => setState(() => _role = role),
      borderColor: sel ? BC.steel : BC.border,
      color: sel ? BC.steelTint : Colors.white,
      child: Row(
        children: [
          Icon(icon, color: sel ? BC.steel : BC.muted, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(text, style: const TextStyle(fontSize: 13, color: BC.muted, height: 1.35)),
              ],
            ),
          ),
          Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off,
              color: sel ? BC.steel : BC.disabled),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: () => Db.signOut(),
            child: const Text('Esci', style: TextStyle(color: BC.muted)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const Text('Benvenuto in BeCoach',
              style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Come userai l\'app? Potrai attivare anche l\'altro ruolo dal profilo.',
              style: TextStyle(color: BC.muted, height: 1.4)),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome e cognome'),
          ),
          const SizedBox(height: 16),
          _choice('coach', Icons.assignment_ind_outlined, 'Sono un coach',
              'Gestisci i clienti, crei le schede e segui gli allenamenti.'),
          const SizedBox(height: 10),
          _choice('athlete', Icons.fitness_center, 'Mi alleno',
              'Segui la scheda del tuo coach e registra i carichi.'),

          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _go,
            child: const Text('Continua'),
          ),
        ],
      ),
    );
  }
}
