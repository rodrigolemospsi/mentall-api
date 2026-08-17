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

  /// Migra todos os campos criptografados legados (formato 2:CBC) para o formato atual (3:GCM).
  /// Deve ser chamado após o app ser desbloqueado (encryption.configurado == true).
  /// Retorna o número de campos migrados.
  Future<int> migrarCamposLegados({
    required Future<List<dynamic>> Function() listarTodos,
    required Future<void> Function(dynamic item) salvar,
    required List<String> Function(dynamic item) camposCriptografados,
    required dynamic Function(dynamic item, Map<String, String> novosValores) criarAtualizado,
  }) async {
    final enc = encryption;
    if (enc == null || !enc.configurado) return 0;

    int migrados = 0;
    final todos = await listarTodos();

    for (final item in todos) {
      final campos = camposCriptografados(item);
      final novosValores = <String, String>{};
      bool temMudanca = false;

      for (final campo in campos) {
        final valorAtual = (item as dynamic).$get(campo) as String?;
        if (valorAtual != null && valorAtual.startsWith('2:')) {
          final migrado = enc.migrarParaGcm(valorAtual);
          if (migrado != valorAtual) {
            novosValores[campo] = migrado;
            temMudanca = true;
          }
        }
      }

      if (temMudanca) {
        final atualizado = criarAtualizado(item, novosValores);
        await salvar(atualizado);
        migrados += novosValores.length;
      }
    }

    return migrados;
  }
}
