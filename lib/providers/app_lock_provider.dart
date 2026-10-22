import 'package:flutter/foundation.dart';
import '../services/app_preferences.dart';
import '../services/local_auth_service.dart';

class AppLockProvider extends ChangeNotifier {
  AppLockProvider({LocalAuthService? authService})
      : _authService = authService ?? LocalAuthService();

  final LocalAuthService _authService;

  bool _initialized = false;
  bool _enabled = false;
  bool _locked = false;
  bool _deviceAuthAvailable = false;
  bool _authenticating = false;

  bool get initialized => _initialized;
  bool get enabled => _enabled;
  bool get locked => _locked;
  bool get deviceAuthAvailable => _deviceAuthAvailable;
  bool get authenticating => _authenticating;

  Future<void> init() async {
    _deviceAuthAvailable = await _authService.isDeviceAuthAvailable();
    _enabled = await AppPreferences.appLockEnabled;
    if (_enabled) {
      _locked = true;
    }
    _initialized = true;
    notifyListeners();
  }

  void lockIfEnabled() {
    if (!_enabled) return;
    if (_locked) return;
    _locked = true;
    notifyListeners();
  }

  Future<bool> tryUnlock() async {
    if (!_enabled) {
      _locked = false;
      notifyListeners();
      return true;
    }
    if (_authenticating) return false;

    _authenticating = true;
    notifyListeners();

    final ok = await _authService.unlockApp();

    _authenticating = false;
    if (ok) {
      _locked = false;
    }
    notifyListeners();
    return ok;
  }

  /// Ativa ou desativa o bloqueio. Exige autenticação quando [value] muda o estado.
  Future<AppLockToggleResult> setEnabled(bool value) async {
    if (value == _enabled) {
      return AppLockToggleResult.success;
    }

    if (value && !_deviceAuthAvailable) {
      return AppLockToggleResult.noDeviceCredentials;
    }

    _authenticating = true;
    notifyListeners();

    final ok = await _authService.unlockApp();
    _authenticating = false;

    if (!ok) {
      notifyListeners();
      return AppLockToggleResult.authFailed;
    }

    _enabled = value;
    await AppPreferences.setAppLockEnabled(value);
    if (value) {
      _locked = false;
    } else {
      _locked = false;
    }
    notifyListeners();
    return AppLockToggleResult.success;
  }

  Future<void> refreshDeviceAuthAvailability() async {
    _deviceAuthAvailable = await _authService.isDeviceAuthAvailable();
    if (!_deviceAuthAvailable && _enabled) {
      _enabled = false;
      _locked = false;
      await AppPreferences.setAppLockEnabled(false);
    }
    notifyListeners();
  }
}

enum AppLockToggleResult {
  success,
  authFailed,
  noDeviceCredentials,
}
