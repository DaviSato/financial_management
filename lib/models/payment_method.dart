enum PaymentMethod {
  creditCard,
  debitCard,
  pix,
  cash,
  bankSlip,
  bankTransfer;

  String get label => switch (this) {
        PaymentMethod.creditCard => 'Cartão de Crédito',
        PaymentMethod.debitCard => 'Cartão de Débito',
        PaymentMethod.pix => 'Pix',
        PaymentMethod.cash => 'Dinheiro',
        PaymentMethod.bankSlip => 'Boleto',
        PaymentMethod.bankTransfer => 'Transferência',
      };

  String get icon => switch (this) {
        PaymentMethod.creditCard => '💳',
        PaymentMethod.debitCard => '💳',
        PaymentMethod.pix => '⚡',
        PaymentMethod.cash => '💵',
        PaymentMethod.bankSlip => '📄',
        PaymentMethod.bankTransfer => '🏦',
      };

  /// Lê o valor gravado por [toJson], que usa `.name` — não `toString()`.
  /// Valor desconhecido vira null em vez de um método arbitrário: chutar aqui
  /// foi o que escondeu o bug de round-trip original.
  static PaymentMethod? fromString(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final method in PaymentMethod.values) {
      if (method.name == value) return method;
    }
    return null;
  }
}
