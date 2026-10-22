import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';

import '../models/transaction.dart';
import 'api_client.dart';
import 'notification_blocklist.dart';
import 'notification_pipeline.dart';

typedef NotificationTransactionHandler = Future<void> Function(Transaction tx);

/// Deve bater com `applicationId` em `android/app/build.gradle.kts`.
const kRastroAndroidPackage = 'com.jotadevsol.rastro';

/// Callback no isolate de background — precisa de [pragma] no APK release.
/// Encaminha para [NotificationsListener.receivePort] (nome oficial do plugin).
@pragma('vm:entry-point')
void rastroNotificationListenerCallback(NotificationEvent evt) {
  final send = IsolateNameServer.lookupPortByName(
    NotificationsListener.SEND_PORT_NAME,
  );
  send?.send(evt);
}

/// Gerencia a escuta de notificações do sistema.
class NotificationService {
  static bool _uiListening = false;
  static bool _pluginInitialized = false;
  static NotificationTransactionHandler? _onTransaction;
  static ApiClient? _api;

  static void bindApi(ApiClient api) {
    _api = api;
  }

  static void setTransactionHandler(NotificationTransactionHandler? handler) {
    _onTransaction = handler;
  }

  /// Registra ponte UI ↔ background e inicia o serviço Android.
  static Future<void> init() async {
    if (!_pluginInitialized) {
      await NotificationsListener.initialize(
        callbackHandle: rastroNotificationListenerCallback,
      );
      _pluginInitialized = true;
    } else {
      await NotificationsListener.registerEventHandle(
        rastroNotificationListenerCallback,
      );
    }
    _ensureUiPort();

    final granted = await hasPermission;
    if (granted) {
      await _ensureBackgroundService();
    }
  }

  /// Reaplica ponte após retomar o app (evita perder eventos).
  static Future<void> reconnect() async {
    _ensureUiPort();
    if (_pluginInitialized) {
      await NotificationsListener.registerEventHandle(
        rastroNotificationListenerCallback,
      );
    } else {
      await init();
      return;
    }
    if (await hasPermission) {
      await _ensureBackgroundService();
    }
  }

  /// Persiste `foreground: false` e reinicia o listener para cancelar FGS antigo.
  ///
  /// O plugin guarda [PromoteServiceConfig] em SharedPreferences e, no
  /// `onCreate` do serviço Android, promove de novo se `foreground == true`.
  /// Se o serviço já estiver rodando com config antiga, pular `startService`
  /// deixa a notificação "Escutando…" visível indefinidamente.
  static Future<void> _ensureBackgroundService() async {
    try {
      await NotificationsListener.startService(foreground: false);
    } catch (e, st) {
      debugPrint(
        'NotificationService: falha ao iniciar serviço em background: $e\n$st',
      );
      return;
    }
    try {
      await NotificationsListener.demoteToBackground();
    } catch (e, st) {
      debugPrint(
        'NotificationService: demoteToBackground ignorado ou indisponível: $e\n$st',
      );
    }
  }

  static void _ensureUiPort() {
    if (_uiListening) return;
    NotificationsListener.receivePort!.listen(_onEvent);
    _uiListening = true;
  }

  static Future<bool> get hasPermission async =>
      await NotificationsListener.hasPermission ?? false;

  static Future<bool> get isServiceRunning async =>
      await NotificationsListener.isRunning ?? false;

  static Future<bool> requestPermission() async {
    await NotificationsListener.openPermissionSettings();
    return await hasPermission;
  }

  static Future<void> stopService() async {
    await NotificationsListener.stopService();
  }

  static void _onEvent(dynamic event) async {
    if (event is! NotificationEvent) {
      debugPrint('NotificationService: evento ignorado (${event.runtimeType})');
      return;
    }
    await _handleNotificationEvent(event);
  }

  static Future<void> _handleNotificationEvent(NotificationEvent event) async {
    final title = event.title ?? '';
    final body = event.text ?? '';
    final packageName = event.packageName;

    if (_isOwnAppNotification(packageName)) {
      return;
    }
    if (NotificationBlocklist.instance.isBlocked(packageName)) {
      return;
    }

    final tx = await NotificationPipeline(api: _api).resolve(
      title: title,
      body: body,
      packageName: packageName,
    );
    if (tx == null) return;

    final handler = _onTransaction;
    if (handler == null) return;

    try {
      await handler(tx);
    } catch (e, st) {
      debugPrint('NotificationService: falha ao registrar gasto: $e\n$st');
    }
  }

  static bool _isOwnAppNotification(String? packageName) {
    if (packageName == null || packageName.isEmpty) return false;
    return packageName == kRastroAndroidPackage;
  }
}
