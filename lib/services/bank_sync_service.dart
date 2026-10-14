import 'package:flutter/foundation.dart';

import '../models/bank_connection.dart';
import '../models/bank_transaction.dart';
import 'bank_handled_store.dart';
import 'pluggy_client.dart';
import 'pluggy_config.dart';

typedef PluggyClientFactory = PluggyClient Function(
  String clientId,
  String clientSecret,
);

/// Busca na Pluggy as movimentações dos bancos conectados e mantém a caixa de
/// entrada: o que ainda não foi lançado nem descartado.
///
/// Nada vira lançamento sozinho — uma movimentação pode ser algo novo ou o
/// pagamento de algo que já existe (recorrente, parcelado), e só o usuário
/// sabe qual. O serviço só entrega a lista; quem lança é a tela.
class BankSyncService extends ChangeNotifier {
  BankSyncService._({
    PluggyConfig? config,
    BankHandledStore? handled,
    PluggyClientFactory? clientFactory,
    DateTime Function()? now,
  })  : _config = config ?? PluggyConfig(),
        _handled = handled ?? PrefsFirestoreHandledStore(),
        _clientFactory = clientFactory ?? _defaultClient,
        _now = now ?? DateTime.now;

  static BankSyncService _instance = BankSyncService._();
  factory BankSyncService() => _instance;

  /// Instância com dependências trocadas, para testes.
  @visibleForTesting
  static void overrideForTesting({
    PluggyConfig? config,
    BankHandledStore? handled,
    PluggyClientFactory? clientFactory,
    DateTime Function()? now,
  }) {
    _instance = BankSyncService._(
      config: config,
      handled: handled,
      clientFactory: clientFactory,
      now: now,
    );
  }

  static PluggyClient _defaultClient(String id, String secret) =>
      PluggyClient(clientId: id, clientSecret: secret);

  final PluggyConfig _config;
  final BankHandledStore _handled;
  final PluggyClientFactory _clientFactory;
  final DateTime Function() _now;

  /// O Meu Pluggy só atualiza a cada 24h; sincronizar a cada vez que o app
  /// volta ao primeiro plano só gastaria requisições.
  static const minInterval = Duration(minutes: 15);

  /// Quanto para trás olhar. Sem limite, cada sincronização baixaria tudo
  /// desde que o banco foi conectado; o que ficou mais de 60 dias sem ser
  /// lançado sai da caixa de entrada.
  static const lookback = Duration(days: 60);

  List<BankTransaction> _pending = const [];
  DateTime? _lastSync;
  String? _lastError;
  Future<void>? _running;

  List<BankTransaction> get pending => List.unmodifiable(_pending);
  bool get isConfigured => _config.isConfigured;
  DateTime? get lastSync => _lastSync;

  /// Mensagem da última falha, ou null se a última sincronização deu certo.
  String? get lastError => _lastError;
  bool get isSyncing => _running != null;

  /// Sincroniza se a última foi há mais de [minInterval] (ou sempre, com
  /// [force]). Chamadas concorrentes esperam a mesma execução.
  Future<void> sync({bool force = false}) {
    if (_running != null) return _running!;
    final last = _lastSync;
    if (!force && last != null && _now().difference(last) < minInterval) {
      return Future.value();
    }
    _running = _sync().whenComplete(() {
      _running = null;
      notifyListeners();
    });
    notifyListeners();
    return _running!;
  }

  Future<void> _sync() async {
    if (!_config.isConfigured) {
      _pending = const [];
      _lastError = null;
      return;
    }

    final client = _clientFactory(_config.clientId, _config.clientSecret);
    try {
      final handled = await _handled.load();
      final handledFingerprints = handled.values.whereType<String>().toSet();
      final found = <BankTransaction>[];

      for (final connection in _config.connections) {
        found.addAll(await _fetch(client, connection));
      }

      _pending = found
          .where((t) =>
              !handled.containsKey(t.id) &&
              !handledFingerprints.contains(t.fingerprint))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      _lastSync = _now();
      _lastError = null;
    } on PluggyException catch (e) {
      _lastError = e.isUnauthorized
          ? 'Credenciais da Pluggy recusadas. Confira em Perfil > Bancos conectados.'
          : e.statusCode == null
              ? 'Sem conexão com a Pluggy.'
              : 'Erro da Pluggy: ${e.message}';
    } finally {
      client.close();
    }
  }

  Future<List<BankTransaction>> _fetch(
    PluggyClient client,
    BankConnection connection,
  ) async {
    final connectedDay = DateTime(
      connection.connectedAt.year,
      connection.connectedAt.month,
      connection.connectedAt.day,
    );
    final windowStart = _now().subtract(lookback);
    final from = connectedDay.isAfter(windowStart) ? connectedDay : windowStart;

    final result = <BankTransaction>[];
    for (final account in await client.getAccounts(connection.itemId)) {
      final raw = await client.getTransactions(account.id, from: from);
      for (final json in raw) {
        final t = BankTransaction.fromPluggy(
          json,
          account: account,
          institution: connection.institution,
        );
        // Histórico anterior à conexão fica de fora, mesmo que a Pluggy o
        // devolva.
        if (t != null && !t.date.isBefore(connectedDay)) result.add(t);
      }
    }
    return result;
  }

  /// Tira da caixa de entrada (lançadas ou descartadas) e lembra delas.
  Future<void> markHandled(Iterable<BankTransaction> transactions) async {
    final list = transactions.toList();
    if (list.isEmpty) return;
    final ids = {for (final t in list) t.id};
    _pending = _pending.where((t) => !ids.contains(t.id)).toList();
    notifyListeners();
    await _handled.add(list);
  }

  /// Descarta o cache — chamar quando credenciais ou bancos mudam.
  void reset() {
    _pending = const [];
    _lastSync = null;
    _lastError = null;
    notifyListeners();
  }
}
