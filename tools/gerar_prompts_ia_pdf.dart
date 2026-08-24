// ignore_for_file: avoid_print

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class _Prompt {
  final String titulo;
  final String origem;
  final String texto;

  const _Prompt(this.titulo, this.origem, this.texto);
}

// Extrai o conteudo entre """ ... """ (nao-greedy) a partir de um marcador.
String _extrairTriplo(String fonte, String marcador) {
  final inicio = fonte.indexOf(marcador);
  if (inicio == -1) return '';
  final fimAspas = fonte.indexOf('"""', inicio + marcador.length);
  if (fimAspas == -1) return '';
  return fonte.substring(inicio + marcador.length, fimAspas).trim();
}

// Extrai o conteudo de f""" ... """ (templates de runtime com interpolacao).
String _extrairFTriplo(String fonte, String marcador) {
  final inicio = fonte.indexOf(marcador);
  if (inicio == -1) return '';
  final corpo = fonte.substring(inicio + marcador.length);
  final fim = corpo.indexOf('"""');
  if (fim == -1) return '';
  return corpo.substring(0, fim).trim();
}

// Busca todos os blocos """ ... """ em ordem de ocorrencia.
List<String> _todosBlocos(String fonte) {
  final blocos = <String>[];
  var i = 0;
  while (true) {
    final a = fonte.indexOf('"""', i);
    if (a == -1) break;
    final b = fonte.indexOf('"""', a + 3);
    if (b == -1) break;
    blocos.add(fonte.substring(a + 3, b).trim());
    i = b + 3;
  }
  return blocos;
}

