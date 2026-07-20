import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'models/entry_origin.dart';
import 'models/expense.dart';
import 'models/income.dart';
import 'models/parsed_transaction.dart';
import 'providers/category_state.dart';
import 'providers/expense_state.dart';
import 'providers/income_state.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/expense_screen/expense_screen.dart';
import 'screens/income_screen/income_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/auto_import_service.dart';
import 'services/capture_settings.dart';
import 'services/firebase_config.dart';
import 'services/firestore_service.dart';
import 'services/notification_capture_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await initializeDateFormatting('pt_BR', null);
  await StorageService().init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surfaceColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await NotificationService().init();
  await NotificationService().requestPermissions();

  FirestoreService? firestoreService;
  if (FirebaseConfig.isConfigured) {
    await Firebase.initializeApp(options: FirebaseConfig.options);
    firestoreService = FirestoreService();
  }

  runApp(MainApp(firestoreService: firestoreService));
}

class MainApp extends StatelessWidget {
  final FirestoreService? firestoreService;

  const MainApp({super.key, this.firestoreService});

  Future<void> _syncFromCloud(
    ExpenseState expenseState,
    IncomeState incomeState,
    CategoryState categoryState,
    FirestoreService firestoreService,
  ) async {
    await firestoreService.syncFromFirestore(StorageService());
    await Future.wait([
      expenseState.load(),
      incomeState.load(),
      categoryState.load(),
    ]);
  }

  Widget _buildProviders({required Widget child}) {
    final expenseState = ExpenseState(firestoreService)..load();
    final incomeState = IncomeState(firestoreService)..load();
    final categoryState = CategoryState(expenseState, firestoreService)..load();

    if (firestoreService != null) {
      _syncFromCloud(expenseState, incomeState, categoryState, firestoreService!);
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ExpenseState>.value(value: expenseState),
        ChangeNotifierProvider<IncomeState>.value(value: incomeState),
        ChangeNotifierProvider<CategoryState>.value(value: categoryState),
      ],
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (firestoreService == null) {
      return _buildProviders(
        child: _buildMaterialApp(home: const MainScreen()),
      );
    }

    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildMaterialApp(
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.data == null) {
          return _buildMaterialApp(home: const LoginScreen());
        }

        return _buildProviders(
          child: _buildMaterialApp(home: const MainScreen()),
        );
      },
    );
  }

  MaterialApp _buildMaterialApp({required Widget home}) {
    return MaterialApp(
      title: 'Gestão Financeira',
      theme: AppTheme.darkTheme(),
      debugShowCheckedModeBanner: false,
      home: home,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    DashboardScreen(),
    IncomeScreen(),
    ExpenseScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Drena a fila ao abrir: a captura acontece com o app fechado, então o que
    // chegou desde a última sessão só é processado agora.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAutoImport());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _runAutoImport();
  }

  /// Importa automaticamente o que veio de regra confirmada, se o usuário
  /// ativou a opção. Provisório e não reconhecido ficam para revisão manual.
  Future<void> _runAutoImport() async {
    final capture = NotificationCaptureService();
    if (!capture.isSupported || !mounted) return;

    // Referências capturadas antes dos awaits para não usar context depois.
    final expenseState = context.read<ExpenseState>();
    final incomeState = context.read<IncomeState>();
    final categoryState = context.read<CategoryState>();

    if (!await CaptureSettings().isAutoImportEnabled()) return;

    final queue = await capture.peekQueue();
    if (queue.isEmpty) return;

    final plan = const AutoImportService().plan(queue);
    if (plan.isEmpty) return;

    final configured = await CaptureSettings().defaultCategory();
    final category = _resolveAutoCategory(configured, categoryState);

    for (final t in plan.toCreate) {
      if (t.type == TransactionType.income) {
        await incomeState.addIncome(
          Income(
            amount: t.amount,
            title: t.description.isEmpty ? 'Recebimento' : t.description,
            receiveDate: t.postedAt,
            origin: EntryOrigin.automatic,
          ),
        );
      } else {
        await expenseState.addExpense(
          Expense(
            amount: t.amount,
            title: t.description.isEmpty ? 'Compra' : t.description,
            category: category,
            dueDate: t.postedAt,
            paymentMethod: t.paymentMethod,
            origin: EntryOrigin.automatic,
          ),
        );
      }
    }

    await capture.consume(plan.toConsume);
  }

  /// Categoria dos gastos automáticos: a configurada, senão a primeira
  /// existente, senão um rótulo neutro que ainda é válido.
  String _resolveAutoCategory(String? configured, CategoryState categories) {
    if (configured != null && configured.isNotEmpty) return configured;
    if (categories.categories.isNotEmpty) {
      return categories.categories.first.name;
    }
    return 'Outros';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Painel',
            ),
            NavigationDestination(
              icon: Icon(Icons.savings_outlined),
              selectedIcon: Icon(Icons.savings_rounded),
              label: 'Rendimentos',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Gastos',
            ),
          ],
        ),
      ),
    );
  }
}
