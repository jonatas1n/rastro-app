import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';

import '../models/transaction.dart';
import 'local_notification_service.dart';
import 'notification_blocklist.dart';
import 'notification_debug_log.dart';
import 'notification_parser.dart';

typedef NotificationTransactionHandler = Future<void> Function(Transaction tx);

/// Deve bater com `applicationId` em `android/app/build.gradle.kts`.
const kRastroAndroidPackage = 'com.example.rastro';

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
      final running = await isServiceRunning;
      if (running != true) {
        await NotificationsListener.startService(
          title: 'Rastro',
          description: 'Escutando notificações bancárias',
        );
      }
    }

    await _recordDiagnostics('init');
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
    await _recordDiagnostics('reconnect');
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

  static Future<Map<String, bool>> get diagnostics async {
    final portOk = IsolateNameServer.lookupPortByName(
          NotificationsListener.SEND_PORT_NAME,
        ) !=
        null;
    return {
      'pluginInitialized': _pluginInitialized,
      'uiPortRegistered': portOk,
      'uiListening': _uiListening,
      'hasPermission': await hasPermission,
      'serviceRunning': await isServiceRunning,
    };
  }

  static Future<bool> requestPermission() async {
    await NotificationsListener.openPermissionSettings();
    return await hasPermission;
  }

  static Future<void> stopService() async {
    await NotificationsListener.stopService();
  }

  static Future<void> _recordDiagnostics(String reason) async {
    final d = await diagnostics;
    final lines = d.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    NotificationDebugLog.instance.addSystem(
      title: 'Diagnóstico ($reason)',
      body: lines,
    );
  }

  static int _debugSampleIndex = 0;

  static const _debugSamples = [
    (
      packageName: 'com.nu.production',
      title: 'Compra no débito',
      body: 'R\$ 87,30 em SUPERMERCADO DEBUG',
    ),
    (
      packageName: 'com.itau',
      title: 'Compra aprovada',
      body: 'Cartão final 1234 · R\$ 42,50 · PADARIA DEBUG',
    ),
    (
      packageName: 'br.com.bb.android',
      title: 'BB',
      body: 'Compra de R\$ 15,99 aprovada em LOJA DEBUG',
    ),
  ];

  /// Notificação na barra + um evento simulado (sem eco pelo listener).
  static Future<void> triggerDebugTestNotification() async {
    final sample = _debugSamples[
        _debugSampleIndex % _debugSamples.length];
    _debugSampleIndex++;

    final evt = NotificationEvent(
      uniqueId: 'debug-${DateTime.now().millisecondsSinceEpoch}',
      packageName: sample.packageName,
      title: sample.title,
      text: sample.body,
      createAt: DateTime.now(),
    );

    await LocalNotificationService.showDebugTestNotification(
      title: sample.title,
      body: sample.body,
    );

    await _handleNotificationEvent(evt);
  }

  static void _onEvent(dynamic event) async {
    if (event is! NotificationEvent) {
      NotificationDebugLog.instance.addSystem(
        title: 'Evento ignorado',
        body: 'Tipo inesperado: ${event.runtimeType}',
      );
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

    final analysis = NotificationParser.analyze(
      title,
      body,
      packageName: packageName,
    );

    final handlerRegistered = _onTransaction != null;
    bool? handlerSucceeded;
    String? handlerError;

    final parsed = analysis.parsed;
    if (parsed != null && handlerRegistered) {
      final tx = Transaction(
        place: parsed.place,
        amount: parsed.amount,
        category: parsed.category,
        timestamp: DateTime.now(),
        isEssential: true,
        rawNotification: '$title | $body',
      );
      try {
        await _onTransaction!(tx);
        handlerSucceeded = true;
      } catch (e, st) {
        handlerSucceeded = false;
        handlerError = e.toString();
        debugPrint('NotificationService: falha ao registrar gasto: $e\n$st');
      }
    } else if (parsed != null && !handlerRegistered) {
      handlerSucceeded = false;
      handlerError = 'Handler não registrado';
    }

    final checks = analysis.buildChecks(
      title: title,
      body: body,
      packageName: packageName,
      handlerRegistered: handlerRegistered,
      handlerSucceeded: parsed != null ? handlerSucceeded : null,
      handlerError: handlerError,
    );

    NotificationDebugLog.instance.add(
      NotificationDebugEntry(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        at: DateTime.now(),
        packageName: packageName,
        title: title,
        body: body,
        checks: checks,
      ),
    );

    if (parsed == null || handlerSucceeded != true) return;
  }

  static bool _isOwnAppNotification(String? packageName) {
    if (packageName == null || packageName.isEmpty) return false;
    return packageName == kRastroAndroidPackage;
  }
}
