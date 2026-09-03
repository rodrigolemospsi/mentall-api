import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/services/backup_agendamento_service.dart';
import 'package:prontuario_tcc/services/backup_service.dart';
import 'package:prontuario_tcc/services/configuracoes_service.dart';

class _FakeBackup extends BackupService {
  _FakeBackup() : super(encryption: null);
  @override
  String exportarParaJson() => '{"versao":"2.0","teste":true}';
}

void main() {
  setUpAll(() async {
    Hive.init('test/temp_hive/backup_agendamento');
    Hive.registerAdapters();
    await Hive.openBox<String>('app_config');
  });

  tearDownAll(() async {
    await Hive.box<String>('app_config').close();
    await Hive.deleteBoxFromDisk('app_config');
  });

  setUp(() async {
    await Hive.box<String>('app_config').clear();
  });

  group('deveExecutarAgora', () {
    final agora = DateTime(2026, 9, 2, 12);

    test('off nunca executa', () {
      expect(
        BackupAgendamentoService.deveExecutarAgora(
          frequencia: 'off',
          ultimoBackup: null,
          agora: agora,
        ),
        isFalse,
      );
    });

    test('sem backup anterior, qualquer frequencia ativa dispara', () {
      for (final f in ['diario', 'semanal', 'mensal']) {
        expect(
          BackupAgendamentoService.deveExecutarAgora(
            frequencia: f,
            ultimoBackup: null,
            agora: agora,
          ),
          isTrue,
        );
      }
    });

    test('diario dispara apos 24h', () {
      final ultimo = agora.subtract(const Duration(days: 1, minutes: 1));
      expect(
        BackupAgendamentoService.deveExecutarAgora(
          frequencia: 'diario',
          ultimoBackup: ultimo,
          agora: agora,
        ),
        isTrue,
      );
      expect(
        BackupAgendamentoService.deveExecutarAgora(
          frequencia: 'diario',
          ultimoBackup: agora.subtract(const Duration(hours: 23)),
          agora: agora,
        ),
        isFalse,
      );
    });

    test('semanal dispara apos 7 dias; mensal apos 30', () {
      expect(
        BackupAgendamentoService.deveExecutarAgora(
          frequencia: 'semanal',
          ultimoBackup: agora.subtract(const Duration(days: 7)),
          agora: agora,
        ),
        isTrue,
      );
      expect(
        BackupAgendamentoService.deveExecutarAgora(
          frequencia: 'mensal',
          ultimoBackup: agora.subtract(const Duration(days: 30)),
          agora: agora,
        ),
        isTrue,
      );
      expect(
        BackupAgendamentoService.deveExecutarAgora(
          frequencia: 'mensal',
          ultimoBackup: agora.subtract(const Duration(days: 29)),
          agora: agora,
        ),
        isFalse,
      );
    });
  });

  test('executar escreve o arquivo e registra o ultimo backup', () async {
    final config = ConfiguracoesService();
    final svc = BackupAgendamentoService(
      configuracoes: config,
      backupService: _FakeBackup(),
      encryption: null,
    );

    final dir = Directory.systemTemp.createTempSync('mentall_backup_test');
    addTearDown(() => dir.deleteSync(recursive: true));

    final caminho = await svc.executar(diretorio: dir.path);
    expect(caminho, isNotNull);
    expect(File(caminho!).existsSync(), isTrue);
    expect(File(caminho).readAsStringSync(), contains('versao'));
    expect(config.ultimoBackupEm, isNotNull);
  });

  test('verificarEExecutar nao roda quando frequencia off', () async {
    final config = ConfiguracoesService(); // default 'off'
    final svc = BackupAgendamentoService(
      configuracoes: config,
      backupService: _FakeBackup(),
      encryption: null,
    );
    expect(await svc.verificarEExecutar(agora: DateTime(2026, 9, 2)), isNull);
  });
}
