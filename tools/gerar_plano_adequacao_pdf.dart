// ignore_for_file: avoid_print

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() async {
  final pdf = pw.Document(
    title: 'Plano de Adequação LGPD - MentAll PRO',
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
  const ok = PdfColor.fromInt(0xFF2E7D32);
  const pend = PdfColor.fromInt(0xFFE65100);

  pw.TextStyle tituloSecao(int nivel) => pw.TextStyle(
        fontSize: nivel == 1 ? 15 : nivel == 2 ? 12 : 10,
        fontWeight: nivel <= 2 ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: nivel == 1 ? titulo : nivel == 2 ? heading : body,
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
            pw.Text('Plano de Adequação LGPD',
                style: const pw.TextStyle(fontSize: 10, color: cinza)),
          ],
        ),
      );

  pw.Widget bloco(String tituloTxt, String texto,
      {PdfColor? corFundo, pw.FontWeight pesoTitulo = pw.FontWeight.bold}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      margin: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        color: corFundo ?? bg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(tituloTxt,
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pesoTitulo, color: heading)),
          pw.SizedBox(height: 3),
          pw.Text(texto,
              style: const pw.TextStyle(fontSize: 9, color: body, height: 1.4),
              textAlign: pw.TextAlign.justify),
        ],
      ),
    );
  }

  pw.Widget nota(String texto) => pw.Container(
        padding: const pw.EdgeInsets.all(10),
        margin: const pw.EdgeInsets.only(top: 4),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('⚠',
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.black)),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: pw.Text(texto,
                  style: const pw.TextStyle(fontSize: 9, color: body, height: 1.4)),
            ),
          ],
        ),
      );

  pw.Widget frente(int n, String nome, String statusTxt, PdfColor corStatus,
      String descricao, String prazo) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      margin: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 20,
                height: 20,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: marca,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Text('$n',
                    style: const pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Text('F$n — $nome',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold, color: heading)),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(statusTxt,
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold, color: corStatus)),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(descricao,
              style: const pw.TextStyle(fontSize: 9, color: body, height: 1.4),
              textAlign: pw.TextAlign.justify),
          pw.SizedBox(height: 3),
          pw.Text('Prazo sugerido: $prazo',
              style: pw.TextStyle(
                  fontSize: 8, fontWeight: pw.FontWeight.bold, color: cinza)),
        ],
      ),
    );
  }

  pw.Widget linhaTabela(List<String> celulas, {bool destaque = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      color: destaque ? bgDestaque : PdfColors.white,
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: linha, width: 0.4)),
      ),
      child: pw.Row(
        children: [
          for (var i = 0; i < celulas.length; i++) ...[
            if (i > 0) pw.SizedBox(width: 6),
            pw.Expanded(
              flex: i == 0 ? 3 : 2,
              child: pw.Text(
                celulas[i],
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: destaque ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: destaque ? titulo : body,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

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
            child: pw.Text('Plano de Adequação LGPD',
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold, color: titulo))),
        espaco(4),
        pw.Center(
            child: pw.Text('Lei 13.709/2018 · Resolução CFP 1/2009',
                style: const pw.TextStyle(fontSize: 11, color: cinza))),
        espaco(16),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
              color: bgDestaque,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
          child: pw.Text(
            'Este plano consolida o diagnóstico da política de privacidade atual do MentAll PRO '
            'frente aos concorrentes brasileiros (PsiLuz, Copilloto, Mently e Zenklub) e define as '
            'frentes de adequação à LGPD. O objetivo é evoluir a governança de dados preservando o '
            'diferencial do produto: armazenamento local no dispositivo do profissional '
            '(local-first), com criptografia AES-256-GCM e controle pleno do psicólogo sobre os '
            'dados clínicos.',
            style: const pw.TextStyle(fontSize: 10, color: body, height: 1.5),
            textAlign: pw.TextAlign.justify,
          ),
        ),
        espaco(16),

        // ===== 1. SUMÁRIO EXECUTIVO =====
        pw.Text('1. Sumário Executivo', style: tituloSecao(1)),
        espaco(8),
        bloco(
          'Situação atual',
          'A política do MentAll PRO é funcional e cobre dados coletados, finalidade, segurança, '
          'compartilhamento, retenção, direitos, IA e contato. Porém, comparada aos concorrentes, '
          'faltam: DPO/Encarregado nomeado, prazo de retenção explícito (5 anos CFP), mapeamento de '
          'base legal por categoria, detalhamento dos provedores de IA e da transferência '
          'internacional (art. 33), seção de menores de idade e notificação de incidentes (art. 48).',
        ),
        espaco(8),
        pw.Text('1.1 Comparativo com concorrentes', style: tituloSecao(2)),
        espaco(4),
        linhaTabela(['Aspecto', 'MentAll PRO / Concorrentes'], destaque: true),
        linhaTabela(['DPO/Encarregado', 'Falta. PsiLuz, Copilloto, Mently e Zenklub nomeiam DPO']),
        linhaTabela(['Criptografia', 'AES-256-GCM (equal ao PsiLuz AES-256). Todos criptografam']),
        linhaTabela(['Local de armazenamento', 'Local-first no dispositivo (único). Concorrentes usam servidor']),
        linhaTabela(['Retenção', 'Falta prazo. Concorrentes: 5 anos (Resolução CFP 1/2009)']),
        linhaTabela(['Base legal por dado', 'Falta mapeamento. Zenklub/Copilloto mapeiam por categoria']),
        linhaTabela(['IA sem treinamento', 'Previsto (alinhado a PsiLuz/Copilloto)']),
        espaco(10),

        // ===== 2. FRENTES =====
        pw.Text('2. Frentes de Adequação', style: tituloSecao(1)),
        espaco(8),
        frente(1, 'Governança e DPO', 'A FAZER', pend,
            'Nomear Encarregado de Proteção de Dados (DPO) com e-mail dedicado '
            'dpo@mentallpro.com.br e registrar as operações de tratamento (art. 41 da LGPD). '
            'Documentar o papel de controlador (psicólogo) e operador (MentAll PRO).',
            'imediato (0-15 dias)'),
        frente(2, 'Mapeamento de dados e base legal', 'A FAZER', pend,
            'Inventário completo dos dados tratados com base legal por categoria: consentimento '
            '(art. 7º, I), execução de contrato (art. 7º, V), tutela da saúde (art. 7º, VIII e 11, '
            'II, f) e legítimo interesse (art. 7º, IX).',
            '30 dias'),
        frente(3, 'Segurança da informação', 'PARCIAL', ok,
            'Já implementado: criptografia AES-256-GCM em repouso, PIN + biometria, HTTPS, '
            'criptografia do áudio no disco e arquitetura local-first. Ação: documentar as medidas '
            'na política e formalizar o backup/recuperação.',
            'revisão contínua'),
        frente(4, 'Inteligência Artificial', 'PARCIAL', ok,
            'Nomear os provedores de IA (OpenAI, Google Gemini, Groq) como operadores (art. 5º, '
            'VII), reforçar a pseudonimização de nomes antes do envio e declarar a vedação ao '
            'treinamento de modelos. Declarar a transferência internacional (art. 33).',
            '30 dias'),
        frente(5, 'Direitos do titular', 'PARCIAL', ok,
            'Manter os direitos previstos (acesso, correção, portabilidade, eliminação) e '
            'formalizar um fluxo de requisições via DPO com resposta em até 15 dias (art. 18).',
            '30 dias'),
        frente(6, 'Retenção e exclusão', 'A FAZER', pend,
            'Adotar prazo mínimo de 5 anos após a última sessão (Resolução CFP 1/2009) para '
            'prontuários, com arquivamento como política de guarda e exclusão definitiva após '
            'confirmação múltipla registrada em auditoria.',
            '15 dias'),
        frente(7, 'Notificação de incidentes', 'A FAZER', pend,
            'Compromisso de notificar a ANPD e os titulares afetados em caso de incidente de '
            'segurança (art. 48 da LGPD), em prazo razoável, com detalhes do ocorrido.',
            '30 dias'),
        espaco(10),

        // ===== 3. PRIORIDADES =====
        pw.Text('3. Matriz de Prioridades', style: tituloSecao(1)),
        espaco(8),
        linhaTabela(['Prioridade', 'Item'], destaque: true),
        linhaTabela(['P0 — imediato', 'Nomear DPO (dpo@mentallpro.com.br)']),
        linhaTabela(['P0 — imediato', 'Definir prazo de retenção de 5 anos (CFP 1/2009)']),
        linhaTabela(['P1 — 30 dias', 'Mapear base legal por categoria de dado']),
        linhaTabela(['P1 — 30 dias', 'Detalhar provedores de IA + transferência internacional']),
        linhaTabela(['P2 — 60 dias', 'Fluxo de direitos do titular + registro de operações']),
        linhaTabela(['P2 — 60 dias', 'Política de incidentes (art. 48) + menores de idade']),
        espaco(10),

        // ===== 4. MODELO DE POLÍTICA (REFERÊNCIA) =====
        pw.Text('4. Modelo de Política Atualizada (referência para o app)',
            style: tituloSecao(1)),
        espaco(4),
        pw.Text(
            'O texto abaixo consolida as seções que serão aplicadas na política do app quando o '
            'dono autorizar. Não foi aplicado nesta rodada — permanece como anexo de referência.',
            style: const pw.TextStyle(fontSize: 9, color: cinza, height: 1.4)),
        espaco(8),
        bloco(
          'Base legal e finalidade',
          'Tratamos os dados com base na LGPD: consentimento (art. 7º, I), execução do serviço '
          'contratado (art. 7º, V), tutela da saúde na prestação de serviços por psicólogo '
          '(art. 7º, VIII e art. 11, II, f) e legítimo interesse na segurança do sistema '
          '(art. 7º, IX). O profissional é o controlador dos dados clínicos; o MentAll PRO atua '
          'como operador tecnológico.',
        ),
        bloco(
          'Retenção',
          'Prontuários e registros clínicos são mantidos por, no mínimo, 5 anos após a última '
          'sessão, conforme a Resolução CFP 1/2009, com arquivamento como política de guarda. '
          'A exclusão definitiva, quando disponível, é protegida por confirmação múltipla e '
          'registrada em auditoria.',
        ),
        bloco(
          'Inteligência Artificial',
          'Os dados enviados para processamento por IA (transcrição e síntese) são utilizados '
          'exclusivamente para gerar a resposta, com pseudonimização de nomes antes do envio, '
          'e não são usados para treinamento de modelos. Os provedores (OpenAI, Google Gemini, '
          'Groq) atuam como operadores, em conformidade com o art. 33 da LGPD para transferência '
          'internacional.',
        ),
        bloco(
          'Encarregado de Dados (DPO)',
          'Para dúvidas, exercício de direitos ou requisições relacionadas à proteção de dados, '
          'fale com o Encarregado: dpo@mentallpro.com.br. Respondemos em até 15 dias.',
        ),
        bloco(
          'Incidentes e menores',
          'Em caso de incidente de segurança, notificaremos a ANPD e os afetados (art. 48). '
          'O atendimento a menores é de responsabilidade do profissional, exigindo o '
          'consentimento do responsável legal.',
        ),
        espaco(12),
        nota('Documento interno de adequação. As datas e prazos são sugestões — '
            'podem ser ajustados conforme o cronograma do produto.'),
      ],
    ),
  );

  final bytes = await pdf.save();
  final arquivo = File('Plano_adequacao_LGPD_MentAll_PRO.pdf');
  await arquivo.writeAsBytes(bytes);
  print('PDF gerado: ${arquivo.absolute.path}');
  print('Tamanho: ${(bytes.length / 1024).toStringAsFixed(1)} KB');
}
