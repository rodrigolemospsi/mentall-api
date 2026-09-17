import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/models/paciente.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';
import 'package:prontuario_tcc/services/paciente_service.dart';
import 'package:prontuario_tcc/widgets/novo_paciente_dialog.dart';

void main() {
  late Directory dir;
  late EncryptionService encryption;

  setUp(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    dir = await Directory.systemTemp.createTemp('novo_paciente_test_');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(PacienteAdapter());
    await Hive.openBox<Paciente>('pacientes');
    encryption = EncryptionService();
    await encryption.gerarChave();
  });

  tearDown(() async {
    WidgetController.hitTestWarningShouldBeFatal = false;
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Finder campo(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => TextButton(
        onPressed: () => mostrarDialogNovoPaciente(
          context: context,
          pacienteService: PacienteService(encryption: encryption),
          termoSingular: 'paciente',
          termoSingularCapitalizado: 'Paciente',
          novoOuNova: 'Novo',
          cadastradoOuCadastrada: 'cadastrado',
          doOuDa: 'do',
        ),
        child: const Text('Novo'),
      ),
    ))));
    await tester.tap(find.text('Novo'));
    await tester.pumpAndSettle();
    await tester.enterText(campo('Nome completo'), 'Paciente sintetico');
    await tester.ensureVisible(campo('Data de nascimento'));
  }

  testWidgets('mascara permite digitar e apagar ano parcial', (tester) async {
    await abrir(tester);
    for (final digits in ['2', '29', '290', '2902', '29022', '290220',
      '2902200', '29022000', '2902200', '290220', '29022', '2902', '29', '2', '']) {
      await tester.enterText(campo('Data de nascimento'), digits);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'Entrada: $digits');
      final text = tester.widget<TextField>(campo('Data de nascimento')).controller!.text;
      expect(text.replaceAll('/', ''), digits);
    }
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  for (final invalid in ['29/02/', '31/02/2000', '29/02/2001', '01/13/2000', '01/01/0000', '01/01/9999']) {
    testWidgets('rejeita $invalid e permite corrigir e salvar no mesmo dialogo', (tester) async {
      await abrir(tester);
      await tester.enterText(campo('Data de nascimento'), invalid);
      await tester.runAsync(() async {
        await tester.tap(find.text('Salvar'));
        await Hive.box<Paciente>('pacientes').flush();
      });
      await tester.pump();
      expect(Hive.box<Paciente>('pacientes').isEmpty, isTrue);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.widget<TextField>(campo('Data de nascimento')).decoration!.errorText, isNotNull);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);

      await tester.ensureVisible(campo('Data de nascimento'));
      await tester.enterText(campo('Data de nascimento'), '29022000');
      await tester.runAsync(() async {
        await tester.tap(find.text('Salvar'));
        await Hive.box<Paciente>('pacientes').flush();
      });
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.runAsync(() async {
        await Hive.box<Paciente>('pacientes').close();
        await Hive.openBox<Paciente>('pacientes');
      });
      final saved = Hive.box<Paciente>('pacientes').values.single;
      expect(encryption.descriptografar(saved.nome), 'Paciente sintetico');
      expect(saved.dataNascimento, DateTime(2000, 2, 29));
    });
  }
}
