/// Uma notificação crua capturada pelo serviço nativo, antes de qualquer
/// interpretação.
///
/// Fase 0 do fluxo de importação: aqui só existe o texto como o banco enviou.
/// A conversão em Expense/Income acontece depois, sobre formatos reais
/// coletados no aparelho — não sobre formatos presumidos.
class CapturedNotification {
  final String packageName;
  final String title;
  final String text;
  final String bigText;
  final String subText;
  final DateTime postedAt;

  /// Caminho do arquivo na fila. O Dart é quem apaga depois de consumir.
  final String filePath;

  const CapturedNotification({
    required this.packageName,
    required this.title,
    required this.text,
    required this.bigText,
    required this.subText,
    required this.postedAt,
    required this.filePath,
  });

  /// O corpo mais completo disponível: notificações longas trazem o texto
  /// inteiro em bigText e uma versão truncada em text.
  String get body => bigText.isNotEmpty ? bigText : text;

  /// Tudo que o parser terá à disposição, concatenado — útil para inspecionar
  /// e para casar padrões sem depender de qual campo o banco usou.
  String get fullText =>
      [title, body, subText].where((s) => s.isNotEmpty).join(' · ');

  factory CapturedNotification.fromJson(
    Map<String, dynamic> json, {
    required String filePath,
  }) {
    return CapturedNotification(
      packageName: json['packageName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      text: json['text'] as String? ?? '',
      bigText: json['bigText'] as String? ?? '',
      subText: json['subText'] as String? ?? '',
      postedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['postTime'] as num?)?.toInt() ?? 0,
      ),
      filePath: filePath,
    );
  }

  Map<String, dynamic> toJson() => {
    'packageName': packageName,
    'title': title,
    'text': text,
    'bigText': bigText,
    'subText': subText,
    'postTime': postedAt.millisecondsSinceEpoch,
  };

  @override
  String toString() =>
      'CapturedNotification($packageName, $postedAt, "$fullText")';
}
