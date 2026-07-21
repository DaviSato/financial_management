import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/category_state.dart';
import 'providers/expense_state.dart';
import 'providers/income_state.dart';
import 'providers/privacy_state.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/expense_screen/expense_screen.dart';
import 'screens/income_screen/income_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'services/auth_service.dart';
import 'services/cloud_config.dart';
import 'services/firebase_config.dart';
import 'services/firestore_service.dart';
import 'services/logo_config.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'utils/platform_capabilities.dart';

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

  // Avisos de vencimento só no mobile: no desktop o agendamento local ainda
  // não está configurado (ver PlatformCapabilities).
  if (PlatformCapabilities.supportsScheduledNotifications) {
    await NotificationService().init();
    await NotificationService().requestPermissions();
  }

  // Config da nuvem: app (SharedPreferences) sobrepõe o .env. Carregada aqui
  // para que FirebaseConfig possa lê-la de forma síncrona no boot.
  await CloudConfig().load();

  // Token do logo.dev, mesmo esquema: app sobrepõe o .env.
  await LogoConfig().load();

  FirestoreService? firestoreService;
  if (FirebaseConfig.isConfigured) {
    try {
      await Firebase.initializeApp(options: FirebaseConfig.options);
      FirebaseConfig.initialized = true;
      firestoreService = FirestoreService();
    } catch (e) {
      // Config inválida não pode travar o app no boot: cai no modo local, de
      // onde dá para corrigir em Perfil > Conectar à nuvem.
      debugPrint('Falha ao inicializar o Firebase: $e');
      FirebaseConfig.initialized = false;
      firestoreService = null;
    }
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
        ChangeNotifierProvider<PrivacyState>(create: (_) => PrivacyState()..load()),
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

/// Um destino de navegação, compartilhado entre a barra inferior (mobile) e o
/// rail lateral (desktop/janela larga).
class _NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  /// Acima desta largura a navegação vira um rail lateral em vez da barra
  /// inferior — o layout de celular estica feio numa janela de desktop.
  static const _railBreakpoint = 720.0;

  /// Bem largo: o rail ganha rótulos ao lado dos ícones.
  static const _extendedRailBreakpoint = 1100.0;

  static const List<Widget> _screens = [
    DashboardScreen(),
    IncomeScreen(),
    ExpenseScreen(),
    ProfileScreen(),
  ];

  static const List<_NavDestination> _destinations = [
    _NavDestination(
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
      label: 'Painel',
    ),
    _NavDestination(
      icon: Icons.savings_outlined,
      selectedIcon: Icons.savings_rounded,
      label: 'Rendimentos',
    ),
    _NavDestination(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      label: 'Gastos',
    ),
    _NavDestination(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Perfil',
    ),
  ];

  void _onSelect(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= _railBreakpoint;
        return useRail ? _buildWideLayout(constraints) : _buildNarrowLayout();
      },
    );
  }

  Widget _buildNarrowLayout() {
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
          onDestinationSelected: _onSelect,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout(BoxConstraints constraints) {
    final extended = constraints.maxWidth >= _extendedRailBreakpoint;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onSelect,
            extended: extended,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.06),
          ),
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
    );
  }
}
