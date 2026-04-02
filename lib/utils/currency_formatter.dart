import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );

  /// Format a double value as Brazilian currency
  /// Example: 3450.00 -> R$ 3.450,00
  static String format(double value) {
    return _currencyFormat.format(value);
  }

  /// Format a double value as Brazilian currency without symbol
  /// Example: 3450.00 -> 3.450,00
  static String formatNoSymbol(double value) {
    final formatted = _currencyFormat.format(value);
    return formatted.replaceFirst('R\$ ', '');
  }

  /// Parse a user input and return a double
  /// Handles formatted input: "R$ 1.234,56" or raw input
  static double? parse(String value) {
    try {
      if (value.isEmpty) return null;

      // Remove R$ symbol e espaços
      String cleaned = value.replaceAll('R\$', '').trim();

      // Se contém ponto e vírgula, é o formato brasileiro (1.234,56)
      if (cleaned.contains(',')) {
        // Remove pontos (separador de milhar)
        cleaned = cleaned.replaceAll('.', '');
        // Substitui vírgula por ponto para parsing
        cleaned = cleaned.replaceAll(',', '.');
      } else if (cleaned.contains('.')) {
        // Se só tem ponto, pode ser o separador decimal
        // Conta quantos pontos tem
        int pontosCount = '.'.allMatches(cleaned).length;
        if (pontosCount == 1) {
          // Um ponto = separador decimal (padrão US)
          // Deixa como está
        } else {
          // Múltiplos pontos = pontos de milhar, remove todos menos o último
          final parts = cleaned.split('.');
          cleaned = '${parts.join()}.${parts.last}';
        }
      }

      return double.parse(cleaned);
    } catch (e) {
      return null;
    }
  }
}
