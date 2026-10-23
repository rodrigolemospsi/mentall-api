import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prontuario_tcc/screens/exportar_tudo_page.dart';

const _resumo = ResumoExportacaoCompleta(
  pacientes: 3,
  ativos: 2,
  sessoes: 5,
  contratos: 2,
  anamneses: 1,
);

Widget _app({
  Future<void> Function()? exportar,
  Future<bool> Function()? autenticar,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: ExportarTudoPage(
        resumo: () => _resumo,
        exportar: exportar ?? () async {},
        autenticar: autenticar ?? () async => true,
      ),
    ),
  );
}

/// Viewport alto para a lista (lazy) construir todos os cartões e o botão.
Future<void> _telaGrande(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('mostra o resumo do acervo e os avisos de segurança',
      (tester) async {
    await _telaGrande(tester);
    await tester.pumpWidget(_app());

    expect(find.text('O que será exportado'), findsOneWidget);
    expect(find.text('3 (2 ativos)'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.textContaining('NÃO são cifrados'), findsOneWidget);
    expect(find.textContaining('não substitui o backup'), findsOneWidget);
    expect(find.text('Exportar tudo em PDF'), findsWidgets);
  });

  testWidgets('exporta quando a autenticação é aprovada', (tester) async {
    await _telaGrande(tester);
    var exportou = false;
    await tester.pumpWidget(
      _app(
        exportar: () async {
          exportou = true;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('botao_exportar_tudo')));
    await tester.pumpAndSettle();

    expect(exportou, isTrue);
    expect(find.text('Exportação concluída. Se o compartilhamento foi fechado '
        'sem salvar, toque no botão novamente para gerar os arquivos.'), findsOneWidget);
  });

  testWidgets('não exporta quando a autenticação é recusada', (tester) async {
    await _telaGrande(tester);
    var exportou = false;
    await tester.pumpWidget(
      _app(
        autenticar: () async => false,
        exportar: () async {
          exportou = true;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('botao_exportar_tudo')));
    await tester.pumpAndSettle();

    expect(exportou, isFalse);
    expect(
      find.text('Autenticação necessária para exportar dados clínicos.'),
      findsOneWidget,
    );
  });

  testWidgets('mostra erro quando a geração falha', (tester) async {
    await _telaGrande(tester);
    await tester.pumpWidget(
      _app(
        exportar: () async => throw StateError('falha simulada'),
      ),
    );

    await tester.tap(find.byKey(const Key('botao_exportar_tudo')));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível gerar os PDFs. Tente novamente.'),
      findsOneWidget,
    );
  });
}
