import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../models/bank_history_entry.dart';
import '../providers/category_state.dart';
import '../providers/expense_state.dart';
import '../providers/income_state.dart';
import 'bank_auto_launcher.dart';
import 'bank_sync_service.dart';
import 'cloud_config.dart';
import 'firebase_config.dart';
import 'firestore_service.dart';
import 'gemini_config.dart';
import 'notification_service.dart';
import 'pluggy_config.dart';
import 'storage_service.dart';

/// Sincronização dos bancos com o app fechado (só Android, via WorkManager).
///
/// A cada [frequency] o sistema acorda o app num isolate próprio. Se a
/// próxima atualização da Pluggy ([BankSyncService.nextUpdateAt]) ainda não
/// chegou, ele sai sem tocar na rede; se já, busca na Pluggy, deixa a IA
/// lançar o que tiver confiança alta e avisa por notificação. Quando roda é o
/// Android que decide (economia de bateria, Doze); [frequency] é só o mínimo
/// entre duas execuções.
///
/// Os dois lados (app aberto e tarefa) gravam no mesmo SharedPreferences, mas
/// cada isolate tem o seu cache. Para não sobrescreverem um ao outro:
/// - a tarefa não faz nada enquanto o app está em primeiro plano
///   ([markForeground]) — ele mesmo sincroniza;
/// - ao voltar ao primeiro plano o app relê tudo do disco ([reloadIfRan]).
class BackgroundSync {
  BackgroundSync._();

  static const _taskName = 'bank-sync';

  /// Acordar é barato: fora do horário da Pluggy a tarefa só lê uma chave e
  /// sai. Assim a novidade chega até ~1h depois de a Pluggy atualizar.
  /// Agendar uma tarefa avulsa no horário exato não compensa: se uma
  /// execução morrer antes de agendar a seguinte, a corrente se perde.
  static const frequency = Duration(hours: 1);

  /// Folga depois do horário previsto: a atualização da Pluggy leva alguns
  /// minutos para terminar.
  static const _updateMargin = Duration(minutes: 15);

  /// Quando vale buscar de novo (próxima atualização da Pluggy + folga).
  static const _dueKey = 'bank_bg_due_at';

  /// App em primeiro plano desde quando (ISO 8601); ausente = em background.
  static const _foregroundKey = 'app_foreground_since';

  /// Quando a tarefa rodou pela última vez com sucesso.
  static const _lastRunKey = 'bank_bg_last_run';

  /// Pendentes já avisadas, para não notificar a mesma coisa de novo.
  static const _notifiedKey = 'bank_bg_notified';

  /// Um app morto sem passar por "paused" deixaria a marca para sempre; mais
  /// velha que isto, vale como em background.
  static const _foregroundStale = Duration(hours: 2);

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static DateTime? _seenRun;
  static DateTime? _rememberedSync;

