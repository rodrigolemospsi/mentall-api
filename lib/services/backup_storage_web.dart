import 'dart:convert';

/// Pasta escolhida pelo usuário para os backups automáticos (stub web).
class PastaBackup {
  final String valor;
  final String nome;

  const PastaBackup({required this.valor, required this.nome});
}

/// Erro amigável ao escolher/validar a pasta de backup (stub web).
class PastaBackupException implements Exception {
  final String mensagem;

  const PastaBackupException(this.mensagem);

  @override
  String toString() => mensagem;
}

/// No ambiente web, o backup automático em arquivo não é realizado (usa o
/// fluxo de download/compartilhamento existente). Retorna sempre `null`.
Future<String?> salvarBackupArquivo(
  String conteudo,
  String nomeArquivo, {
  String? diretorio,
}) async => null;

/// Sem seletor de pasta no navegador; não implementado.
Future<PastaBackup?> escolherPastaBackup() async => null;

/// Sem pasta configurável no navegador.
String nomePastaBackupParaExibir(String valor, {String nomeSalvo = ''}) =>
    nomeSalvo.trim().isNotEmpty ? nomeSalvo.trim() : '';

/// Converte um [Map] em JSON legível (idêntico ao io).
String? jsonParaTexto(Map<String, dynamic> dados) {
  try {
    return jsonEncode(dados);
  } catch (_) {
    return null;
  }
}
