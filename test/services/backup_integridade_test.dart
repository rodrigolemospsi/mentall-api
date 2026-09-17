import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/contrato_terapeutico.dart';
import 'package:prontuario_tcc/models/paciente.dart';
import 'package:prontuario_tcc/models/pacote.dart';
import 'package:prontuario_tcc/models/perfil_profissional.dart';
import 'package:prontuario_tcc/models/progresso_sessao.dart';
import 'package:prontuario_tcc/models/sessao.dart';
import 'package:prontuario_tcc/services/backup_agendamento_service.dart';
import 'package:prontuario_tcc/services/backup_service.dart';
import 'package:prontuario_tcc/services/configuracoes_service.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';
import 'package:prontuario_tcc/services/paciente_service.dart';
import 'package:prontuario_tcc/services/progresso_service.dart';

class _FalhaEnvelope extends EncryptionService {
  @override
  String? criptografarEnvelope(String jsonClaro) => null;
}

void main() {
  late Directory dir;
  late EncryptionService encryption;
  late BackupService backup;
  late PacienteService pacientes;
  late List<Box> boxes;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('mentall_backup_integridade_');
    Hive.init(dir.path);
    Hive.registerAdapters();
    await Hive.openBox<String>('encryption_meta');
    await Hive.openBox<String>('app_config');
    await Hive.openBox<Paciente>('pacientes');
    await Hive.openBox<Sessao>('sessoes');
    await Hive.openBox<PerfilProfissional>('perfil_profissional');
    await Hive.openBox<ContratoTerapeutico>('contratos');
    await Hive.openBox<Pacote>('pacotes');
    await Hive.openBox<ProgressoSessao>('progresso_sessoes');
    boxes = [
      Hive.box<String>('encryption_meta'),
      Hive.box<String>('app_config'),
      Hive.box<Paciente>('pacientes'),
      Hive.box<Sessao>('sessoes'),
      Hive.box<PerfilProfissional>('perfil_profissional'),
      Hive.box<ContratoTerapeutico>('contratos'),
      Hive.box<Pacote>('pacotes'),
      Hive.box<ProgressoSessao>('progresso_sessoes'),
    ];
  });

  setUp(() async {
    boxes[2] = Hive.box<Paciente>('pacientes');
    for (final box in boxes) {
      await box.clear();
    }
    encryption = EncryptionService();
    await encryption.gerarChave();
    backup = BackupService(encryption: encryption);
    pacientes = PacienteService(encryption: encryption);
    await pacientes.adicionarPaciente(
      Paciente(id: 'p1', nome: 'Original', dataCadastro: DateTime(2026, 9, 1)),
    );
  });

  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('agendamento real salva uma camada e restaura os registros', () async {
    final config = ConfiguracoesService();
    final agendamento = BackupAgendamentoService(
      configuracoes: config,
      backupService: backup,
    );
    final caminho = await agendamento.executar(diretorio: dir.path);
    expect(caminho, isNotNull);
    final arquivo = await File(caminho!).readAsString();
    final claro = jsonDecode(encryption.descriptografarEnvelope(arquivo)!);
    expect(claro['versao'], '2.0');
    await Hive.box<Paciente>('pacientes').clear();
    expect(await backup.importarDeJson(arquivo), contains('1 paciente(s)'));
    expect(pacientes.buscarPacientePorId('p1')!.nome, 'Original');
    expect(config.ultimoBackupEm, isNotNull);
  });

  test('importa envelope duplo ja emitido pelo agendamento antigo', () async {
    final duplo = encryption.criptografarEnvelope(backup.exportarParaJson())!;
    await Hive.box<Paciente>('pacientes').clear();
    expect(await backup.importarDeJson(duplo), contains('1 paciente(s)'));
    expect(pacientes.buscarPacientePorId('p1')!.nome, 'Original');
  });

  test('rejeita terceira camada de envelope sem modificar registros', () async {
    final duplo = encryption.criptografarEnvelope(backup.exportarParaJson())!;
    final triplo = encryption.criptografarEnvelope(duplo)!;
    expect(await backup.importarDeJson(triplo), isNot(contains('concluída')));
    expect(pacientes.buscarPacientePorId('p1')!.nome, 'Original');
  });

  test('falha de cifragem nao exporta dados claros', () async {
    final falha = _FalhaEnvelope();
    await falha.gerarChave();
    expect(BackupService(encryption: falha).exportarParaJson, throwsStateError);
  });

  test('falha de cifragem nao grava arquivo nem marca sucesso', () async {
    final falha = _FalhaEnvelope();
    await falha.gerarChave();
    final destino = await dir.createTemp('saida_');
    final config = ConfiguracoesService();
    final agendamento = BackupAgendamentoService(
      configuracoes: config,
      backupService: BackupService(encryption: falha),
    );
    expect(await agendamento.executar(diretorio: destino.path), isNull);
    expect(await destino.list().toList(), isEmpty);
    expect(config.ultimoBackupEm, isNull);
  });

  test('sem chave nao exporta nem importa legado em claro', () async {
    final semChave = BackupService();
    expect(semChave.exportarParaJson, throwsStateError);
    final resultado = await semChave.importarDeJson(
      jsonEncode({
        'versao': '2.0',
        'pacientes': [
          {'id': 'p2', 'nome': 'Novo'},
        ],
      }),
    );
    expect(resultado, isNot(contains('concluída')));
    expect(Hive.box<Paciente>('pacientes').length, 1);
  });

  test('registro invalido no fim nao sobrescreve paciente anterior', () async {
    final resultado = await backup.importarDeJson(
      jsonEncode({
        'versao': '2.0',
        'pacientes': [
          {'id': 'p1', 'nome': 'Sobrescrito'},
        ],
        'progresso_sessoes': [
          {'id': 42, 'paciente_id': 'p1'},
        ],
      }),
    );
    expect(resultado, isNot(contains('concluída')));
    await Hive.box<Paciente>('pacientes').close();
    await Hive.openBox<Paciente>('pacientes');
    pacientes = PacienteService(encryption: encryption);
    expect(pacientes.buscarPacientePorId('p1')!.nome, 'Original');
  });

  test('versao desconhecida nao modifica registros', () async {
    final resultado = await backup.importarDeJson(
      jsonEncode({
        'versao': '999',
        'pacientes': [
          {'id': 'p1', 'nome': 'Sobrescrito'},
        ],
      }),
    );
    expect(resultado, isNot(contains('concluída')));
    expect(pacientes.buscarPacientePorId('p1')!.nome, 'Original');
  });

  test('ids duplicados sao rejeitados antes de sobrescrever', () async {
    final resultado = await backup.importarDeJson(
      jsonEncode({
        'versao': '2.0',
        'pacientes': [
          {'id': 'p1', 'nome': 'Primeiro'},
          {'id': 'p1', 'nome': 'Segundo'},
        ],
      }),
    );
    expect(resultado, isNot(contains('concluída')));
    expect(pacientes.buscarPacientePorId('p1')!.nome, 'Original');
  });

  test('referencia a paciente ausente rejeita todo o arquivo', () async {
    final resultado = await backup.importarDeJson(
      jsonEncode({
        'versao': '2.0',
        'pacientes': [
          {'id': 'p1', 'nome': 'Sobrescrito'},
        ],
        'sessoes': [
          {'id': 's1', 'paciente_id': 'ausente'},
        ],
      }),
    );
    expect(resultado, isNot(contains('concluída')));
    expect(pacientes.buscarPacientePorId('p1')!.nome, 'Original');
    expect(Hive.box<Sessao>('sessoes').isEmpty, isTrue);
  });

  test('progresso nao pode apontar para sessao de outro paciente', () async {
    final resultado = await backup.importarDeJson(
      jsonEncode({
        'versao': '2.0',
        'pacientes': [
          {'id': 'p2', 'nome': 'Outro'},
        ],
        'sessoes': [
          {'id': 's1', 'paciente_id': 'p1'},
        ],
        'progresso_sessoes': [
          {'id': 'g1', 'paciente_id': 'p2', 'sessao_id': 's1'},
        ],
      }),
    );
    expect(resultado, isNot(contains('concluída')));
    expect(Hive.box<Paciente>('pacientes').length, 1);
    expect(Hive.box<Sessao>('sessoes').isEmpty, isTrue);
  });

  test(
    'restaura estrutura 1.0 sem secoes adicionadas posteriormente',
    () async {
      final resultado = await backup.importarDeJson(
        jsonEncode({
          'versao': '1.0',
          'perfil_profissional': [
            {
              'id': 'perfil',
              'nome': 'Profissional',
              'registro_profissional': '00/12345',
              'abordagem_clinica': 'TCC',
              'termo_pessoa_atendida': 'paciente',
              'data_criacao': '2026-01-01T00:00:00.000',
            },
          ],
          'pacientes': [
            {
              'id': 'p1',
              'nome': 'Legado',
              'data_nascimento': null,
              'contato': '',
              'tipo_atendimento': 'Particular',
              'observacoes': '',
              'ativo': true,
              'data_cadastro': '2026-01-01T00:00:00.000',
            },
          ],
          'sessoes': [
            {
              'id': 's1',
              'paciente_id': 'p1',
              'numero_sessao': 1,
              'data': '2026-01-01T10:00:00.000',
              'humor': 5,
              'relato_pos_sessao': 'Registro legado',
            },
          ],
        }),
      );
      expect(resultado, contains('1 paciente(s)'));
      await Hive.box<Paciente>('pacientes').close();
      await Hive.openBox<Paciente>('pacientes');
      expect(
        PacienteService(encryption: encryption).buscarPacientePorId('p1')!.nome,
        'Legado',
      );
      final sessao = Hive.box<Sessao>('sessoes').values.single;
      expect(
        encryption.descriptografar(sessao.relatoPosSessao),
        'Registro legado',
      );
      expect(sessao.statusPagamento, 'pendente');
      expect(Hive.box<PerfilProfissional>('perfil_profissional').length, 1);
    },
  );

  test(
    'progresso antecipado sem sessao salva nao impede restaurar backup real',
    () async {
      final progresso = ProgressoService(encryption: encryption);
      progresso.salvar(
        pacienteId: 'p1',
        sessaoId: 'ainda-nao-salva',
        numeroSessao: 2,
        sintomas: [],
        metas: [],
        avaliacaoGeral: 'Avaliacao preliminar',
        tendencia: 'estavel',
      );
      await Hive.box<ProgressoSessao>('progresso_sessoes').flush();
      final arquivo = backup.exportarParaJson();
      await Hive.box<Paciente>('pacientes').clear();
      await Hive.box<ProgressoSessao>('progresso_sessoes').clear();
      expect(await backup.importarDeJson(arquivo), contains('1 paciente(s)'));
      expect(pacientes.buscarPacientePorId('p1')!.nome, 'Original');
      expect(
        progresso.obterPorPaciente('p1').single.avaliacaoGeral,
        'Avaliacao preliminar',
      );
      expect(Hive.box<Sessao>('sessoes').isEmpty, isTrue);
    },
  );
}
