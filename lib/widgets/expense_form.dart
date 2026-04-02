import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../models/payment_method.dart';
import '../models/recurrence.dart';
import '../providers/app_state.dart';
import '../utils/brazilian_currency_input_formatter.dart';
import '../utils/currency_formatter.dart';
import 'category_form_dialog.dart';

class ExpenseFormDialog extends StatefulWidget {
  final Expense? expense;
  final Function(Expense) onSave;

  const ExpenseFormDialog({super.key, this.expense, required this.onSave});

  @override
  State<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<ExpenseFormDialog> {
  late TextEditingController _amountController;
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late TextEditingController _durationController;
  late DateTime _selectedDate;
  String? _selectedCategory;
  late RecurrenceType _recurrenceType;
  late int _durationMonths;
  PaymentMethod? _paymentMethod;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _amountController = TextEditingController(
      text: e != null ? CurrencyFormatter.format(e.amount) : '',
    );
    _titleController = TextEditingController(text: e?.title ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    _durationController = TextEditingController(
      text: e?.durationMonths?.toString() ?? '1',
    );
    _selectedDate = e?.dueDate ?? DateTime.now();
    _selectedCategory = e?.category;
    _recurrenceType = e?.recurrenceType ?? RecurrenceType.once;
    _durationMonths = e?.durationMonths ?? 1;
    _paymentMethod = e?.paymentMethod;
    _selectedDate = e?.dueDate ?? DateTime.now();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedCategory == null) {
      final categories = context.read<AppState>().categories;
      if (categories.isNotEmpty) _selectedCategory = categories.first.name;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _saveExpense() {
    if (_titleController.text.isEmpty) {
      _showError('Informe um título');
      return;
    }
    if (_amountController.text.isEmpty) {
      _showError('Informe um valor');
      return;
    }
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      _showError('Selecione uma categoria');
      return;
    }
    final amount = CurrencyFormatter.parse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showError('Informe um valor válido');
      return;
    }
    if (_recurrenceType == RecurrenceType.period && _durationMonths <= 0) {
      _showError('Defina a duração em meses');
      return;
    }

    widget.onSave(
      Expense(
        id: widget.expense?.id,
        amount: amount,
        title: _titleController.text,
        category: _selectedCategory!,
        dueDate: _selectedDate,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        recurrenceType: _recurrenceType,
        durationMonths: _recurrenceType == RecurrenceType.period
            ? _durationMonths
            : null,
        paymentMethod: _paymentMethod,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.expense != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar Gasto' : 'Novo Gasto'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          if (_selectedCategory == null && appState.categories.isNotEmpty) {
            _selectedCategory = appState.categories.first.name;
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Informações básicas ──────────────────────
                  _SectionLabel('Informações'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Título',
                      hintText: 'Ex: Supermercado, Aluguel, Gasolina',
                      prefixIcon: Icon(Icons.title_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [BrazilianCurrencyInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Valor',
                      hintText: 'R\$ 0,00',
                      prefixIcon: Icon(Icons.attach_money_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedCategory),
                    initialValue:
                        appState.categories.any(
                          (c) => c.name == _selectedCategory,
                        )
                        ? _selectedCategory
                        : null,
                    items: appState.categories.map((category) {
                      return DropdownMenuItem(
                        value: category.name,
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: category.color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(category.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null)
                        setState(() => _selectedCategory = value);
                    },
                    decoration: InputDecoration(
                      labelText: 'Categoria',
                      prefixIcon: const Icon(Icons.label_outlined),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'Nova categoria',
                        onPressed: () async {
                          final created = await CategoryFormDialog.show(
                            context,
                          );
                          if (created != null) {
                            setState(() => _selectedCategory = created.name);
                          }
                        },
                      ),
                    ),
                  ),

                  // ── Pagamento ────────────────────────────────
                  const SizedBox(height: 24),
                  _SectionLabel('Pagamento'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PaymentMethod?>(
                    key: ValueKey(_paymentMethod),
                    initialValue: _paymentMethod,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Não informado'),
                      ),
                      ...PaymentMethod.values.map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Row(
                            children: [
                              Text(m.icon),
                              const SizedBox(width: 8),
                              Text(m.label),
                            ],
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _paymentMethod = value),
                    decoration: const InputDecoration(
                      labelText: 'Método de Pagamento',
                      prefixIcon: Icon(Icons.payment_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onTap: _selectDate,
                    canRequestFocus: false,
                    showCursor: false,
                    controller: TextEditingController(
                      text:
                          '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Data de vencimento',
                      prefixIcon: Icon(Icons.date_range_outlined),
                    ),
                  ),

                  // ── Recorrência ──────────────────────────────
                  const SizedBox(height: 24),
                  _SectionLabel('Recorrência'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<RecurrenceType>(
                    initialValue: _recurrenceType,
                    onChanged: (value) => setState(
                      () => _recurrenceType = value ?? RecurrenceType.once,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: RecurrenceType.once,
                        child: Text('Gasto Único'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceType.monthly,
                        child: Text('Mensal (Recorrente)'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceType.period,
                        child: Text('Por Período'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Gasto',
                      prefixIcon: Icon(Icons.repeat_outlined),
                    ),
                  ),
                  if (_recurrenceType == RecurrenceType.period) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState(
                        () => _durationMonths = int.tryParse(value) ?? 1,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Duração (meses)',
                        hintText: 'Ex: 6',
                        prefixIcon: Icon(Icons.hourglass_bottom_outlined),
                      ),
                    ),
                  ],

                  // ── Observações ──────────────────────────────
                  const SizedBox(height: 24),
                  _SectionLabel('Observações'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Adicione observações...',
                    ),
                  ),

                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _saveExpense,
                          child: Text(isEdit ? 'Salvar' : 'Adicionar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF6E6E78),
        letterSpacing: 0.8,
      ),
    );
  }
}
