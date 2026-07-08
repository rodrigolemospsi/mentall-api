import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/paciente.dart';
import 'package:prontuario_tcc/models/perfil_profissional.dart';
import 'package:prontuario_tcc/models/sessao.dart';
import 'package:prontuario_tcc/services/paciente_service.dart';
import 'package:prontuario_tcc/services/perfil_profissional_service.dart';
import 'package:prontuario_tcc/services/sessao_service.dart';
import 'package:prontuario_tcc/services/status_clinico_sessao_service.dart';

void main() {
  setUpAll(() async {
    Hive.init('test/temp_hive/models_services');
    Hive.registerAdapters();
    await Hive.openBox<Paciente>('pacientes');
    await Hive.openBox<Sessao>('sessoes');
    await Hive.openBox<PerfilProfissional>('perfil_profissional');
  });

  tearDownAll(() async {
    await Hive.box<Paciente>('pacientes').close();
    await Hive.box<Sessao>('sessoes').close();
    await Hive.box<PerfilProfissional>('perfil_profissional').close();
    await Hive.deleteBoxFromDisk('pacientes');
    await Hive.deleteBoxFromDisk('sessoes');
    await Hive.deleteBoxFromDisk('perfil_profissional');
  });

  setUp(() async {
    await Hive.box<Paciente>('pacientes').clear();
    await Hive.box<Sessao>('sessoes').clear();
    await Hive.box<PerfilProfissional>('perfil_profissional').clear();
  });

  // ===================== MODELOS =====================

  group('Paciente', () {
    test('deve criar paciente com valores padrão', () {
      final paciente = Paciente(id: '1', nome: 'Maria');

      expect(paciente.id, '1');
      expect(paciente.nome, 'Maria');
      expect(paciente.contato, '');
      expect(paciente.tipoAtendimento, 'Particular');
      expect(paciente.ativo, true);
      expect(paciente.observacoes, '');
      expect(paciente.estaAtivo, true);
      expect(paciente.estaArquivado, false);
    });

    test('copyWith deve preservar campos não alterados', () {
      final paciente = Paciente(
        id: '1',
        nome: 'Maria',
        contato: '11999999999',
        tipoAtendimento: 'Online',
      );
      final copia = paciente.copyWith(nome: 'João');

      expect(copia.id, '1');
      expect(copia.nome, 'João');
      expect(copia.contato, '11999999999');
      expect(copia.tipoAtendimento, 'Online');
    });

    test('arquivar deve marcar como inativo', () {
      final paciente = Paciente(id: '1', nome: 'Maria');
      final arquivado = paciente.arquivar();

      expect(arquivado.ativo, false);
    });

    test('restaurar deve marcar como ativo', () {
      final paciente = Paciente(id: '1', nome: 'Maria', ativo: false);
      final restaurado = paciente.restaurar();

      expect(restaurado.ativo, true);
    });

    test('nomeExibicao deve retornar nome limpo', () {
      final paciente = Paciente(id: '1', nome: '  João  ');
      expect(paciente.nomeExibicao, 'João');
    });

    test('nomeExibicao deve retornar placeholder para nome vazio', () {
      final paciente = Paciente(id: '1', nome: '  ');
      expect(paciente.nomeExibicao, 'Sem nome');
    });

    test('inicial deve retornar primeira letra maiúscula', () {
      final paciente = Paciente(id: '1', nome: 'maria');
      expect(paciente.inicial, 'M');
    });

    test('inicial deve retornar ? para nome vazio', () {
      final paciente = Paciente(id: '1', nome: '');
      expect(paciente.inicial, '?');
    });

    test('idade deve calcular corretamente', () {
      final paciente = Paciente(
        id: '1',
        nome: 'Maria',
        dataNascimento: DateTime(2000, 6, 15),
      );
      expect(paciente.idade, greaterThanOrEqualTo(25));
      expect(paciente.idade, lessThan(27));
    });

    test('idade deve retornar null sem data de nascimento', () {
      final paciente = Paciente(id: '1', nome: 'Maria');
      expect(paciente.idade, isNull);
    });
  });

  group('PerfilProfissional', () {
    test('deve criar perfil com valores padrão', () {
      final perfil = PerfilProfissional(id: '1', nome: 'Dr. Silva');

      expect(perfil.id, '1');
      expect(perfil.nome, 'Dr. Silva');
      expect(perfil.registroProfissional, '');
      expect(perfil.abordagemClinica, 'Integrativa');
      expect(perfil.termoPessoaAtendida, 'paciente');
    });

    test('termos devem variar conforme termoPessoaAtendida', () {
      final perfil = PerfilProfissional(
        id: '1', nome: 'Dr.', termoPessoaAtendida: 'cliente',
      );

      expect(perfil.termoSingular, 'cliente');
      expect(perfil.termoPlural, 'clientes');
      expect(perfil.artigoDefinidoSingular, 'o');
      expect(perfil.novoRegistroLabel, 'Novo cliente');
    });

    test('termo feminino para pessoa atendida', () {
      final perfil = PerfilProfissional(
        id: '1', nome: 'Dr.', termoPessoaAtendida: 'pessoa atendida',
      );

      expect(perfil.artigoDefinidoSingular, 'a');
      expect(perfil.artigoIndefinidoSingular, 'uma');
      expect(perfil.termoPlural, 'pessoas atendidas');
    });

    test('copyWith deve funcionar', () {
      final perfil = PerfilProfissional(id: '1', nome: 'Dr. Silva');
      final copia = perfil.copyWith(abordagemClinica: 'TCC');

      expect(copia.abordagemClinica, 'TCC');
      expect(copia.nome, 'Dr. Silva');
    });

    test('usaAbordagemTcc', () {
      final perfil = PerfilProfissional(
        id: '1', nome: 'Dr.', abordagemClinica: 'TCC',
      );
      expect(perfil.usaAbordagemTcc, true);
      expect(perfil.usaLogoterapia, false);
    });

    test('nenhumaPessoaCadastradaMensagem para cliente', () {
      final perfil = PerfilProfissional(
        id: '1', nome: 'Dr.', termoPessoaAtendida: 'cliente',
      );
      expect(
        perfil.nenhumaPessoaCadastradaMensagem,
        'Nenhum cliente cadastrado ainda.',
      );
    });
  });

  group('Sessao', () {
    test('deve criar sessão com valores padrão', () {
      final sessao = Sessao(
        id: '1', pacienteId: 'pac1', numeroSessao: 1, data: DateTime.now(),
      );

      expect(sessao.id, '1');
      expect(sessao.pacienteId, 'pac1');
      expect(sessao.numeroSessao, 1);
      expect(sessao.humor, 5);
      expect(sessao.arquivada, false);
      expect(sessao.statusProcessamento, 'manual');
      expect(sessao.revisadoPeloProfissional, false);
      expect(sessao.origemRelato, 'manual');
    });

    test('possuiRelatoPosSessao deve retornar true quando preenchido', () {
      final sessao = Sessao(
        id: '1', pacienteId: 'pac1', numeroSessao: 1, data: DateTime.now(),
        relatoPosSessao: 'Relato clínico...',
      );
      expect(sessao.possuiRelatoPosSessao, true);
    });

    test('possuiAudioRelato deve detectar path ou base64', () {
      final sessaoPath = Sessao(
        id: '1', pacienteId: 'pac1', numeroSessao: 1, data: DateTime.now(),
        audioRelatoPath: '/tmp/audio.wav',
      );
      expect(sessaoPath.possuiAudioRelato, true);

      final sessaoBase64 = Sessao(
        id: '1', pacienteId: 'pac1', numeroSessao: 1, data: DateTime.now(),
        audioRelatoBase64: 'd3d3Lg==',
      );
      expect(sessaoBase64.possuiAudioRelato, true);

      final vazia = Sessao(
        id: '2', pacienteId: 'pac1', numeroSessao: 2, data: DateTime.now(),
      );
      expect(vazia.possuiAudioRelato, false);
    });

    test('possuiConteudoClinico deve detectar qualquer campo preenchido', () {
      final vazia = Sessao(
        id: '1', pacienteId: 'pac1', numeroSessao: 1, data: DateTime.now(),
      );
      expect(vazia.possuiConteudoClinico, false);

      final preenchida = Sessao(
        id: '2', pacienteId: 'pac1', numeroSessao: 2, data: DateTime.now(),
        temaPrincipal: 'Ansiedade social',
      );
      expect(preenchida.possuiConteudoClinico, true);
    });

    test('estaAguardandoRevisao para status de processamento', () {
      final gravando = Sessao(
        id: '1', pacienteId: 'pac1', numeroSessao: 1, data: DateTime.now(),
        statusProcessamento: 'audio_gravado',
      );
      expect(gravando.estaAguardandoRevisao, true);

      final revisado = Sessao(
        id: '2', pacienteId: 'pac1', numeroSessao: 2, data: DateTime.now(),
        statusProcessamento: 'revisado',
      );
      expect(revisado.estaAguardandoRevisao, false);
    });

    test('copyWith deve funcionar', () {
      final sessao = Sessao(
        id: '1', pacienteId: 'pac1', numeroSessao: 1, data: DateTime.now(),
        relatoPosSessao: 'Original',
      );
      final copia = sessao.copyWith(relatoPosSessao: 'Editado');

      expect(copia.relatoPosSessao, 'Editado');
      expect(copia.pacienteId, 'pac1');
    });

    test('estaAtiva / arquivada', () {
      final ativa = Sessao(
        id: '1', pacienteId: 'pac1', numeroSessao: 1, data: DateTime.now(),
      );
      expect(ativa.estaAtiva, true);

      final arquivada = Sessao(
        id: '2', pacienteId: 'pac1', numeroSessao: 2, data: DateTime.now(),
        arquivada: true,
      );
      expect(arquivada.estaAtiva, false);
    });
  });

  // ===================== SERVIÇOS =====================

  group('StatusClinicoSessaoService', () {
    final service = const StatusClinicoSessaoService();

    Sessao sessaoBase({int? numero}) {
      return Sessao(
        id: '$numero',
        pacienteId: 'pac1',
        numeroSessao: numero ?? 1,
        data: DateTime.now(),
      );
    }

    test('sessão vazia', () {
      final sessao = sessaoBase();
      final info = service.calcular(sessao);

      expect(info.status, StatusClinicoSessao.vazia);
      expect(info.possuiPendencia, false);
      expect(info.podeGerarIa, false);
      expect(info.podeMarcarComoRevisada, false);
    });

    test('relato disponível sem transcrição', () {
      final sessao = sessaoBase()
        ..relatoPosSessao = 'Relato clínico...';

      final info = service.calcular(sessao);

      expect(info.status, StatusClinicoSessao.relatoDisponivel);
      expect(info.exigeAcaoProfissional, true);
      expect(info.podeMarcarComoRevisada, true);
      expect(info.podeGerarIa, false);
    });

    test('áudio disponível sem transcrição', () {
      final sessao = sessaoBase()
        ..audioRelatoPath = '/tmp/audio.wav';

      final info = service.calcular(sessao);

      expect(info.status, StatusClinicoSessao.relatoDisponivel);
    });

    test('transcrição pendente quando relato existe mas ainda transcrevendo', () {
      final sessao = sessaoBase()
        ..relatoPosSessao = 'Relato...'
        ..transcricaoRelato = 'Transcrição parcial...'
        ..statusProcessamento = 'transcrevendo';

      final info = service.calcular(sessao);

      expect(info.status, StatusClinicoSessao.transcricaoPendente);
      expect(info.possuiPendencia, true);
      expect(info.podeGerarIa, false);
      expect(info.podeMarcarComoRevisada, false);
    });

    test('IA pendente quando transcrição existe mas IA não', () {
      final sessao = sessaoBase()
        ..transcricaoRelato = 'Transcrição do áudio...';

      final info = service.calcular(sessao);

      expect(info.status, StatusClinicoSessao.iaPendente);
      expect(info.podeGerarIa, true);
      expect(info.iaValida, false);
    });

    test('revisão pendente quando IA gerada mas não revisada', () {
      final sessao = sessaoBase()
        ..transcricaoRelato = 'Transcrição...'
        ..apontamentosCopiloto = 'Apontamentos gerados pela IA...';

      final info = service.calcular(sessao);

      expect(info.status, StatusClinicoSessao.revisaoPendente);
      expect(info.podeGerarIa, true);
      expect(info.podeMarcarComoRevisada, true);
      expect(info.iaValida, true);
      expect(info.exigeAcaoProfissional, true);
    });

    test('revisão pendente quando geradoComIa = true', () {
      final sessao = sessaoBase()
        ..transcricaoRelato = 'Transcrição...'
        ..geradoComIa = true;

      final info = service.calcular(sessao);

      expect(info.status, StatusClinicoSessao.revisaoPendente);
    });

    test('concluída quando revisada pelo profissional', () {
      final sessao = sessaoBase()
        ..transcricaoRelato = 'Transcrição...'
        ..apontamentosCopiloto = 'Apontamentos...'
        ..revisadoPeloProfissional = true;

      final info = service.calcular(sessao);

      expect(info.status, StatusClinicoSessao.concluida);
      expect(info.possuiPendencia, false);
      expect(info.podeMarcarComoRevisada, false);
      expect(info.iaValida, true);
    });

    test('erro quando possui erro de processamento', () {
      final sessao = sessaoBase()
        ..erroProcessamentoIa = 'Falha na API';

      final info = service.calcular(sessao);

      expect(info.status, StatusClinicoSessao.erro);
      expect(info.exigeAcaoProfissional, true);
      expect(info.podeGerarIa, false);
      expect(info.podeMarcarComoRevisada, false);
    });

    test('relato disponível sem transcrição nem IA', () {
      final sessao = sessaoBase()
        ..relatoPosSessao = 'Relato...'
        ..revisadoPeloProfissional = false;

      final info = service.calcular(sessao);

      expect(info.status, StatusClinicoSessao.relatoDisponivel);
      expect(info.podeMarcarComoRevisada, true);
      expect(info.podeGerarIa, false);
    });
  });

  group('PacienteService', () {
    late PacienteService service;

    setUp(() {
      service = PacienteService();
    });

    test('deve adicionar e listar pacientes', () async {
      final paciente = Paciente(id: '1', nome: 'Maria');
      await service.adicionarPaciente(paciente);

      final pacientes = service.listarPacientes();
      expect(pacientes.length, 1);
      expect(pacientes.first.nome, 'Maria');
    });

    test('deve listar apenas pacientes ativos', () async {
      await service.adicionarPaciente(Paciente(id: '1', nome: 'Ativo'));
      await service.adicionarPaciente(Paciente(
        id: '2', nome: 'Arquivado', ativo: false,
      ));

      final ativos = service.listarPacientesAtivos();
      expect(ativos.length, 1);
      expect(ativos.first.nome, 'Ativo');
    });

    test('deve arquivar e restaurar paciente', () async {
      final paciente = Paciente(id: '1', nome: 'Maria');
      await service.adicionarPaciente(paciente);

      await service.arquivarPaciente(paciente);
      expect(paciente.ativo, false);

      final arquivados = service.listarPacientesArquivados();
      expect(arquivados.length, 1);

      await service.restaurarPaciente(paciente);
      expect(paciente.ativo, true);

      final ativos = service.listarPacientesAtivos();
      expect(ativos.length, 1);
    });

    test('deve buscar paciente por nome', () async {
      await service.adicionarPaciente(Paciente(id: '1', nome: 'Maria Silva'));
      await service.adicionarPaciente(Paciente(id: '2', nome: 'João Santos'));

      final resultados = service.buscarPacientesPorNome('maria');
      expect(resultados.length, 1);
      expect(resultados.first.nome, 'Maria Silva');
    });

    test('deve buscar paciente por id', () async {
      await service.adicionarPaciente(Paciente(id: 'abc123', nome: 'Maria'));

      final encontrado = service.buscarPacientePorId('abc123');
      expect(encontrado, isNotNull);
      expect(encontrado!.nome, 'Maria');

      final naoEncontrado = service.buscarPacientePorId('nao_existe');
      expect(naoEncontrado, isNull);
    });

    test('deve excluir paciente', () async {
      final paciente = Paciente(id: '1', nome: 'Maria');
      await service.adicionarPaciente(paciente);
      await service.excluirPaciente(paciente);

      expect(service.listarPacientes(), isEmpty);
    });

    test('deve ordenar por nome', () async {
      await service.adicionarPaciente(Paciente(id: '2', nome: 'Zélia'));
      await service.adicionarPaciente(Paciente(id: '1', nome: 'Ana'));

      final pacientes = service.listarPacientes();
      expect(pacientes.first.nome, 'Ana');
      expect(pacientes.last.nome, 'Zélia');
    });

    test('deve retornar lista vazia quando não há pacientes', () {
      expect(service.listarPacientes(), isEmpty);
      expect(service.listarPacientesAtivos(), isEmpty);
    });
  });

  group('SessaoService', () {
    late SessaoService service;

    setUp(() {
      service = SessaoService();
    });

    Sessao criarSessao(String id, String pacienteId, int numero) {
      return Sessao(
        id: id,
        pacienteId: pacienteId,
        numeroSessao: numero,
        data: DateTime.now(),
      );
    }

    test('deve adicionar e listar sessões', () async {
      await service.adicionarSessao(criarSessao('1', 'pac1', 1));

      final sessoes = service.listarTodasSessoes();
      expect(sessoes.length, 1);
    });

    test('deve listar sessões do paciente', () async {
      await service.adicionarSessao(criarSessao('1', 'pac1', 1));
      await service.adicionarSessao(criarSessao('2', 'pac1', 2));
      await service.adicionarSessao(criarSessao('3', 'pac2', 1));

      final doPaciente = service.listarSessoesDoPaciente('pac1');
      expect(doPaciente.length, 2);

      final doOutro = service.listarSessoesDoPaciente('pac2');
      expect(doOutro.length, 1);
    });

    test('deve arquivar e restaurar sessão', () async {
      final sessao = criarSessao('1', 'pac1', 1);
      await service.adicionarSessao(sessao);

      await service.arquivarSessao(sessao);
      expect(sessao.arquivada, true);

      final arquivadas = service.listarTodasSessoesArquivadas();
      expect(arquivadas.length, 1);

      await service.restaurarSessao(sessao);
      expect(sessao.arquivada, false);

      final ativas = service.listarTodasSessoesAtivas();
      expect(ativas.length, 1);
    });

    test('deve calcular próximo número de sessão', () async {
      expect(service.proximoNumeroSessao('pac1'), 1);

      await service.adicionarSessao(criarSessao('1', 'pac1', 1));
      expect(service.proximoNumeroSessao('pac1'), 2);

      await service.adicionarSessao(criarSessao('2', 'pac1', 5));
      expect(service.proximoNumeroSessao('pac1'), 6);
    });

    test('deve buscar sessão por id', () async {
      await service.adicionarSessao(criarSessao('s1', 'pac1', 1));

      final encontrada = service.buscarSessaoPorId('s1');
      expect(encontrada, isNotNull);

      final naoEncontrada = service.buscarSessaoPorId('nao_existe');
      expect(naoEncontrada, isNull);
    });

    test('deve contar sessões do paciente', () async {
      await service.adicionarSessao(criarSessao('1', 'pac1', 1));
      await service.adicionarSessao(criarSessao('2', 'pac1', 2));
      await service.adicionarSessao(criarSessao('3', 'pac2', 1));

      expect(service.contarSessoesDoPaciente('pac1'), 2);
      expect(service.contarSessoesDoPaciente('pac2'), 1);
    });

    test('sessão adicionada já começa como não arquivada', () async {
      final sessao = criarSessao('1', 'pac1', 1)
        ..arquivada = true;
      await service.adicionarSessao(sessao);

      expect(sessao.arquivada, false);
    });
  });

  group('PerfilProfissionalService', () {
    late PerfilProfissionalService service;

    setUp(() {
      service = PerfilProfissionalService();
    });

    test('deve iniciar sem perfil', () {
      expect(service.perfilConfigurado(), false);
      expect(service.obterPerfil(), isNull);
    });

    test('deve criar perfil', () async {
      final perfil = PerfilProfissional(id: '1', nome: 'Dr. Silva');
      await service.salvarPerfil(perfil);

      expect(service.perfilConfigurado(), true);
      final obtido = service.obterPerfil();
      expect(obtido, isNotNull);
      expect(obtido!.nome, 'Dr. Silva');
    });

    test('deve atualizar perfil existente', () async {
      final perfil = PerfilProfissional(id: '1', nome: 'Dr. Silva');
      await service.salvarPerfil(perfil);

      final perfilAtualizado = PerfilProfissional(
        id: '1', nome: 'Dr. Silva Atualizado', abordagemClinica: 'TCC',
      );
      await service.salvarPerfil(perfilAtualizado);

      final obtido = service.obterPerfil();
      expect(obtido!.nome, 'Dr. Silva Atualizado');
      expect(obtido.abordagemClinica, 'TCC');
    });

    test('deve limpar perfil', () async {
      final perfil = PerfilProfissional(id: '1', nome: 'Dr. Silva');
      await service.salvarPerfil(perfil);

      await service.limparPerfil();
      expect(service.perfilConfigurado(), false);
    });
  });
}
