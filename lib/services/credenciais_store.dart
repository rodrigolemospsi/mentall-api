import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistência durável das credenciais do servidor (usuário/senha),
/// independente do box `app_config` do Hive.
///
/// O `app_config` pode ser limpo (ex.: reconfiguração ou chave ainda não
/// carregada no boot). As credenciais precisam sobreviver a isso para permitir
/// a renovação silenciosa do JWT — sem elas, `forceReauthenticate` enviaria
/// usuário/senha em branco e tomaria um 401 confuso.
abstract class CredenciaisStore {
  Future<void> salvar(String username, String password);
  Future<(String?, String?)> carregar();
  Future<void> limpar();
}

/// Implementação real: cofre do sistema (Keychain no iOS / Keystore no
/// Android) via `flutter_secure_storage`, sem exigir biometria.
///
/// Usa as MESMAS chaves que `AuthService.salvarCredenciaisServidor` para que os
/// dois caminhos compartilhem uma única fonte de verdade.
class SecureCredenciaisStore implements CredenciaisStore {
  static const String _userKey = 'server_username';
  static const String _passKey = 'server_password';

  final FlutterSecureStorage _storage;

  SecureCredenciaisStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  @override
  Future<void> salvar(String username, String password) async {
    await _storage.write(key: _userKey, value: username);
    await _storage.write(key: _passKey, value: password);
  }

  @override
  Future<(String?, String?)> carregar() async {
    final username = await _storage.read(key: _userKey);
    final password = await _storage.read(key: _passKey);
    return (username, password);
  }

  @override
  Future<void> limpar() async {
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _passKey);
  }
}
