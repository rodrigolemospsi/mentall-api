import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Salva um arquivo de backup em um diretório.
///
/// - Se [diretorio] for vazio, usa o diretório de documentos do app.
/// - Retorna o caminho completo do arquivo salvo, ou `null` em erro.
Future<String?> salvarBackupArquivo(
  String conteudo,
  String nomeArquivo, {
  String? diretorio,
}) async {
  try {
    final pasta = (diretorio != null && diretorio.isNotEmpty)
        ? await Directory(diretorio).create(recursive: true)
        : await getApplicationDocumentsDirectory();
    final arquivo = File(
      '${pasta.path}${Platform.pathSeparator}$nomeArquivo',
    );
    await arquivo.writeAsString(conteudo);
    return arquivo.path;
  } catch (_) {
    return null;
  }
}

/// Abre um seletor de pasta para o usuário escolher onde salvar o backup.
/// Retorna o caminho da pasta, ou `null` se cancelado/indisponível.
Future<String?> escolherPastaBackup() async {
  try {
    final caminho = await FilePicker.platform.getDirectoryPath();
    return (caminho != null && caminho.isNotEmpty) ? caminho : null;
  } catch (_) {
    return null;
  }
}

/// Converte um [Map] em JSON legível (usado para exibir o conteúdo do backup).
String? jsonParaTexto(Map<String, dynamic> dados) {
  try {
    return jsonEncode(dados);
  } catch (_) {
    return null;
  }
}
