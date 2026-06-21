import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'providers/auth_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/finance_profile_provider.dart';
import 'providers/messages_provider.dart';
import 'services/api_client.dart';
import 'services/notification_service.dart';
import 'services/local_notification_service.dart';
import 'services/spending_summary_notification.dart';
import 'models/transaction.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/permission_screen.dart';
import 'services/notification_debug_log.dart';
import 'theme/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  await LocalNotificationService.init();
  await NotificationService.init();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:          Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final api = ApiClient();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(api: api)..init()),
        ChangeNotifierProvider(create: (_) => TransactionProvider(api: api)),
        ChangeNotifierProvider(create: (_) => FinanceProfileProvider()..load()),
        ChangeNotifierProvider(create: (_) => MessagesProvider(api: api)),
        ChangeNotifierProvider.value(value: NotificationDebugLog.instance),
      ],
      child: const RastroApp(),
    ),
  );
}

class RastroApp extends StatefulWidget {
  const RastroApp({super.key});

  @override
  State<RastroApp> createState() => _RastroAppState();
}

class _RastroAppState extends State<RastroApp> with WidgetsBindingObserver {
  bool _hasNotifPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
      NotificationService.reconnect();
      SpendingSummaryNotification.refresh();
    }
  }

  Future<void> _checkPermission() async {
    final granted = await NotificationService.hasPermission;
    final running = await NotificationService.isServiceRunning;
    if (granted && !running) {
      await NotificationService.init();
    }
    if (mounted) setState(() => _hasNotifPermission = granted);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rastro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary:   RastroColors.accent,
          secondary: RastroColors.safe,
          surface:   RastroColors.surface,
          error:     RastroColors.danger,
        ),
        scaffoldBackgroundColor: RastroColors.base,
        useMaterial3: true,
      ),
      home: _RootGate(hasNotifPermission: _hasNotifPermission, onPermissionCheck: _checkPermission),
    );
  }
}

class _RootGate extends StatelessWidget {
  final bool hasNotifPermission;
  final VoidCallback onPermissionCheck;

  const _RootGate({required this.hasNotifPermission, required this.onPermissionCheck});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthProvider>().state;

    // Aguarda verificação inicial
    if (authState == AuthState.unknown) {
      return const Scaffold(
        backgroundColor: RastroColors.base,
        body: Center(child: CircularProgressIndicator(color: RastroColors.accent)),
      );
    }

    // Não autenticado → tela de login
    if (authState == AuthState.unauthenticated) {
      return const AuthScreen();
    }

    // Autenticado — handler de gastos ativo em qualquer tela pós-login
    return _AuthenticatedNotificationScope(
      child: !hasNotifPermission
          ? PermissionScreen(onGranted: onPermissionCheck)
          : const _HomeWithSpendingNotification(),
    );
  }
}

class _AuthenticatedNotificationScope extends StatefulWidget {
  final Widget child;
  const _AuthenticatedNotificationScope({required this.child});

  @override
  State<_AuthenticatedNotificationScope> createState() =>
      _AuthenticatedNotificationScopeState();
}

class _AuthenticatedNotificationScopeState
    extends State<_AuthenticatedNotificationScope> {
  @override
  void initState() {
    super.initState();
    NotificationService.setTransactionHandler(_onBankNotification);
  }

  @override
  void dispose() {
    NotificationService.setTransactionHandler(null);
    super.dispose();
  }

  Future<void> _onBankNotification(Transaction tx) async {
    if (!mounted) return;
    final txProv = context.read<TransactionProvider>();
    final finProv = context.read<FinanceProfileProvider>();
    await txProv.addTransaction(tx);
    if (!mounted) return;
    await finProv.refreshSpending();
    if (!mounted) return;
    final raw = tx.rawNotification ?? '';
    if (raw.contains(' DEBUG')) return;
    await LocalNotificationService.showTransactionAlert(tx);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _HomeWithSpendingNotification extends StatefulWidget {
  const _HomeWithSpendingNotification();

  @override
  State<_HomeWithSpendingNotification> createState() =>
      _HomeWithSpendingNotificationState();
}

class _HomeWithSpendingNotificationState
    extends State<_HomeWithSpendingNotification> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SpendingSummaryNotification.startIfEnabled();
    });
  }

  @override
  void dispose() {
    SpendingSummaryNotification.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
