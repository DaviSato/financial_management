import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bank_transaction.dart';

/// Falha numa chamada à Pluggy. [statusCode] é null quando nem houve resposta
/// (sem rede, timeout).
class PluggyException implements Exception {
  final int? statusCode;
  final String message;

  const PluggyException(this.message, {this.statusCode});

  /// Credenciais recusadas no `/auth`.
  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => 'PluggyException($statusCode): $message';
}

/// Item da Pluggy como o app precisa dele: id, nome do banco e quando a
/// Pluggy buscou os dados no banco pela última vez.
class PluggyItem {
  final String id;
  final String institution;

  /// `UPDATED`, `UPDATING`, `OUTDATED`, `LOGIN_ERROR`, `WAITING_USER_INPUT`.
  final String? status;

  /// Última vez que a Pluggy trouxe dados do banco com sucesso (horário
  /// local). É o "até quando" das movimentações da caixa de entrada.
  final DateTime? lastUpdatedAt;

  /// Próxima atualização automática agendada pela Pluggy (horário local).
  final DateTime? nextAutoSyncAt;

  const PluggyItem({
    required this.id,
    required this.institution,
    this.status,
    this.lastUpdatedAt,
    this.nextAutoSyncAt,
  });

  bool get isUpdating => status == 'UPDATING';

  /// Status que pedem ação do usuário no Meu Pluggy (reconectar, etc.).
  bool get hasProblem =>
      status == 'LOGIN_ERROR' ||
      status == 'OUTDATED' ||
      status == 'WAITING_USER_INPUT';

  factory PluggyItem.fromJson(Map<String, dynamic> json) {
    final connector = json['connector'] as Map<String, dynamic>?;
    return PluggyItem(
      id: json['id'] as String,
      institution: (connector?['name'] ?? '') as String,
      status: json['status'] as String?,
      lastUpdatedAt: _parseDate(json['lastUpdatedAt']),
      nextAutoSyncAt: _parseDate(json['nextAutoSyncAt']),
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}

/// Cliente HTTP mínimo da API da Pluggy (https://api.pluggy.ai).
///
/// Autentica com clientId/clientSecret em `POST /auth` e reaproveita a API key
/// devolvida, que vale 2 horas. As chamadas vão direto do app: é o modelo do
/// Meu Pluggy, em que as credenciais são do próprio usuário e só dão acesso às
/// contas dele.
class PluggyClient {
  PluggyClient({
    required this.clientId,
    required this.clientSecret,
    http.Client? httpClient,
    DateTime Function()? now,
  })  : _http = httpClient ?? http.Client(),
        _now = now ?? DateTime.now;

  final String clientId;
  final String clientSecret;
  final http.Client _http;
  final DateTime Function() _now;

  static final _base = Uri.parse('https://api.pluggy.ai');

  /// A key vale 2h; renova um pouco antes para não expirar no meio de uma
  /// sincronização com várias páginas.
  static const _keyLifetime = Duration(hours: 1, minutes: 50);
  static const _timeout = Duration(seconds: 30);

  String? _apiKey;
  DateTime? _apiKeyExpiresAt;

  Future<String> _key() async {
    final expiresAt = _apiKeyExpiresAt;
    if (_apiKey != null && expiresAt != null && _now().isBefore(expiresAt)) {
      return _apiKey!;
    }

    final response = await _send(
      () => _http.post(
        _base.replace(path: '/auth'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'clientId': clientId, 'clientSecret': clientSecret}),
      ),
    );
    final key = (_decode(response) as Map<String, dynamic>)['apiKey'];
    if (key is! String || key.isEmpty) {
      throw const PluggyException('Resposta do /auth sem apiKey');
    }
    _apiKey = key;
    _apiKeyExpiresAt = _now().add(_keyLifetime);
    return key;
  }

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? query,
  ]) async {
    final uri = _base.replace(path: path, queryParameters: query);
    final key = await _key();
    final response =
        await _send(() => _http.get(uri, headers: {'X-API-KEY': key}));
    return _decode(response) as Map<String, dynamic>;
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } catch (e) {
      throw PluggyException('Falha de conexão com a Pluggy: $e');
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    if (response.statusCode == 401) {
      // Key revogada ou expirada antes do previsto: a próxima chamada pede
      // outra em vez de insistir na mesma.
      _apiKey = null;
    }
    throw PluggyException(
      _errorMessage(response),
      statusCode: response.statusCode,
    );
  }

  static Object? _decode(http.Response response) =>
      jsonDecode(utf8.decode(response.bodyBytes));

  static String _errorMessage(http.Response response) {
    try {
      final body = _decode(response);
      if (body is Map && body['message'] is String) {
        return body['message'] as String;
      }
    } catch (_) {
      // Corpo não-JSON: cai na mensagem genérica.
    }
    return 'HTTP ${response.statusCode}';
  }

  /// `GET /items/{id}` — valida o id colado pelo usuário e lê o nome do banco
  /// e a data da última atualização.
  Future<PluggyItem> getItem(String itemId) async =>
      PluggyItem.fromJson(await _get('/items/$itemId'));

  /// `GET /accounts?itemId=` — contas correntes, poupanças e cartões do item.
  Future<List<BankAccount>> getAccounts(String itemId) async {
    final accounts = <BankAccount>[];
    var page = 1;
    while (true) {
      final json = await _get('/accounts', {
        'itemId': itemId,
        'page': '$page',
      });
      for (final a in json['results'] as List) {
        accounts.add(BankAccount.fromPluggy(a as Map<String, dynamic>));
      }
      final totalPages = (json['totalPages'] as num?)?.toInt() ?? 1;
      if (page >= totalPages) return accounts;
      page++;
    }
  }

  /// `GET /v2/transactions` — movimentações da conta com data a partir de
  /// [from], percorrendo todas as páginas pelo cursor `after`.
  ///
  /// Devolve o JSON cru: a tradução para o app depende da conta (cartão ou
  /// não), que fica em [BankTransaction.fromPluggy].
  Future<List<Map<String, dynamic>>> getTransactions(
    String accountId, {
    required DateTime from,
  }) async {
    final results = <Map<String, dynamic>>[];
    String? after;
    do {
      final json = await _get('/v2/transactions', {
        'accountId': accountId,
        'dateFrom': _date(from),
        'after': ?after,
      });
      for (final t in json['results'] as List) {
        results.add(t as Map<String, dynamic>);
      }
      after = _cursor(json['next'] as String?);
    } while (after != null);
    return results;
  }

  /// O `next` vem como query string pronta (`?accountId=…&after=…`); o
  /// parâmetro `after` deve ir só com o valor decodificado.
  static String? _cursor(String? next) {
    if (next == null || next.isEmpty) return null;
    final query = next.startsWith('?') ? next.substring(1) : next;
    return Uri.splitQueryString(query)['after'];
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void close() => _http.close();
}
