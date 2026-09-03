import 'dart:convert';

/// No ambiente web, o backup automático em arquivo não é realizado (usa o
/// fluxo de download/compartilhamento existente). Retorna sempre `null`.
Future<String?> salvarBackupArquivo(
  String conteudo,
  String nomeArquivo, {
  String? diretorio,
}) async =>
    null;

/// Sem seletor de pasta no navegador; não implementado.
Future<String?> escolherPastaBackup() async => null;

/// Converte um [Map] em JSON legível (idêntico ao io).
String? jsonParaTexto(Map<String, dynamic> dados) {
  try {
    return jsonEncode(dados);
  } catch (_) {
    return null;
  }
}
