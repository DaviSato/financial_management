/// De qual banco veio um gasto/rendimento lançado pela caixa de entrada da
/// Pluggy. Guarda nome e logo no próprio lançamento (e não o id do item) para
/// o selo aparecer igual em outro aparelho, onde os bancos podem nem estar
/// configurados.
class BankOrigin {
  final String name;

  /// Domínio do logo (logo.dev); null quando o banco não tem logo escolhido.
  final String? logoDomain;

  const BankOrigin({required this.name, this.logoDomain});

  Map<String, dynamic> toJson() => {
        'name': name,
        if (logoDomain != null) 'logoDomain': logoDomain,
      };

  static BankOrigin? fromJson(Object? json) {
    if (json is! Map) return null;
    return BankOrigin(
      name: (json['name'] ?? '') as String,
      logoDomain: json['logoDomain'] as String?,
    );
  }
}
