import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prontuario_tcc/screens/lgpd/politica_privacidade_page.dart';
import 'package:prontuario_tcc/screens/lgpd/termos_uso_page.dart';
import 'package:prontuario_tcc/utils/links_legais.dart';

/// Canal nativo do url_launcher: o teste intercepta para conferir a URL exata
/// que o app manda abrir (sem tocar no navegador).
const MethodChannel _canalUrlLauncher =
    MethodChannel('plugins.flutter.io/url_launcher');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var lancadas = <String>[];

  setUp(() {
    lancadas = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canalUrlLauncher, (call) async {
      if (call.method == 'launch') {
        final argumentos = (call.arguments as Map).cast<String, Object?>();
        lancadas.add(argumentos['url'] as String);
        return true;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canalUrlLauncher, null);
  });

  Future<void> telaGrande(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  test('LinksLegais.abrir envia a URL oficial ao navegador', () async {
    final abriu = await LinksLegais.abrir(LinksLegais.privacidade);

    expect(abriu, isTrue);
    expect(lancadas, <String>[LinksLegais.privacidade]);
  });

  test('as URLs oficiais apontam para o domínio publicado', () {
    expect(LinksLegais.privacidade, 'https://mentallpro.com.br/privacidade/');
    expect(LinksLegais.termos, 'https://mentallpro.com.br/termos/');
    expect(LinksLegais.exclusaoConta, 'https://mentallpro.com.br/exclusao/');
    expect(LinksLegais.versaoPublicada, contains('1.2'));
  });

  testWidgets('política in-app mostra a versão publicada e abre o site',
      (tester) async {
    await telaGrande(tester);
    await tester.pumpWidget(const MaterialApp(home: PoliticaPrivacidadePage()));

    expect(find.textContaining('Versão 1.2'), findsOneWidget);
    expect(
      find.textContaining('mentallpro.com.br/privacidade'),
      findsWidgets,
    );

    await tester.tap(find.text('Ler a versão oficial no site'));
    await tester.pumpAndSettle();

    expect(lancadas, contains(LinksLegais.privacidade));
  });

  testWidgets('termos in-app mostra a versão publicada e abre o site',
      (tester) async {
    await telaGrande(tester);
    await tester.pumpWidget(const MaterialApp(home: TermosUsoPage()));

    expect(find.textContaining('Versão 1.2'), findsOneWidget);
    expect(find.textContaining('mentallpro.com.br/termos'), findsWidgets);

    await tester.tap(find.text('Ler a versão oficial no site'));
    await tester.pumpAndSettle();

    expect(lancadas, contains(LinksLegais.termos));
  });
}
