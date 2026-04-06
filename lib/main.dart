import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'screens/dashboard_screen.dart';
import 'services/notification_service.dart';
import 'screens/expense_screen.dart';
import 'screens/income_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/firebase_config.dart';
import 'services/firestore_service.dart';
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

  @override
  Widget build(BuildContext context) {
    // No Firebase: provider above MaterialApp, go straight to MainScreen
    if (firestoreService == null) {
      return ChangeNotifierProvider(
        create: (_) => AppState(),
        child: _buildMaterialApp(home: const MainScreen()),
      );
    }

    // Firebase configured: watch auth state outside MaterialApp so the
    // ChangeNotifierProvider always sits above the Navigator
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

        return ChangeNotifierProvider(
          create: (_) => AppState(firestoreService)..syncFromCloud(),
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

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    DashboardScreen(),
    IncomeScreen(),
    ExpenseScreen(),
  ];

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
