import 'package:financial_management/theme/app_theme.dart';
import 'package:flutter/material.dart';

enum SortOption {
  dateDesc,
  dateAsc,
  amountDesc,
  amountAsc,
  paidLast,
  categoryAz,
}

class SortButton extends StatelessWidget {
  const SortButton({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final SortOption selected;
  final void Function(SortOption) onSelected;

  static const _items = [
    (SortOption.dateDesc, Icons.history_rounded, 'Mais recente primeiro'),
    (SortOption.dateAsc, Icons.update_rounded, 'Mais antigo primeiro'),
    (
      SortOption.amountDesc,
      Icons.trending_down_rounded,
      'Maior valor primeiro',
    ),
    (SortOption.amountAsc, Icons.trending_up_rounded, 'Menor valor primeiro'),
    (
      SortOption.paidLast,
      Icons.check_circle_outline_rounded,
      'Não pagos primeiro',
    ),
    (SortOption.categoryAz, Icons.label_outline_rounded, 'Categoria A→Z'),
  ];

  bool get _isDefault => selected == SortOption.dateDesc;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SortOption>(
      tooltip: 'Ordenar',
      onSelected: onSelected,
      offset: const Offset(0, 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_vert_rounded,
              size: 18,
              color: _isDefault ? Colors.white54 : AppTheme.primaryColor,
            ),
            const SizedBox(width: 4),
            Text(
              'Ordenar',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _isDefault ? Colors.white38 : AppTheme.primaryColor,
              ),
            ),
            if (!_isDefault) ...[
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
      itemBuilder: (_) => _items.map((item) {
        final (option, icon, label) = item;
        final isSelected = selected == option;
        return PopupMenuItem<SortOption>(
          value: option,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : const Color(0xFF6E6E78),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? AppTheme.primaryColor : Colors.white,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: AppTheme.primaryColor,
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
