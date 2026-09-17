import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:prontuario_tcc/services/audio_relato_service.dart';

void main() {
  test('limparCacheAudio esvazia o cache de audio descriptografado',
      () async {
    final dir = await Directory.systemTemp.createTemp('audio_cache_');
    final arquivo = File('${dir.path}/relato_test.m4a');
    await arquivo.writeAsBytes(utf8.encode('audio_bruto'));

    AudioRelatoService.limparCacheAudio();
    expect(AudioRelatoService.tamanhoCacheAudio, 0);

    final bytes = await AudioRelatoService.lerAudioDescriptografado(arquivo.path);
    expect(bytes, isNotEmpty);
    expect(AudioRelatoService.tamanhoCacheAudio, 1);

    AudioRelatoService.limparCacheAudio();
    expect(AudioRelatoService.tamanhoCacheAudio, 0);

    await dir.delete(recursive: true);
  });
}
