import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/services/configuracoes_service.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';

void main() {
  group('ConfiguracoesService', () {
    late ConfiguracoesService config;

    setUpAll(() async {
      Hive.init('test/temp_hive/configuracoes_service');
      await Hive.openBox<String>('app_config');
    });

    tearDownAll(() async {
      await Hive.deleteBoxFromDisk('app_config');
    });

    setUp(() async {
      await Hive.box<String>('app_config').clear();
      config = ConfiguracoesService();
    });

    test('valores padrao quando box vazia', () {
      expect(config.duracaoPadraoSessaoMinutos, 60);
      expect(config.lembretePadraoAtivado, false);
      expect(config.antecedenciaPadraoMinutos, 1440);
      expect(config.sugerirArtigos, true);
    });

    test('setters persistem valores', () async {
      await config.setDuracaoPadraoSessaoMinutos(50);
      await config.setLembretePadraoAtivado(true);
      await config.setAntecedenciaPadraoMinutos(120);
      await config.setSugerirArtigos(false);

      expect(config.duracaoPadraoSessaoMinutos, 50);
      expect(config.lembretePadraoAtivado, true);
      expect(config.antecedenciaPadraoMinutos, 120);
      expect(config.sugerirArtigos, false);
    });

    test('valor corrompido cai no padrao', () async {
      await Hive.box<String>('app_config')
          .put('duracao_padrao_sessao_min', 'abc');
      expect(config.duracaoPadraoSessaoMinutos, 60);
    });
  });

  group('EncryptionService.trocarPin', () {
    late EncryptionService encryption;

    setUpAll(() async {
      Hive.init('test/temp_hive/configuracoes_service');
      await Hive.openBox<String>('encryption_meta');
    });

    tearDownAll(() async {
      await Hive.deleteBoxFromDisk('encryption_meta');
    });

    setUp(() async {
      await Hive.box<String>('encryption_meta').clear();
      encryption = EncryptionService();
      await encryption.inicializar();
      await encryption.configurarPin('1234');
    });

    test('mantem dados legiveis apos a troca', () async {
      final cifrado = encryption.criptografar('dado clinico sensivel');
      expect(cifrado, isNot('dado clinico sensivel'));

      final sucesso = await encryption.trocarPin('1234', '9876');
      expect(sucesso, true);

      expect(encryption.descriptografar(cifrado), 'dado clinico sensivel');
    });

    test('novo PIN desbloqueia e decifra dados antigos', () async {
      final cifrado = encryption.criptografar('outro dado');
      await encryption.trocarPin('1234', '9876');

      final nova = EncryptionService();
      await nova.inicializar();
      expect(await nova.desbloquear('9876'), true);
      expect(nova.descriptografar(cifrado), 'outro dado');
    });

    test('PIN antigo deixa de funcionar', () async {
      await encryption.trocarPin('1234', '9876');

      final nova = EncryptionService();
      await nova.inicializar();
      expect(await nova.desbloquear('1234'), false);
    });

    test('falha com PIN atual incorreto', () async {
      final sucesso = await encryption.trocarPin('0000', '9876');
      expect(sucesso, false);
    });
  });
}
