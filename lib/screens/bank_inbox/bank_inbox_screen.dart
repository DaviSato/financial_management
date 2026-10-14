import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/bank_origin.dart';
import '../../models/bank_transaction.dart';
import '../../models/expense.dart';
import '../../models/income.dart';
import '../../models/recurrence.dart';
import '../../providers/expense_state.dart';
import '../../providers/income_state.dart';
import '../../services/bank_sync_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/expense_form.dart';
import '../../widgets/income_form.dart';
import '../../widgets/swipe_delete_background.dart';
import '../../widgets/swipeable_card_frame.dart';
import '../profile/pluggy_config_screen.dart';
import 'widgets/bank_transaction_card.dart';

/// Caixa de entrada das movimentações dos bancos conectados via Pluggy.
///
/// Cada movimentação vira lançamento só quando o usuário confirma pelo
/// formulário (a categoria continua obrigatória). Deslizar descarta.
class BankInboxScreen extends StatefulWidget {
  const BankInboxScreen({super.key});

  @override
  State<BankInboxScreen> createState() => _BankInboxScreenState();
}

class _BankInboxScreenState extends State<BankInboxScreen> {
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

  Future<void> _openConfig() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PluggyConfigScreen()),
    );
    await _sync.sync();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar tudo?'),
        content: const Text(
          'As movimentações somem da caixa de entrada e não voltam numa '
          'próxima sincronização.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _sync.markHandled(_sync.pending);
  }

  /// Abre o formulário pré-preenchido. Ao salvar, o lançamento entra pelo
  /// caminho normal do provider e a movimentação sai da caixa de entrada.
  void _launch(BankTransaction t) {
    if (t.type == TransactionType.income) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IncomeFormDialog(
            income: Income(
              amount: t.amount,
              title: t.description,
              receiveDate: t.date,
              bankOrigin: _origin(t),
            ),
            isEditing: false,
            onSave: (income) {
              context.read<IncomeState>().addIncome(income);
              _sync.markHandled([t]);
            },
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseFormDialog(
          expense: _expenseDraft(t),
          isEditing: false,
          onSave: (expense) {
            context.read<ExpenseState>().addExpense(expense);
            _sync.markHandled([t]);
          },
        ),
      ),
    );
  }

  /// Na primeira parcela de uma compra parcelada, sugere o parcelamento
  /// inteiro (o app guarda o total e divide por mês). As parcelas seguintes
  /// chegam como movimentações próprias; essas o usuário descarta.
  static Expense _expenseDraft(BankTransaction t) {
    if (t.isInstallment && t.installmentNumber == 1) {
      return Expense(
        amount: t.amount * t.totalInstallments!,
        title: t.description,
        category: '',
        dueDate: t.date,
        paymentMethod: t.paymentMethod,
        recurrenceType: RecurrenceType.installment,
        durationMonths: t.totalInstallments,
        bankOrigin: _origin(t),
      );
    }
    return Expense(
      amount: t.amount,
      title: t.description,
      category: '',
      dueDate: t.date,
      paymentMethod: t.paymentMethod,
      bankOrigin: _origin(t),
    );
  }

  static BankOrigin _origin(BankTransaction t) =>
      BankOrigin(name: t.institution, logoDomain: t.institutionLogo);

  @override
  Widget build(BuildContext context) {
    final pending = _sync.pending;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimentações do banco'),
        actions: [
          IconButton(
            tooltip: 'Bancos conectados',
            onPressed: _openConfig,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: !_sync.isConfigured
          ? _NotConfigured(onConfigure: _openConfig)
          : RefreshIndicator(
              onRefresh: () => _sync.sync(force: true),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  if (_sync.isSyncing) const LinearProgressIndicator(),
                  if (_sync.lastError != null)
                    _ErrorBanner(message: _sync.lastError!),
                  if (pending.isEmpty && !_sync.isSyncing)
                    const _EmptyInbox()
                  else if (pending.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                      child: Row(
                        children: [
                          Text(
                            'PENDENTES · ${pending.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6E6E78),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _clearAll,
                            icon: const Icon(
                              Icons.delete_sweep_outlined,
                              size: 16,
                            ),
                            label: const Text('Descartar tudo'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.expenseColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final t in pending)
                      SwipeableCardFrame(
                        child: Dismissible(
                          key: ValueKey(t.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => _sync.markHandled([t]),
                          background: const SwipeDeleteBackground(),
                          child: BankTransactionCard(
                            transaction: t,
                            onLaunch: () => _launch(t),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 32,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
          const Text(
            'Nada pendente',
            style: TextStyle(fontSize: 13, color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Novas movimentações dos bancos conectados aparecem aqui. O Meu '
            'Pluggy atualiza uma vez por dia.',
            style: TextStyle(fontSize: 12, color: Colors.white38),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.expenseColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppTheme.expenseColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured({required this.onConfigure});
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_outlined,
              size: 40,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum banco conectado',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Conecte seus bancos pelo Meu Pluggy para trazer as '
              'movimentações para cá.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onConfigure,
              child: const Text('Configurar'),
            ),
          ],
        ),
      ),
    );
  }
}
