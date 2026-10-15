import 'package:flutter/material.dart';

import '../screens/bank_inbox/bank_inbox_screen.dart';
import '../services/bank_sync_service.dart';

/// Sino no AppBar com quantas movimentações dos bancos conectados aguardam ser
/// lançadas; abre a caixa de entrada.
///
/// Some enquanto nenhum banco estiver configurado. Sincroniza ao aparecer; a
/// volta ao primeiro plano é tratada no MainScreen, que antes relê o que a
/// sincronização em background gravou.
class BankInboxButton extends StatefulWidget {
  const BankInboxButton({super.key});

  @override
  State<BankInboxButton> createState() => _BankInboxButtonState();
}

class _BankInboxButtonState extends State<BankInboxButton> {
  final _sync = BankSyncService();

  @override
  void initState() {
    super.initState();
    _sync.addListener(_onChanged);
    _sync.sync();
  }

  @override
  void dispose() {
    _sync.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
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
        child: const Icon(Icons.account_balance_outlined),
      ),
    );
  }
}
