/// Um item da Pluggy (conexão com um banco) cadastrado no app.
///
/// No Meu Pluggy não dá para listar os items pela API (`GET /items` responde
/// 403), então o usuário cola o id de cada um e o app guarda aqui.
class BankConnection {
  final String itemId;

  /// Nome do banco. No Meu Pluggy o conector é sempre "MeuPluggy", então
  /// quem diz o banco é o usuário.
  final String institution;

  /// Domínio do logo do banco (logo.dev), mostrado como bandeira em cada
  /// movimentação. O arquivo fica em cache via LogoService.
  final String? logoDomain;

  /// Quando a conexão foi cadastrada no app. Só movimentações a partir deste
  /// dia entram na caixa de entrada — o histórico anterior fica de fora.
  final DateTime connectedAt;

  const BankConnection({
    required this.itemId,
    required this.institution,
    required this.connectedAt,
    this.logoDomain,
  });

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'institution': institution,
        'connectedAt': connectedAt.toIso8601String(),
        if (logoDomain != null) 'logoDomain': logoDomain,
      };

  factory BankConnection.fromJson(Map<String, dynamic> json) {
    return BankConnection(
      itemId: json['itemId'] as String,
      institution: (json['institution'] ?? '') as String,
      connectedAt: DateTime.parse(json['connectedAt'] as String),
      logoDomain: json['logoDomain'] as String?,
    );
  }
}
