import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<String?> selecionarArquivoJson() async {
  final resultado = await FilePicker.platform.pickFiles(
    type: FileType.any,
    withData: true,
  );
  if (resultado == null || resultado.files.isEmpty) return null;

  final arquivo = resultado.files.first;
  if (arquivo.bytes != null) {
    return utf8.decode(arquivo.bytes!);
  }
  final caminho = arquivo.path;
  if (caminho == null) return null;
  return File(caminho).readAsString();
}

Future<void> exportarJson(String conteudo, String nomeArquivo) async {
  final dir = await getTemporaryDirectory();
  final arquivo = File('${dir.path}${Platform.pathSeparator}$nomeArquivo');
  await arquivo.writeAsString(conteudo);
  await Share.shareXFiles(
    [XFile(arquivo.path, mimeType: 'application/json')],
    subject: 'Backup MentAll',
  );
}
