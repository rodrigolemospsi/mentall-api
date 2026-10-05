import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/compromisso.dart';
import 'package:prontuario_tcc/models/paciente.dart';
import 'package:prontuario_tcc/services/compromisso_service.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';
import 'package:prontuario_tcc/widgets/compromisso_form_dialog.dart';

void main() {
  late Directory dir;
  late EncryptionService encryption;

  setUpAll(() async {
    Hive.registerAdapters();
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('compromisso_dialog_test_');
    Hive.init(dir.path);
    await Hive.openBox<Paciente>('pacientes');
    await Hive.openBox<Compromisso>('compromissos');
    encryption = EncryptionService();
    await encryption.gerarChave();
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  final paciente = Paciente(id: 'p1', nome: 'Paciente X');

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => mostrarCompromissoFormDialog(
              context: context,
              pacientes: [paciente],
              termoPessoa: 'Paciente',
              compromissoService: CompromissoService(encryption: encryption),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  Finder campoTitulo() => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Título (opcional)',
      );

  testWidgets('Cancelar sem alteracoes fecha direto, sem confirmacao',
      (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar alterações?'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Cancelar com alteracoes pede confirmacao; continuar e descartar',
      (tester) async {
    await abrir(tester);
    await tester.enterText(campoTitulo(), 'Sessão teste');
    await tester.pump();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar alterações?'), findsOneWidget);

    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar alterações?'), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
