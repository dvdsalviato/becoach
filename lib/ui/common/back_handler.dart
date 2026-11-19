import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'widgets.dart';

/// Tasto indietro nelle schermate principali:
/// da una scheda torna alla prima, sulla prima torna in cima,
/// poi serve premere due volte per chiudere l'app.
class ShellBackHandler extends StatefulWidget {
  final int tab;
  final ValueChanged<int> setTab;
  final ScrollController homeScroll;
  final Widget child;
  const ShellBackHandler({
    super.key,
    required this.tab,
    required this.setTab,
    required this.homeScroll,
    required this.child,
  });

  @override
  State<ShellBackHandler> createState() => _ShellBackHandlerState();
}

class _ShellBackHandlerState extends State<ShellBackHandler> {
  DateTime? _lastBack;

  void _onBack() {
    if (widget.tab != 0) {
      widget.setTab(0);
      return;
    }
    final sc = widget.homeScroll;
    if (sc.hasClients && sc.offset > 10) {
      sc.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }
    final now = DateTime.now();
    if (_lastBack != null && now.difference(_lastBack!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    toast(context, 'Premi di nuovo indietro per uscire');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: widget.child,
    );
  }
}
