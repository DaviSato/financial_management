import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.selectedMonth,
    required this.onPrevious,
    required this.onNext,
    required this.onGoToToday,
    required this.onMonthTap,
  });

  final DateTime selectedMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onGoToToday;
  final VoidCallback onMonthTap;

  static Future<DateTime?> showPicker(BuildContext context, DateTime selected) {
    return showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthPickerDialog(selected: selected),
    );
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return selectedMonth.year == now.year && selectedMonth.month == now.month;
  }

  bool get _isPastMonth {
    final now = DateTime.now();
    return selectedMonth.isBefore(DateTime(now.year, now.month));
  }

  @override
  Widget build(BuildContext context) {
    final raw = DateFormat('MMMM yyyy', 'pt_BR').format(selectedMonth);
    final label = raw[0].toUpperCase() + raw.substring(1);

    final Color labelColor = _isPastMonth ? Colors.white38 : Colors.white;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NavButton(
                icon: Icons.chevron_left_rounded,
                onPressed: onPrevious,
              ),
              _MonthLabel(label: label, color: labelColor, onTap: onMonthTap),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                onPressed: onNext,
              ),
            ],
          ),
        ),
        if (!_isCurrentMonth) ...[
          const SizedBox(width: 8),
          _TodayButton(onPressed: onGoToToday),
        ],
      ],
    );
  }
}

/// Rótulo central do seletor: mostra o mês e um caret indicando que ao tocar
/// abre o seletor de mês/ano.
class _MonthLabel extends StatelessWidget {
  const _MonthLabel({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: color,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.expand_more_rounded,
                  size: 16,
                  color: color.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Atalho para voltar ao mês atual. Só aparece quando outro mês está
/// selecionado; o tint primário sinaliza a ação de "pular para hoje".
class _TodayButton extends StatelessWidget {
  const _TodayButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primary.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.today_rounded, size: 15, color: primary),
              const SizedBox(width: 5),
              Text(
                'Hoje',
                style: TextStyle(
                  fontSize: 12.5,
                  color: primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 44,
          child: Icon(icon, size: 22, color: Colors.white54),
        ),
      ),
    );
  }
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.selected});
  final DateTime selected;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year;

  static const _months = [
    'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
    'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
  ];

  @override
  void initState() {
    super.initState();
    _year = widget.selected.year;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final primary = Theme.of(context).colorScheme.primary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Year navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _year--),
                  color: Colors.white60,
                ),
                Text(
                  '$_year',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _year++),
                  color: Colors.white60,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Month grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.6,
              ),
              itemCount: 12,
              itemBuilder: (ctx, index) {
                final month = index + 1;
                final isSelected =
                    widget.selected.year == _year && widget.selected.month == month;
                final isCurrent = now.year == _year && now.month == month;
                final isPast =
                    DateTime(_year, month).isBefore(DateTime(now.year, now.month));

                Color textColor;
                if (isSelected) {
                  textColor = Colors.white;
                } else if (isPast) {
                  textColor = Colors.white38;
                } else {
                  textColor = Colors.white70;
                }

                return GestureDetector(
                  onTap: () => Navigator.pop(context, DateTime(_year, month)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primary
                          : isCurrent
                              ? primary.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: isCurrent && !isSelected
                          ? Border.all(color: primary.withValues(alpha: 0.6))
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _months[index],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected || isCurrent
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: textColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
