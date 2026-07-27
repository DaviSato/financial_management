import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../models/payment_method.dart';
import '../models/recurrence.dart';
import '../providers/category_state.dart';
import '../theme/app_theme.dart';
import '../utils/brazilian_currency_input_formatter.dart';
import '../utils/currency_formatter.dart';
import 'category_form_dialog.dart';
import 'logo_picker_field.dart';

const _monthNames = [
  'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
  'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
];

class ExpenseFormDialog extends StatefulWidget {
  final Expense? expense;
  final Function(Expense) onSave;

  /// Sobrepõe a detecção de edição. Um rascunho vindo da captura de
  /// notificações é pré-preenchido (via [expense]), mas é um lançamento novo —
  /// então o cabeçalho deve dizer "Novo Gasto", não "Editar".
  final bool? isEditing;

  /// Mês a que o "marcar como pago" se refere. Um gasto recorrente é pago mês a
  /// mês (ver [Expense.paidByMonth]), e a edição recebe o gasto *original* — a
  /// data de vencimento dele não diz qual mês o usuário está olhando. Quem abre
  /// o formulário a partir de uma lista mensal passa o mês selecionado; quando
  /// nulo, cai no mês do próprio vencimento.
  final DateTime? referenceMonth;

  const ExpenseFormDialog({
    super.key,
    this.expense,
    required this.onSave,
    this.isEditing,
    this.referenceMonth,
  });

