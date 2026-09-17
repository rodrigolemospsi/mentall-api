import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:prontuario_tcc/services/auth_service.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';

/// Verificação NO APARELHO do platform channel do `local_auth`.
///
/// Os testes de widget usam um gate falso (`_FakeGate`) e NÃO exercitam o
/// plugin nativo. Foi assim que o `MainActivity` voltou a ser `FlutterActivity`
/// e a biometria parou de funcionar sem nenhum teste falhar. Este teste chama o
/// plugin de verdade e falha se o aparelho (com biometria cadastrada) deixar de
/// expô-la para o app.
///
/// Rodar em aparelho COM biometria cadastrada:
///   flutter test integration_test/biometria_smoke_test.dart -d `<device>`
///
/// Não lança o app (o que dispararia o prompt do sistema e travaria a execução
/// automática) — valida apenas o canal nativo.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('o aparelho expoe biometria para o app', (tester) async {
    final auth = AuthService(EncryptionService());

    final suporta = await auth.dispositivoPossuiBiometria;
    expect(
      suporta,
      isTrue,
      reason: 'false em aparelho COM biometria cadastrada indica que o '
          'MainActivity voltou a ser FlutterActivity (o local_auth exige '
          'FlutterFragmentActivity) ou que falta USE_BIOMETRIC no manifesto.',
    );

    final tipos = await auth.tiposBiometriaDisponiveis;
    expect(tipos, isNotEmpty,
        reason: 'O aparelho deveria enumerar ao menos um tipo de biometria.');
  });
}
