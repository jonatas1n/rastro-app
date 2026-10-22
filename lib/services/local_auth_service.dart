import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

class LocalAuthService {
  LocalAuthService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  static const _unlockReason =
      'Confirme sua identidade para acessar o Rastro';

  Future<bool> isDeviceAuthAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e, st) {
      debugPrint('LocalAuthService.isDeviceAuthAvailable: $e\n$st');
      return false;
    }
  }

  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Desbloquear Rastro',
            biometricHint: '',
            cancelButton: 'Cancelar',
          ),
        ],
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (e, st) {
      debugPrint('LocalAuthService.authenticate: $e\n$st');
      return false;
    }
  }

  Future<bool> unlockApp() => authenticate(reason: _unlockReason);
}
