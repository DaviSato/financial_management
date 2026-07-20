/// Soma [months] meses a [date] preservando o dia sempre que possível.
///
/// `DateTime(2026, 1 + 1, 31)` no Dart estoura para 03/03 — o que faria um
/// recebimento do dia 31 cair no mês errado. Aqui o dia é limitado ao último
/// dia do mês de destino (31/01 + 1 mês → 28/02).
DateTime addMonths(DateTime date, int months) {
  final target = DateTime(date.year, date.month + months, 1);
  final lastDayOfTarget = DateTime(target.year, target.month + 1, 0).day;
  final day = date.day > lastDayOfTarget ? lastDayOfTarget : date.day;
  return DateTime(target.year, target.month, day);
}

/// Diferença em meses entre dois momentos, ignorando o dia.
int monthsBetween(DateTime from, DateTime to) =>
    (to.year - from.year) * 12 + (to.month - from.month);
