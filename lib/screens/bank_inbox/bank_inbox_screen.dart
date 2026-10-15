import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/ai_suggestion.dart';
import '../../models/bank_history_entry.dart';
import '../../models/bank_origin.dart';
import '../../models/bank_transaction.dart';
import '../../models/expense.dart';
import '../../models/income.dart';
import '../../models/recurrence.dart';
import '../../providers/category_state.dart';
import '../../providers/expense_state.dart';
import '../../providers/income_state.dart';
import '../../services/bank_sync_service.dart';
import '../../services/pluggy_config.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/expense_form.dart';
import '../../widgets/income_form.dart';
import '../../widgets/swipe_delete_background.dart';
import '../profile/pluggy_config_screen.dart';
import 'widgets/bank_history_tile.dart';
import 'widgets/bank_transaction_card.dart';
import 'widgets/bank_update_card.dart';

/// Movimentações dos bancos conectados via Pluggy: o que precisa de atenção
/// (ainda não lançado nem descartado) no topo e, abaixo, o histórico de tudo
/// que chegou e do que foi feito com cada coisa.
///
/// Cada movimentação vira lançamento só quando o usuário confirma pelo
/// formulário (a categoria continua obrigatória). Deslizar descarta. Pelo
/// histórico dá para abrir o lançamento ou desfazer.
class BankInboxScreen extends StatefulWidget {
  const BankInboxScreen({super.key});

  @override
  State<BankInboxScreen> createState() => _BankInboxScreenState();
}

class _BankInboxScreenState extends State<BankInboxScreen> {
  final _sync = BankSyncService();

  /// Filtros do histórico; null = todos.
  BankOutcome? _outcomeFilter;
  String? _bankFilter;
  bool _aiOnly = false;

  /// Sincronização pedida pelo usuário (tentar de novo, voltar da
  /// configuração). A que roda ao abrir a tela é silenciosa: os dados já
  /// estão na tela e só mudam se a Pluggy trouxer algo novo.
  bool _manualSync = false;

  @override
  void initState() {
    super.initState();
    _sync.addListener(_onChanged);
    _sync.sync();
  }

