import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';

void main() {
  late EncryptionService encryption;

  setUpAll(() async {
    Hive.init('test/temp_hive/encryption_pin');
    Hive.registerAdapters();
    await Hive.openBox<String>('encryption_meta');
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('encryption_meta');
  });

  setUp(() async {
    await Hive.box<String>('encryption_meta').clear();
    encryption = EncryptionService();
    await encryption.inicializar();
  });

  test('validarPin rejeita PIN quando nao ha chave protegida por PIN legado', () async {
    await encryption.gerarChave();
    // Com a chave em memoria mas sem encrypted_key legado, qualquer PIN deve falhar.
    expect(await encryption.validarPin('1234'), isFalse);
    expect(await encryption.validarPin('000000'), isFalse);
  });

  test('validarPin nao aceita PIN qualquer apenas por a chave estar em memoria', () async {
    await encryption.gerarChave();
    // Garante que a chave esta em memoria (configurado == true)
    expect(encryption.configurado, isTrue);
    // Mesmo assim, sem PIN legado registrado, validarPin deve falhar
    // (bug corrigido: antes retornava true incondicionalmente quando _key != null).
    expect(await encryption.validarPin('senha-qualquer'), isFalse);
  });
}