void main() async {
  final pdf = pw.Document(
    title: 'Prompts de IA - MentAll PRO',
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
            pw.Text('Prompts de IA',
                style: const pw.TextStyle(fontSize: 10, color: cinza)),
          ],
        ),
      );

  // ============================================================
  // Le os prompts dos arquivos fonte (fidelidade ao codigo)
  // ============================================================
  final prompts = <_Prompt>[];

  final abordagensFile = File('backend/prompts/abordagens.py');
  final iaFile = File('backend/services/ia_clinica.py');

  if (await abordagensFile.exists() && await iaFile.exists()) {
    final abordagensSrc = await abordagensFile.readAsString();
    final iaSrc = await iaFile.readAsString();

    // 1) PROMPT_UNIVERSAL
    final universal = _extrairTriplo(abordagensSrc, 'PROMPT_UNIVERSAL = """');
    if (universal.isNotEmpty) {
      prompts.add(_Prompt(
        'PROMPT_UNIVERSAL',
        'backend/prompts/abordagens.py (linha 1)',
        universal,
      ));
    }

    // 2) PROMPTS_ABORDAGEM (14 abordagens, na ordem do dicionario)
    const chaves = [
      'TCC', 'Psicanálise', 'Psicodinâmica', 'Humanista',
      'Fenomenológico-existencial', 'Logoterapia', 'Gestalt-terapia',
      'Sistêmica', 'ACT', 'DBT', 'Terapia do Esquema', 'Integrativa',
      'Outra', 'Análise do Comportamento',
    ];

    // Busca cada bloco pela chave: "Nome": """..."""
    for (final chave in chaves) {
      final bloco = _extrairTriplo(abordagensSrc, '"$chave": """');
      if (bloco.isNotEmpty) {
        prompts.add(_Prompt(
          'Abordagem: $chave',
          'backend/prompts/abordagens.py (PROMPTS_ABORDAGEM)',
          bloco,
        ));
      }
    }

    // Caso "Análise do Comportamento" seja adicionada apos o dicionario:
    final analiseComportamento =
        _extrairTriplo(abordagensSrc, '"Análise do Comportamento"] = """');
    if (analiseComportamento.isNotEmpty &&
        !prompts.any((p) => p.titulo == 'Abordagem: Análise do Comportamento')) {
      prompts.add(_Prompt(
        'Abordagem: Análise do Comportamento',
        'backend/prompts/abordagens.py (adicionado apos o dicionario)',
        analiseComportamento,
      ));
    }

    // 3) PROMPT_PROGRESSO
    final progresso = _extrairTriplo(abordagensSrc, 'PROMPT_PROGRESSO = """');
    if (progresso.isNotEmpty) {
      prompts.add(_Prompt(
        'PROMPT_PROGRESSO',
        'backend/prompts/abordagens.py (linha 441)',
        progresso,
      ));
    }

    // 4) Prompt de rerank de artigos (ia_clinica.py)
    final rerank = _extrairFTriplo(
        iaSrc, 'prompt = f"""Você é um assistente de pesquisa clínica em psicologia.');
    if (rerank.isNotEmpty) {
      prompts.add(_Prompt(
        'Rerank de artigos científicos',
        'backend/services/ia_clinica.py (linha 169)',
        rerank,
      ));
    }

    // 5) Template de síntese (montado em runtime)
    final templateSintese = _extrairFTriplo(iaSrc, 'return f"""');
    if (templateSintese.isNotEmpty) {
      prompts.add(_Prompt(
        'Template de síntese (runtime)',
        'backend/services/ia_clinica.py (_montar_prompt_sintese, linha 306)',
        templateSintese,
      ));
    }

    // 6) Template de progresso (montado em runtime)
    final templateProgresso =
        _extrairFTriplo(iaSrc, 'prompt = f"""{PROMPT_PROGRESSO}');
    if (templateProgresso.isNotEmpty) {
      prompts.add(_Prompt(
        'Template de progresso (runtime)',
        'backend/services/ia_clinica.py (gerar_progresso, linha 645)',
        templateProgresso,
      ));
    }
  }

  if (prompts.isEmpty) {
    stderr.writeln(
        'ERRO: nao foi possivel ler os arquivos de prompts do backend.');
    exitCode = 1;
    return;
  }

  // ============================================================
  // Monta o PDF
  // ============================================================
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(26),
      header: (_) => cabecalho(),
      footer: (ctx) => pw.Center(
          child: pw.Text('Página ${ctx.pageNumber}',
              style: const pw.TextStyle(fontSize: 7, color: cinza))),
      build: (ctx) => [
        pw.Center(
            child: pw.Text('MentAll PRO',
                style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: marca,
                    letterSpacing: 1.5))),
        espaco(4),
        pw.Center(
            child: pw.Text('Prompts utilizados pelas IAs',
                style: pw.TextStyle(
                    fontSize: 15, fontWeight: pw.FontWeight.bold, color: titulo))),
        espaco(4),
        pw.Center(
            child: pw.Text(
                'Síntese · Abordagens · Progresso · Artigos — texto fiel ao código-fonte',
                style: const pw.TextStyle(fontSize: 10, color: cinza))),
        espaco(14),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
              color: bgDestaque,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
          child: pw.Text(
            'Este documento reúne os prompts de IA usados pelo MentAll PRO, extraídos '
            'diretamente do backend. Os textos estão transcritos como aparecem no '
            'código (PT-BR, sem edição). Os prompts entre chaves (ex.: {material_base}) '
            'são preenchidos em tempo de execução com os dados da sessão.',
            style: const pw.TextStyle(fontSize: 9.5, color: body, height: 1.5),
            textAlign: pw.TextAlign.justify,
          ),
        ),
        espaco(14),
        pw.Text('Índice (${prompts.length} prompts)', style: tituloSecao(1)),
        espaco(6),
        for (var i = 0; i < prompts.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text('${i + 1}. ${prompts[i].titulo}',
                style: const pw.TextStyle(fontSize: 10, color: body)),
          ),
        espaco(8),
      ],
    ),
  );

  // Uma secao por prompt (paginas novas para os longos)
  for (var i = 0; i < prompts.length; i++) {
    final p = prompts[i];
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(26),
        header: (_) => cabecalho(),
        footer: (ctx) => pw.Center(
            child: pw.Text('Página ${ctx.pageNumber}',
                style: const pw.TextStyle(fontSize: 7, color: cinza))),
        build: (ctx) => [
          pw.Text('Prompt ${i + 1} de ${prompts.length}',
              style: const pw.TextStyle(fontSize: 9, color: cinza)),
          espaco(4),
          pw.Text(p.titulo, style: tituloSecao(1)),
          espaco(2),
          pw.Text('Origem: ${p.origem}',
              style: const pw.TextStyle(fontSize: 8.5, color: cinza, fontStyle: pw.FontStyle.italic)),
          espaco(8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: bg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: linha, width: 0.5),
            ),
            child: pw.Text(
              p.texto,
              style:               pw.TextStyle(
                fontSize: 9,
                color: body,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  final bytes = await pdf.save();
  final arquivo = File('Prompts_IA_MentAll_PRO.pdf');
  await arquivo.writeAsBytes(bytes);
  print('PDF gerado: ${arquivo.absolute.path}');
  print('Tamanho: ${(bytes.length / 1024).toStringAsFixed(1)} KB');
  print('Prompts incluidos: ${prompts.length}');
}
