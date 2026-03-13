import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OffCredentials {
  final String username;
  final String password;

  OffCredentials({required this.username, required this.password});

  bool get isValid => username.isNotEmpty && password.isNotEmpty;
}

final offCredentialsProvider = StateNotifierProvider<OffCredentialsNotifier, OffCredentials?>((ref) {
  return OffCredentialsNotifier();
});

class OffCredentialsNotifier extends StateNotifier<OffCredentials?> {
  static const _storage = FlutterSecureStorage();
  static const _keyUser = 'off_username';
  static const _keyPass = 'off_password';

  OffCredentialsNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final user = await _storage.read(key: _keyUser);
    final pass = await _storage.read(key: _keyPass);
    if (user != null && pass != null) {
      state = OffCredentials(username: user, password: pass);
    }
  }

  Future<void> set(String username, String password) async {
    await _storage.write(key: _keyUser, value: username);
    await _storage.write(key: _keyPass, value: password);
    state = OffCredentials(username: username, password: password);
  }

  Future<void> clear() async {
    await _storage.delete(key: _keyUser);
    await _storage.delete(key: _keyPass);
    state = null;
  }
}
