import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/compromisso.dart';
import 'package:prontuario_tcc/models/contrato_terapeutico.dart';
import 'package:prontuario_tcc/models/paciente.dart';
import 'package:prontuario_tcc/models/pacote.dart';
import 'package:prontuario_tcc/models/perfil_profissional.dart';
import 'package:prontuario_tcc/models/progresso_sessao.dart';
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
    await Hive.openBox<Compromisso>('compromissos');
    await Hive.openBox<ContratoTerapeutico>('contratos');
    await Hive.openBox('anamneses_enviadas');
    await Hive.openBox('avaliacoes_iniciais');
    await Hive.openBox('respostas_escalas');
    await Hive.openBox<String>('app_config');
    await Hive.openBox<Pacote>('pacotes');
    await Hive.openBox<ProgressoSessao>('progresso_sessoes');
    await Hive.openBox<String>('auth_meta');
    await Hive.openBox<String>('encryption_meta');
    await Hive.openBox('auditoria');
  });

  tearDownAll(() async {
    await Hive.box<Paciente>('pacientes').close();
    await Hive.box<Sessao>('sessoes').close();
    await Hive.box<PerfilProfissional>('perfil_profissional').close();
    await Hive.deleteBoxFromDisk('pacientes');
    await Hive.deleteBoxFromDisk('sessoes');
    await Hive.deleteBoxFromDisk('perfil_profissional');
    await Hive.deleteBoxFromDisk('compromissos');
    await Hive.deleteBoxFromDisk('contratos');
    await Hive.deleteBoxFromDisk('anamneses_enviadas');
    await Hive.deleteBoxFromDisk('avaliacoes_iniciais');
    await Hive.deleteBoxFromDisk('respostas_escalas');
    await Hive.deleteBoxFromDisk('app_config');
    await Hive.box<Pacote>('pacotes').close();
    await Hive.deleteBoxFromDisk('pacotes');
    await Hive.box<ProgressoSessao>('progresso_sessoes').close();
    await Hive.deleteBoxFromDisk('progresso_sessoes');
    await Hive.box<String>('auth_meta').close();
    await Hive.deleteBoxFromDisk('auth_meta');
    await Hive.box<String>('encryption_meta').close();
    await Hive.deleteBoxFromDisk('encryption_meta');
    await Hive.deleteBoxFromDisk('auditoria');
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
        home: MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: PacienteDetailPage(paciente: paciente),
        ),
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

    expect(find.byIcon(Icons.edit_outlined), findsAtLeastNWidgets(1));
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
    await tester.pump();
    await tester.pump();

    await tester.tap(find.textContaining('Sessões ('));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

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
    await tester.pump();
    await tester.pump();

    await tester.tap(find.textContaining('Sessões ('));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Sessão 1'), findsOneWidget);
  });

  testWidgets('deve abrir dialog de edicao ao tocar em editar', (tester) async {
    await tester.pumpWidget(criarApp());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pump();
    await tester.pump();

    expect(find.text('Editar paciente'), findsOneWidget);
    expect(find.text('Salvar'), findsOneWidget);
  });
}
