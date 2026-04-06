import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/category_form_dialog.dart';

class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categorias'), elevation: 0),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CategoryFormDialog.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Nova Categoria'),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          if (appState.categories.isEmpty) {
            return _buildEmptyState(context);
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
            itemCount: appState.categories.length,
            itemBuilder: (context, index) {
              return _CategoryItem(
                category: appState.categories[index],
                onEdit: () => CategoryFormDialog.show(
                  context,
                  category: appState.categories[index],
                ),
                onDelete: () => _confirmDelete(
                  context,
                  appState.categories[index],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.category_outlined, size: 48, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Text(
            'Nenhuma categoria',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Crie categorias para organizar seus gastos',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => CategoryFormDialog.show(context),
            icon: const Icon(Icons.add),
            label: const Text('Criar primeira categoria'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (dialogContext) => _DeleteCategoryDialog(
        category: category,
        onConfirm: () {
          context.read<AppState>().deleteCustomCategory(category.id);
          Navigator.pop(dialogContext);
        },
        onCancel: () => Navigator.pop(dialogContext),
      ),
    );
  }
}

// ─── Delete Dialog ────────────────────────────────────────────────────────────

class _DeleteCategoryDialog extends StatelessWidget {
  const _DeleteCategoryDialog({
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

// ─── Category List Item ───────────────────────────────────────────────────────

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: category.color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          title: Text(
            category.name,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit,
                tooltip: 'Editar',
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 20, color: AppTheme.expenseColor),
                onPressed: onDelete,
                tooltip: 'Excluir',
              ),
            ],
          ),
        ),
      );
  }
}
