import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/captured_notification.dart';
import '../../models/expense.dart';
import '../../models/income.dart';
import '../../models/parsed_transaction.dart';
import '../../providers/expense_state.dart';
import '../../providers/income_state.dart';
import '../../services/notification_capture_service.dart';
import '../../services/transaction_parser.dart';
import '../../theme/app_theme.dart';
import '../../widgets/expense_form.dart';
import '../../widgets/income_form.dart';
import '../../widgets/swipe_delete_background.dart';
import '../../widgets/swipeable_card_frame.dart';
import 'notification_capture_config_screen.dart';
import 'widgets/captured_notification_card.dart';
import 'widgets/permission_banner.dart';

/// Uma entrada da lista: uma notificação (com seu parse) e os arquivos da fila
/// que ela representa — duplicatas da mesma transação são agrupadas para que
/// apagar ou lançar remova todas de uma vez.
class _CaptureGroup {
  final CapturedNotification representative;
  final ParsedTransaction? parsed;
  final List<CapturedNotification> members;

  const _CaptureGroup(this.representative, this.parsed, this.members);
}

/// Captura notificações de apps de banco e as apresenta para revisão manual.
///
/// Cada notificação capturada é interpretada pelo parser e vira um lançamento
/// só quando o usuário confirma pelo formulário — nunca automaticamente, para
/// não duplicar gastos que já existem (recorrentes, parcelados).
class NotificationCaptureScreen extends StatefulWidget {
  const NotificationCaptureScreen({super.key});

  @override
  State<NotificationCaptureScreen> createState() =>
      _NotificationCaptureScreenState();
}

class _NotificationCaptureScreenState extends State<NotificationCaptureScreen>
    with WidgetsBindingObserver {
  final _service = NotificationCaptureService();
  final _parser = const TransactionParser();

  bool _loading = true;
  bool _permissionGranted = false;
  List<CapturedNotification> _captured = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // O usuário concede a permissão fora do app e volta; e a fila só cresce
    // enquanto estamos em background. Os dois casos pedem releitura ao voltar.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final granted = await _service.isPermissionGranted();
    final captured = await _service.peekQueue();

    if (!mounted) return;
    setState(() {
      _permissionGranted = granted;
      _captured = captured;
      _loading = false;
    });
  }

  Future<void> _clearQueue() async {
    await _service.clearQueue();
    await _refresh();
  }

  /// Agrupa as capturas: as reconhecidas pela mesma transação (dedupeKey)
  /// viram um item só; as não reconhecidas ficam individuais.
  List<_CaptureGroup> _groups() {
    final byKey = <String, List<CapturedNotification>>{};
    final order = <String>[];
    for (final notification in _captured) {
      final parsed = _parser.parse(notification);
      final key = parsed?.dedupeKey ?? 'raw:${notification.filePath}';
      if (!byKey.containsKey(key)) {
        byKey[key] = [];
        order.add(key);
      }
      byKey[key]!.add(notification);
    }
    return [
      for (final key in order)
        _CaptureGroup(
          byKey[key]!.first,
          _parser.parse(byKey[key]!.first),
          byKey[key]!,
        ),
    ];
  }

  Future<void> _deleteGroup(_CaptureGroup group) async {
    await _service.consume(group.members);
    await _refresh();
  }

  /// Abre o formulário pré-preenchido a partir do que o parser extraiu. Ao
  /// salvar, o lançamento entra pelo caminho normal do provider e as capturas
  /// do grupo saem da fila. A categoria continua sendo pedida no formulário.
  void _launch(_CaptureGroup group) {
    final parsed = group.parsed;
    final isIncome = parsed?.type == TransactionType.income;

    void consume() {
      _service.consume(group.members);
      _refresh();
    }

    if (isIncome) {
      final draft = Income(
        amount: parsed!.amount,
        title: parsed.description,
        receiveDate: parsed.postedAt,
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IncomeFormDialog(
            income: draft,
            isEditing: false,
            onSave: (income) {
              context.read<IncomeState>().addIncome(income);
              consume();
            },
          ),
        ),
      );
      return;
    }

    // Gasto — inclui o caso "não reconhecida", que abre o formulário vazio.
    final draft = parsed == null
        ? null
        : Expense(
            amount: parsed.amount,
            title: parsed.description,
            category: '',
            dueDate: parsed.postedAt,
            paymentMethod: parsed.paymentMethod,
          );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseFormDialog(
          expense: draft,
          isEditing: false,
          onSave: (expense) {
            context.read<ExpenseState>().addExpense(expense);
            consume();
          },
        ),
      ),
    );
  }

  void _openConfig() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationCaptureConfigScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_service.isSupported) return const _UnsupportedPlatform();

    final groups = _groups();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações capturadas'),
        actions: [
          IconButton(
            tooltip: 'Apps monitorados',
            onPressed: _openConfig,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  if (!_permissionGranted)
                    PermissionBanner(
                      onOpenSettings: () async {
                        await _service.openSettings();
                      },
                    ),
                  if (groups.isEmpty)
                    const _EmptyQueue()
                  else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                      child: Row(
                        children: [
                          Text(
                            'CAPTURADAS · ${groups.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6E6E78),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _clearQueue,
                            icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                            label: const Text('Limpar tudo'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.expenseColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final group in groups)
                      SwipeableCardFrame(
                        child: Dismissible(
                          key: ValueKey(group.representative.filePath),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => _deleteGroup(group),
                          background: const SwipeDeleteBackground(),
                          child: CapturedNotificationCard(
                            notification: group.representative,
                            parsed: group.parsed,
                            onLaunch: () => _launch(group),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

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
            'Nada capturado ainda',
            style: TextStyle(fontSize: 13, color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Notificações dos apps marcados aparecem aqui, mesmo com o '
            'Gestor fechado.',
            style: TextStyle(fontSize: 12, color: Colors.white38),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _UnsupportedPlatform extends StatelessWidget {
  const _UnsupportedPlatform();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Captura de notificações')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.phonelink_erase_outlined,
                size: 40,
                color: AppTheme.expenseColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Disponível apenas no Android',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'O iOS não oferece API para ler notificações de outros apps. '
                'Não é uma permissão difícil de obter — a capacidade não '
                'existe no sistema.',
                style: TextStyle(fontSize: 12, color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
