// ─── Delete Dialog ────────────────────────────────────────────────────────────

import 'package:financial_management/models/category.dart';
import 'package:financial_management/theme/app_theme.dart';
import 'package:flutter/material.dart';

class DeleteCategoryDialog extends StatelessWidget {
  const DeleteCategoryDialog({
    super.key,
    required this.category,
    required this.onConfirm,
    required this.onCancel,
  });

  final Category category;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
      title: const Text('Excluir categoria'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Tem certeza que deseja excluir esta categoria?',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            category.name,
            style: TextStyle(fontSize: 12, color: category.color),
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
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.expenseColor,
                  minimumSize: const Size(0, 42),
                ),
                child: const Text('Excluir'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
