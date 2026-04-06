import 'package:financial_management/screens/expense_screen/widgets/category_chip.dart';
import 'package:financial_management/theme/app_theme.dart';
import 'package:flutter/material.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onManageCategories,
  });

  final List categories;
  final String? selectedCategory;
  final void Function(String?) onCategorySelected;
  final VoidCallback onManageCategories;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                GestureDetector(
                  onTap: onManageCategories,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: const Icon(
                      Icons.category,
                      size: 16,
                      color: Color(0xFF6E6E78),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CategoryChip(
                  label: 'Todos',
                  color: AppTheme.primaryColor,
                  selected: selectedCategory == null,
                  onTap: () => onCategorySelected(null),
                ),
                const SizedBox(width: 8),
                ...categories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CategoryChip(
                      label: category.name,
                      color: category.color,
                      selected: selectedCategory == category.name,
                      onTap: () => onCategorySelected(category.name),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),
      ],
    );
  }
}
