import 'dart:typed_data';

/// Stub para execução no navegador: a exportação completa em PDF usa arquivos
/// temporários e o share sheet do sistema, indisponíveis no ambiente web.
Future<List<String>> compartilharPdfs(
  List<({String nome, Uint8List bytes})> arquivos,
) async {
  throw UnsupportedError(
    'A exportação completa em PDF está disponível apenas no aplicativo.',
  );
}
