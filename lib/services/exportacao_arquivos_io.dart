import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Compartilha um ou mais PDFs gerados em memória.
///
/// Grava os bytes em arquivos temporários e abre o share sheet do sistema com
/// todos de uma vez (o usuário escolhe WhatsApp, Drive, e-mail, "Salvar em
/// arquivos" etc.). Retorna os caminhos gravados.
Future<List<String>> compartilharPdfs(
  List<({String nome, Uint8List bytes})> arquivos,
) async {
  final pasta = await getTemporaryDirectory();
  final caminhos = <String>[];
  final xfiles = <XFile>[];
  for (final arquivo in arquivos) {
    final destino = File('${pasta.path}${Platform.pathSeparator}${arquivo.nome}');
    await destino.writeAsBytes(arquivo.bytes, flush: true);
    caminhos.add(destino.path);
    xfiles.add(XFile(destino.path, mimeType: 'application/pdf'));
  }
  await Share.shareXFiles(
    xfiles,
    subject: 'MentAll PRO — exportação de dados',
  );
  return caminhos;
}
