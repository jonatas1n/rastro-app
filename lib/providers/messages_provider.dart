import 'package:flutter/foundation.dart';
import '../services/api_client.dart';

class MessagesProvider extends ChangeNotifier {
  final ApiClient _api;
  List<ContextMessage> _messages = [];
  bool _loading = false;

  List<ContextMessage> get messages => _messages;
  bool                 get loading  => _loading;
  int  get unreadCount => _messages.where((m) => !m.opened).length;

  MessagesProvider({required ApiClient api}) : _api = api;

  Future<void> fetch() async {
    _loading = true;
    notifyListeners();
    try {
      _messages = await _api.fetchMessages();
    } catch (_) {
      // Silencioso — mensagens são um plus, não bloqueiam o app
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> acknowledge(ContextMessage msg) async {
    msg.opened = true;
    notifyListeners();
    try {
      await _api.ackMessage(msg.id);
    } catch (_) {}
  }

  Future<void> acknowledgeAll() async {
    for (final m in _messages) {
      m.opened = true;
    }
    notifyListeners();
    for (final m in _messages) {
      try { await _api.ackMessage(m.id); } catch (_) {}
    }
  }
}
