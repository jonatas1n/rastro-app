import 'package:flutter/material.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'providers/auth_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/messages_provider.dart';
import 'providers/history_provider.dart';
import 'services/api_client.dart';
import 'services/notification_service.dart';
import 'services/local_notification_service.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/permission_screen.dart';
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
        ChangeNotifierProvider(create: (_) => MessagesProvider(api: api)),
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
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  Future<void> _checkPermission() async {
    final running = await NotificationsListener.isRunning ?? false;
    if (mounted) setState(() => _hasNotifPermission = running);
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

    // Autenticado mas sem permissão de notificações
    if (!hasNotifPermission) {
      return PermissionScreen(onGranted: onPermissionCheck);
    }

    // Tudo pronto
    return const HomeScreen();
  }
}
