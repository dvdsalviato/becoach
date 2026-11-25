import 'package:flutter/material.dart';

import '../../db.dart';
import '../../gym/gym_db.dart';
import '../../gym/gym_models.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../updates.dart';
import '../common/adaptive_shell.dart';
import '../common/back_handler.dart';
import '../common/widgets.dart';
import 'cash_page.dart';
import 'checkin_page.dart';
import 'gym_home_page.dart';
import 'gym_more_page.dart';
import 'members_page.dart';

/// Ingresso nel gestionale: crea/collega la palestra, attende l'approvazione o apre il gestionale.
class GymGate extends StatelessWidget {
  final AppUser me;
  const GymGate({super.key, required this.me});

  @override
  Widget build(BuildContext context) {
    final gid = me.gymId;
    if (gid == null) return GymSetupPage(me: me);
    return StreamBuilder<Gym?>(
      stream: GymDb.gymStream(gid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Scaffold(body: Loading());
        }
        final g = snap.data;
        if (snap.hasError || g == null) return _PendingPage(me: me, gymId: gid);
        if (!g.isStaff(me.uid)) return _PendingPage(me: me, gymId: gid);
        return GymShell(key: ValueKey(g.id), me: me, gym: g);
      },
    );
  }
}

class GymShell extends StatefulWidget {
  final AppUser me;
  final Gym gym;
  const GymShell({super.key, required this.me, required this.gym});

  @override
  State<GymShell> createState() => _GymShellState();
}

class _GymShellState extends State<GymShell> {
  int _tab = 0;
  final _homeScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Updates.checkOnStart(context);
    });
  }

  @override
  void dispose() {
    _homeScroll.dispose();
    super.dispose();
  }

  void _setTab(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final me = widget.me, g = widget.gym;
    return GymScope(
      gym: g,
      me: me,
      child: ShellBackHandler(
        tab: _tab,
        setTab: _setTab,
        homeScroll: _homeScroll,
        child: AdaptiveShell(
          tab: _tab,
          onTab: _setTab,
          items: [
            ShellItem(
                icon: Icons.space_dashboard_outlined,
                selectedIcon: Icons.space_dashboard,
                label: 'Home',
                page: GymHomePage(scroll: _homeScroll, openTab: _setTab)),
            const ShellItem(icon: Icons.badge_outlined, label: 'Iscritti', page: MembersPage(), fullWidth: true),
            const ShellItem(icon: Icons.qr_code_scanner, label: 'Ingressi', page: CheckinPage(), fullWidth: true),
            if (g.canSeeCash(me.uid)) const ShellItem(icon: Icons.point_of_sale_outlined, label: 'Cassa', page: CashPage()),
            const ShellItem(icon: Icons.tune, label: 'Altro', page: GymMorePage()),
          ],
        ),
      ),
    );
  }
}

/// Rende disponibili palestra e utente a tutte le pagine del gestionale.
class GymScope extends InheritedWidget {
  final Gym gym;
  final AppUser me;
  const GymScope({super.key, required this.gym, required this.me, required super.child});

  static GymScope of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<GymScope>();
    assert(s != null, 'GymScope mancante');
    return s!;
  }

  @override
  bool updateShouldNotify(GymScope old) => old.gym != gym || old.me != me;
}

/// Le pagine aperte sopra al gestionale perdono il GymScope: lo ripassiamo.
Route<T> gymRoute<T>(BuildContext context, WidgetBuilder builder) {
  final s = GymScope.of(context);
  return pageRoute<T>((c) => GymScope(gym: s.gym, me: s.me, child: Builder(builder: builder)));
}

class _PendingPage extends StatelessWidget {
  final AppUser me;
  final String gymId;
  const _PendingPage({required this.me, required this.gymId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.hourglass_top,
          title: 'In attesa di approvazione',
          text: 'Il titolare della palestra deve approvare il tuo accesso (Altro → Staff). '
              'Appena lo fa, il gestionale si apre da solo.',
          action: Column(
            children: [
              OutlinedButton(
                onPressed: () async {
                  try {
                    await GymDb.rejectStaff(gymId, me.uid);
                  } catch (_) {}
                  await GymDb.leaveGym(me);
                },
                child: const Text('Annulla richiesta'),
              ),
              TextButton(onPressed: () => Db.signOut(), child: const Text('Esci', style: TextStyle(color: BC.muted))),
            ],
          ),
        ),
      ),
    );
  }
}

class GymSetupPage extends StatefulWidget {
  final AppUser me;
  const GymSetupPage({super.key, required this.me});

  @override
  State<GymSetupPage> createState() => _GymSetupPageState();
}

class _GymSetupPageState extends State<GymSetupPage> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await f();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: [
        TextButton(
          onPressed: _busy ? null : () => Db.updateUser(widget.me.uid, {'gymMode': false}),
          child: const Text('Usa come allenato', style: TextStyle(color: BC.muted)),
        ),
      ]),
      body: Readable(
        maxWidth: 560,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            const Text('Gestionale palestra',
                style: TextStyle(fontFamily: BC.display, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
            const SizedBox(height: 6),
            const Text('Iscritti, abbonamenti, certificati medici, ingressi con tessera QR e prima nota.',
                style: TextStyle(color: BC.muted, height: 1.4)),
            const SectionLabel('Sono il titolare'),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nome della palestra'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () {
                            if (_name.text.trim().isEmpty) {
                              setState(() => _error = 'Scrivi il nome della palestra');
                              return;
                            }
                            _run(() => GymDb.createGym(widget.me, _name.text));
                          },
                    child: const Text('Crea la palestra'),
                  ),
                ],
              ),
            ),
            const SectionLabel('Lavoro in una palestra (staff)'),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Chiedi al titolare il codice staff (lo trova in Altro → Staff).',
                      style: TextStyle(fontSize: 13, color: BC.muted)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Codice staff'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              final n = await GymDb.requestJoin(widget.me, _code.text);
                              if (n == null) throw 'Codice non trovato';
                            }),
                    child: const Text('Invia richiesta'),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: BC.danger)),
            ],
          ],
        ),
      ),
    );
  }
}
