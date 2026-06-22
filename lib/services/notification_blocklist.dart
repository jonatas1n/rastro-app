import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pacotes Android cujas notificações o Rastro ignora (não registra gasto).
class NotificationBlocklist extends ChangeNotifier {
  NotificationBlocklist._();
  static final instance = NotificationBlocklist._();

  static const _prefsKey = 'notification_blocked_packages';

  final Set<String> _blocked = {};
  bool _loaded = false;

  Set<String> get blocked => Set.unmodifiable(_blocked);
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    _blocked.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          if (e is String && e.isNotEmpty) _blocked.add(e);
        }
      } catch (_) {
        // preferência corrompida — recomeça vazio
      }
    }
    _loaded = true;
    notifyListeners();
  }

  bool isBlocked(String? packageName) {
    if (packageName == null || packageName.isEmpty) return false;
    return _blocked.contains(packageName);
  }

  Future<void> block(String packageName) async {
    if (packageName.isEmpty) return;
    if (!_blocked.add(packageName)) return;
    await _persist();
    notifyListeners();
  }

  Future<void> blockAll(Iterable<String> packageNames) async {
    var changed = false;
    for (final p in packageNames) {
      if (p.isEmpty) continue;
      if (_blocked.add(p)) changed = true;
    }
    if (!changed) return;
    await _persist();
    notifyListeners();
  }

  Future<void> unblock(String packageName) async {
    if (!_blocked.remove(packageName)) return;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _blocked.toList()..sort();
    await prefs.setString(_prefsKey, jsonEncode(list));
  }
}
