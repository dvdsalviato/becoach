import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../db.dart';
import '../theme.dart';
import 'common/widgets.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  String _msg(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email non valida';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email o password errati';
      case 'email-already-in-use':
        return 'Esiste già un account con questa email';
      case 'weak-password':
        return 'Password troppo debole (almeno 6 caratteri)';
      case 'network-request-failed':
        return 'Nessuna connessione';
      case 'operation-not-allowed':
        return 'Questo metodo di accesso non è attivo su Firebase';
      case 'account-exists-with-different-credential':
        return 'Questa email è già registrata con un altro metodo: accedi con email e password';
      default:
        return e.message ?? 'Errore (${e.code})';
    }
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    if (email.isEmpty || pass.isEmpty || (_register && _name.text.trim().isEmpty)) {
      setState(() => _error = 'Compila tutti i campi');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (_register) {
        final cred = await auth.createUserWithEmailAndPassword(email: email, password: pass);
        await cred.user?.updateDisplayName(_name.text.trim());
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: pass);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Db.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } catch (e) {
      if (mounted) setState(() => _error = 'Accesso con Google non riuscito: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Scrivi la tua email per reimpostare la password');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) toast(context, 'Ti abbiamo inviato una mail per reimpostare la password');
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset('assets/logo.png', width: 132, height: 132),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(_register ? 'Crea il tuo account' : 'Accedi',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('Coach e allenati, nella stessa app.',
                      style: TextStyle(color: BC.muted, fontSize: 14)),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _google,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      backgroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.account_circle_outlined, size: 22),
                    label: const Text('Continua con Google'),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: BC.border)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('oppure con email',
                            style: TextStyle(color: BC.muted, fontSize: 13)),
                      ),
                      Expanded(child: Divider(color: BC.border)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_register) ...[
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Nome e cognome'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: BC.danger, fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_register ? 'Crea account' : 'Accedi'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _register = !_register;
                              _error = null;
                            }),
                    child: Text(_register ? 'Ho già un account' : 'Non hai un account? Registrati'),
                  ),
                  if (!_register)
                    TextButton(
                      onPressed: _busy ? null : _reset,
                      child: const Text('Password dimenticata',
                          style: TextStyle(color: BC.muted, fontWeight: FontWeight.w500)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
