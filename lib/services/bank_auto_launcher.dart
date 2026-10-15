import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_suggestion.dart';
import '../models/bank_history_entry.dart';
import '../models/bank_origin.dart';
import '../models/bank_transaction.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../models/recurrence.dart';
import '../providers/category_state.dart';
import '../providers/expense_state.dart';
import '../providers/income_state.dart';
import 'bank_sync_service.dart';
import 'gemini_client.dart';
import 'gemini_config.dart';

typedef GeminiClientFactory = GeminiClient Function(String apiKey);

/// Manda para o Gemini as movimentações que chegaram do banco e aplica o que
/// ele classificar com confiança alta: lança o gasto/rendimento, marca como
/// pago o recorrente que a movimentação está pagando, ou descarta o que não é
/// gasto nem rendimento. O resto fica na caixa de entrada com a sugestão.
///
/// Cada movimentação vai para a IA uma vez só: a resposta fica guardada por
/// id (também a das aplicadas, para que "desfazer" não a lance de novo).
class BankAutoLauncher {
  BankAutoLauncher({
    required this.expenses,
    required this.incomes,
    required this.categories,
    GeminiConfig? config,
    GeminiClientFactory? clientFactory,
    DateTime Function()? now,
  })  : _config = config ?? GeminiConfig(),
        _clientFactory = clientFactory ?? _defaultClient,
        _now = now ?? DateTime.now;

  final ExpenseState expenses;
  final IncomeState incomes;
  final CategoryState categories;
  final GeminiConfig _config;
  final GeminiClientFactory _clientFactory;
  final DateTime Function() _now;

  static GeminiClient _defaultClient(String key) => GeminiClient(apiKey: key);

  /// A partir de quanto a decisão da IA é aplicada sem perguntar.
  static const threshold = 0.8;

  /// Movimentações por chamada; um lote maior arrisca a resposta truncar.
  static const _batchSize = 40;

  /// Sugestões guardadas por mais que a janela da Pluggy não servem mais.
  static const _keep = Duration(days: 75);

  static const _prefsKey = 'ai_suggestions';

  Map<String, AiSuggestion>? _suggestions;

  bool get isEnabled => _config.isEnabled;

  /// Sugestão da IA para a movimentação, se ela já passou por lá.
  AiSuggestion? suggestionFor(String transactionId) =>
      _suggestions?[transactionId];

  /// Classifica as pendentes que ainda não foram para a IA e aplica o que
  /// tem confiança alta. Devolve a mensagem de erro, ou null.
  Future<String?> run(BankSyncService sync) async {
    if (!_config.isEnabled) return null;
    final suggestions = await _load();
    final fresh =
        sync.pending.where((t) => !suggestions.containsKey(t.id)).toList();
    if (fresh.isEmpty) return null;

    final client = _clientFactory(_config.apiKey);
    final results = <AiSuggestion>[];
    String? error;
    try {
      for (var i = 0; i < fresh.length; i += _batchSize) {
        final batch = fresh.sublist(
          i,
          i + _batchSize > fresh.length ? fresh.length : i + _batchSize,
        );
        results.addAll(
          await client.classify(
            transactions: batch,
            categories: [for (final c in categories.categories) c.name],
            expenses: _knownExpenses(batch),
            incomes: _knownIncomes(batch),
            now: _now(),
          ),
        );
      }
    } on GeminiException catch (e) {
      error = e.isQuota
          ? 'Limite gratuito do Gemini atingido. O que faltou vai na próxima '
              'sincronização.'
          : e.isUnauthorized
              ? 'Chave do Gemini recusada. Confira em Perfil > Bancos '
                  'conectados.'
              : e.statusCode == null
                  ? 'Sem conexão com o Gemini.'
                  : 'Erro do Gemini: ${e.message}';
    } finally {
      client.close();
    }

    // O que voltou antes de um erro (lotes anteriores) não se perde.
    for (final s in results) {
      suggestions[s.transactionId] = s;
    }
    await _save();

    final byId = {for (final t in fresh) t.id: t};
    final applied = <BankHistoryEntry>[];
    for (final s in results) {
      if (s.confidence < threshold) continue;
      final entry = await apply(byId[s.transactionId]!, s, auto: true);
      if (entry != null) applied.add(entry);
    }
    await sync.record(applied);
    return error;
  }

