import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/compromisso.dart';
import 'package:prontuario_tcc/models/enums.dart';
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
    await tester.pumpWidget(
      MaterialApp(
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
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> abrirCriacao(
    WidgetTester tester,
    void Function(Compromisso?) onResult,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final resultado = await mostrarCompromissoFormDialog(
                  context: context,
                  pacientes: [paciente],
                  termoPessoa: 'Paciente',
                  compromissoService: CompromissoService(
                    encryption: encryption,
                  ),
                );
                onResult(resultado);
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  Finder campoTitulo() => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == 'Título (opcional)',
  );

  testWidgets('Cancelar sem alteracoes fecha direto, sem confirmacao', (
    tester,
  ) async {
    await abrir(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar alterações?'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'Cancelar com alteracoes pede confirmacao; continuar e descartar',
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
    },
  );

  Compromisso existente({
    String? paiId,
    String recorrencia = '',
    DateTime? limite,
  }) {
    return Compromisso(
      id: 'c1',
      pacienteId: 'p1',
      dataHoraInicio: DateTime(2026, 8, 25, 10),
      dataHoraFim: DateTime(2026, 8, 25, 11),
      titulo: 'Sessão',
      recorrencia: recorrencia,
      dataLimiteRecorrencia: limite,
      compromissoPaiId: paiId,
    );
  }

  Future<Compromisso?> editar(WidgetTester tester, Compromisso c) async {
    Compromisso? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                resultado = await mostrarCompromissoFormDialog(
                  context: context,
                  pacientes: [paciente],
                  termoPessoa: 'Paciente',
                  compromissoExistente: c,
                  compromissoService: CompromissoService(
                    encryption: encryption,
                  ),
                );
              },
              child: const Text('Editar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    return resultado;
  }

  testWidgets('editar o compromisso pai preserva a recorrência', (
    tester,
  ) async {
    final limite = DateTime(2026, 12, 31);
    final resultado = await editar(
      tester,
      existente(
        recorrencia: FrequenciaRecorrencia.semanal.value,
        limite: limite,
      ),
    );

    expect(resultado, isNotNull);
    expect(resultado!.recorrencia, FrequenciaRecorrencia.semanal.value);
    expect(resultado.dataLimiteRecorrencia, limite);
  });

  testWidgets('editar uma ocorrência preserva o vínculo com o pai', (
    tester,
  ) async {
    final resultado = await editar(tester, existente(paiId: 'pai-1'));

    expect(resultado, isNotNull);
    expect(resultado!.compromissoPaiId, 'pai-1');
  });

  testWidgets('evento geral salva sem paciente', (tester) async {
    Compromisso? resultado;
    await abrirCriacao(tester, (r) => resultado = r);

    await tester.tap(find.text('Sessão'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Evento geral').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    expect(resultado, isNotNull);
    expect(resultado!.tipoEvento, 'evento_geral');
    expect(resultado!.pacienteId, '');
    expect(resultado!.modalidade, 'presencial');
    expect(resultado!.lembreteAtivado, false);
  });
}
