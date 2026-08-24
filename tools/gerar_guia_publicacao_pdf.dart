// ignore_for_file: avoid_print

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() async {
  final pdf = pw.Document(
    title: 'Guia de Publicação e Custos - MentAll PRO',
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
        fontSize: nivel == 1 ? 16 : nivel == 2 ? 13 : 11,
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
            pw.Text('Guia de Publicação e Custos',
                style: const pw.TextStyle(fontSize: 10, color: cinza)),
          ],
        ),
      );

  pw.Widget passo(int n, String titulo, String texto) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 6),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 22,
              height: 22,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: marca,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(11)),
              ),
              child: pw.Text('$n',
                  style: const pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(titulo,
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold, color: heading)),
                  pw.SizedBox(height: 2),
                  pw.Text(texto,
                      style: const pw.TextStyle(fontSize: 10, color: body, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );

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
              flex: i == 0 ? 2 : i == 1 ? 2 : 1,
              child: pw.Text(
                celulas[i],
                style: pw.TextStyle(
                  fontSize: 9,
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

  pw.Widget nota(String texto) => pw.Container(
        padding: const pw.EdgeInsets.all(10),
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
            child: pw.Text('Guia de Publicação e Custos',
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold, color: titulo))),
        espaco(4),
        pw.Center(
            child: pw.Text('Google Play · App Store · Site — passo a passo',
                style: const pw.TextStyle(fontSize: 11, color: cinza))),
        espaco(16),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
              color: bgDestaque,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
          child: pw.Text(
            'Como usar este guia: cada seção é um passo, na ordem. Os valores estão em reais '
            'com o equivalente em dólar entre parênteses. Câmbio de referência R\$ 5,50. '
            'Valores aproximados em agosto/2026 — confirme na data da compra.',
            style: const pw.TextStyle(fontSize: 10, color: body, height: 1.5),
            textAlign: pw.TextAlign.justify,
          ),
        ),
        espaco(16),

        // ===== PARTE 1 =====
        pw.Text('Parte 1 — Publicar no Google Play (Android)',
            style: tituloSecao(1)),
        espaco(8),
        passo(1, 'Criar a conta de desenvolvedor',
            'Acesse play.google.com/console e crie sua conta Google de desenvolvedor. Use o mesmo e-mail de sempre para facilitar.'),
        passo(2, 'Pagar a taxa única',
            'O Google cobra US\$ 25 (~R\$ 140) uma única vez. Após pagar, a conta fica ativa para sempre.'),
        passo(3, 'Gerar a chave de assinatura (keystore)',
            'É uma senha que "assina" o app. Guarde o arquivo e a senha em local seguro (nuvem + HD externo). Se perder, não consegue mais atualizar o app.'),
        passo(4, 'Gerar o arquivo de publicação (.aab)',
            'Rode o comando flutter build appbundle no computador. Ele gera o arquivo final que você envia ao Google.'),
        passo(5, 'Preencher a ficha do app',
            'Nome "MentAll PRO", descrição, categoria (Saúde e Bem-estar), ícone e capturas de tela.'),
        passo(6, 'Publicar como teste fechado (oculto)',
            'Escolha "Teste fechado" e crie uma lista de e-mails de testadores. O app fica invisível para o público, só essas pessoas baixam.'),
        passo(7, 'Validar com 2 a 3 pessoas',
            'Peça para testarem e anotarem qualquer problema. Corrija e envie uma nova versão.'),
        passo(8, 'Lançar em produção',
            'Quando estiver confiante, clique em "Lançar em produção". O app entra na loja pública — você controla o momento.'),
        espaco(10),

        // ===== PARTE 2 =====
        pw.Text('Parte 2 — Publicar na App Store (iPhone)', style: tituloSecao(1)),
        espaco(8),
        passo(1, 'Criar a conta Apple Developer',
            'Acesse developer.apple.com e crie a conta. Se for pessoa física, usa seu CPF. Se tiver CNPJ, melhor (nome da empresa aparece na loja).'),
        passo(2, 'Pagar a taxa anual',
            'A Apple cobra US\$ 99 (~R\$ 545) por ano. Sem essa conta, não dá para testar nem publicar no iPhone.'),
        passo(3, 'Definir o identificador único (Bundle ID)',
            'É o "CPF" do app na loja, ex.: br.com.mentallpro. Ele não pode mudar depois. Hoje o projeto usa um valor provisório que precisa ser corrigido.'),
        passo(4, 'Corrigir o nome exibido',
            'Hoje o app aparece como "Prontuario Tcc" no iPhone. Vamos trocar para "MentAll PRO".'),
        passo(5, 'Gerar o ícone do app',
            'O ícone do iPhone está desatualizado. Vamos gerar o ícone novo com a logo francesa violeta.'),
        passo(6, 'Criar o certificado de assinatura',
            'O Xcode (no seu Mac) cria o certificado que assina o app, ligado à sua conta Apple.'),
        passo(7, 'Gerar o arquivo no Mac',
            'Rode o comando flutter build ipa no seu Mac. Exige uma máquina Apple (você já tem).'),
        passo(8, 'Publicar no TestFlight (oculto)',
            'Suba o arquivo pelo site da Apple e libere para até 10.000 testadores por e-mail. Invisível ao público.'),
        passo(9, 'Lançar manualmente',
            'Depois que a Apple aprovar, o app fica "aprovado mas oculto". Você escolhe quando liberar na loja pública.'),
        espaco(10),

        // ===== PARTE 3 =====
        pw.Text('Parte 3 — Todos os custos', style: tituloSecao(1)),
        espaco(8),
        linhaTabela(['Item', 'Valor', 'Frequência'], destaque: true),
        linhaTabela(['Google Play Console', 'US\$ 25 (~R\$ 140)', 'uma vez']),
        linhaTabela(['Apple Developer Program', 'US\$ 99 (~R\$ 545)', 'por ano']),
        linhaTabela(['Domínio .com.br', 'já tem (R\$ 40/ano)', 'por ano']),
        linhaTabela(['Hospedagem do site', 'ver Parte 4', '-']),
        linhaTabela(['Fly.io (backend)', '~US\$ 5,70 (~R\$ 31)', 'por mês']),
        linhaTabela(['RevenueCat (assinaturas)', 'R\$ 0 (até US\$ 2.500/mês de receita)', '-']),
        linhaTabela(['Asaas (Pix)', 'R\$ 0,00 por Pix', 'por uso']),
        espaco(8),
        nota('Resumo do 1º ano (sem site): ~R\$ 1.057, sendo R\$ 140 (Google, uma vez) + '
            'R\$ 545 (Apple, por ano) + R\$ 372 (backend, por ano). A partir do 2º ano, '
            'o custo fixo cai para ~R\$ 917/ano (sem a taxa única do Google).'),
        espaco(10),

        // ===== PARTE 4 =====
        pw.Text('Parte 4 — Orçamento do site (5 provedores)',
            style: tituloSecao(1)),
        espaco(4),
        pw.Text(
            'Você já tem o endereço (domínio). Falta escolher o provedor (onde o site fica hospedado). '
            'Seu site é em Astro + Tailwind (estático), o que permite a opção gratuita.',
            style: const pw.TextStyle(fontSize: 10, color: body, height: 1.5)),
        espaco(8),
        linhaTabela(['Provedor', 'Custo', 'Resumo'], destaque: true),
        linhaTabela(['Vercel', 'R\$ 0 (grátis)', 'Site estático + domínio próprio grátis + deploy automático. Painel em inglês.']),
        linhaTabela(['Netlify', 'R\$ 0 (grátis)', 'Alternativa idêntica ao Vercel.']),
        linhaTabela(['Cloudflare Pages', 'R\$ 0 (grátis)', 'Velocidade global (CDN). Configuração levemente técnica.']),
        linhaTabela(['Hostinger', '~R\$ 22-35/mês (R\$ 264-420/ano)', 'E-mail profissional + suporte em português. Pago.']),
        linhaTabela(['Locaweb', '~R\$ 19-50/mês', 'Tradição no Brasil + suporte. Mais caro.']),
        espaco(8),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: bgDestaque,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Recomendação',
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold, color: titulo)),
              pw.SizedBox(height: 4),
              pw.Text(
                'Gaste R\$ 0 no provedor usando o Vercel (seu site já foi planejado para ele). '
                'Conecte o domínio que você já tem, de graça. Só contrate Hostinger/Locaweb se quiser '
                'um e-mail profissional próprio (ex.: contato@mentallpro.com.br) — nesse caso, o custo '
                'adicional se justifica.',
                style: const pw.TextStyle(fontSize: 10, color: body, height: 1.5),
                textAlign: pw.TextAlign.justify,
              ),
            ],
          ),
        ),
        espaco(10),

        // ===== PARTE 5 =====
        pw.Text('Parte 5 — Orçamento final + linha do tempo',
            style: tituloSecao(1)),
        espaco(8),
        linhaTabela(['Cenário', 'Custo no 1º ano'], destaque: true),
        linhaTabela(['Site no Vercel (grátis)', '~R\$ 1.057']),
        linhaTabela(['Site na Hostinger', '~R\$ 1.321']),
        espaco(8),
        pw.Text('Linha do tempo sugerida', style: tituloSecao(2)),
        espaco(4),
        passo(1, 'Semana 1 — Android',
            'Conta Google + taxa + keystore + gerar o .aab + enviar para teste fechado.'),
        passo(2, 'Semana 2 — Teste',
            'Testadores validam o app. Corrige o que aparecer.'),
        passo(3, 'Semana 3 — iPhone',
            'Conta Apple + taxa + corrigir nome/ícone/bundle ID + build no Mac + TestFlight.'),
        passo(4, 'Depois — Site',
            'Publicar o site no Vercel conectando o domínio que você já tem (R\$ 0).'),
        espaco(10),

        nota('Câmbio de referência R\$ 5,50. Valores aproximados em agosto/2026. '
            'As taxas do Google e da Apple são cobradas em dólar e podem variar com o câmbio. '
            'Confirme os valores oficiais no site de cada loja na data da compra.'),
      ],
    ),
  );

  final bytes = await pdf.save();
  final arquivo = File('Guia_Publicacao_MentAll_PRO.pdf');
  await arquivo.writeAsBytes(bytes);
  print('PDF gerado: ${arquivo.absolute.path}');
  print('Tamanho: ${(bytes.length / 1024).toStringAsFixed(1)} KB');
}
