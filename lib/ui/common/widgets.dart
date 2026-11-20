import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme.dart';

/// Da questa larghezza in su l'app usa il layout desktop (menu laterale, pannelli affiancati).
const wideBreakpoint = 900.0;

bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= wideBreakpoint;

/// Su schermi larghi tiene il contenuto centrato e a una larghezza leggibile.
class Readable extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const Readable({super.key, required this.child, this.maxWidth = 860});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );
  }
}

/// Pagina aperta sopra le altre: su schermi larghi resta centrata, sul telefono a tutto schermo.
class PageFrame extends StatelessWidget {
  final Widget child;
  const PageFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!isWide(context)) return child;
    return ColoredBox(
      color: const Color(0xFFE9ECEF),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Material(elevation: 2, child: child),
        ),
      ),
    );
  }
}

Route<T> pageRoute<T>(WidgetBuilder builder) =>
    MaterialPageRoute<T>(builder: (context) => PageFrame(child: builder(context)));

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(4);
    return Material(
      color: color ?? Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor ?? BC.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
                color: BC.muted,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final String initials;
  final double size;
  const Avatar(this.initials, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: BC.avatar, shape: BoxShape.circle),
      child: Text(
        initials,
        style: TextStyle(
          color: BC.steel,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

class Tag extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;
  const Tag(this.text, {super.key, this.fg = BC.muted, this.bg = const Color(0xFFEEF0F2)});

  const Tag.warn(this.text, {super.key})
      : fg = BC.warnFg,
        bg = BC.warnBg;

  const Tag.steel(this.text, {super.key})
      : fg = BC.steelDark,
        bg = BC.steelTint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class LiveTag extends StatelessWidget {
  final String text;
  const LiveTag({super.key, this.text = 'Live'});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: Color(0xFF6E93B8), shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BC.steel)),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: BC.steelLight),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: BC.muted, height: 1.4)),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  final String overline;
  final String title;
  final Widget? trailing;
  const PageHeader({super.key, required this.overline, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(overline.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                        color: BC.muted)),
                const SizedBox(height: 4),
                Text(title,
                    style: const TextStyle(
                        fontFamily: BC.display,
                        fontSize: 34,
                        height: 1.0,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.0)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
}

class ErrorBox extends StatelessWidget {
  final Object? error;
  const ErrorBox(this.error, {super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Errore: $error',
              textAlign: TextAlign.center, style: const TextStyle(color: BC.danger)),
        ),
      );
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), dismissDirection: DismissDirection.horizontal));
}

Future<void> openUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) {
    toast(context, 'Link non valido');
    return;
  }
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) toast(context, 'Impossibile aprire il link');
}

Future<bool> confirm(BuildContext context, String title, String text,
    {String ok = 'Conferma', bool danger = false}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text(title, style: const TextStyle(fontFamily: 'Space Grotesk', fontSize: 18, fontWeight: FontWeight.w700)),
      content: Text(text, style: const TextStyle(color: BC.body, height: 1.4)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annulla', style: TextStyle(color: BC.muted))),
        TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(ok, style: TextStyle(color: danger ? BC.danger : BC.steel))),
      ],
    ),
  );
  return res == true;
}

Future<String?> askText(BuildContext context,
    {required String title,
    String initial = '',
    String hint = '',
    int maxLines = 1,
    TextInputType? keyboard}) async {
  final ctrl = TextEditingController(text: initial);
  final res = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text(title, style: const TextStyle(fontFamily: 'Space Grotesk', fontSize: 18, fontWeight: FontWeight.w700)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Annulla', style: TextStyle(color: BC.muted))),
        TextButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Salva')),
      ],
    ),
  );
  return res;
}


/// Messaggio comprensibile per gli errori più comuni di Firebase.
String friendlyError(Object e) {
  final t = e.toString();
  if (t.contains('permission-denied') || t.contains('PERMISSION_DENIED')) {
    return 'Permesso negato da Firebase: le regole di sicurezza non sono aggiornate. '
        'Il coach deve incollare le regole nuove in Firestore → Regole.';
  }
  if (t.contains('unavailable') || t.contains('network')) {
    return 'Nessuna connessione con il server. Controlla internet e riprova.';
  }
  return 'Errore: $t';
}