  /// Agenda a tarefa periódica. Chamado a cada boot; o `update` mantém o
  /// horário da que já existe.
  static Future<void> register() async {
    if (!isSupported) return;
    try {
      await Workmanager().initialize(callbackDispatcher);
      await Workmanager().registerPeriodicTask(
        _taskName,
        _taskName,
        frequency: frequency,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
      _seenRun = await _lastRun();
      // Sincronizar com o app aberto também adia a próxima em background.
      final sync = BankSyncService();
      sync.addListener(() => _rememberNextUpdate(sync));
    } catch (e) {
      debugPrint('Falha ao agendar a sincronização em background: $e');
    }
  }

  /// Marca se o app está em primeiro plano, para a tarefa ficar de fora.
  static Future<void> markForeground(bool foreground) async {
    if (!isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    if (foreground) {
      await prefs.setString(_foregroundKey, DateTime.now().toIso8601String());
    } else {
      await prefs.remove(_foregroundKey);
    }
  }

  /// Se a tarefa rodou desde a última vez que o app olhou, relê do disco o
  /// que ela gravou (o cache do SharedPreferences deste isolate está velho) e
  /// devolve true para quem chama recarregar o que tem em memória.
  static Future<bool> reloadIfRan() async {
    if (!isSupported) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final last = await _lastRun();
    if (last == null || last == _seenRun) return false;
    _seenRun = last;
    return true;
  }

  /// Grava quando vale a tarefa buscar de novo, depois de uma sincronização
  /// que deu certo. Sem horário futuro (Pluggy atrasada), apaga: a tarefa
  /// busca a cada execução até a Pluggy atualizar.
  static Future<void> _rememberNextUpdate(BankSyncService sync) async {
    final last = sync.lastSync;
    if (last == null || last == _rememberedSync || sync.lastError != null) {
      return;
    }
    _rememberedSync = last;
    final prefs = await SharedPreferences.getInstance();
    final next = sync.nextUpdateAt;
    if (next != null && next.isAfter(DateTime.now())) {
      await prefs.setString(
        _dueKey,
        next.add(_updateMargin).toIso8601String(),
      );
    } else {
      await prefs.remove(_dueKey);
    }
  }

  /// A Pluggy ainda não atualizou desde a última busca. Um horário a mais de
  /// um dia de distância é tratado como lixo, para nunca travar a tarefa.
  static bool _notDue(SharedPreferences prefs) {
    final raw = prefs.getString(_dueKey);
    final due = raw == null ? null : DateTime.tryParse(raw);
    if (due == null) return false;
    final wait = due.difference(DateTime.now());
    return wait > Duration.zero && wait < const Duration(hours: 26);
  }

  static Future<DateTime?> _lastRun() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastRunKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// O que a tarefa faz, já dentro do isolate de background.
  static Future<bool> _run() async {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    // O engine de background pode ser reaproveitado entre execuções; o app
    // aberto pode ter gravado desde então.
    await prefs.reload();
    if (_notDue(prefs)) return true;

    final since = prefs.getString(_foregroundKey);
    final sinceAt = since == null ? null : DateTime.tryParse(since);
    if (sinceAt != null &&
        DateTime.now().difference(sinceAt) < _foregroundStale) {
      return true;
    }

    await dotenv.load();
    await StorageService().init();
    await CloudConfig().load();
    await PluggyConfig().load();
    await GeminiConfig().load();
    if (!PluggyConfig().isConfigured) return true;

    FirestoreService? firestore;
    if (FirebaseConfig.isConfigured) {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: FirebaseConfig.options);
      }
      FirebaseConfig.initialized = true;
      // Sessão é restaurada do disco; sem usuário logado, o app aberto
      // mostraria a tela de login — não há para quem lançar.
      final user = await FirebaseAuth.instance
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
      if (user == null) return true;
      firestore = FirestoreService();
    }

    try {
      await NotificationService().init();
    } catch (e) {
      debugPrint('Falha ao iniciar notificações em background: $e');
    }

    final expenses = ExpenseState(firestore);
    final incomes = IncomeState(firestore);
    final categories = CategoryState(expenses, firestore);
    await Future.wait([expenses.load(), incomes.load(), categories.load()]);

    final sync = BankSyncService()
      ..autoLauncher = BankAutoLauncher(
        expenses: expenses,
        incomes: incomes,
        categories: categories,
      );
    final start = DateTime.now();
    await sync.sync(force: true);
    await _rememberNextUpdate(sync);

    // Os gravadores do Firestore não são aguardados por quem lança; sem
    // esperar aqui, o isolate pode morrer antes de subirem.
    if (firestore != null) {
      try {
        await FirebaseFirestore.instance
            .waitForPendingWrites()
            .timeout(const Duration(seconds: 30));
      } catch (e) {
        debugPrint('Escritas pendentes no Firestore: $e');
      }
    }

    // Falha da Pluggy (rede, credencial): o WorkManager tenta de novo depois.
    if (sync.lastError != null) return false;

    await prefs.setString(_lastRunKey, DateTime.now().toIso8601String());
    await _notify(prefs, sync, start);
    return true;
  }

  static Future<void> _notify(
    SharedPreferences prefs,
    BankSyncService sync,
    DateTime start,
  ) async {
    final launched = sync.history
        .where((e) =>
            e.auto &&
            e.outcome != BankOutcome.discarded &&
            !(e.handledAt?.isBefore(start) ?? true))
        .length;

    final notified = (prefs.getStringList(_notifiedKey) ?? const []).toSet();
    final pendingIds = [for (final t in sync.pending) t.id];
    final fresh = pendingIds.where((id) => !notified.contains(id)).length;
    await prefs.setStringList(_notifiedKey, pendingIds);

    if (launched == 0 && fresh == 0) return;
    try {
      await NotificationService().showBankSummary(
        launched: launched,
        pending: fresh,
      );
    } catch (e) {
      debugPrint('Falha ao notificar a sincronização: $e');
    }
  }
}

/// Ponto de entrada do isolate de background do WorkManager.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    try {
      return await BackgroundSync._run();
    } catch (e, s) {
      debugPrint('Falha na sincronização em background: $e\n$s');
      return false;
    }
  });
}
