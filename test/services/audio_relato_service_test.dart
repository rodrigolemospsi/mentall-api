import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prontuario_tcc/services/audio_relato_service.dart';

void main() {
  test('excluirArquivoAudioFisico remove o arquivo fisico', () async {
    final dir = await Directory.systemTemp.createTemp('audio_excluir_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final file = File('${dir.path}/relato.m4a');
    await file.writeAsBytes([1, 2, 3, 4]);

    await AudioRelatoService.excluirArquivoAudioFisico(file.path);

    expect(await file.exists(), isFalse);
  });

  test('excluirArquivoAudioFisico nao lanca para caminho inexistente',
      () async {
    await AudioRelatoService.excluirArquivoAudioFisico(
        '/caminho/que/nao/existe_xyz.m4a');
    // Nao deve lancar.
  });
}
