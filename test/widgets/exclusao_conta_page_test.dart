import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prontuario_tcc/screens/exclusao_conta_page.dart';

Widget _app({
  Future<Map<String, dynamic>> Function(String)? excluirConta,
  Future<void> Function()? limparSessao,
  VoidCallback? aoConcluir,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: ExclusaoContaPage(
        contaEmail: 'psi@exemplo.com',
        excluirConta: excluirConta ??
            (_) async => <String, dynamic>{'sucesso': true},
        limparSessao: limparSessao ?? () async {},
        aoConcluir: aoConcluir,
      ),
    ),
  );
}

/// Viewport alto o suficiente para a lista (que é lazy) construir todos os
/// cartões e botões da tela de exclusão sem precisar de scroll nos testes.
Future<void> _telaGrande(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _avancarParaConfirmacao(WidgetTester tester) async {
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
}

Future<void> _digitar(WidgetTester tester, String texto) async {
  await tester.enterText(find.byType(TextField), texto);
  await tester.pump();
}

FilledButton _botaoExcluir(WidgetTester tester) {
  return tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'Excluir conta definitivamente'),
  );
}

Map<String, dynamic> _reciboExemplo({bool jaExcluida = false}) {
  return <String, dynamic>{
    'sucesso': true,
    'ja_excluida': jaExcluida,
    'quando': '2026-10-23T18:00:00+00:00',
    'eliminado': <String, dynamic>{
      'usuarios': 1,
      'contratos': 2,
      'anamneses': 0,
      'recuperacoes': 1,
    },
    'retido': <String, dynamic>{
      'prontuario':
          'O prontuário clínico cifrado permanece no aparelho do profissional.',
    },
  };
}

void main() {
  testWidgets('aviso explica o que é apagado e o que permanece no aparelho',
      (tester) async {
    await _telaGrande(tester);
    await tester.pumpWidget(_app());
    expect(find.text('Passo 1 de 3 — Aviso'), findsOneWidget);
    expect(find.textContaining('prontuário clínico cifrado'), findsWidgets);
    expect(find.textContaining('Contratos terapêuticos'), findsOneWidget);
    expect(find.textContaining('Google Calendar'), findsOneWidget);

    await _avancarParaConfirmacao(tester);
    expect(find.text('Passo 2 de 3 — Confirmação'), findsOneWidget);
    expect(find.textContaining('psi@exemplo.com'), findsOneWidget);
  });

  testWidgets('só habilita a exclusão depois de digitar EXCLUIR',
      (tester) async {
    await _telaGrande(tester);
    await tester.pumpWidget(_app());
    await _avancarParaConfirmacao(tester);

    expect(_botaoExcluir(tester).onPressed, isNull);
    await _digitar(tester, 'EXCLUI');
    expect(_botaoExcluir(tester).onPressed, isNull);
    // A comparação é sem caixa (o backend também usa upper()).
    await _digitar(tester, 'excluir');
    expect(_botaoExcluir(tester).onPressed, isNotNull);
  });

  testWidgets('sucesso mostra recibo, limpa a sessão e lista o que foi apagado',
      (tester) async {
    await _telaGrande(tester);
    String? confirmacaoEnviada;
    var limpouSessao = false;

    await tester.pumpWidget(
      _app(
        excluirConta: (confirmacao) async {
          confirmacaoEnviada = confirmacao;
          return <String, dynamic>{
            'sucesso': true,
            'recibo': _reciboExemplo(),
          };
        },
        limparSessao: () async {
          limpouSessao = true;
        },
      ),
    );
    await _avancarParaConfirmacao(tester);
    await _digitar(tester, 'EXCLUIR');
    await tester.tap(find.text('Excluir conta definitivamente'));
    await tester.pumpAndSettle();

    expect(confirmacaoEnviada, 'EXCLUIR');
    expect(limpouSessao, isTrue);
    expect(find.text('Passo 3 de 3 — Recibo'), findsOneWidget);
    expect(find.text('Conta excluída'), findsOneWidget);
    expect(find.textContaining('Concluído em'), findsOneWidget);
    expect(find.text('Conta e login: 1'), findsOneWidget);
    expect(find.text('Contratos terapêuticos: 2'), findsOneWidget);
    expect(find.text('Pedidos de recuperação: 1'), findsOneWidget);
    expect(find.text('Respostas de anamnese: 0'), findsNothing);
    expect(
      find.textContaining('permanece no aparelho do profissional'),
      findsWidgets,
    );
    expect(find.textContaining('Política de Privacidade'), findsWidgets);
  });

  testWidgets('erro da conta administrativa é exibido sem gerar recibo',
      (tester) async {
    await _telaGrande(tester);
    await tester.pumpWidget(
      _app(
        excluirConta: (_) async => <String, dynamic>{
          'sucesso': false,
          'status': 403,
          'erro': 'A conta administrativa não pode ser excluída pelo aplicativo.',
        },
      ),
    );
    await _avancarParaConfirmacao(tester);
    await _digitar(tester, 'EXCLUIR');
    await tester.tap(find.text('Excluir conta definitivamente'));
    await tester.pumpAndSettle();

    expect(
      find.text('A conta administrativa não pode ser excluída pelo aplicativo.'),
      findsOneWidget,
    );
    expect(find.text('Conta excluída'), findsNothing);
    expect(find.text('Passo 2 de 3 — Confirmação'), findsOneWidget);
  });

  testWidgets('falha de conexão permite tentar de novo', (tester) async {
    await _telaGrande(tester);
    var chamadas = 0;
    await tester.pumpWidget(
      _app(
        excluirConta: (_) async {
          chamadas++;
          if (chamadas == 1) {
            return <String, dynamic>{
              'sucesso': false,
              'erro': 'Erro de conexão. Verifique a internet e tente novamente.',
            };
          }
          return <String, dynamic>{
            'sucesso': true,
            'recibo': _reciboExemplo(),
          };
        },
      ),
    );
    await _avancarParaConfirmacao(tester);
    await _digitar(tester, 'EXCLUIR');
    await tester.tap(find.text('Excluir conta definitivamente'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Erro de conexão'), findsOneWidget);

    await tester.tap(find.text('Excluir conta definitivamente'));
    await tester.pumpAndSettle();

    expect(chamadas, 2);
    expect(find.text('Conta excluída'), findsOneWidget);
  });

  testWidgets('recibo informa quando a conta já estava excluída',
      (tester) async {
    await _telaGrande(tester);
    await tester.pumpWidget(
      _app(
        excluirConta: (_) async => <String, dynamic>{
          'sucesso': true,
          'recibo': _reciboExemplo(jaExcluida: true),
        },
      ),
    );
    await _avancarParaConfirmacao(tester);
    await _digitar(tester, 'EXCLUIR');
    await tester.tap(find.text('Excluir conta definitivamente'));
    await tester.pumpAndSettle();

    expect(find.text('A conta já estava excluída'), findsOneWidget);
  });

  testWidgets('concluir aciona a navegação de saída', (tester) async {
    await _telaGrande(tester);
    var concluiu = false;
    await tester.pumpWidget(
      _app(
        excluirConta: (_) async => <String, dynamic>{
          'sucesso': true,
          'recibo': _reciboExemplo(),
        },
        aoConcluir: () {
          concluiu = true;
        },
      ),
    );
    await _avancarParaConfirmacao(tester);
    await _digitar(tester, 'EXCLUIR');
    await tester.tap(find.text('Excluir conta definitivamente'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Concluir'));
    await tester.pump();

    expect(concluiu, isTrue);
  });
}
