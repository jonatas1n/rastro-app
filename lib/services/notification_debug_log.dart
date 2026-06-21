import 'package:flutter/foundation.dart';

class NotificationDebugCheck {
  final String id;
  final String label;
  final bool ok;
  final String? detail;

  const NotificationDebugCheck({
    required this.id,
    required this.label,
    required this.ok,
    this.detail,
  });
}

class NotificationDebugEntry {
  final String id;
  final DateTime at;
  final String? packageName;
  final String title;
  final String body;
  final List<NotificationDebugCheck> checks;
  final bool isSystem;

  NotificationDebugEntry({
    required this.id,
    required this.at,
    required this.packageName,
    required this.title,
    required this.body,
    required this.checks,
    this.isSystem = false,
  });

  int get passedCount => checks.where((c) => c.ok).length;
  int get totalCount => checks.length;

  bool get saved => checks.any((c) => c.id == 'saved' && c.ok);
}

class NotificationDebugLog extends ChangeNotifier {
  NotificationDebugLog._();
  static final instance = NotificationDebugLog._();

  static const _maxEntries = 150;

  final List<NotificationDebugEntry> _entries = [];

  List<NotificationDebugEntry> get entries => List.unmodifiable(_entries);

  void add(NotificationDebugEntry entry) {
    _entries.insert(0, entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(_maxEntries, _entries.length);
    }
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  /// Linha de status (ponte, permissão, serviço).
  void addSystem({required String title, required String body}) {
    add(
      NotificationDebugEntry(
        id: 'sys-${DateTime.now().millisecondsSinceEpoch}',
        at: DateTime.now(),
        packageName: null,
        title: title,
        body: body,
        checks: const [
          NotificationDebugCheck(
            id: 'system',
            label: 'Evento de diagnóstico',
            ok: true,
          ),
        ],
        isSystem: true,
      ),
    );
  }
}
