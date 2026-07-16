import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/sessao.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';
import 'package:prontuario_tcc/services/sessao_service.dart';

void main() {
  late EncryptionService encryption;
  late SessaoService service;

  setUpAll(() async {
    Hive.init('test/temp_hive/sessao_encrypt');
    Hive.registerAdapters();
    await Hive.openBox<String>('encryption_meta');
    await Hive.openBox<Sessao>('sessoes');
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('sessoes');
    await Hive.deleteBoxFromDisk('encryption_meta');
  });

  setUp(() async {
    await Hive.box<String>('encryption_meta').clear();
    await Hive.box<Sessao>('sessoes').clear();
    encryption = EncryptionService();
    await encryption.inicializar();
    await encryption.configurarPin('1234');
    service = SessaoService(encryption: encryption);
  });

  const artigos =
      '1. Artigo Teste (2020, 12 citações) — Autor A; Autor B\n'
      '   Relevância: relacionado ao caso.\n'
      '   https://doi.org/10.1234/teste';

  Sessao _novaSessao() => Sessao(
        id: 's1',
        pacienteId: 'p1',
        numeroSessao: 1,
        data: DateTime(2026, 7, 15),
        relatoPosSessao: 'Relato',
        transcricaoRelato: 'Transcricao',
        geradoComIa: true,
        statusProcessamento: 'ia_processada',
        artigosSugeridos: artigos,
      );

  test('adicionar e listar preserva artigosSugeridos', () async {
    await service.adicionarSessao(_novaSessao());

    final sessoes = service.listarSessoesDoPaciente('p1');
    expect(sessoes.single.artigosSugeridos, artigos);
  });

  test('atualizar apos listar preserva artigosSugeridos', () async {
    await service.adicionarSessao(_novaSessao());

    final sessao = service.listarSessoesDoPaciente('p1').single;
    sessao.intervencoes = 'Editado';
    await service.atualizarSessao(sessao);

    final relida = service.listarSessoesDoPaciente('p1').single;
    expect(relida.artigosSugeridos, artigos);
    expect(relida.intervencoes, 'Editado');
  });

  test('listar duas vezes nao corrompe (dupla descriptografia)', () async {
    await service.adicionarSessao(_novaSessao());

    service.listarSessoesDoPaciente('p1');
    final sessoes = service.listarSessoesDoPaciente('p1');
    expect(sessoes.single.artigosSugeridos, artigos);
  });

  test('reabrir box (restart do app) preserva artigosSugeridos', () async {
    await service.adicionarSessao(_novaSessao());

    await Hive.box<Sessao>('sessoes').close();
    await Hive.openBox<Sessao>('sessoes');

    final service2 = SessaoService(encryption: encryption);
    final sessoes = service2.listarSessoesDoPaciente('p1');
    expect(sessoes.single.artigosSugeridos, artigos);
  });

  test('pendentes de revisao vem descriptografadas', () async {
    final s = _novaSessao();
    s.revisadoPeloProfissional = false;
    await service.adicionarSessao(s);

    final pendentes = service.listarSessoesPendentesRevisao();
    expect(pendentes.single.artigosSugeridos, artigos);
    expect(pendentes.single.transcricaoRelato, 'Transcricao');
  });
}
