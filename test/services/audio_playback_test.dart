import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prontuario_tcc/services/audio_relato_service.dart';

void main() {
  test('limparRecursosReproducao apaga temporarios de playback', () async {
    final dir = await Directory.systemTemp.createTemp('audio_playback_');
    final arq1 = File('${dir.path}/pb_1.m4a');
    final arq2 = File('${dir.path}/pb_2.m4a');
    await arq1.writeAsBytes([1, 2, 3]);
    await arq2.writeAsBytes([4, 5, 6]);

    AudioRelatoService.limparRecursosReproducao();
    AudioRelatoService.registrarPlaybackTemporario(arq1.path);
    AudioRelatoService.registrarPlaybackTemporario(arq2.path);
    expect(AudioRelatoService.tamanhoTemporariosPlayback, 2);

    await AudioRelatoService.limparRecursosReproducao();

    expect(AudioRelatoService.tamanhoTemporariosPlayback, 0);
    expect(arq1.existsSync(), isFalse);
    expect(arq2.existsSync(), isFalse);

    await dir.delete(recursive: true);
  });
}
