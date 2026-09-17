import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guarda de regressao para a configuracao nativa exigida pelo `local_auth`.
///
/// Testes de widget usam um gate falso e NAO exercitam o platform channel do
/// plugin. Foi exatamente por isso que a regressao do desbloqueio biometrico
/// passou despercebida: o `MainActivity` era `FlutterActivity` (o plugin exige
/// `FlutterFragmentActivity`), o tema nao era AppCompat e faltava a permissao
/// `USE_BIOMETRIC`. Este teste le os arquivos de configuracao e falha se
/// qualquer um desses contratos for quebrado.
void main() {
  group('configuracao nativa do local_auth', () {
    test(
      'MainActivity estende FlutterFragmentActivity (nao FlutterActivity)',
      () {
        final arquivo = File(
          'android/app/src/main/kotlin/com/mentall/app/MainActivity.kt',
        );
        expect(
          arquivo.existsSync(),
          isTrue,
          reason: 'MainActivity.kt nao encontrado em ${arquivo.path}',
        );

        final conteudo = arquivo.readAsStringSync();
        expect(
          conteudo.contains('FlutterFragmentActivity'),
          isTrue,
          reason:
              'local_auth exige FlutterFragmentActivity; sem isso o '
              'BiometricPrompt retorna NOT_FRAGMENT_ACTIVITY (uiUnavailable) '
              'e o app cai no fail-safe "sem biometria".',
        );
        // Garante que nao ha uma heranca direta de FlutterActivity.
        expect(
          RegExp(
            r'class\s+MainActivity\s*:\s*FlutterActivity\s*\(',
          ).hasMatch(conteudo),
          isFalse,
          reason: 'MainActivity ainda estende FlutterActivity.',
        );
      },
    );

    test('AndroidManifest declara a permissao USE_BIOMETRIC', () {
      final conteudo = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(
        conteudo.contains('android.permission.USE_BIOMETRIC'),
        isTrue,
        reason: 'A permissao USE_BIOMETRIC e exigida pelo local_auth.',
      );
    });

    test('LaunchTheme usa base Theme.AppCompat (claro e escuro)', () {
      for (final caminho in const [
        'android/app/src/main/res/values/styles.xml',
        'android/app/src/main/res/values-night/styles.xml',
      ]) {
        final conteudo = File(caminho).readAsStringSync();
        final match = RegExp(
          r'<style\s+name="LaunchTheme"\s+parent="([^"]+)"',
        ).firstMatch(conteudo);
        expect(
          match,
          isNotNull,
          reason: 'LaunchTheme nao encontrado em $caminho',
        );
        expect(
          match!.group(1)!.contains('Theme.AppCompat'),
          isTrue,
          reason:
              'O tema do BiometricPrompt precisa ser AppCompat em '
              '$caminho (parent atual: ${match.group(1)}).',
        );
      }
    });
  });
}
