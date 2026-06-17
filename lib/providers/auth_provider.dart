import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../services/sync_queue.dart';

enum AuthState { unknown, unauthenticated, authenticated }

class AuthProvider extends ChangeNotifier {
  final ApiClient _api;

  AuthState _state = AuthState.unknown;
  String    _name  = '';
  String?   _error;

  AuthState get state => _state;
  String    get name  => _name;
  String?   get error => _error;
  bool      get isAuthenticated => _state == AuthState.authenticated;

  AuthProvider({required ApiClient api}) : _api = api;

  Future<void> init() async {
    final stored = await AuthStorage.load();
    if (stored != null) {
      _name  = stored.name;
      _state = AuthState.authenticated;
    } else {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> register(String email, String password, String name) async {
    _error = null;
    try {
      final result = await _api.register(email, password, name);
      await AuthStorage.save(result);
      _name  = result.name;
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Falha de conexão com a API';
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _error = null;
    try {
      final result = await _api.login(email, password);
      await AuthStorage.save(result);
      _name  = result.name;
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Falha de conexão com a API';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await AuthStorage.clear();
    _state = AuthState.unauthenticated;
    _name  = '';
    notifyListeners();
  }
}
