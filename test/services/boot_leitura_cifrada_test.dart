import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/perfil_profissional.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';
import 'package:prontuario_tcc/services/perfil_profissional_service.dart';

void main() {
  setUpAll(() async {
    Hive.init('test/temp_hive/boot_leitura');
    Hive.registerAdapters();
    await Hive.openBox<PerfilProfissional>('perfil_profissional');
    await Hive.openBox<String>('encryption_meta');
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('perfil_profissional');
    await Hive.deleteBoxFromDisk('encryption_meta');
  });

  setUp(() async {
    await Hive.box<PerfilProfissional>('perfil_profissional').clear();
    await Hive.box<String>('encryption_meta').clear();
  });

  test('obterPerfil com perfil cifrado e chave ausente nao lanca (boot)', () async {
    // Simula o estado no boot: o perfil esta salvo cifrado (chave existe no
    // cofre) mas a chave ainda NAO foi carregada em memoria.
    await Hive.box<PerfilProfissional>('perfil_profissional').put(
      'p1',
      PerfilProfissional(
        id: 'p1',
        nome: '3:nonce:cifrado',
        registroProfissional: '3:nonce:cifrado',
      ),
    );

    final service = PerfilProfissionalService(encryption: EncryptionService());
    // Nao deve lancar: o app apenas verifica que existe perfil para o splash.
    expect(() => service.obterPerfil(), returnsNormally);
  });
}
