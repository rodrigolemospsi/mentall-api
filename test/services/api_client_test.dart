import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/services/api_client.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';

void main() {
  setUpAll(() async {
    Hive.init('test/temp_hive/api_client');
    Hive.registerAdapters();
    await Hive.openBox<String>('app_config');
    await Hive.openBox<String>('auth_meta');
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('app_config');
    await Hive.deleteBoxFromDisk('auth_meta');
  });

  setUp(() async {
    await Hive.box<String>('app_config').clear();
    await Hive.box<String>('auth_meta').clear();
    ApiClient.authToken = null;
  });

  test('setCredentials persiste criptografado quando ha chave', () async {
    final encryption = EncryptionService();
    EncryptionService.setInstance(encryption);
    await encryption.inicializar();
    await encryption.gerarChave();
    expect(encryption.configurado, isTrue);

    await ApiClient.setCredentials('admin', 'minha-senha-secreta');
    final armazenado = Hive.box<String>('app_config').get('auth_password');
    // Nao deve estar em texto puro
    expect(armazenado, isNot('minha-senha-secreta'));
    // Leitura retorna o valor correto
    expect(ApiClient.password, 'minha-senha-secreta');
  });

  test('setCredentials nao persiste em texto puro sem criptografia', () async {
    final encryption = EncryptionService();
    EncryptionService.setInstance(encryption);
    await encryption.inicializar();
    // Sem gerarChave -> configurado == false -> tryEncrypt retorna null
    expect(encryption.configurado, isFalse);

    await ApiClient.setCredentials('admin', 'senha-em-claro');
    final armazenado = Hive.box<String>('app_config').get('auth_password');
    // Nao deve persistir em texto puro (chave excluida do Hive)
    expect(armazenado, isNull);
    // Mantem em memoria para o fluxo atual funcionar
    expect(ApiClient.password, 'senha-em-claro');
  });

  test('password nao devolve ciphertext quando a chave nao esta carregada',
      () async {
    // 1) Execucao com chave: senha persistida de forma cifrada.
    final comChave = EncryptionService();
    EncryptionService.setInstance(comChave);
    await comChave.inicializar();
    await comChave.gerarChave();
    await ApiClient.setCredentials('admin', 'minha-senha');
    final cifrado = Hive.box<String>('app_config').get('auth_password');
    expect(cifrado, startsWith('3:'));

    // 2) Nova execucao: chave ainda NAO carregada (app bloqueado).
    final semChave = EncryptionService();
    EncryptionService.setInstance(semChave);
    await semChave.inicializar();
    expect(semChave.configurado, isFalse);

    // Nao deve enviar o ciphertext como se fosse a senha (evita 401 confuso).
    expect(ApiClient.password, '');
  });
}
