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

  late RecurrenceType _recurrenceType;
  late int _durationMonths;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.income != null
          ? CurrencyFormatter.format(widget.income!.amount)
          : '',
    );
    _titleController = TextEditingController(text: widget.income?.title ?? '');
    _notesController = TextEditingController(text: widget.income?.notes ?? '');
    _durationController = TextEditingController(
      text: widget.income?.durationMonths?.toString() ?? '1',
    );
    _recurrenceType = widget.income?.recurrenceType ?? RecurrenceType.once;
    _durationMonths = widget.income?.durationMonths ?? 1;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _durationController.dispose();
    super.dispose();
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
              TextField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Ex: Salário, Bônus, Freelance',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [BrazilianCurrencyInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Valor',
                  hintText: 'R\$ 0,00',
                ),
              ),

              const SizedBox(height: 16),
              DropdownButtonFormField<RecurrenceType>(
                initialValue: _recurrenceType,
                onChanged: (value) => setState(
                  () => _recurrenceType = value ?? RecurrenceType.once,
                ),
                items: const [
                  DropdownMenuItem(
                    value: RecurrenceType.once,
                    child: Text('Rendimento Único'),
                  ),
                  DropdownMenuItem(
                    value: RecurrenceType.monthly,
                    child: Text('Rendimento Mensal (Recorrente)'),
                  ),
                  DropdownMenuItem(
                    value: RecurrenceType.period,
                    child: Text('Rendimento por Período'),
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Tipo de Rendimento',
                ),
              ),
              if (_recurrenceType == RecurrenceType.period) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) => setState(
                    () => _durationMonths = int.tryParse(value) ?? 1,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Duração (meses)',
                    hintText: 'Ex: 6',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observações (opcional)',
                  hintText: 'Adicione observações...',
                ),
              ),
              const SizedBox(height: 24),
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
            ],
          ),
        ),
      ),
    );
  }
}
