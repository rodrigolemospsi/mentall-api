import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/contrato_terapeutico.dart';
import 'package:prontuario_tcc/models/paciente.dart';
import 'package:prontuario_tcc/models/pacote.dart';
import 'package:prontuario_tcc/models/perfil_profissional.dart';
import 'package:prontuario_tcc/models/progresso_sessao.dart';
import 'package:prontuario_tcc/models/sessao.dart';
import 'package:prontuario_tcc/services/backup_service.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';
import 'package:prontuario_tcc/services/paciente_service.dart';

void main() {
  late EncryptionService encryption;
  late BackupService backup;
  late PacienteService pacienteService;

  setUpAll(() async {
    Hive.init('test/temp_hive/backup_envelope');
    Hive.registerAdapters();
    await Hive.openBox<String>('encryption_meta');
    await Hive.openBox<Paciente>('pacientes');
    await Hive.openBox<Sessao>('sessoes');
    await Hive.openBox<PerfilProfissional>('perfil_profissional');
    await Hive.openBox<ContratoTerapeutico>('contratos');
    await Hive.openBox<Pacote>('pacotes');
    await Hive.openBox<ProgressoSessao>('progresso_sessoes');
  });

  tearDownAll(() async {
    for (final b in [
      'encryption_meta', 'pacientes', 'sessoes', 'perfil_profissional',
      'contratos', 'pacotes', 'progresso_sessoes',
    ]) {
      await Hive.deleteBoxFromDisk(b);
    }
  });

  setUp(() async {
    await Hive.box<String>('encryption_meta').clear();
    await Hive.box<Paciente>('pacientes').clear();
    await Hive.box<Sessao>('sessoes').clear();
    await Hive.box<PerfilProfissional>('perfil_profissional').clear();
    encryption = EncryptionService();
    await encryption.inicializar();
    await encryption.gerarChave();
    backup = BackupService(encryption: encryption);
    pacienteService = PacienteService(encryption: encryption);
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

  test('export com PIN gera envelope cifrado, nao JSON claro', () async {
    await pacienteService.adicionarPaciente(novoPaciente());

    final saida = backup.exportarParaJson();
    final envelope = jsonDecode(saida) as Map<String, dynamic>;

    expect(envelope['tipo'], 'mentall_backup_v1');
    expect(envelope['nonce'], isNotEmpty);
    expect(envelope['cifrado'], isNotEmpty);
    expect(envelope['mac'], isNotEmpty);
    // Nenhum dado clinico em claro dentro do envelope
    expect(saida, isNot(contains('Original')));
    expect(saida, isNot(contains('pacientes')));
  });

  test('roundtrip do envelope restaura os dados', () async {
    await pacienteService.adicionarPaciente(novoPaciente());
    final snapshot = backup.exportarParaJson();

    await Hive.box<Paciente>('pacientes').clear();
    final resultado = await backup.importarDeJson(snapshot);
    expect(resultado, contains('1 paciente(s)'));

    expect(pacienteService.buscarPacientePorId('p1')!.nome, 'Original');
  });

  test('import rejeita envelope com MAC adulterado', () async {
    await pacienteService.adicionarPaciente(novoPaciente());
    final snapshot = backup.exportarParaJson();
    final envelope = jsonDecode(snapshot) as Map<String, dynamic>;

    // Adultera o ciphertext (troca um byte)
    final cifrado = base64Decode(envelope['cifrado'] as String);
    final adulterado = [...cifrado];
    adulterado[0] = (adulterado[0] ^ 0x01) & 0xFF;
    envelope['cifrado'] = base64Encode(Uint8List.fromList(adulterado));

    final resultado = await backup.importarDeJson(jsonEncode(envelope));
    expect(resultado, contains('integridade'));
  });

  test('import rejeita envelope com MAC truncado/alterado', () async {
    await pacienteService.adicionarPaciente(novoPaciente());
    final snapshot = backup.exportarParaJson();
    final envelope = jsonDecode(snapshot) as Map<String, dynamic>;
    envelope['mac'] = '00' * 32;

    final resultado = await backup.importarDeJson(jsonEncode(envelope));
    expect(resultado, contains('integridade'));
  });

  test('import sem chave (sem PIN) rejeita envelope cifrado', () async {
    await pacienteService.adicionarPaciente(novoPaciente());
    final snapshot = backup.exportarParaJson();

    final backupSemPin = BackupService();
    final resultado = await backupSemPin.importarDeJson(snapshot);
    expect(resultado, contains('PIN'));
  });

  test('backward compat: JSON claro legado ainda importa', () async {
    final claro = jsonEncode({
      'versao': '2.0',
      'pacientes': [
        {
          'id': 'p1',
          'nome': 'Legado',
          'contato': '',
          'email': '',
          'tipo_atendimento': 'Particular',
          'observacoes': '',
          'ativo': true,
          'data_cadastro': '2026-07-01T00:00:00.000',
        }
      ],
    });

    final resultado = await backup.importarDeJson(claro);
    expect(resultado, contains('1 paciente(s)'));
    expect(pacienteService.buscarPacientePorId('p1')!.nome, 'Legado');
  });

  test('sem PIN (sem chave) export continua em claro (legado)', () async {
    final backupSemPin = BackupService();
    final pacSemPin = PacienteService();
    await pacSemPin.adicionarPaciente(novoPaciente());

    final saida = backupSemPin.exportarParaJson();
    final dados = jsonDecode(saida) as Map<String, dynamic>;
    expect(dados['pacientes'], isNotNull);
  });
}
