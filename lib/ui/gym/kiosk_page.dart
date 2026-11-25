import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../gym/gym_db.dart';
import '../../gym/gym_models.dart';
import '../../theme.dart';
import '../common/widgets.dart';
import 'gym_shell.dart';
import 'gym_widgets.dart';

/// Postazione all'ingresso: PC o tablet collegato al lettore QR del tornello.
/// I lettori USB/seriali "a tastiera" scrivono il codice e premono Invio: qui un campo
/// sempre attivo lo riceve, controlla l'iscritto e mostra VERDE o ROSSO a tutto schermo.
class KioskPage extends StatefulWidget {
  const KioskPage({super.key});

  @override
  State<KioskPage> createState() => _KioskPageState();
}

class _KioskPageState extends State<KioskPage> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  Timer? _reset;
  Timer? _keepFocus;
  MobileScannerController? _cam;
  bool _busy = false;
  Member? _m;
  AccessCheck? _c;
  String? _error;
  Uint8List? _photo;
  String _last = '';
  DateTime _lastAt = DateTime(2000);

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _keepFocus = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && !_focus.hasFocus) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _reset?.cancel();
    _keepFocus?.cancel();
    _cam?.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _handle(String raw) async {
    final code = raw.trim();
    _input.clear();
    _focus.requestFocus();
    if (code.isEmpty || _busy) return;
    final now = DateTime.now();
    if (code == _last && now.difference(_lastAt).inSeconds < 6) return;
    _last = code;
    _lastAt = now;
    final scope = GymScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _m = null;
      _c = null;
      _photo = null;
    });
    try {
      final m = await GymDb.findByCode(scope.gym.id, code);
      if (m == null) {
        setState(() => _error = 'Tessera non riconosciuta');
        HapticFeedback.heavyImpact();
      } else {
        final c = checkAccess(m, scope.gym);
        setState(() {
          _m = m;
          _c = c;
        });
        if (c.ok) {
          await GymDb.checkin(scope.gym.id, m, ok: true, by: 'Postazione ingresso');
        } else {
          SystemSound.play(SystemSoundType.alert);
          HapticFeedback.heavyImpact();
        }
        GymDb.getFile(scope.gym.id, m.id, 'photo').then((p) {
          if (mounted && _m?.id == m.id) setState(() => _photo = p);
        }).catchError((_) {});
      }
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() {
          _m = null;
          _c = null;
          _error = null;
          _photo = null;
        });
      }
    });
  }

  Future<void> _force() async {
    final m = _m, c = _c;
    if (m == null || c == null) return;
    final scope = GymScope.of(context);
    await GymDb.checkin(scope.gym.id, m, ok: false, note: 'Forzato: ${c.problems.join(', ')}', by: scope.me.name);
    if (mounted) {
      setState(() => _c = AccessCheck(true, const [], ['Ingresso forzato dalla reception']));
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gym = GymScope.of(context).gym;
    final m = _m, c = _c;
    Color bg = const Color(0xFF14171C);
    if (_error != null || (c != null && !c.ok)) bg = const Color(0xFF7A1A14);
    if (c != null && c.ok) bg = const Color(0xFF17633A);
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(children: [
          // campo invisibile che riceve il codice dal lettore
          Positioned(
            left: -1000,
            child: SizedBox(
              width: 10,
              child: TextField(
                controller: _input,
                focusNode: _focus,
                autofocus: true,
                showCursor: false,
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.none,
                onSubmitted: _handle,
              ),
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white54),
                tooltip: 'Chiudi postazione',
              ),
              Expanded(
                child: Text(gym.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, letterSpacing: 2, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                onPressed: () => setState(() {
                  if (_cam == null) {
                    _cam = MobileScannerController(formats: const [BarcodeFormat.qrCode], facing: CameraFacing.front);
                  } else {
                    _cam!.dispose();
                    _cam = null;
                  }
                }),
                icon: Icon(_cam == null ? Icons.videocam_outlined : Icons.videocam_off_outlined, color: Colors.white54),
                tooltip: 'Usa la fotocamera del tablet',
              ),
            ]),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _busy
                        ? const CircularProgressIndicator(color: Colors.white)
                        : _content(m, c),
                  ),
                ),
              ),
            ),
            if (_cam != null)
              SizedBox(
                height: 180,
                child: MobileScanner(
                  controller: _cam,
                  onDetect: (cap) {
                    final v = cap.barcodes.isEmpty ? null : cap.barcodes.first.rawValue;
                    if (v != null) _handle(v);
                  },
                ),
              ),
          ]),
        ]),
      ),
    );
  }

  Widget _content(Member? m, AccessCheck? c) {
    const white = TextStyle(color: Colors.white);
    if (_error != null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 96),
        const SizedBox(height: 16),
        Text(_error!, textAlign: TextAlign.center, style: white.copyWith(fontFamily: BC.display, fontSize: 34, fontWeight: FontWeight.w700)),
      ]);
    }
    if (m == null || c == null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.qr_code_2, color: Colors.white70, size: 120),
        const SizedBox(height: 20),
        Text('Apri l\'app BeCoach\ne avvicina il QR al lettore',
            textAlign: TextAlign.center, style: white.copyWith(fontFamily: BC.display, fontSize: 30, fontWeight: FontWeight.w700, height: 1.2)),
      ]);
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(c.ok ? Icons.check_circle : Icons.block, color: Colors.white, size: 88),
      const SizedBox(height: 10),
      Text(c.ok ? 'BENVENUTO' : 'INGRESSO NON CONSENTITO',
          textAlign: TextAlign.center, style: white.copyWith(fontFamily: BC.display, fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: 1)),
      const SizedBox(height: 18),
      Row(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: _photo != null
              ? Image.memory(_photo!, width: 120, height: 120, fit: BoxFit.cover)
              : SizedBox(width: 120, height: 120, child: Center(child: MemberAvatar(m, size: 100))),
        ),
        const SizedBox(width: 18),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.fullName, style: white.copyWith(fontSize: 28, fontWeight: FontWeight.w700)),
            Text(m.cardLabel, style: white.copyWith(color: Colors.white70, fontSize: 16)),
          ]),
        ),
      ]),
      const SizedBox(height: 18),
      for (final p in c.problems) Text(p, textAlign: TextAlign.center, style: white.copyWith(fontSize: 20, fontWeight: FontWeight.w600)),
      for (final w in c.warnings) Text(w, textAlign: TextAlign.center, style: white.copyWith(fontSize: 17, color: const Color(0xFFFFE2A8))),
      if (!c.ok) ...[
        const SizedBox(height: 18),
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
          onPressed: _force,
          child: const Text('Fai entrare comunque (reception)'),
        ),
      ],
    ]);
  }
}
