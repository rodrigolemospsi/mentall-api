import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/paciente.dart';
import 'package:prontuario_tcc/models/perfil_profissional.dart';
import 'package:prontuario_tcc/models/sessao.dart';
import 'package:prontuario_tcc/screens/paciente_detail_page.dart';

void main() {
  late Paciente paciente;

  setUpAll(() async {
    Hive.init('test/temp_hive/paciente_detail');
    Hive.registerAdapters();
    await Hive.openBox<Paciente>('pacientes');
    await Hive.openBox<Sessao>('sessoes');
    await Hive.openBox<PerfilProfissional>('perfil_profissional');
  });

  tearDownAll(() async {
    await Hive.box<Paciente>('pacientes').close();
    await Hive.box<Sessao>('sessoes').close();
    await Hive.box<PerfilProfissional>('perfil_profissional').close();
    await Hive.deleteBoxFromDisk('pacientes');
    await Hive.deleteBoxFromDisk('sessoes');
    await Hive.deleteBoxFromDisk('perfil_profissional');
  });

  setUp(() async {
    await Hive.box<Paciente>('pacientes').clear();
    await Hive.box<Sessao>('sessoes').clear();
    await Hive.box<PerfilProfissional>('perfil_profissional').clear();

    paciente = Paciente(id: '1', nome: 'Maria Silva');
    await Hive.box<Paciente>('pacientes').put('1', paciente);

    final perfil = PerfilProfissional(id: '1', nome: 'Dr. Teste');
    await Hive.box<PerfilProfissional>('perfil_profissional').put('1', perfil);
  });

  Widget criarApp() {
    return ProviderScope(
      child: MaterialApp(
        home: PacienteDetailPage(paciente: paciente),
      ),
    );
  }

  testWidgets('deve exibir nome do paciente no AppBar', (tester) async {
    await tester.pumpWidget(criarApp());
    await tester.pump();

    expect(find.text('Maria Silva'), findsAtLeastNWidgets(1));
  });

  testWidgets('deve exibir botoes de editar e exportar', (tester) async {
    await tester.pumpWidget(criarApp());
    await tester.pump();

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
    expect(find.text('Nova sessão'), findsOneWidget);
  });

  testWidgets('deve exibir card de resumo do paciente', (tester) async {
    await tester.pumpWidget(criarApp());
    await tester.pump();

    expect(find.textContaining('Particular'), findsOneWidget);
    expect(find.text('Ativo'), findsOneWidget);
  });

  testWidgets('deve mostrar que nao ha sessoes', (tester) async {
    await tester.pumpWidget(criarApp());
    await tester.pump();

    expect(find.text('Nenhuma sessão ativa'), findsOneWidget);
  });

  testWidgets('deve listar sessoes ativas do paciente', (tester) async {
    await tester.runAsync(() async {
      await Hive.box<Sessao>('sessoes').put('1', Sessao(
        id: '1',
        pacienteId: '1',
        numeroSessao: 1,
        data: DateTime.now(),
        temaPrincipal: 'Ansiedade',
      ));
    });

    await tester.pumpWidget(criarApp());
    await tester.pump();

    expect(find.textContaining('Sessão'), findsOneWidget);
  });

  testWidgets('deve abrir dialog de edicao ao tocar em editar', (tester) async {
    await tester.pumpWidget(criarApp());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pump();

    expect(find.text('Editar paciente'), findsOneWidget);
    expect(find.text('Salvar'), findsOneWidget);
  });
}
