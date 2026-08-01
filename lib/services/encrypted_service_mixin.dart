import 'encryption_service.dart';

mixin EncryptedServiceMixin {
  EncryptionService? get encryption;

  bool get _criptografiaAtiva {
    final enc = encryption;
    return enc != null && enc.configurado;
  }

  String encrypt(String value) {
    final enc = encryption;
    if (enc == null || !enc.configurado || value.isEmpty) return value;
    return enc.criptografar(value);
  }

  String decrypt(String value) {
    final enc = encryption;
    if (enc == null || !enc.configurado || value.isEmpty) return value;
    return enc.descriptografar(value);
  }
}
