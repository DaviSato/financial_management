import 'package:flutter/foundation.dart';

import '../models/bank_connection.dart';
import '../models/bank_history_entry.dart';
import '../models/bank_transaction.dart';
import 'bank_auto_launcher.dart';
import 'bank_history_store.dart';
import 'pluggy_client.dart';
import 'pluggy_config.dart';

typedef PluggyClientFactory = PluggyClient Function(
  String clientId,
  String clientSecret,
);

/// Busca na Pluggy as movimentações dos bancos conectados e mantém a caixa de
/// entrada (o que ainda não foi lançado nem descartado) e o histórico (o que
/// já foi, e o que virou).
///
/// Depois de cada sincronização, o [autoLauncher] (quando ligado) manda as
/// novas para a IA e lança o que ela classificar com confiança alta; o resto
/// fica na caixa de entrada para o usuário decidir.
class BankSyncService extends ChangeNotifier {
  BankSyncService._({
    PluggyConfig? config,
    BankHistoryStore? history,
    PluggyClientFactory? clientFactory,
    DateTime Function()? now,
  })  : _config = config ?? PluggyConfig(),
        _store = history ?? PrefsFirestoreHistoryStore(),
        _clientFactory = clientFactory ?? _defaultClient,
        _now = now ?? DateTime.now;

  static BankSyncService _instance = BankSyncService._();
  factory BankSyncService() => _instance;

  /// Instância com dependências trocadas, para testes.
  @visibleForTesting
  static void overrideForTesting({
    PluggyConfig? config,
    BankHistoryStore? history,
    PluggyClientFactory? clientFactory,
    DateTime Function()? now,
  }) {
    _instance = BankSyncService._(
      config: config,
      history: history,
      clientFactory: clientFactory,
      now: now,
    );
  }

  static PluggyClient _defaultClient(String id, String secret) =>
      PluggyClient(clientId: id, clientSecret: secret);

  final PluggyConfig _config;
  final BankHistoryStore _store;
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
  Map<String, BankHistoryEntry> _history = {};
  Map<String, PluggyItem> _items = const {};
  DateTime? _lastSync;
  String? _lastError;
  String? _autoError;
  Future<void>? _running;

  /// Lançamento automático pela IA. Registrado no boot, onde estão os
  /// providers de gastos/rendimentos; null = tudo fica para o usuário.
  BankAutoLauncher? autoLauncher;

  List<BankTransaction> get pending => List.unmodifiable(_pending);

  /// O que já saiu da caixa de entrada, da movimentação mais recente para a
  /// mais antiga. Registros antigos sem retrato ficam de fora (não há o que
  /// mostrar), mas continuam impedindo a movimentação de voltar.
  List<BankHistoryEntry> get history {
    final list = _history.values.where((e) => e.transaction != null).toList()
      ..sort((a, b) {
        final byDate = b.transaction!.date.compareTo(a.transaction!.date);
        if (byDate != 0) return byDate;
        final at = a.handledAt, bt = b.handledAt;
        if (at == null || bt == null) return 0;
        return bt.compareTo(at);
      });
    return list;
  }

  /// Situação de cada item na Pluggy (última atualização, status), por
  /// itemId, como lida na última sincronização.
  Map<String, PluggyItem> get items => Map.unmodifiable(_items);

  /// Próxima atualização automática da Pluggy entre os bancos conectados (a
  /// mais cedo), como lida na última sincronização. Pode já ter passado, se
  /// a Pluggy atrasou.
  DateTime? get nextUpdateAt {
    DateTime? next;
    for (final item in _items.values) {
      final at = item.nextAutoSyncAt;
      if (at != null && (next == null || at.isBefore(next))) next = at;
    }
    return next;
  }

  bool get isConfigured => _config.isConfigured;
  DateTime? get lastSync => _lastSync;

  /// Mensagem da última falha, ou null se a última sincronização deu certo.
  String? get lastError => _lastError;

  /// Falha do lançamento automático na última sincronização (cota, chave).
  String? get autoError => _autoError;
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
    // O histórico aparece mesmo sem banco configurado (ou sem rede).
    final history = await _store.load();
    _history = history;

    if (!_config.isConfigured) {
      _pending = const [];
      _items = const {};
      _lastError = null;
      return;
    }

    final client = _clientFactory(_config.clientId, _config.clientSecret);
    try {
      final found = <BankTransaction>[];
      final items = <String, PluggyItem>{};

      for (final connection in _config.connections) {
        items[connection.itemId] = await client.getItem(connection.itemId);
        found.addAll(await _fetch(client, connection));
      }

      // Registros antigos guardavam só o id: completa com o retrato enquanto
      // a Pluggy ainda devolve a movimentação.
      final enriched = [
        for (final t in found)
          if (history[t.id] case final e? when e.transaction == null)
            e.withTransaction(t),
      ];
      if (enriched.isNotEmpty) {
        for (final e in enriched) {
          history[e.transactionId] = e;
        }
        await _store.save(enriched);
      }

      final fingerprints =
          history.values.map((e) => e.fingerprint).whereType<String>().toSet();
      _pending = found
          .where((t) =>
              !history.containsKey(t.id) &&
              !fingerprints.contains(t.fingerprint))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      _items = items;
      _lastSync = _now();
      _lastError = null;
      await _runAutoLauncher();
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

  Future<void> _runAutoLauncher() async {
    final launcher = autoLauncher;
    if (launcher == null || !launcher.isEnabled) {
      _autoError = null;
      return;
    }
    try {
      _autoError = await launcher.run(this);
    } catch (e) {
      debugPrint('Falha no lançamento automático: $e');
      _autoError = 'Falha no lançamento automático.';
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
          institutionLogo: connection.logoDomain,
        );
        // Histórico anterior à conexão fica de fora, mesmo que a Pluggy o
        // devolva.
        if (t != null && !t.date.isBefore(connectedDay)) result.add(t);
      }
    }
    return result;
  }

  /// A movimentação virou o gasto/rendimento [launchedId].
  Future<void> launch(BankTransaction t, {required String launchedId}) =>
      record([
        BankHistoryEntry.of(
          t,
          BankOutcome.launched,
          at: _now(),
          launchedId: launchedId,
        ),
      ]);

  /// Não era para lançar.
  Future<void> discard(Iterable<BankTransaction> transactions) => record([
        for (final t in transactions)
          BankHistoryEntry.of(t, BankOutcome.discarded, at: _now()),
      ]);

  /// Tira da caixa de entrada e grava no histórico.
  Future<void> record(List<BankHistoryEntry> entries) async {
    if (entries.isEmpty) return;
    final ids = {for (final e in entries) e.transactionId};
    _pending = _pending.where((t) => !ids.contains(t.id)).toList();
    for (final e in entries) {
      _history[e.transactionId] = e;
    }
    notifyListeners();
    await _store.save(entries);
  }

  /// Tira do histórico e devolve à caixa de entrada. Apagar o lançamento,
  /// se houver, fica com quem chama (é ele que tem os providers).
  Future<void> restore(BankHistoryEntry entry) async {
    _history.remove(entry.transactionId);
    final t = entry.transaction;
    if (t != null && !_pending.any((p) => p.id == t.id)) {
      _pending = [..._pending, t]..sort((a, b) => b.date.compareTo(a.date));
    }
    notifyListeners();
    await _store.remove([entry.transactionId]);
  }

  /// Descarta o cache — chamar quando credenciais ou bancos mudam.
  void reset() {
    _pending = const [];
    _items = const {};
    _lastSync = null;
    _lastError = null;
    notifyListeners();
  }
}
