import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'db.dart';
import 'models.dart';
import 'theme.dart';
import 'ui/athlete/athlete_shell.dart';
import 'ui/auth_page.dart';
import 'ui/coach/coach_shell.dart';
import 'ui/common/widgets.dart';
import 'ui/role_setup_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const BeCoachApp());
}

class BeCoachApp extends StatelessWidget {
  const BeCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeCoach',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Android 15 disegna l'app sotto i tasti di navigazione: teniamo tutto
      // il contenuto (pagine, fogli, finestre) sopra di loro.
      builder: (context, child) => ColoredBox(
        color: Colors.white,
        child: SafeArea(
          top: false,
          left: false,
          right: false,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Loading());
        }
        final user = snap.data;
        if (user == null) return const AuthPage();
        return _UserGate(key: ValueKey(user.uid), user: user);
      },
    );
  }
}

class _UserGate extends StatefulWidget {
  final User user;
  const _UserGate({super.key, required this.user});

  @override
  State<_UserGate> createState() => _UserGateState();
}

class _UserGateState extends State<_UserGate> {
  late final Stream<AppUser?> _stream = Db.userStream(widget.user.uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return Scaffold(body: ErrorBox(snap.error));
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Loading());
        }
        final me = snap.data;
        if (me == null) return RoleSetupPage(user: widget.user);
        return me.coachMode ? CoachShell(me: me) : AthleteShell(me: me);
      },
    );
  }
}
