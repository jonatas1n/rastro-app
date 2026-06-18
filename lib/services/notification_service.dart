import 'package:flutter/foundation.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';

import '../models/transaction.dart';
import 'notification_parser.dart';

typedef NotificationTransactionHandler = Future<void> Function(Transaction tx);

/// Gerencia a escuta de notificações do sistema.
///
/// Precisa ser inicializado em main() após WidgetsFlutterBinding.
/// A permissão de NotificationListenerService deve ser concedida
/// pelo usuário em Configurações > Notificações > Acesso a notificações.
class NotificationService {
  static bool _listening = false;
  static NotificationTransactionHandler? _onTransaction;

  /// Registra callback com acesso ao [TransactionProvider] (UI + sync).
  static void setTransactionHandler(NotificationTransactionHandler? handler) {
    _onTransaction = handler;
  }

  /// Inicializa o listener. Chame em main() após WidgetsFlutterBinding.
  static Future<void> init() async {
    await NotificationsListener.initialize();

    if (!_listening) {
      NotificationsListener.receivePort?.listen(_onEvent);
      _listening = true;
    }

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

  static Future<bool> get isServiceRunning async =>
      await NotificationsListener.isRunning ?? false;

  static Future<bool> requestPermission() async {
    await NotificationsListener.openPermissionSettings();
    return await NotificationsListener.hasPermission ?? false;
  }

  static Future<void> stopService() async {
    await NotificationsListener.stopService();
  }

  static Future<void> _onEvent(dynamic event) async {
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

    final handler = _onTransaction;
    if (handler == null) {
      debugPrint(
        'NotificationService: gasto ignorado na UI (handler não registrado) '
        '${parsed.amount} ${parsed.place}',
      );
      return;
    }

    try {
      await handler(tx);
    } catch (e, st) {
      debugPrint('NotificationService: falha ao registrar gasto: $e\n$st');
    }
  }
}
