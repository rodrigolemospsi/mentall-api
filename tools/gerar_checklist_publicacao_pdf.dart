// ignore_for_file: avoid_print

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() async {
  final pdf = pw.Document(
    title: 'Checklist de Publicação - MentAll PRO',
    author: 'MentAll PRO',
  );

  const titulo = PdfColor.fromInt(0xFF3C096C);
  const marca = PdfColor.fromInt(0xFFC77DFF);
  const cinza = PdfColor.fromInt(0xFF64748B);
  const heading = PdfColor.fromInt(0xFF1E293B);
  const body = PdfColor.fromInt(0xFF334155);
  const bg = PdfColor.fromInt(0xFFF8FAFC);
  const bgDestaque = PdfColor.fromInt(0xFFF3E8FF);
  const linha = PdfColor.fromInt(0xFFE2E8F0);
  const vermelho = PdfColor.fromInt(0xFFB91C1C);

  pw.TextStyle tituloSecao(int nivel) => pw.TextStyle(
        fontSize: nivel == 1 ? 15 : nivel == 2 ? 12 : 10,
        fontWeight: nivel <= 2 ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: nivel == 1 ? titulo : heading,
      );

  pw.Widget espaco([double h = 6]) => pw.SizedBox(height: h);

  pw.Widget cabecalho() => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 4),
        decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: linha, width: 0.5))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('MentAll PRO',
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold, color: marca)),
            pw.Text('Checklist de Publicação',
                style: const pw.TextStyle(fontSize: 10, color: cinza)),
          ],
        ),
      );

  pw.Widget check(String texto) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 2.5, bottom: 2.5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 9,
              height: 9,
              margin: const pw.EdgeInsets.only(top: 2.5, right: 7),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: cinza, width: 0.8),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
              ),
            ),
            pw.Expanded(
              child: pw.Text(texto,
                  style: const pw.TextStyle(
                      fontSize: 9.5, color: body, height: 1.35)),
            ),
          ],
        ),
      );

  pw.Widget bloco(String tituloTxt, String texto) => pw.Container(
        padding: const pw.EdgeInsets.all(10),
        margin: const pw.EdgeInsets.only(bottom: 6),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(tituloTxt,
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold, color: heading)),
            pw.SizedBox(height: 3),
            pw.Text(texto,
                style: const pw.TextStyle(
                    fontSize: 9.5, color: body, height: 1.4)),
          ],
        ),
      );

  pw.Widget alerta(String texto) => pw.Container(
        padding: const pw.EdgeInsets.all(10),
        margin: const pw.EdgeInsets.only(bottom: 6),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFFEF2F2),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: PdfColor.fromInt(0xFFFECACA), width: 0.6),
        ),
        child: pw.Text(texto,
            style: const pw.TextStyle(
                fontSize: 9.5, color: vermelho, height: 1.4)),
      );

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (_) => cabecalho(),
      footer: (ctx) => pw.Center(
          child: pw.Text('Página ${ctx.pageNumber}',
              style: const pw.TextStyle(fontSize: 7, color: cinza))),
      build: (ctx) => [
        // ===== CAPA =====
        pw.Center(
            child: pw.Text('MentAll PRO',
                style: pw.TextStyle(
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                    color: marca,
                    letterSpacing: 1.5))),
        espaco(4),
        pw.Center(
            child: pw.Text('Checklist de Publicação',
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold, color: titulo))),
        espaco(4),
        pw.Center(
            child: pw.Text(
                'Google Play | App Store | LGPD | Processo de release',
                style: const pw.TextStyle(fontSize: 11, color: cinza))),
        espaco(14),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
              color: bgDestaque,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
          child: pw.Text(
            'Como usar: cada linha é um item verificável. Marque a caixa quando o item estiver '
            'concluído e confirmado (não só "feito no código"). A Parte A (LGPD) é pré-requisito: '
            'nada de loja antes dela. Nenhuma afirmação pública sem comportamento correspondente no '
            'produto.',
            style: const pw.TextStyle(fontSize: 10, color: body, height: 1.5),
            textAlign: pw.TextAlign.justify,
          ),
        ),
        espaco(14),

        // ===== PARTE A =====
        pw.Text('Parte A - Bloqueadores de LGPD e de loja (não adiar)',
            style: tituloSecao(1)),
        espaco(2),
        pw.Text(
            'Obrigatórios antes de qualquer publicação. Referências: plano P0/P1 (doc 02) e '
            'checklist de conformidade (doc 16).',
            style: const pw.TextStyle(fontSize: 9, color: cinza)),
        espaco(6),
        alerta(
            'Sem exclusão de conta e sem Política de Privacidade em URL pública, o app é '
            'reprovado automaticamente nas duas lojas.'),
        check(
            'A1. Publicar Política de Privacidade e Termos de Uso em URL pública (ativa, não-PDF) e '
            'linkar dentro do app  [P0.5]'),
        check(
            'A2. Corrigir os textos (Política, Termos e aviso de IA) para listar TODOS os terceiros '
            'reais, com o que recebem, país e finalidade (hoje omite Groq e DeepSeek)  [P0.1]'),
        check(
            'A3. Decidir o DeepSeek: remover da ordem de provedores OU consentimento específico do '
            'titular + RIPD específico  [P0.2 / D1]'),
        check(
            'A4. Decidir a localização do banco: migrar para região brasileira OU documentar a '
            'transferência (art. 33)  [P0.3 / D2]'),
        check(
            'A5. Cifrar no servidor os dados persistidos (contrato, anamnese, telefone) OU parar de '
            'persistir o que o app já guarda  [P0.4]'),
        check(
            'A6. Implantar exclusão de conta no app + URL web de solicitação de exclusão  [P1.9]'),
        check(
            'A7. Nomear o encarregado (DPO), publicar canal, prazo de resposta (15 dias) e aviso à '
            'ANPD  [P1.1 / P1.8]'),
        check(
            'A8. Remover a cópia local em texto claro com dados reais (backend/data/mentall.db) e '
            'expurgar os logs com segredo/PII  [P0.11 / P1.13]'),
        check(
            'A9. Fechar o desbloqueio fail-open; garantir áudio nunca em claro; corrigir ou remover '
            'a afirmação de pinning  [P0.7 / P0.8 / P0.10]'),
        check(
            'A10. Assinar o DPA com o psicólogo-cliente e com os subprocessadores (Groq, OpenAI, '
            'Turso, Sentry, SMTP, wuzapi)  [P1.2]'),
        check(
            'A11. Concluir o RIPD (art. 38) e o ROPA (art. 37)  [P1.4 / P1.3]'),
        check(
            'A12. Produzir a Política de retenção/descarte, o Plano de incidentes e o material do '
            'titular (aviso + consentimento)  [P1.6 / P1.7 / P1.5]'),
        check(
            'A13. Telemetria com opt-out e aviso no primeiro uso  [P1.14]'),
        check(
            'A14. Menores: campo de responsável legal e consentimento específico (art. 14)  [P1.15]'),
        espaco(10),

        // ===== PARTE B =====
        pw.Text('Parte B - Pendências técnicas de loja', style: tituloSecao(1)),
        espaco(6),
        check(
            'B1. Preencher o Data Safety (Google Play) linha a linha e conferir contra o código  [P1.10]'),
        check('B2. Preencher o App Privacy / nutrition labels (Apple)  [P1.10]'),
        check(
            'B3. Preencher a declaração de apps de saúde (Play), a classificação IARC/faixa etária e '
            'o status de dispositivo médico (Apple)'),
        check(
            'B4. iOS: adicionar NSFaceIDUsageDescription e ITSAppUsesNonExemptEncryption; corrigir o '
            'nome exibido para "MentAll PRO"; excluir o prontuário do backup do iCloud (diretriz '
            'Apple 5.1.3(ii))  [P2.16]'),
        check('B5. Gerar o keystore de produção e guardá-lo fora do repositório'),
        check(
            'B6. Produzir as capturas de tela da App Store (6.7", 6.5" e 5.5") - as do Play já existem'),
        check(
            'B7. Escrever descrição, categorias e palavras-chave sem alegações não sustentadas '
            '(não usar "100% conforme", "dados nunca saem do aparelho", "criptografia ponta a ponta")'),
        check(
            'B8. Contratar as contas de desenvolvedor: Google Play (US\$ 25, taxa única) e Apple '
            '(US\$ 99/ano)'),
        check(
            'B9. Preparar conta/modo de demonstração para o revisor (Apple) e isolar os dados de '
            'demonstração dos prontuários reais  [P2.17]'),
        check('B10. Definir e travar o Bundle ID definitivo (br.com.mentallpro)'),
        check(
            'B11. Decidir a categoria de loja (Play: Medicina x Produtividade; Apple: Medical)  [D10]'),
        espaco(10),

        // ===== PARTE C =====
        pw.Text('Parte C - Processo de release (qualidade e rollback)',
            style: tituloSecao(1)),
        espaco(6),
        check('C1. Uma correção = um commit (permite rollback e investigação por bisect)'),
        check(
            'C2. flutter analyze --no-pub com exit 0 (o CI reprova em qualquer aviso, incl. '
            'unused_element)'),
        check(
            'C3. flutter test --no-pub 100% e suíte do backend isolado 100%'),
        check(
            'C4. flutter build appbundle (Play) e build de release do iOS compilam sem erro'),
        check(
            'C5. Re-scan de segurança (Strix) após as mudanças de segurança recentes'),
        check(
            'C6. Conferir os secrets do Fly (JWT, chaves de IA, Turso, SMTP, wuzapi) e '
            'ALLOW_SQLITE_FALLBACK=false  [P1.12]'),
        check('C7. Bump de versão + CHANGELOG + tag de release'),
        check(
            'C8. Pré-lançamento em aparelho real (checklist de fumaça do AGENTS.md): desbloqueio por '
            'biometria, gravar -> transcrever, síntese -> salvar com a tela apagando, PDF e bloqueio'),
        espaco(10),

        // ===== PARTE D =====
        pw.Text('Parte D - Submissão e lançamento', style: tituloSecao(1)),
        espaco(6),
        pw.Text('Google Play (Android)', style: tituloSecao(2)),
        check('D1. Criar a conta de desenvolvedor e pagar a taxa única (US\$ 25)'),
        check('D2. Gerar o keystore e assinar o app bundle (.aab)'),
        check('D3. Preencher a ficha do app (nome, descrição, categoria, ícone, capturas)'),
        check('D4. Publicar em teste fechado e validar com 2 a 3 pessoas'),
        check('D5. Corrigir o que aparecer e reenviar'),
        check('D6. Lançar em produção (você controla o momento)'),
        espaco(6),
        pw.Text('Apple App Store (iPhone)', style: tituloSecao(2)),
        check('D7. Criar a Apple Developer Program e pagar a anuidade (US\$ 99/ano)'),
        check('D8. Ajustar Bundle ID, nome de exibição, ícone e chaves do Info.plist'),
        check('D9. Gerar o build no Mac e subir pelo TestFlight (oculto)'),
        check('D10. Revisar e lançar manualmente após a aprovação da Apple'),
        espaco(6),
        pw.Text('Antes de apertar o botão', style: tituloSecao(2)),
        check('D11. Revisão jurídica dos textos públicos (Política, Termos, textos de loja)'),
        check(
            'D12. Conferência final: nenhuma frase da lista de bloqueio editorial presente nos textos'),
        espaco(10),

        // ===== PARTE E =====
        pw.Text('Parte E - Pós-publicação', style: tituloSecao(1)),
        espaco(6),
        check('E1. Monitorar o painel do encarregado (canal do titular) e registrar solicitações'),
        check(
            'E2. Acompanhar crash/erros (Sentry desligado por padrão - ativar com DSN só com PII '
            'desativada)'),
        check('E3. Revisar ROPA/RIPD e este checklist a cada mudança relevante (mínimo trimestral)'),
        check(
            'E4. Manter o comparativo de mercado (docs/competidores) e as políticas sincronizados '
            'com o código'),
        espaco(12),

        bloco(
          'Regra de ouro',
          'Nenhuma afirmação em documento público ou texto de loja sem comportamento '
          'correspondente no produto. Onde o comportamento ainda não existe, o texto descreve o '
          'estado atual e a mudança entra no plano - nunca na promessa.'),
      ],
    ),
  );

  final bytes = await pdf.save();
  final arquivo = File('Checklist_Publicacao_MentAll_PRO.pdf');
  await arquivo.writeAsBytes(bytes);
  print('PDF gerado: ${arquivo.absolute.path}');
  print('Tamanho: ${(bytes.length / 1024).toStringAsFixed(1)} KB');
}
