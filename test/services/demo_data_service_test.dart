import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/paciente.dart';
import 'package:prontuario_tcc/models/sessao.dart';
import 'package:prontuario_tcc/services/avaliacao_inicial_service.dart';
import 'package:prontuario_tcc/services/configuracoes_service.dart';
import 'package:prontuario_tcc/services/demo_data_service.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';
import 'package:prontuario_tcc/services/paciente_service.dart';
import 'package:prontuario_tcc/services/sessao_service.dart';

void main() {
  late EncryptionService encryption;
  late DemoDataService demo;
  late PacienteService pacienteService;
  late SessaoService sessaoService;
  late AvaliacaoInicialService avaliacaoService;
  late ConfiguracoesService config;

  setUpAll(() async {
    Hive.init('test/temp_hive/demo_data');
    Hive.registerAdapters();
    await Hive.openBox<Paciente>('pacientes');
    await Hive.openBox<Sessao>('sessoes');
    await Hive.openBox('avaliacoes_iniciais');
    await Hive.openBox<String>('app_config');
    await Hive.openBox<String>('encryption_meta');
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('pacientes');
    await Hive.deleteBoxFromDisk('sessoes');
    await Hive.deleteBoxFromDisk('avaliacoes_iniciais');
    await Hive.deleteBoxFromDisk('app_config');
    await Hive.deleteBoxFromDisk('encryption_meta');
  });

  setUp(() async {
    await Hive.box<Paciente>('pacientes').clear();
    await Hive.box<Sessao>('sessoes').clear();
    await Hive.box('avaliacoes_iniciais').clear();
    await Hive.box<String>('app_config').clear();
    await Hive.box<String>('encryption_meta').clear();

    encryption = EncryptionService();
    await encryption.inicializar();

    pacienteService = PacienteService(encryption: encryption);
    sessaoService = SessaoService(encryption: encryption);
    avaliacaoService = AvaliacaoInicialService(encryption: encryption);
    config = ConfiguracoesService();

    demo = DemoDataService(
      encryption: encryption,
      fotoLoader: () async => 'Zm90bw==',
    );
  });

  test('cria a paciente demo com os dados corretos', () async {
    await demo.semearSeNecessario();

    final linda =
        pacienteService.buscarPacientePorId(DemoDataService.pacienteDemoId);
    expect(linda, isNotNull);
    expect(linda!.nome, 'Linda M. Tester');
    expect(linda.dataNascimento, DateTime(1991, 1, 25));
    expect(linda.tratamento, 'feminino');
    expect(linda.ehDemo, true);
    expect(linda.fotoBase64, isNotEmpty);
    expect(linda.ativo, true);
  });

  test('preenche todos os campos da avaliacao inicial', () async {
    await demo.semearSeNecessario();

    final anamnese =
        avaliacaoService.obterPorPaciente(DemoDataService.pacienteDemoId);
    expect(anamnese, isNotNull);
    expect(anamnese!.queixaPrincipal, isNotEmpty);
    expect(anamnese.historicoClinico, isNotEmpty);
    expect(anamnese.medicamentos, isNotEmpty);
    expect(anamnese.hipoteseDiagnostica, isNotEmpty);
    expect(anamnese.objetivosTerapeuticos, isNotEmpty);
    expect(anamnese.observacoes, isNotEmpty);
  });

  test('cria 4 sessoes com transcricao e sem sintese', () async {
    await demo.semearSeNecessario();

    final sessoes =
        sessaoService.listarSessoesDoPaciente(DemoDataService.pacienteDemoId);
    expect(sessoes.length, 4);

    final numeros = sessoes.map((s) => s.numeroSessao).toList()..sort();
    expect(numeros, [1, 2, 3, 4]);

    for (final s in sessoes) {
      expect(s.transcricaoRelato, isNotEmpty);
      expect(s.statusProcessamento, 'transcrito');
      expect(s.geradoComIa, false);
      expect(s.revisadoPeloProfissional, false);
      expect(s.relatoPosSessao, isEmpty);
      expect(s.apontamentosCopiloto, isEmpty);
      expect(s.artigosSugeridos, isEmpty);
    }

    final datas = sessoes.map((s) => s.data).toList()..sort();
    expect(datas.first, DateTime(2026, 7, 8, 14, 0));
    expect(datas.last, DateTime(2026, 7, 29, 14, 0));
  });

  test('eh idempotente e marca a flag demo_criado', () async {
    await demo.semearSeNecessario();
    expect(config.demoCriado, true);

    await demo.semearSeNecessario();

    expect(pacienteService.listarPacientes().length, 1);
    expect(
      sessaoService.listarSessoesDoPaciente(DemoDataService.pacienteDemoId).length,
      4,
    );
  });
}
