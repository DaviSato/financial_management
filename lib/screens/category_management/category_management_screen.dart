import 'package:financial_management/screens/category_management/widgets/category_item.dart';
import 'package:financial_management/screens/category_management/widgets/delete_category_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../providers/category_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/category_form_dialog.dart';

class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({super.key});

  void _confirmDelete(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (dialogContext) => DeleteCategoryDialog(
        category: category,
        onConfirm: () {
          context.read<CategoryState>().deleteCustomCategory(category.id);
          Navigator.pop(dialogContext);
        },
        onCancel: () => Navigator.pop(dialogContext),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categorias'), elevation: 0),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CategoryFormDialog.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Nova Categoria'),
      ),
      body: Consumer<CategoryState>(
        builder: (context, appState, _) {
          if (appState.categories.isEmpty) {
            return _buildEmptyState(context);
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
            itemCount: appState.categories.length,
            itemBuilder: (context, index) {
              return CategoryItem(
                category: appState.categories[index],
                onEdit: () => CategoryFormDialog.show(
                  context,
                  category: appState.categories[index],
                ),
                onDelete: () =>
                    _confirmDelete(context, appState.categories[index]),
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
            child: const Icon(
              Icons.category_outlined,
              size: 48,
              color: Colors.grey,
            ),
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
}
