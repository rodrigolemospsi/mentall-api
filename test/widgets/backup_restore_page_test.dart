import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/providers/service_providers.dart';
import 'package:prontuario_tcc/screens/backup_restore_page.dart';
import 'package:prontuario_tcc/services/backup_agendamento_service.dart';
import 'package:prontuario_tcc/services/backup_service.dart';
import 'package:prontuario_tcc/services/configuracoes_service.dart';

class _FakeConfiguracoes extends ConfiguracoesService {
  String frequencia = 'off';

  @override
  String get backupFrequencia => frequencia;

  @override
  Future<void> setBackupFrequencia(String v) async {
    frequencia = v;
  }

  @override
  String get backupLocal => '';

  @override
  DateTime? get ultimoBackupEm => null;

  @override
  Stream<BoxEvent> observar() => const Stream<BoxEvent>.empty();
}

class _FakeBackupAgendamento extends BackupAgendamentoService {
  _FakeBackupAgendamento()
      : super(
          configuracoes: ConfiguracoesService(),
          backupService: BackupService(),
        );

  int chamadas = 0;

  @override
  Future<String?> executar({String? diretorio, DateTime? agora}) async {
    chamadas++;
    return '/tmp/backup.json';
  }
}

void main() {
  late _FakeConfiguracoes fakeConfig;
  late _FakeBackupAgendamento fakeAgendamento;

  setUp(() {
    fakeConfig = _FakeConfiguracoes();
    fakeAgendamento = _FakeBackupAgendamento();
  });

  Widget app() => ProviderScope(
        overrides: [
          configuracoesServiceProvider.overrideWithValue(fakeConfig),
          backupAgendamentoServiceProvider.overrideWithValue(fakeAgendamento),
        ],
        child: const MaterialApp(home: BackupRestorePage()),
      );

  testWidgets('renderiza exportar/importar e o backup automatico',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Backup e dados'), findsOneWidget);
    expect(find.text('Exportar backup'), findsOneWidget);
    expect(find.text('Importar backup'), findsOneWidget);

    // O card de backup automático fica abaixo do viewport (ListView preguiçosa).
    await tester.scrollUntilVisible(
      find.text('Fazer agora'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Backup automático'), findsOneWidget);
    expect(find.text('Frequência'), findsOneWidget);
    expect(find.text('Último backup'), findsOneWidget);
    expect(find.text('Fazer agora'), findsOneWidget);
  });

  testWidgets('muda a frequencia do backup e persiste', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Frequência'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diário').last);
    await tester.pumpAndSettle();

    expect(fakeConfig.frequencia, 'diario');
  });

  testWidgets('Fazer agora dispara o backup agendado', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Fazer agora'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Fazer agora'));
    await tester.pumpAndSettle();

    expect(fakeAgendamento.chamadas, 1);
    expect(find.textContaining('Backup salvo em'), findsOneWidget);
  });
}
