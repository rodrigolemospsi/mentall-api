// ignore_for_file: avoid_print

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const primaria = PdfColor.fromInt(0xFF2066FF);
const cinza = PdfColor.fromInt(0xFF64748B);
const heading = PdfColor.fromInt(0xFF1E293B);
const body = PdfColor.fromInt(0xFF334155);
const bg = PdfColor.fromInt(0xFFF8FAFC);
const linha = PdfColor.fromInt(0xFFE2E8F0);

void main() async {
  final pdf = pw.Document(
    title: 'Guia de Configuracao - Mac Mini M4',
    author: 'MentAll PRO',
  );

  pw.TextStyle tituloSecao(int nivel) => pw.TextStyle(
        fontSize: nivel == 1 ? 16 : nivel == 2 ? 12 : 10,
        fontWeight: nivel <= 2 ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: nivel == 1 ? primaria : nivel == 2 ? heading : body,
      );

  pw.Widget espaco([double h = 6]) => pw.SizedBox(height: h);

  pw.Widget cabecalho() => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 4),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: linha, width: 0.5),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('MentAll PRO',
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: primaria)),
            pw.Text('Guia de Configuracao - Mac Mini M4',
                style: const pw.TextStyle(fontSize: 9, color: cinza)),
          ],
        ),
      );

  pw.Widget comando(String cmd, {String? comentario}) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 6),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFF0F172A),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(cmd,
                style: const pw.TextStyle(
                    fontSize: 9.5,
                    color: PdfColor.fromInt(0xFFE2E8F0),
                    height: 1.4)),
            if (comentario != null)
              pw.Text(comentario,
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColor.fromInt(0xFF94A3B8))),
          ],
        ),
      );

  pw.Widget item(String texto) => pw.Bullet(
        text: texto,
        bulletColor: primaria,
        style: const pw.TextStyle(fontSize: 10, color: body, height: 1.45),
      );

  pw.Widget aviso(String texto) => pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 4),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFE8F1FF),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Atencao: ',
                style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: primaria)),
            pw.Expanded(
              child: pw.Text(texto,
                  style: const pw.TextStyle(
                      fontSize: 9.5, color: heading, height: 1.4)),
            ),
          ],
        ),
      );

  pw.Widget tabela(List<String> cabecalhos, List<List<String>> linhas,
      {List<double>? larguras}) {
    final columnWidths = <int, pw.TableColumnWidth>{};
    if (larguras != null) {
      for (var i = 0; i < larguras.length; i++) {
        columnWidths[i] = pw.FixedColumnWidth(larguras[i]);
      }
    } else {
      for (var i = 0; i < cabecalhos.length; i++) {
        columnWidths[i] = pw.FlexColumnWidth();
      }
    }
    return pw.Table(
      border: pw.TableBorder.all(color: linha, width: 0.5),
      columnWidths: columnWidths,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEFF6FF)),
          children: cabecalhos
              .map((c) => pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(c,
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: heading)),
                  ))
              .toList(),
        ),
        ...linhas.map((l) => pw.TableRow(
              children: l
                  .map((cell) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(cell,
                            style: const pw.TextStyle(
                                fontSize: 8.5, color: body)),
                      ))
                  .toList(),
            )),
      ],
    );
  }

  pdf.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    header: (_) => cabecalho(),
    footer: (ctx) => pw.Center(
        child: pw.Text('Pagina ${ctx.pageNumber}',
            style: const pw.TextStyle(fontSize: 7, color: cinza))),
    build: (ctx) => [
      pw.Center(
          child: pw.Text('MentAll PRO',
              style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: primaria,
                  letterSpacing: 1.5))),
      espaco(4),
      pw.Center(
          child: pw.Text('Guia de Configuracao no Mac Mini M4',
              style: const pw.TextStyle(fontSize: 13, color: cinza))),
      espaco(4),
      pw.Center(
          child: pw.Text(
              'Passo a passo para instalar o ambiente e transferir o projeto',
              style: const pw.TextStyle(fontSize: 9, color: cinza))),
      espaco(14),

      // ============================================================
      // 0. RESUMO
      // ============================================================
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Resumo do que voce vai fazer', style: tituloSecao(2)),
            espaco(6),
            item('1. Transferir o projeto (Git ou copia direta da pasta).'),
            item('2. Instalar os programas base (CLT, Homebrew).'),
            item('3. Instalar Flutter + Android Studio e gerar o APK.'),
            item('4. Instalar Python e rodar o backend local.'),
            item('5. Conectar ao Fly.io para fazer deploy.'),
            item('6. (Opcional) Ativar iOS com Xcode.'),
          ],
        ),
      ),
      espaco(14),

      // ============================================================
      // 1. PREPARACAO - TRANSFERIR O PROJETO
      // ============================================================
      pw.Text('1. Preparacao - transferir o projeto', style: tituloSecao(1)),
      espaco(8),
      pw.Text('Opcao A - Git (recomendada)',
          style: pw.TextStyle(
              fontSize: 11, fontWeight: pw.FontWeight.bold, color: heading)),
      espaco(4),
      item('No PC atual: commit das mudancas pendentes e envio ao GitHub.'),
      comando(
          'git add -A  &&  git commit -m "preparando transferencia"  &&  git push origin master',
          comentario:
              'O repositorio ja aponta para o GitHub (rodrigolemospsi/mentall-api).'),
      item('No Mac: clonar o repositorio.'),
      comando('git clone https://github.com/rodrigolemospsi/mentall-api.git'),
      espaco(6),
      pw.Text('Opcao B - Copia direta da pasta',
          style: pw.TextStyle(
              fontSize: 11, fontWeight: pw.FontWeight.bold, color: heading)),
      espaco(4),
      item('Copiar a pasta inteira via pendrive/SSD (ou AirDrop).'),
      item('Depois de copiar, apagar o lixo de build e cache (libera ~1,25 GB).'),
      comando(
          'rm -rf build .dart_tool android/.gradle backend/__pycache__ ios/Flutter/ephemeral backend/data',
          comentario: 'Rode dentro da pasta do projeto no Mac.'),
      espaco(6),
      aviso('O arquivo backend/.env contem chaves reais (OpenAI, Gemini, Turso, '
          'SMTP, JWT) e NAO vai pelo Git. Copie-o manualmente para a pasta '
          'backend/ do Mac. Nao publique este arquivo em repositorio publico.'),
      espaco(8),

      // ============================================================
      // 2. PROGRAMAS BASE
      // ============================================================
      pw.Text('2. Programas base (obrigatorios)', style: tituloSecao(1)),
      espaco(8),
      item('Xcode Command Line Tools (necessario para Git e compiladores).'),
      comando('xcode-select --install'),
      item('Homebrew (gerenciador de pacotes do macOS).'),
      comando(
          '/bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"',
          comentario:
              'Apos instalar, siga as instrucoes para adicionar o brew ao PATH.'),
      item('Git (ja vem com o Command Line Tools). Confirme com:'),
      comando('git --version'),
      espaco(8),

      // ============================================================
      // 3. FLUTTER + ANDROID
      // ============================================================
      pw.Text('3. Flutter + Android (gerar o APK)', style: tituloSecao(1)),
      espaco(8),
      item('Baixar o Flutter SDK (ultima versao estavel) em flutter.dev. '
          'O projeto exige Dart 3.12.2 ou superior.'),
      comando(
          'cd ~ && unzip ~/Downloads/flutter_macos_arm64_<versao>-stable.zip',
          comentario:
              'Descompacte em uma pasta de sua preferencia (ex.: ~/development).'),
      item('Adicionar o Flutter ao PATH (adicione a linha no ~/.zshrc).'),
      comando('export PATH="\$PATH:\$HOME/development/flutter/bin"',
          comentario: 'Depois rode: source ~/.zshrc'),
      item('Validar a instalacao.'),
      comando('flutter doctor',
          comentario: 'Deve acusar apenas o Android SDK/Xcode pendentes.'),
      item('Instalar o Android Studio (traz SDK, JDK e emulador).'),
      comando('brew install --cask android-studio'),
      item('Abrir o Android Studio e instalar o Android SDK (ele ja sugere). '
          'Em seguida, aceitar as licencas:'),
      comando('flutter doctor --android-licenses'),
      espaco(4),
      item('Dentro da pasta do projeto, baixar as dependencias e gerar o APK.'),
      comando('flutter pub get'),
      comando('flutter build apk',
          comentario:
              'O APK sai em build/app/outputs/flutter-apk/app-release.apk.'),
      espaco(8),

      // ============================================================
      // 4. BACKEND (PYTHON)
      // ============================================================
      pw.Text('4. Backend (Python)', style: tituloSecao(1)),
      espaco(8),
      item('Instalar Python 3.12.'),
      comando('brew install python@3.12'),
      item('Criar ambiente virtual e instalar dependencias.'),
      comando('cd backend'),
      comando('python3.12 -m venv .venv'),
      comando('source .venv/bin/activate'),
      comando('pip install -r requirements.txt'),
      item('Colocar o arquivo .env (copiado do PC) dentro da pasta backend/.'),
      item('Rodar o backend localmente.'),
      comando('python -m uvicorn main:app --host 0.0.0.0 --port 8000'),
      item('Testar no navegador.'),
      comando('http://localhost:8000/health',
          comentario:
              'Deve retornar {"status":"ok",...} com "database":"turso".'),
      espaco(8),

      // ============================================================
      // 5. DEPLOY NO FLY.IO
      // ============================================================
      pw.Text('5. Deploy no Fly.io', style: tituloSecao(1)),
      espaco(8),
      item('Instalar o flyctl.'),
      comando('brew install flyctl'),
      item('Fazer login na sua conta Fly.io.'),
      comando('flyctl auth login'),
      item('Fazer deploy (na raiz do projeto, onde esta o fly.toml).'),
      comando('flyctl deploy -a mentall-api'),
      item('Ver os logs do backend em producao.'),
      comando('flyctl logs -a mentall-api'),
      aviso('Os segredos (chaves de API, JWT_SECRET, TURSO, SMTP) ja estao '
          'configurados no Fly.io e nao precisam ser recriados no Mac.'),
      espaco(8),

      // ============================================================
      // 6. IOS (OPCIONAL)
      // ============================================================
      pw.Text('6. iOS (opcional - so quando for publicar na App Store)',
          style: tituloSecao(1)),
      espaco(8),
      item('Instalar o Xcode pela App Store (~12 GB).'),
      item('Instalar o CocoaPods.'),
      comando('brew install cocoapods'),
      item('No projeto, trocar o Bundle ID e o nome de exibicao:'),
      item('- Bundle ID: com.example.prontuarioTcc  ->  com.mentall.app'),
      item('- Nome de exibicao: "Prontuario Tcc"  ->  "MentAll PRO"'),
      item('(Editar em ios/Runner.xcodeproj/project.pbxproj e '
          'ios/Runner/Info.plist)'),
      item('Gerar o icone iOS: em pubspec.yaml, mudar "ios: false" para '
          '"ios: true" e rodar:'),
      comando('dart run flutter_launcher_icons'),
      item('Ter uma conta Apple Developer (US\$ 99/ano) e configurar a '
          'assinatura (signing) + App Store Connect para publicar.'),
      comando('flutter build ipa',
          comentario: 'Requer Xcode e conta Apple configurada.'),
      espaco(8),

      // ============================================================
      // 7. CHECKLIST FINAL
      // ============================================================
      pw.Text('7. Checklist final', style: tituloSecao(1)),
      espaco(8),
      tabela(
        ['Passo', 'Comando', 'Confirmacao esperada'],
        [
          ['Flutter ok', 'flutter doctor', 'Sem erros criticos'],
          ['Dependencias', 'flutter pub get', 'Sem erros'],
          ['Backend de pe', 'uvicorn main:app', '/health -> "database":"turso"'],
          ['Deploy', 'flyctl deploy', '"Machine ... started"'],
          ['APK', 'flutter build apk', 'app-release.apk gerado'],
        ],
        larguras: [70, 130, 150],
      ),
      espaco(8),

      // ============================================================
      // 8. COMANDOS UTEIS
      // ============================================================
      pw.Text('8. Comandos uteis (referencia rapida)', style: tituloSecao(1)),
      espaco(8),
      tabela(
        ['Acao', 'Comando'],
        [
          ['Rodar app (web)', 'flutter run -d chrome'],
          ['Build APK', 'flutter build apk'],
          ['Rodar testes', 'flutter test'],
          ['Regenerar Hive', 'dart run build_runner build'],
          ['Backend local', 'python -m uvicorn main:app --port 8000'],
          ['Deploy Fly', 'flyctl deploy -a mentall-api'],
          ['Logs Fly', 'flyctl logs -a mentall-api'],
        ],
        larguras: [110, 240],
      ),
      espaco(8),

      pw.Text('MentAll PRO - Solucoes para Psicologos',
          style: const pw.TextStyle(fontSize: 8, color: cinza)),
    ],
  ));

  final file = File('docs/guia_configuracao_mac_mini_m4.pdf');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(await pdf.save());
  print('PDF gerado: ${file.absolute.path}');
  print('Tamanho: ${(await file.length() / 1024).toStringAsFixed(0)} KB');
}