  @override
  void dispose() {
    _sync.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openConfig() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PluggyConfigScreen()),
    );
    // Conexões podem ter mudado: busca de novo mesmo dentro do intervalo.
    await _retry();
  }

  Future<void> _retry() async {
    if (!mounted) return;
    setState(() => _manualSync = true);
    try {
      await _sync.sync(force: true);
    } finally {
      if (mounted) setState(() => _manualSync = false);
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar tudo?'),
        content: const Text(
          'As movimentações vão para o histórico como descartadas. Dá para '
          'devolvê-las depois, uma a uma.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _sync.discard(_sync.pending);
  }

  AiSuggestion? _suggestion(BankTransaction t) =>
      _sync.autoLauncher?.suggestionFor(t.id);

  /// Card da pendente. Com sugestão da IA que não seja lançar algo novo
  /// (marcar um recorrente como pago, confirmar um recebimento, ignorar), o
  /// botão principal aplica a sugestão e o formulário fica como alternativa.
  Widget _pendingCard(BankTransaction t) {
    final s = _suggestion(t);
    if (s == null) {
      return BankTransactionCard(transaction: t, onLaunch: () => _launch(t));
    }

    final percent = '${(s.confidence * 100).round()}%';
    final isExpense = t.type == TransactionType.expense;
    final formLabel = isExpense ? 'Lançar como gasto' : 'Lançar como renda';
    switch (s.action) {
      case AiAction.payExpense || AiAction.matchIncome:
        final match = s.action == AiAction.payExpense
            ? context
                .read<ExpenseState>()
                .expenses
                .where((e) => e.id == s.matchId)
                .firstOrNull
                ?.title
            : context
                .read<IncomeState>()
                .incomes
                .where((i) => i.id == s.matchId)
                .firstOrNull
                ?.title;
        if (match == null) break;
        return BankTransactionCard(
          transaction: t,
          aiHint: s.action == AiAction.payExpense
              ? 'Parece o pagamento de "$match" · $percent'
              : 'Parece o recebimento de "$match" · $percent',
          actionLabel:
              s.action == AiAction.payExpense ? 'Marcar paga' : 'Confirmar',
          onLaunch: () => _applySuggestion(t, s),
          secondaryLabel: formLabel,
          onSecondary: () => _launch(t),
        );
      case AiAction.ignore:
        return BankTransactionCard(
          transaction: t,
          aiHint: 'Sugere ignorar${s.reason != null ? ': ${s.reason}' : ''}'
              ' · $percent',
          actionLabel: 'Descartar',
          onLaunch: () => _sync.discard([t]),
          secondaryLabel: formLabel,
          onSecondary: () => _launch(t),
        );
      case AiAction.expense || AiAction.income:
        break;
    }
    return BankTransactionCard(
      transaction: t,
      aiHint: [
        if (s.category != null) s.category!,
        if (s.title != null) s.title!,
        percent,
      ].join(' · '),
      onLaunch: () => _launch(t),
    );
  }

  Future<void> _applySuggestion(BankTransaction t, AiSuggestion s) async {
    final entry = await _sync.autoLauncher?.apply(t, s);
    if (entry == null) {
      if (mounted) _snack('Não deu para aplicar a sugestão. Lance pelo formulário.');
      return;
    }
    await _sync.record([entry]);
  }

  /// Abre o formulário pré-preenchido (com nome e categoria sugeridos pela
  /// IA, quando há). Ao salvar, o lançamento entra pelo caminho normal do
  /// provider e a movimentação vai para o histórico.
  void _launch(BankTransaction t) {
    final s = _suggestion(t);
    final title = s?.title ?? t.description;
    if (t.type == TransactionType.income) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IncomeFormDialog(
            income: Income(
              amount: t.amount,
              title: title,
              receiveDate: t.date,
              bankOrigin: _origin(t),
            ),
            isEditing: false,
            onSave: (income) {
              context.read<IncomeState>().addIncome(income);
              _sync.launch(t, launchedId: income.id);
            },
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseFormDialog(
          expense: _expenseDraft(t, title: title, category: _category(s)),
          isEditing: false,
          onSave: (expense) {
            context.read<ExpenseState>().addExpense(expense);
            _sync.launch(t, launchedId: expense.id);
          },
        ),
      ),
    );
  }

  /// Na primeira parcela de uma compra parcelada, sugere o parcelamento
  /// inteiro (o app guarda o total e divide por mês). As parcelas seguintes
  /// chegam como movimentações próprias; essas o usuário descarta.
  static Expense _expenseDraft(
    BankTransaction t, {
    required String title,
    required String category,
  }) {
    if (t.isInstallment && t.installmentNumber == 1) {
      return Expense(
        amount: t.amount * t.totalInstallments!,
        title: title,
        category: category,
        dueDate: t.date,
        paymentMethod: t.paymentMethod,
        recurrenceType: RecurrenceType.installment,
        durationMonths: t.totalInstallments,
        bankOrigin: _origin(t),
      );
    }
    return Expense(
      amount: t.amount,
      title: title,
      category: category,
      dueDate: t.date,
      paymentMethod: t.paymentMethod,
      bankOrigin: _origin(t),
    );
  }

  static BankOrigin _origin(BankTransaction t) =>
      BankOrigin(name: t.institution, logoDomain: t.institutionLogo);

  /// Categoria sugerida pela IA, se existe; vazia deixa o formulário pedir.
  String _category(AiSuggestion? s) {
    final name = s?.category?.toLowerCase();
    if (name == null) return '';
    for (final c in context.read<CategoryState>().categories) {
      if (c.name.toLowerCase() == name) return c.name;
    }
    return '';
  }

  // ─── Histórico ────────────────────────────────────────────────────────────

  /// O gasto ou rendimento criado a partir da movimentação, se ainda existe.
  Object? _launched(BankHistoryEntry entry) {
    final id = entry.launchedId;
    if (id == null) return null;
    if (entry.transaction!.type == TransactionType.income) {
      return context
          .read<IncomeState>()
          .incomes
          .where((i) => i.id == id)
          .firstOrNull;
    }
    return context
        .read<ExpenseState>()
        .expenses
        .where((e) => e.id == id)
        .firstOrNull;
  }

  void _openLaunched(Object launched) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => launched is Expense
            ? ExpenseFormDialog(
                expense: launched,
                onSave: context.read<ExpenseState>().updateExpense,
              )
            : IncomeFormDialog(
                income: launched as Income,
                onSave: context.read<IncomeState>().updateIncome,
              ),
      ),
    );
  }

  Future<void> _showEntry(BankHistoryEntry entry) async {
    final launched = _launched(entry);
    final action = await showModalBottomSheet<_EntryAction>(
      context: context,
      showDragHandle: true,
      // Sem isso o sheet fica limitado a ~metade da tela e os detalhes de uma
      // movimentação vinculada estouram embaixo, em cima dos botões.
      isScrollControlled: true,
      builder: (_) => _EntrySheet(entry: entry, launched: launched),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _EntryAction.open:
        _openLaunched(launched!);
      case _EntryAction.restore:
        final matched = entry.outcome == BankOutcome.matched;
        if (launched != null && !await _confirmUndo(launched, matched)) {
          return;
        }
        if (!mounted) return;
        if (matched) {
          // O gasto/rendimento já existia: só tira o "pago" que a
          // conciliação marcou.
          await _sync.autoLauncher?.unmatch(entry);
        } else if (launched is Expense) {
          await context.read<ExpenseState>().deleteExpense(launched.id);
        } else if (launched is Income) {
          await context.read<IncomeState>().deleteIncome(launched.id);
        }
        await _sync.restore(entry);
        if (mounted) _snack('Movimentação de volta às pendentes.');
    }
  }

  Future<bool> _confirmUndo(Object launched, bool matched) async {
    final title =
        launched is Expense ? launched.title : (launched as Income).title;
    final kind = launched is Expense ? 'O gasto' : 'O rendimento';
    final String message;
    if (!matched) {
      message = '$kind "$title" será apagado e a movimentação volta para as '
          'pendentes.';
    } else if (launched is Expense) {
      message = '"$title" deixa de constar como pago neste mês (se foi esta '
          'movimentação que marcou) e ela volta para as pendentes.';
    } else {
      message = 'A movimentação deixa de ser o recebimento de "$title" e volta '
          'para as pendentes.';
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(matched ? 'Desfazer vínculo?' : 'Desfazer lançamento?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.expenseColor,
            ),
            child: const Text('Desfazer'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pending = _sync.pending;
    final history = _sync.history;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimentações do banco'),
        actions: [
          IconButton(
            tooltip: 'Bancos conectados',
            onPressed: _openConfig,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: !_sync.isConfigured && history.isEmpty
          ? _NotConfigured(onConfigure: _openConfig)
          // Sem "puxar para atualizar": o Meu Pluggy só atualiza uma vez por
          // dia, então buscar de novo não traz nada. Ao abrir a tela já
          // sincroniza; depois de uma falha, o aviso oferece tentar de novo.
          : CustomScrollView(
              slivers: [
                SliverList.list(children: _header(pending, history)),
                ..._historySlivers(history),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  List<Widget> _header(
    List<BankTransaction> pending,
    List<BankHistoryEntry> history,
  ) {
    return [
      // Barra só quando o usuário pediu ou ainda não há nada para mostrar.
      if (_sync.isSyncing &&
          (_manualSync || (pending.isEmpty && history.isEmpty)))
        const LinearProgressIndicator(),
      if (_sync.lastError != null)
        _ErrorBanner(message: _sync.lastError!, onRetry: _retry),
      if (_sync.autoError != null)
        _ErrorBanner(
          message: _sync.autoError!,
          color: aiColor,
          onRetry: _retry,
        ),
      if (_sync.items.isNotEmpty) ...[
        const _SectionLabel('ÚLTIMA ATUALIZAÇÃO'),
        BankUpdateCard(
          banks: [
            for (final c in PluggyConfig().connections)
              if (_sync.items[c.itemId] case final item?)
                (connection: c, item: item),
          ],
        ),
      ],
      if (pending.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 2),
          child: Row(
            children: [
              Text(
                'PENDENTES',
                style: _SectionLabel.style.copyWith(
                  color: const Color(0xFFB0883B),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFB0883B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${pending.length}',
                  style: _SectionLabel.style.copyWith(
                    color: const Color(0xFFB0883B),
                    letterSpacing: 0,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearAll,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white54,
                  textStyle: const TextStyle(fontSize: 12),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Descartar tudo'),
              ),
            ],
          ),
        ),
        // Um bloco só, com divisórias: a moldura recorta o swipe nos cantos.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                for (final (i, t) in pending.indexed) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 62,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  Dismissible(
                    key: ValueKey(t.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _sync.discard([t]),
                    background: const SwipeDeleteBackground(),
                    child: _pendingCard(t),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
      if (pending.isEmpty && history.isEmpty && !_sync.isSyncing)
        const _EmptyInbox(),
    ];
  }

  void _clearFilters() {
    _outcomeFilter = null;
    _bankFilter = null;
    _aiOnly = false;
  }

  /// Filtros do histórico num sheet. Aplicam na hora: a lista atrás já
  /// mostra o resultado.
  Future<void> _openFilters(
    List<BankHistoryEntry> history,
    Map<String, String?> logos,
    List<String> banks,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) {
          void update(VoidCallback change) {
            setState(change);
            setSheet(() {});
          }

          final bankFilter = banks.contains(_bankFilter) ? _bankFilter : null;
          bool matchesBank(BankHistoryEntry e) =>
              bankFilter == null || e.transaction!.institution == bankFilter;
          bool matchesOutcome(BankHistoryEntry e) =>
              _outcomeFilter == null || e.outcome == _outcomeFilter;
          bool matchesAi(BankHistoryEntry e) => !_aiOnly || e.auto;

          // Cada contador respeita os outros filtros: mostra quanto sobra ao
          // escolher a opção.
          final byBank = history.where(matchesBank).where(matchesAi);
          final byOutcome = history.where(matchesOutcome).where(matchesAi);
          final aiCount = history
              .where((e) => e.auto && matchesBank(e) && matchesOutcome(e))
              .length;
          final hasFilter =
              _outcomeFilter != null || _aiOnly || bankFilter != null;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
                    child: Row(
                      children: [
                        const Text(
                          'Filtrar histórico',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (hasFilter)
                          TextButton(
                            onPressed: () => update(_clearFilters),
                            child: const Text('Limpar'),
                          ),
                      ],
                    ),
                  ),
                  const _SectionLabel('RESULTADO'),
                  for (final o in [
                    null,
                    BankOutcome.launched,
                    BankOutcome.discarded,
                    BankOutcome.matched,
                  ])
                    // "Já cadastradas" só vira filtro quando existe.
                    if (o != BankOutcome.matched ||
                        history.any((e) => e.outcome == o))
                      _FilterOption(
                        leading: Icon(
                          o?.icon ?? Icons.inbox_rounded,
                          size: 20,
                          color: o?.color ?? Colors.white60,
                        ),
                        label: o?.filterLabel ?? 'Todas',
                        subtitle: o?.description,
                        count: o == null
                            ? byBank.length
                            : byBank.where((e) => e.outcome == o).length,
                        selected: _outcomeFilter == o,
                        onTap: () => update(() => _outcomeFilter = o),
                      ),
                  if (history.any((e) => e.auto)) ...[
                    const _SectionLabel('QUEM FEZ'),
                    _FilterOption(
                      leading: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 20,
                        color: aiColor,
                      ),
                      label: 'Só o que a IA fez',
                      count: aiCount,
                      selected: _aiOnly,
                      color: aiColor,
                      toggle: true,
                      onTap: () => update(() => _aiOnly = !_aiOnly),
                    ),
                  ],
                  if (banks.length > 1) ...[
                    const _SectionLabel('BANCO'),
                    _FilterOption(
                      leading: const Icon(
                        Icons.account_balance_outlined,
                        size: 20,
                        color: Colors.white60,
                      ),
                      label: 'Todos',
                      count: byOutcome.length,
                      selected: bankFilter == null,
                      onTap: () => update(() => _bankFilter = null),
                    ),
                    for (final b in banks)
                      _FilterOption(
                        leading: BankLogo(logoDomain: logos[b], size: 24),
                        label: b,
                        count: byOutcome
                            .where((e) => e.transaction!.institution == b)
                            .length,
                        selected: bankFilter == b,
                        onTap: () => update(() => _bankFilter = b),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _historySlivers(List<BankHistoryEntry> history) {
    if (history.isEmpty) return const [];

    // Bancos: os conectados (mesmo sem nada no histórico ainda) mais os que
    // só aparecem no histórico (conexão removida ou renomeada).
    final logos = <String, String?>{};
    for (final c in PluggyConfig().connections) {
      if (c.institution.isNotEmpty) logos[c.institution] = c.logoDomain;
    }
    for (final e in history) {
      final t = e.transaction!;
      if (t.institution.isEmpty) continue;
      logos[t.institution] ??= t.institutionLogo;
    }
    final banks = logos.keys.toList()..sort();
    // O banco filtrado pode ter sumido (conexão removida, histórico expirou).
    final bankFilter = banks.contains(_bankFilter) ? _bankFilter : null;

    final filtered = history
        .where((e) =>
            (bankFilter == null || e.transaction!.institution == bankFilter) &&
            (_outcomeFilter == null || e.outcome == _outcomeFilter) &&
            (!_aiOnly || e.auto))
        .toList();
    final active = [
      if (_outcomeFilter case final o?) o.filterLabel,
      if (_aiOnly) 'Pela IA',
      ?bankFilter,
    ];

    // Linhas achatadas: cabeçalho do dia (DateTime) seguido das entradas.
    final rows = <Object>[];
    DateTime? day;
    for (final e in filtered) {
      final d = e.transaction!.date;
      final key = DateTime(d.year, d.month, d.day);
      if (key != day) rows.add(day = key);
      rows.add(e);
    }

    return [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  const Text('HISTÓRICO', style: _SectionLabel.style),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _openFilters(history, logos, banks),
                    icon: Badge(
                      isLabelVisible: active.isNotEmpty,
                      label: Text('${active.length}'),
                      backgroundColor: AppTheme.primaryColor,
                      child: const Icon(Icons.tune_rounded, size: 18),
                    ),
                    label: const Text('Filtrar'),
                    style: TextButton.styleFrom(
                      foregroundColor: active.isEmpty
                          ? Colors.white60
                          : AppTheme.primaryColor,
                      textStyle: const TextStyle(fontSize: 12),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            if (active.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${active.join(' · ')} — ${filtered.length} de '
                        '${history.length}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(_clearFilters),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white54,
                        textStyle: const TextStyle(fontSize: 12),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Limpar'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      if (rows.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              bankFilter != null &&
                      !history
                          .any((e) => e.transaction!.institution == bankFilter)
                  ? 'Nada de $bankFilter no histórico ainda. Aparece aqui '
                      'depois de lançar ou descartar.'
                  : 'Nada com esse filtro.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white38),
            ),
          ),
        )
      else
        SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (context, i) => switch (rows[i]) {
            final DateTime d => _DayHeader(day: d),
            final BankHistoryEntry e => BankHistoryTile(
                entry: e,
                onTap: () => _showEntry(e),
              ),
            _ => const SizedBox.shrink(),
          },
        ),
    ];
  }
}

enum _EntryAction { open, restore }

/// Detalhes de uma movimentação do histórico e o que dá para fazer com ela.
class _EntrySheet extends StatelessWidget {
  const _EntrySheet({required this.entry, required this.launched});

  final BankHistoryEntry entry;

  /// Gasto/rendimento vinculado, se ainda existe.
  final Object? launched;

  @override
  Widget build(BuildContext context) {
    final t = entry.transaction!;
    final isExpense = t.type == TransactionType.expense;
    final date = DateFormat("d 'de' MMMM 'de' y", 'pt_BR').format(t.date);
    final handledAt = entry.handledAt;
    final matched = entry.outcome == BankOutcome.matched;
    final lostLaunch =
        (entry.outcome == BankOutcome.launched || matched) &&
            launched == null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BankLogo(logoDomain: t.institutionLogo, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.description.isEmpty ? 'Sem descrição' : t.description,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${isExpense ? '−' : '+'} '
                        '${CurrencyFormatter.format(t.amount)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isExpense
                              ? AppTheme.expenseColor
                              : AppTheme.incomColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detail('Data', date),
            _detail(
              'Origem',
              [t.institution, t.accountLabel]
                  .where((p) => p.isNotEmpty)
                  .join(' · '),
            ),
            if (t.paymentMethod != null)
              _detail('Forma', t.paymentMethod!.label),
            if (t.isInstallment)
              _detail(
                'Parcela',
                '${t.installmentNumber} de ${t.totalInstallments}',
              ),
            if (t.pending) _detail('Situação no banco', 'Pendente'),
            _detail(
              'Resultado',
              [
                // "Paga pela IA" soaria como se a IA tivesse pago; o que ela
                // (ou o usuário) fez foi lançar. O vínculo aparece abaixo.
                matched ? 'Lançada' : outcomeLabel(entry),
                if (entry.auto) 'pela IA',
                if (handledAt != null)
                  'em ${DateFormat("dd/MM 'às' HH:mm", 'pt_BR').format(handledAt)}',
              ].join(' '),
              color: entry.auto ? aiColor : entry.outcome.color,
            ),
            if (matched && launched != null)
              _detail(
                isExpense ? 'Pagamento de' : 'Recebimento de',
                launched is Expense
                    ? (launched as Expense).title
                    : (launched as Income).title,
              ),
            if (lostLaunch)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  matched
                      ? 'O lançamento vinculado a esta movimentação foi apagado.'
                      : 'O lançamento criado a partir desta movimentação foi '
                          'apagado.',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ),
            const SizedBox(height: 20),
            if (launched != null) ...[
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, _EntryAction.open),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(isExpense ? 'Abrir gasto' : 'Abrir rendimento'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, _EntryAction.restore),
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: Text(matched ? 'Desfazer vínculo' : 'Desfazer lançamento'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.expenseColor,
                ),
              ),
            ] else
              FilledButton.tonalIcon(
                onPressed: () => Navigator.pop(context, _EntryAction.restore),
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: const Text('Voltar para pendentes'),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _detail(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6E6E78)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  static const style = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Color(0xFF6E6E78),
    letterSpacing: 0.8,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(text, style: style),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    final label = switch (diff) {
      0 => 'Hoje',
      1 => 'Ontem',
      _ => toBeginningOfSentenceCase(
          DateFormat(
            day.year == now.year ? "EEEE, d 'de' MMM" : "d 'de' MMM 'de' y",
            'pt_BR',
          ).format(day),
        ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
        ),
      ),
    );
  }
}

/// Uma opção do sheet de filtros: ícone, rótulo, quantas sobram e a marca
/// de selecionada (rádio, ou caixa quando [toggle]).
class _FilterOption extends StatelessWidget {
  const _FilterOption({
    required this.leading,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.color,
    this.toggle = false,
  });

  final Widget leading;
  final String label;
  final String? subtitle;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  /// Cor da marca de selecionada; null = cor principal.
  final Color? color;
  final bool toggle;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppTheme.primaryColor;
    final IconData mark = toggle
        ? (selected
            ? Icons.check_box_rounded
            : Icons.check_box_outline_blank_rounded)
        : (selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            SizedBox(width: 28, child: Center(child: leading)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: count == 0 && !selected ? Colors.white38 : null,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white38,
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              mark,
              size: 20,
              color: selected ? tint : Colors.white24,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 32,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
          const Text(
            'Nenhuma movimentação ainda',
            style: TextStyle(fontSize: 13, color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'O que chegar dos bancos conectados aparece aqui. O Meu Pluggy '
            'atualiza uma vez por dia.',
            style: TextStyle(fontSize: 12, color: Colors.white38),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    this.color = AppTheme.expenseColor,
    this.onRetry,
  });
  final String message;
  final Color color;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 12)),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: color,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Tentar de novo'),
            ),
        ],
      ),
    );
  }
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured({required this.onConfigure});
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_outlined,
              size: 40,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum banco conectado',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Conecte seus bancos pelo Meu Pluggy para trazer as '
              'movimentações para cá.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onConfigure,
              child: const Text('Configurar'),
            ),
          ],
        ),
      ),
    );
  }
}
