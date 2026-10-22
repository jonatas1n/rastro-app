import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_client.dart';
import 'database_service.dart';

/// IDs das ações disponíveis na notificação de cada gasto detectado.
const String kTxMarkEssentialActionId = 'tx_mark_essential';
const String kTxNotExpenseActionId = 'tx_not_expense';

typedef TransactionActionRefresh = Future<void> Function();

/// Trata os toques nos botões da notificação de gasto.
///
/// As ações podem chegar com o app aberto (foreground) ou com ele em segundo
/// plano/encerrado (background isolate). Em ambos os casos a alteração é
/// aplicada direto no SQLite; quando o app está aberto, a UI também é atualizada.
class NotificationActionService {
  static TransactionActionRefresh? _onForegroundRefresh;

  /// Registrado pelo escopo autenticado para recarregar a UI após uma ação.
  static void setForegroundRefreshHandler(TransactionActionRefresh? handler) {
    _onForegroundRefresh = handler;
  }

  /// Chamado pelo plugin quando o app está em foreground.
  static Future<void> handleForeground(NotificationResponse response) async {
    final handled = await applyAction(response);
    if (!handled) return;
    final refresh = _onForegroundRefresh;
    if (refresh == null) return;
    await refresh();
  }

  /// Aplica a ação no banco local. Retorna `true` se algo foi alterado.
  static Future<bool> applyAction(NotificationResponse response) async {
    final localId = response.payload;
    if (localId == null || localId.isEmpty) return false;

    final actionId = response.actionId;
    final db = DatabaseService();

    if (actionId == kTxMarkEssentialActionId) {
      await db.updateEssential(localId, true);
      await _pushEssential(localId);
      return true;
    }

    if (actionId == kTxNotExpenseActionId) {
      await db.delete(localId);
      return true;
    }

    return false;
  }

  static Future<void> _pushEssential(String localId) async {
    try {
      await ApiClient().updateTransaction(localId, isEssential: true);
    } catch (e) {
      debugPrint('NotificationActionService: falha ao propagar essencial: $e');
      await DatabaseService().addPendingUpdate(localId, {'is_essential': true});
    }
  }
}

/// Handler executado em isolate separado quando o app não está em foreground.
@pragma('vm:entry-point')
void notificationActionBackgroundHandler(NotificationResponse response) async {
  DartPluginRegistrant.ensureInitialized();
  await NotificationActionService.applyAction(response);
}