  /// Executa a sugestão: cria o lançamento ou marca o existente como pago.
  /// Devolve o registro para o histórico, ou null se a sugestão não serve
  /// (categoria que não existe, gasto vinculado que sumiu...).
  Future<BankHistoryEntry?> apply(
    BankTransaction t,
    AiSuggestion s, {
    bool auto = false,
  }) async {
    final at = _now();
    final isIncome = t.type == TransactionType.income;
    switch (s.action) {
      case AiAction.expense:
        if (isIncome) return null;
        final category = _category(s.category);
        if (category == null) return null;
        final installment = t.isInstallment;
        // Parcela 2+ sem o parcelamento cadastrado: lançar só ela daria um
        // parcelamento pela metade.
        if (installment && t.installmentNumber != 1) return null;
        final expense = Expense(
          amount: installment ? t.amount * t.totalInstallments! : t.amount,
          title: s.title ?? t.description,
          category: category,
          dueDate: t.date,
          paymentMethod: t.paymentMethod,
          recurrenceType:
              installment ? RecurrenceType.installment : RecurrenceType.once,
          durationMonths: installment ? t.totalInstallments : null,
          // O dinheiro já saiu: nasce pago.
          paidByMonth: {
            installment ? _monthKey(t.date) : 'once': t.date,
          },
          bankOrigin: _origin(t),
        );
        await expenses.addExpense(expense);
        return BankHistoryEntry.of(
          t,
          BankOutcome.launched,
          at: at,
          launchedId: expense.id,
          auto: auto,
        );

      case AiAction.income:
        if (!isIncome) return null;
        final income = Income(
          amount: t.amount,
          title: s.title ?? t.description,
          receiveDate: t.date,
          bankOrigin: _origin(t),
        );
        await incomes.addIncome(income);
        return BankHistoryEntry.of(
          t,
          BankOutcome.launched,
          at: at,
          launchedId: income.id,
          auto: auto,
        );

      case AiAction.payExpense:
        if (isIncome) return null;
        final expense =
            expenses.expenses.where((e) => e.id == s.matchId).firstOrNull;
        if (expense == null) return null;
        if (!expense.isPaidForMonth(t.date)) {
          await expenses.updateExpense(
            expense.copyWith(
              paidByMonth: {
                ...expense.paidByMonth,
                _paidKey(expense, t.date): t.date,
              },
            ),
          );
        }
        return BankHistoryEntry.of(
          t,
          BankOutcome.matched,
          at: at,
          launchedId: expense.id,
          auto: auto,
        );

      case AiAction.matchIncome:
        if (!isIncome) return null;
        final exists = incomes.incomes.any((i) => i.id == s.matchId);
        if (!exists) return null;
        return BankHistoryEntry.of(
          t,
          BankOutcome.matched,
          at: at,
          launchedId: s.matchId,
          auto: auto,
        );

      case AiAction.ignore:
        return BankHistoryEntry.of(
          t,
          BankOutcome.discarded,
          at: at,
          auto: auto,
        );
    }
  }

  /// Desfaz o "pago" que [apply] marcou ao vincular a movimentação a um gasto
  /// existente. Só mexe se a marca é a dela (data da movimentação) — uma
  /// marcação feita à mão fica.
  Future<void> unmatch(BankHistoryEntry entry) async {
    final t = entry.transaction;
    if (t == null || t.type == TransactionType.income) return;
    final expense =
        expenses.expenses.where((e) => e.id == entry.launchedId).firstOrNull;
    if (expense == null) return;
    final key = _paidKey(expense, t.date);
    if (expense.paidByMonth[key] != t.date) return;
    await expenses.updateExpense(
      expense.copyWith(
        paidByMonth: Map.of(expense.paidByMonth)..remove(key),
      ),
    );
  }

  /// O que pode estar sendo pago: recorrentes e parcelas do mês de cada
  /// movimentação e do anterior (conta de 30/09 paga em 01/10), e gastos
  /// avulsos em aberto.
  List<AiKnownEntry> _knownExpenses(List<BankTransaction> batch) {
    final result = <String, AiKnownEntry>{};
    for (final month in _months(batch)) {
      for (final e in expenses.getExpensesListForMonth(month)) {
        final paid = e.isPaidForMonth(month);
        if (e.recurrenceType == RecurrenceType.once && paid) continue;
        result['${e.id}|${_monthKey(e.dueDate)}'] = AiKnownEntry(
          id: e.id,
          title: e.title,
          amount: e.amount,
          date: e.dueDate,
          paid: paid,
        );
      }
    }
    return result.values.toList();
  }

  List<AiKnownEntry> _knownIncomes(List<BankTransaction> batch) {
    final result = <String, AiKnownEntry>{};
    for (final month in _months(batch)) {
      for (final i in incomes.getIncomesListForMonth(month)) {
        result['${i.id}|${_monthKey(i.receiveDate)}'] = AiKnownEntry(
          id: i.id,
          title: i.title,
          amount: i.amount,
          date: i.receiveDate,
        );
      }
    }
    return result.values.toList();
  }

  static Set<DateTime> _months(List<BankTransaction> batch) => {
        for (final t in batch) ...[
          DateTime(t.date.year, t.date.month),
          DateTime(t.date.year, t.date.month - 1),
        ],
      };

  /// Nome da categoria como cadastrado, ignorando maiúsculas.
  String? _category(String? name) {
    if (name == null) return null;
    final wanted = name.trim().toLowerCase();
    for (final c in categories.categories) {
      if (c.name.toLowerCase() == wanted) return c.name;
    }
    return null;
  }

  static BankOrigin _origin(BankTransaction t) =>
      BankOrigin(name: t.institution, logoDomain: t.institutionLogo);

  static String _paidKey(Expense e, DateTime date) =>
      e.recurrenceType == RecurrenceType.once ? 'once' : _monthKey(date);

  static String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  /// Descarta o cache; a próxima leitura volta ao disco (a tarefa em
  /// background pode ter gravado sugestões novas).
  void forget() => _suggestions = null;

  Future<Map<String, AiSuggestion>> _load() async {
    if (_suggestions != null) return _suggestions!;
    final result = <String, AiSuggestion>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final cutoff = _now().subtract(_keep);
        for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries) {
          final s = AiSuggestion.fromJson(
            e.key,
            Map<String, dynamic>.from(e.value as Map),
          );
          if (s != null && s.createdAt.isAfter(cutoff)) result[e.key] = s;
        }
      }
    } catch (e) {
      // Cache corrompido: no pior caso, as pendentes vão de novo para a IA.
      debugPrint('Falha ao ler as sugestões da IA: $e');
    }
    return _suggestions = result;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode({
        for (final s in _suggestions!.values) s.transactionId: s.toJson(),
      }),
    );
  }
}
