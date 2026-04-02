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

  static PaymentMethod? fromString(String? value) {
    if (value == null) return null;
    return PaymentMethod.values.firstWhere(
      (e) => e.toString() == value,
      orElse: () => PaymentMethod.creditCard,
    );
  }
}
