import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/paciente.dart';
import 'package:prontuario_tcc/models/perfil_profissional.dart';
import 'package:prontuario_tcc/models/sessao.dart';
import 'package:prontuario_tcc/services/backup_service.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';
import 'package:prontuario_tcc/services/paciente_service.dart';
import 'package:prontuario_tcc/services/sessao_service.dart';

void main() {
  late EncryptionService encryption;
  late BackupService backup;
  late PacienteService pacienteService;
  late SessaoService sessaoService;

  setUpAll(() async {
    Hive.init('test/temp_hive/backup_service');
    Hive.registerAdapters();
    await Hive.openBox<String>('encryption_meta');
    await Hive.openBox<Paciente>('pacientes');
    await Hive.openBox<Sessao>('sessoes');
    await Hive.openBox<PerfilProfissional>('perfil_profissional');
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('pacientes');
    await Hive.deleteBoxFromDisk('sessoes');
    await Hive.deleteBoxFromDisk('perfil_profissional');
    await Hive.deleteBoxFromDisk('encryption_meta');
  });

  setUp(() async {
    await Hive.box<String>('encryption_meta').clear();
    await Hive.box<Paciente>('pacientes').clear();
    await Hive.box<Sessao>('sessoes').clear();
    await Hive.box<PerfilProfissional>('perfil_profissional').clear();
    encryption = EncryptionService();
    await encryption.inicializar();
    await encryption.configurarPin('1234');
    backup = BackupService(encryption: encryption);
    pacienteService = PacienteService(encryption: encryption);
    sessaoService = SessaoService(encryption: encryption);
  });

  Paciente novoPaciente() => Paciente(
        id: 'p1',
        nome: 'Original',
        contato: '11999999999',
        email: 'a@b.com',
        tipoAtendimento: 'Particular',
        observacoes: 'Obs',
        ativo: true,
        dataCadastro: DateTime(2026, 7, 1),
      );

  Sessao novaSessao() => Sessao(
        id: 's1',
        pacienteId: 'p1',
        numeroSessao: 1,
        data: DateTime(2026, 7, 15),
        relatoPosSessao: 'Relato',
        artigosSugeridos: 'Artigos',
      );

  test('export gera JSON em texto claro mesmo com PIN', () async {
    await pacienteService.adicionarPaciente(novoPaciente());
    await sessaoService.adicionarSessao(novaSessao());

    final json = jsonDecode(backup.exportarParaJson()) as Map<String, dynamic>;

    final paciente = (json['pacientes'] as List).single;
    expect(paciente['nome'], 'Original');
    expect(paciente['contato'], '11999999999');

    final sessao = (json['sessoes'] as List).single;
    expect(sessao['relato_pos_sessao'], 'Relato');
    expect(sessao['artigos_sugeridos'], 'Artigos');
  });

  test('import sobrescreve registro existente com mesmo ID', () async {
    await pacienteService.adicionarPaciente(novoPaciente());
    await sessaoService.adicionarSessao(novaSessao());

    final snapshot = backup.exportarParaJson();

    final paciente = pacienteService.buscarPacientePorId('p1')!;
    paciente.nome = 'Modificado';
    await pacienteService.atualizarPaciente(paciente);

    final sessao = sessaoService.buscarSessaoPorId('s1')!;
    await sessaoService.arquivarSessao(sessao);

    final resultado = await backup.importarDeJson(snapshot);
    expect(resultado, contains('Importação concluída'));

    final restaurado = pacienteService.buscarPacientePorId('p1')!;
    expect(restaurado.nome, 'Original');

    final sessaoRestaurada = sessaoService.buscarSessaoPorId('s1')!;
    expect(sessaoRestaurada.arquivada, false);
    expect(sessaoRestaurada.relatoPosSessao, 'Relato');

    expect(Hive.box<Paciente>('pacientes').length, 1);
    expect(Hive.box<Sessao>('sessoes').length, 1);
  });

  test('import criptografa campos sensiveis ao salvar', () async {
    await pacienteService.adicionarPaciente(novoPaciente());
    final snapshot = backup.exportarParaJson();

    await Hive.box<Paciente>('pacientes').clear();
    final resultado = await backup.importarDeJson(snapshot);
    expect(resultado, contains('1 paciente(s)'));

    final bruto = Hive.box<Paciente>('pacientes').values.single;
    expect(bruto.nome, isNot('Original'));
    expect(encryption.descriptografar(bruto.nome), 'Original');

    final lido = pacienteService.buscarPacientePorId('p1')!;
    expect(lido.nome, 'Original');
  });

  test('import adiciona registros novos quando nao existem', () async {
    await pacienteService.adicionarPaciente(novoPaciente());
    await sessaoService.adicionarSessao(novaSessao());
    final snapshot = backup.exportarParaJson();

    await Hive.box<Paciente>('pacientes').clear();
    await Hive.box<Sessao>('sessoes').clear();

    final resultado = await backup.importarDeJson(snapshot);
    expect(resultado, contains('1 paciente(s)'));
    expect(resultado, contains('1 sessão(ões)'));

    expect(pacienteService.buscarPacientePorId('p1'), isNotNull);
    expect(sessaoService.buscarSessaoPorId('s1'), isNotNull);
  });

  test('roundtrip sem criptografia (sem PIN)', () async {
    final backupSemPin = BackupService();
    final pacienteServiceSemPin = PacienteService();

    await pacienteServiceSemPin.adicionarPaciente(novoPaciente());
    final snapshot = backupSemPin.exportarParaJson();

    await Hive.box<Paciente>('pacientes').clear();
    await backupSemPin.importarDeJson(snapshot);

    expect(pacienteServiceSemPin.buscarPacientePorId('p1')!.nome, 'Original');
  });
}
