import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/contrato_terapeutico.dart';
import 'package:prontuario_tcc/models/paciente.dart';
import 'package:prontuario_tcc/services/contrato_service.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';
import 'package:prontuario_tcc/services/paciente_service.dart';

void main() {
  late EncryptionService encryption;
  late PacienteService pacienteService;
  late ContratoService contratoService;

  setUpAll(() async {
    Hive.init('test/temp_hive/campos_criptografados');
    Hive.registerAdapters();
    await Hive.openBox<String>('encryption_meta');
    await Hive.openBox<Paciente>('pacientes');
    await Hive.openBox<ContratoTerapeutico>('contratos');
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('pacientes');
    await Hive.deleteBoxFromDisk('contratos');
    await Hive.deleteBoxFromDisk('encryption_meta');
  });

  setUp(() async {
    await Hive.box<String>('encryption_meta').clear();
    await Hive.box<Paciente>('pacientes').clear();
    await Hive.box<ContratoTerapeutico>('contratos').clear();
    encryption = EncryptionService();
    await encryption.inicializar();
    await encryption.gerarChave();
    pacienteService = PacienteService(encryption: encryption);
    contratoService = ContratoService(encryption: encryption);
  });

  Paciente novoPaciente() => Paciente(
        id: 'p1',
        nome: 'Maria',
        dataNascimento: DateTime(1990, 1, 1),
        contato: '11999999999',
        tipoAtendimento: 'Particular',
        observacoes: 'Obs',
        ativo: true,
        dataCadastro: DateTime(2026, 7, 1),
        fotoBase64: 'Zm90by1kZS10ZXN0ZQ==',
        enderecoJson: '{"cep":"12345-678","cidade":"Feira"}',
      );

  test('fotoBase64 e enderecoJson ficam cifrados no Hive e legiveis na leitura',
      () async {
    await pacienteService.adicionarPaciente(novoPaciente());

    // Reabre o box do disco para verificar o estado cifrado (em repouso).
    await Hive.box<Paciente>('pacientes').close();
    final box = await Hive.openBox<Paciente>('pacientes');
    final bruto = box.values.single;
    expect(bruto.fotoBase64, isNot('Zm90by1kZS10ZXN0ZQ=='));
    expect(bruto.enderecoJson, isNot('{"cep":"12345-678","cidade":"Feira"}'));

    final leitura = PacienteService(encryption: encryption);
    final lido = leitura.buscarPacientePorId('p1')!;
    expect(lido.fotoBase64, 'Zm90by1kZS10ZXN0ZQ==');
    expect(lido.enderecoJson, '{"cep":"12345-678","cidade":"Feira"}');
  });

  test('atualizar depois de listar nao corrompe foto/endereco', () async {
    await pacienteService.adicionarPaciente(novoPaciente());

    final p = pacienteService.buscarPacientePorId('p1')!;
    p.observacoes = 'Editado';
    await pacienteService.atualizarPaciente(p);

    final relido = pacienteService.buscarPacientePorId('p1')!;
    expect(relido.fotoBase64, 'Zm90by1kZS10ZXN0ZQ==');
    expect(relido.enderecoJson, '{"cep":"12345-678","cidade":"Feira"}');
    expect(relido.observacoes, 'Editado');
  });

  test('token e url do contrato ficam cifrados no Hive', () async {
    final contrato = ContratoTerapeutico(
      id: 'c1',
      pacienteId: 'p1',
      token: 'tok-secreto-abc',
      url: 'https://api.example/contratos/tok-secreto-abc',
      dataCriacao: DateTime(2026, 7, 2),
    );
    await contratoService.criarLocalmente(contrato);

    // Reabre o box do disco para verificar o estado cifrado (em repouso).
    await Hive.box<ContratoTerapeutico>('contratos').close();
    final box = await Hive.openBox<ContratoTerapeutico>('contratos');
    final bruto = box.values.single;
    expect(bruto.token, isNot('tok-secreto-abc'));
    expect(bruto.url, isNot('https://api.example/contratos/tok-secreto-abc'));

    final leitura = ContratoService(encryption: encryption);
    final lido = leitura.obterPorPaciente('p1')!;
    expect(lido.token, 'tok-secreto-abc');
    expect(lido.url, 'https://api.example/contratos/tok-secreto-abc');
  });

  test('marcar como enviado nao corrompe token/url', () async {
    final contrato = ContratoTerapeutico(
      id: 'c2',
      pacienteId: 'p1',
      token: 'tok-secreto-xyz',
      url: 'https://api.example/contratos/tok-secreto-xyz',
      dataCriacao: DateTime(2026, 7, 2),
    );
    await contratoService.criarLocalmente(contrato);

    final c = contratoService.obterPorPaciente('p1')!;
    await contratoService.marcarComoEnviado(c);

    final relido = contratoService.obterPorPaciente('p1')!;
    expect(relido.token, 'tok-secreto-xyz');
    expect(relido.url, 'https://api.example/contratos/tok-secreto-xyz');
    expect(relido.status, 'enviado');
  });
}
