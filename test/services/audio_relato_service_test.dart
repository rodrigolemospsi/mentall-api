import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:prontuario_tcc/services/audio_relato_service.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';

void main() {
  late EncryptionService encryption;
  late Directory tempDir;

  setUpAll(() async {
    Hive.init('test/temp_hive/audio_relato');
    await Hive.openBox<String>('encryption_meta');
    tempDir = await Directory.systemTemp.createTemp('mentall_audio_test');
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('encryption_meta');
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    await Hive.box<String>('encryption_meta').clear();
    encryption = EncryptionService();
    EncryptionService.setInstance(encryption);
    await encryption.inicializar();
    await encryption.gerarChave();
  });

  test('descriptografa audio com marcador 3 (GCM)', () async {
    final bytesOriginais = utf8.encode('conteudo de audio de teste');
    final base64Str = base64Encode(bytesOriginais);
    final cifrado = EncryptionService.tryEncrypt(base64Str);

    expect(cifrado, isNotNull);
    expect(cifrado!.startsWith('3:'), isTrue);

    final arquivo = File('${tempDir.path}/audio_cifrado.m4a');
    await arquivo.writeAsString(cifrado);

    final resultado =
        await AudioRelatoService.lerAudioDescriptografado(arquivo.path);

    expect(resultado, orderedEquals(bytesOriginais));
  });

  test('retorna arquivo nao criptografado intacto', () async {
    final bytesOriginais = utf8.encode('audio em texto puro');
    final arquivo = File('${tempDir.path}/audio_limpo.m4a');
    await arquivo.writeAsBytes(bytesOriginais);

    final resultado =
        await AudioRelatoService.lerAudioDescriptografado(arquivo.path);

    expect(resultado, orderedEquals(bytesOriginais));
  });
}
