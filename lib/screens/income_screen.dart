import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/income_state.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../widgets/income_form.dart';
import '../widgets/logout_action.dart';

class IncomeScreen extends StatelessWidget {
  const IncomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rendimentos'),
        actions: const [LogoutAction()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Novo Rendimento'),
      ),
      body: Consumer<IncomeState>(
        builder: (context, appState, _) {
          final incomes = [...appState.incomes]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (incomes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.incomColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.savings_outlined,
                      size: 32,
                      color: AppTheme.incomColor.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum rendimento',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Registre seu primeiro rendimento',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
            itemCount: incomes.length,
            itemBuilder: (context, index) {
              final income = incomes[index];
              return _IncomeCard(
                title: income.title,
                amount: income.amount,
                onEdit: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => IncomeFormDialog(
                        income: income,
                        onSave: (updated) =>
                            context.read<IncomeState>().updateIncome(updated),
                      ),
                    ),
                  );
                },
                onDelete: () =>
                    _confirmDelete(context, income.id, income.title),
              );
            },
          );
        },
      ),
    );
  }

  void _openForm(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncomeFormDialog(
          onSave: (income) => context.read<IncomeState>().addIncome(income),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id, String title) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.expenseColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: AppTheme.expenseColor,
            size: 24,
          ),
        ),
        title: const Text('Excluir rendimento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tem certeza que deseja excluir este rendimento?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.white38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.expenseColor,
                    minimumSize: const Size(0, 42),
                  ),
                  onPressed: () {
                    context.read<IncomeState>().deleteIncome(id);
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Excluir'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Income Card ──────────────────────────────────────────────────────────────

class _IncomeCard extends StatelessWidget {
  const _IncomeCard({
    required this.title,
    required this.amount,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final double amount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.incomColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: AppTheme.incomColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              CurrencyFormatter.format(amount),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppTheme.incomColor,
                letterSpacing: -0.4,
              ),
            ),
            SizedBox(
              width: 32,
              child: PopupMenuButton(
                padding: EdgeInsets.zero,
                iconSize: 18,
                icon: const Icon(
                  Icons.more_vert,
                  size: 18,
                  color: Color(0xFF4E4E58),
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    onTap: onEdit,
                    child: const Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16),
                        SizedBox(width: 10),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    onTap: onDelete,
                    child: const Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: AppTheme.expenseColor,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Excluir',
                          style: TextStyle(color: AppTheme.expenseColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
