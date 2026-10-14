import 'package:flutter/material.dart';

import '../screens/bank_inbox/bank_inbox_screen.dart';
import '../services/bank_sync_service.dart';

/// Sino no AppBar com quantas movimentações dos bancos conectados aguardam ser
/// lançadas; abre a caixa de entrada.
///
/// Some enquanto nenhum banco estiver configurado. Sincroniza ao aparecer e ao
/// voltar ao primeiro plano — o [BankSyncService] limita a frequência real.
class BankInboxButton extends StatefulWidget {
  const BankInboxButton({super.key});

  @override
  State<BankInboxButton> createState() => _BankInboxButtonState();
}

class _BankInboxButtonState extends State<BankInboxButton>
    with WidgetsBindingObserver {
  final _sync = BankSyncService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync.addListener(_onChanged);
    _sync.sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sync.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync.sync();
  }

  @override
  Widget build(BuildContext context) {
    if (!_sync.isConfigured) return const SizedBox.shrink();

    final count = _sync.pending.length;
    return IconButton(
      tooltip: 'Movimentações do banco',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BankInboxScreen()),
      ),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: Icon(
          count > 0
              ? Icons.notifications_active_outlined
              : Icons.notifications_none_rounded,
        ),
      ),
    );
  }
}
