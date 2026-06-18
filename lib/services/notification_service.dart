import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'notification_parser.dart';
import 'database_service.dart';
import 'local_notification_service.dart';
import '../models/transaction.dart';
import 'spending_summary_notification.dart';

/// Gerencia a escuta de notificações do sistema.
///
/// Precisa ser inicializado em main() após o app estar pronto.
/// A permissão de NotificationListenerService deve ser concedida
/// pelo usuário em Configurações > Notificações > Acesso a notificações.
class NotificationService {
  static final _db = DatabaseService();
  static bool _listening = false;

  /// Inicializa o listener. Chame em main() após WidgetsFlutterBinding.
  static Future<void> init() async {
    if (!_listening) {
      NotificationsListener.receivePort?.listen(_onEvent);
      _listening = true;
    }

    await NotificationsListener.initialize();

    final running = await NotificationsListener.isRunning;
    if (running != true) {
      await NotificationsListener.startService(
        title: 'Rastro',
        description: 'Escutando notificações bancárias',
      );
    }
  }

  static Future<bool> get hasPermission async =>
      await NotificationsListener.hasPermission ?? false;

  static Future<bool> requestPermission() async {
    await NotificationsListener.openPermissionSettings();
    return await NotificationsListener.hasPermission ?? false;
  }

  static Future<void> stopService() async {
    await NotificationsListener.stopService();
  }

  static void _onEvent(dynamic event) async {
    if (event is! NotificationEvent) return;

    final title = event.title ?? '';
    final body = event.text ?? '';

    final parsed = NotificationParser.parse(
      title,
      body,
      packageName: event.packageName,
    );
    if (parsed == null) return;

    final tx = Transaction(
      place: parsed.place,
      amount: parsed.amount,
      category: parsed.category,
      timestamp: DateTime.now(),
      isEssential: true,
      rawNotification: '$title | $body',
    );

    await _db.insert(tx);
    await LocalNotificationService.showTransactionAlert(tx);
    await SpendingSummaryNotification.refresh();
  }
}
