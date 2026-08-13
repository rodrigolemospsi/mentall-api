import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/services/configuracoes_service.dart';

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
}
