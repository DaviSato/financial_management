import 'package:flutter/material.dart';

import '../models/income.dart';
import '../models/recurrence.dart';
import '../utils/brazilian_currency_input_formatter.dart';
import '../utils/currency_formatter.dart';

class IncomeFormDialog extends StatefulWidget {
  final Income? income;
  final Function(Income) onSave;

  const IncomeFormDialog({super.key, this.income, required this.onSave});

  @override
  State<IncomeFormDialog> createState() => _IncomeFormDialogState();
}

class _IncomeFormDialogState extends State<IncomeFormDialog> {
  late TextEditingController _amountController;
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late TextEditingController _durationController;
  late TextEditingController _intervalController;

  late RecurrenceType _recurrenceType;
  late int _durationMonths;
  late int _intervalMonths;
  late DateTime _receiveDate;

  @override
  void initState() {
    super.initState();
    final i = widget.income;
    _amountController = TextEditingController(
      text: i != null ? CurrencyFormatter.format(i.amount) : '',
    );
    _titleController = TextEditingController(text: i?.title ?? '');
    _notesController = TextEditingController(text: i?.notes ?? '');
    _durationController = TextEditingController(
      text: i?.durationMonths?.toString() ?? '1',
    );
    _intervalController = TextEditingController(
      text: i?.effectiveIntervalMonths.toString() ?? '1',
    );
    _recurrenceType = i?.recurrenceType ?? RecurrenceType.once;
    _durationMonths = i?.durationMonths ?? 1;
    _intervalMonths = i?.effectiveIntervalMonths ?? 1;
    _receiveDate = i?.receiveDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _durationController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _receiveDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 10, 12, 31),
    );
    if (picked != null) setState(() => _receiveDate = picked);
  }

  /// Texto explicando o que o intervalo escolhido significa na prática.
  String? get _intervalHint {
    if (_recurrenceType != RecurrenceType.monthly) return null;
    switch (_intervalMonths) {
      case 1:
        return 'Todo mês';
      case 2:
        return 'A cada 2 meses (bimestral)';
      case 3:
        return 'A cada 3 meses (trimestral)';
      case 6:
        return 'A cada 6 meses (semestral)';
      case 12:
        return 'Uma vez por ano — ex: 13º, saque-aniversário do FGTS';
      default:
        return _intervalMonths > 0 ? 'A cada $_intervalMonths meses' : null;
    }
  }

  void _saveIncome() {
    if (_titleController.text.isEmpty) {
      _showError('Informe um título');
      return;
    }
    if (_amountController.text.isEmpty) {
      _showError('Informe um valor');
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
    if (_recurrenceType == RecurrenceType.monthly && _intervalMonths <= 0) {
      _showError('Defina de quantos em quantos meses o rendimento se repete');
      return;
    }

    widget.onSave(
      Income(
        id: widget.income?.id,
        amount: amount,
        title: _titleController.text,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        recurrenceType: _recurrenceType,
        durationMonths: _recurrenceType == RecurrenceType.period
            ? _durationMonths
            : null,
        intervalMonths: _recurrenceType == RecurrenceType.monthly
            ? _intervalMonths
            : null,
        receiveDate: _receiveDate,
        createdAt: widget.income?.createdAt,
      ),
    );
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.income != null;
    final isRecurring = _recurrenceType == RecurrenceType.monthly;
    final isPeriod = _recurrenceType == RecurrenceType.period;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar Rendimento' : 'Novo Rendimento'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Informações básicas ──────────────────────
              const _SectionLabel('Informações'),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Ex: Salário, 13º, Abono salarial',
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
                decoration: InputDecoration(
                  labelText: isRecurring || isPeriod
                      ? 'Valor por recebimento'
                      : 'Valor',
                  hintText: 'R\$ 0,00',
                  prefixIcon: const Icon(Icons.attach_money_outlined),
                ),
              ),

              // ── Recebimento ──────────────────────────────
              const SizedBox(height: 24),
              const _SectionLabel('Recebimento'),
              const SizedBox(height: 12),
              TextField(
                onTap: _selectDate,
                canRequestFocus: false,
                showCursor: false,
                controller: TextEditingController(
                  text:
                      '${_receiveDate.day.toString().padLeft(2, '0')}/${_receiveDate.month.toString().padLeft(2, '0')}/${_receiveDate.year}',
                ),
                decoration: InputDecoration(
                  labelText: _recurrenceType == RecurrenceType.once
                      ? 'Data do recebimento'
                      : 'Primeiro recebimento',
                  prefixIcon: const Icon(Icons.date_range_outlined),
                ),
              ),

              // ── Recorrência ──────────────────────────────
              const SizedBox(height: 24),
              const _SectionLabel('Recorrência'),
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
                    value: RecurrenceType.period,
                    child: Text('Por Período'),
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Tipo de Rendimento',
                  prefixIcon: Icon(Icons.repeat_outlined),
                ),
              ),
              if (isRecurring) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _intervalController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) => setState(
                    () => _intervalMonths = int.tryParse(value) ?? 0,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Repetir a cada (meses)',
                    hintText: 'Ex: 1 = mensal, 6 = semestral, 12 = anual',
                    prefixIcon: Icon(Icons.event_repeat_outlined),
                  ),
                ),
                if (_intervalHint != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _intervalHint!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ],
              if (isPeriod) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) => setState(
                    () => _durationMonths = int.tryParse(value) ?? 0,
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
              const _SectionLabel('Observações'),
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
                      onPressed: _saveIncome,
                      child: Text(isEdit ? 'Salvar' : 'Adicionar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
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