  @override
  State<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<ExpenseFormDialog> {
  late TextEditingController _amountController;
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late TextEditingController _durationController;
  late DateTime _selectedDate;
  late int _selectedDay;
  String? _selectedCategory;
  late RecurrenceType _recurrenceType;
  late int _durationMonths;
  PaymentMethod? _paymentMethod;
  late bool _notifyOnDue;
  late bool _isPaid;
  String? _logoDomain;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _logoDomain = e?.logoDomain;
    _amountController = TextEditingController(
      text: e != null ? CurrencyFormatter.format(e.amount) : '',
    );
    _titleController = TextEditingController(text: e?.title ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    _durationController = TextEditingController(
      text: e?.durationMonths?.toString() ?? '1',
    );
    _selectedDate = e?.dueDate ?? DateTime.now();
    _selectedDay = e?.dueDate.day ?? DateTime.now().day;
    _selectedCategory = e?.category;
    _recurrenceType = e?.recurrenceType ?? RecurrenceType.once;
    _durationMonths = e?.durationMonths ?? 1;
    _paymentMethod = e?.paymentMethod;
    _notifyOnDue = e?.notifyOnDue ?? false;
    _isPaid = e?.isPaidForMonth(widget.referenceMonth ?? _selectedDate) ?? false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedCategory == null) {
      final categories = context.read<CategoryState>().categories;
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

  void _onAmountChanged(String _) {
    if (_recurrenceType == RecurrenceType.installment) setState(() {});
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _showDayPicker() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DayPickerSheet(selectedDay: _selectedDay),
    );
    if (picked != null) setState(() => _selectedDay = picked);
  }

  /// Mês a que a marcação de pago se aplica: o mês que a tela estava exibindo
  /// ou, na falta dele (gasto novo), o mês do vencimento sendo salvo.
  DateTime get _paidMonth => widget.referenceMonth ?? _selectedDate;

  /// Só faz sentido falar em "qual mês" quando o gasto se repete — num gasto
  /// único a chave é sempre `'once'`.
  bool get _isRecurring => _recurrenceType != RecurrenceType.once;

  String _paidSubtitle() {
    final paidDate = widget.expense?.paidDateForMonth(_paidMonth);
    if (_isPaid && paidDate != null) {
      final d = paidDate.day.toString().padLeft(2, '0');
      final m = paidDate.month.toString().padLeft(2, '0');
      return 'Pago em $d/$m/${paidDate.year}';
    }
    if (_isRecurring) {
      return 'Vale só para ${_monthNames[_paidMonth.month - 1]}/${_paidMonth.year}';
    }
    return 'Marque quando este gasto for quitado';
  }

  Color _categoryColor() {
    final categories = context.read<CategoryState>().categories;
    for (final c in categories) {
      if (c.name == _selectedCategory) return c.color;
    }
    return AppTheme.expenseColor;
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
    if ((_recurrenceType == RecurrenceType.period ||
            _recurrenceType == RecurrenceType.installment) &&
        _durationMonths <= 0) {
      _showError('Defina a duração');
      return;
    }

    final dueDate = _recurrenceType == RecurrenceType.once
        ? _selectedDate
        : DateTime(_selectedDate.year, _selectedDate.month, _selectedDay);

    // Mantém os outros meses intactos e mexe só na chave deste. O `??=`
    // preserva a data em que o gasto já havia sido marcado — reabrir e salvar
    // o formulário não deve reescrever esse carimbo para agora.
    final paidByMonth = Map<String, DateTime>.of(
      widget.expense?.paidByMonth ?? const {},
    );
    final paidKey = _recurrenceType == RecurrenceType.once
        ? 'once'
        : '${_paidMonth.year}-${_paidMonth.month.toString().padLeft(2, '0')}';
    if (_isPaid) {
      paidByMonth[paidKey] ??= DateTime.now();
    } else {
      paidByMonth.remove(paidKey);
    }

    widget.onSave(
      Expense(
        id: widget.expense?.id,
        amount: amount,
        title: _titleController.text,
        category: _selectedCategory!,
        dueDate: dueDate,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        recurrenceType: _recurrenceType,
        durationMonths: (_recurrenceType == RecurrenceType.period ||
                _recurrenceType == RecurrenceType.installment)
            ? _durationMonths
            : null,
        paymentMethod: _paymentMethod,
        notifyOnDue: _notifyOnDue,
        paidByMonth: paidByMonth,
        logoDomain: _logoDomain,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.isEditing ?? (widget.expense != null);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar Gasto' : 'Novo Gasto'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<CategoryState>(
        builder: (context, categoryState, _) {
          if (_selectedCategory == null && categoryState.categories.isNotEmpty) {
            _selectedCategory = categoryState.categories.first.name;
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
                    onChanged: _onAmountChanged,
                    decoration: InputDecoration(
                      labelText: _recurrenceType == RecurrenceType.installment
                          ? 'Valor total'
                          : _recurrenceType == RecurrenceType.period ||
                                  _recurrenceType == RecurrenceType.monthly
                              ? 'Valor mensal'
                              : 'Valor',
                      hintText: 'R\$ 0,00',
                      prefixIcon: const Icon(Icons.attach_money_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedCategory),
                    initialValue:
                        categoryState.categories.any(
                          (c) => c.name == _selectedCategory,
                        )
                        ? _selectedCategory
                        : null,
                    items: categoryState.categories.map((category) {
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
                      if (value != null) {
                        setState(() => _selectedCategory = value);
                      }
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

                  // ── Logo da marca ────────────────────────────
                  const SizedBox(height: 12),
                  LogoPickerField(
                    logoDomain: _logoDomain,
                    color: _categoryColor(),
                    onChanged: (d) => setState(() => _logoDomain = d),
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
                  if (_recurrenceType == RecurrenceType.once)
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
                    )
                  else
                    TextField(
                      onTap: _showDayPicker,
                      canRequestFocus: false,
                      showCursor: false,
                      controller: TextEditingController(
                        text: 'Todo dia $_selectedDay',
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Dia de vencimento',
                        prefixIcon: Icon(Icons.today_outlined),
                      ),
                    ),

                  // Marcar pago aqui evita ter que salvar, voltar para a lista
                  // e deslizar o card só para quitar o gasto.
                  const SizedBox(height: 4),
                  SwitchListTile(
                    value: _isPaid,
                    onChanged: (v) => setState(() => _isPaid = v),
                    secondary: Icon(
                      _isPaid
                          ? Icons.check_circle_outline_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: _isPaid ? AppTheme.incomColor : Colors.white38,
                    ),
                    title: const Text('Marcar como pago'),
                    subtitle: Text(_paidSubtitle()),
                    contentPadding: EdgeInsets.zero,
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
                        child: Text('Único'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceType.monthly,
                        child: Text('Recorrente'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceType.installment,
                        child: Text('Parcelado'),
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
                  if (_recurrenceType == RecurrenceType.installment ||
                      _recurrenceType == RecurrenceType.period) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState(
                        () => _durationMonths = int.tryParse(value) ?? 1,
                      ),
                      decoration: InputDecoration(
                        labelText: _recurrenceType == RecurrenceType.installment
                            ? 'Número de parcelas'
                            : 'Duração (meses)',
                        hintText: _recurrenceType == RecurrenceType.installment
                            ? 'Ex: 12'
                            : 'Ex: 6',
                        prefixIcon: const Icon(Icons.hourglass_bottom_outlined),
                      ),
                    ),
                    if (_recurrenceType == RecurrenceType.installment) ...[
                      const SizedBox(height: 8),
                      Builder(
                        builder: (ctx) {
                          final total = CurrencyFormatter.parse(_amountController.text);
                          if (total != null && total > 0 && _durationMonths > 0) {
                            return Text(
                              'Cada parcela: ${CurrencyFormatter.format(total / _durationMonths)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(ctx).colorScheme.primary,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
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

                  // ── Notificação ──────────────────────────────
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: _notifyOnDue,
                    onChanged: (v) => setState(() => _notifyOnDue = v),
                    secondary: Icon(
                      _notifyOnDue
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                      color: _notifyOnDue
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white38,
                    ),
                    title: const Text('Notificar vencimento'),
                    subtitle: const Text('Receba um aviso no dia que este gasto vencer'),
                    contentPadding: EdgeInsets.zero,
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

class _DayPickerSheet extends StatelessWidget {
  const _DayPickerSheet({required this.selectedDay});
  final int selectedDay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DIA DE VENCIMENTO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6E6E78),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: 31,
            itemBuilder: (_, index) {
              final day = index + 1;
              final isSelected = day == selectedDay;
              return GestureDetector(
                onTap: () => Navigator.pop(context, day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
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
