import 'package:flutter/services.dart';

class BrazilianCurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Se está vazio, deixa vazio
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remove tudo que não é dígito
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Se não há dígitos, deixa vazio
    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Converte para número (centavos)
    int centavos = int.parse(digitsOnly);

    // Formata como moeda brasileira
    String formatted = _formatCurrency(centavos);

    // Calcula nova posição do cursor
    int newCursorPosition = _calculateCursorPosition(
      oldValue.text,
      formatted,
      oldValue.selection.baseOffset,
    );

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );
  }

  /// Formata centavos para moeda brasileira (R$ 1.234,56)
  String _formatCurrency(int centavos) {
    String centavosStr = centavos.toString().padLeft(3, '0');
    String reais = centavosStr.substring(0, centavosStr.length - 2);
    String centavosFormatted = centavosStr.substring(centavosStr.length - 2);

    // Adiciona pontos de milhar
    String raiasFormatado = '';
    int contador = 0;
    for (int i = reais.length - 1; i >= 0; i--) {
      if (contador == 3) {
        raiasFormatado = '.$raiasFormatado';
        contador = 0;
      }
      raiasFormatado = reais[i] + raiasFormatado;
      contador++;
    }

    return 'R\$ $raiasFormatado,$centavosFormatted';
  }

  /// Calcula a posição do cursor mantendo a locução no mesmo ponto
  int _calculateCursorPosition(
    String oldText,
    String newText,
    int oldCursorPosition,
  ) {
    // Se estamos deletando caracteres no final, move cursor para o final
    if (oldText.length > newText.length) {
      return newText.length;
    }

    // Se adicionamos caracteres, move cursor para frente
    int difference = newText.length - oldText.length;
    return oldCursorPosition + difference;
  }
}
