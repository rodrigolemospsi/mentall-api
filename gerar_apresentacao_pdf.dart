import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() async {
  final azul = PdfColor.fromInt(0xFF2563EB);
  final azulClaro = PdfColor.fromInt(0xFFEFF6FF);
  final cinza = PdfColor.fromInt(0xFF64748B);
  final fundo = PdfColor.fromInt(0xFFF7F9FA);
  final linha = PdfColor.fromInt(0xFFE2E8F0);

  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        pw.Center(
          child: pw.Text('MENTALL', style: pw.TextStyle(
            fontSize: 28, fontWeight: pw.FontWeight.bold, color: azul, letterSpacing: 3,
          )),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text('Prontuário Clínico com IA', style: pw.TextStyle(
            fontSize: 13, color: cinza,
          )),
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text('Mais tempo para a clínica, menos tempo com a papelada.', style: pw.TextStyle(
            fontSize: 10, color: cinza, fontStyle: pw.FontStyle.italic,
          )),
        ),
        pw.SizedBox(height: 14),
        _linha(azul),

        pw.SizedBox(height: 12),
        _titulo('O QUE É O MENTALL', azul),
        pw.SizedBox(height: 4),
        _texto('O MentAll é um aplicativo de prontuário clínico eletrônico desenvolvido especificamente para psicólogos. Diferente de prontuários genéricos, ele se adapta à SUA abordagem terapêutica e utiliza inteligência artificial como assistente de documentação, nunca como substituto do seu julgamento clínico.'),

        pw.SizedBox(height: 12),
        _titulo('POR QUE USAR O MENTALL', azul),
        pw.SizedBox(height: 6),

        _topico('1. Foco no paciente, não no papel', azul),
        _texto('Após a sessão, grave um breve relato de áudio (até 5 minutos). O app transcreve automaticamente e organiza o conteúdo nos campos do prontuário. Você revisa, ajusta e salva.'),

        pw.SizedBox(height: 6),
        _topico('2. Sua abordagem, sua linguagem', azul),
        _texto('O MentAll adapta os campos clínicos à abordagem do profissional. São 14 abordagens: TCC, Análise do Comportamento, Psicanálise, Psicodinâmica, Humanista, Fenomenológico-existencial, Logoterapia, Gestalt-terapia, Sistêmica, ACT, DBT, Terapia do Esquema, Integrativa e Outra. Cada abordagem altera os rótulos dos campos automaticamente.'),

        pw.SizedBox(height: 6),
        _topico('3. Síntese clínica com IA (GPT-4.1)', azul),
        _texto('A partir do seu relato, a IA gera: relato clínico organizado, síntese clínica, formulação adaptada à abordagem, intervenções realizadas, apontamentos do Copiloto com hipóteses e sugestões, e indicação de artigos científicos em português para leitura complementar. TUDO que a IA gera exige sua revisão antes de compor o prontuário.'),

        pw.SizedBox(height: 6),
        _topico('4. Segurança de verdade', azul),
        _texto('Criptografia AES-256-CBC nos dados sensíveis • PIN de acesso ao app • Autenticação JWT no backend • Dados clínicos nunca saem do app sem criptografia • Auditoria completa de cada ação • Backups exportáveis em JSON e PDF • Arquivamento em vez de exclusão (LGPD).'),

        pw.SizedBox(height: 6),
        _topico('5. Agenda integrada', azul),
        _texto('Compromissos do dia na tela inicial com navegação entre datas. Status de cada sessão: Agendado, Realizado, Cancelado, Faltou. Visão rápida de quem você atende hoje.'),

        pw.SizedBox(height: 6),
        _topico('6. Organização dos pacientes', azul),
        _texto('Cadastro completo com foto, contato, e-mail e data de nascimento. WhatsApp direto do card do paciente. Terminologia personalizável (paciente/cliente/pessoa atendida). Indicador visual de sessões pendentes de revisão.'),

        pw.SizedBox(height: 6),
        _topico('7. Exportação profissional em PDF', azul),
        _texto('5 formatos: registro de sessão, histórico clínico, relatório com evolução, síntese revisada e prontuário completo. Design limpo, paleta azul minimalista, pronto para anexar ou imprimir.'),

        pw.SizedBox(height: 6),
        _topico('8. Privacidade e Ética', azul),
        _texto('Conformidade com LGPD. Áudio limitado a 5 minutos. Aviso sobre uso de IA em todos os documentos. Tela dedicada de Privacidade e Segurança. O profissional sempre decide o que entra no prontuário.'),

        pw.SizedBox(height: 6),
        _topico('9. Rápido e leve', azul),
        _texto('Dados armazenados localmente — funciona offline. Abertura instantânea. Sincronização com IA apenas quando você solicita.'),

        pw.SizedBox(height: 14),
        _linha(azul),
        pw.SizedBox(height: 10),

        _titulo('FUNCIONALIDADES PRINCIPAIS', azul),
        pw.SizedBox(height: 6),

        _tabelaFuncionalidades(azulClaro, linha, azul),

        pw.SizedBox(height: 12),
        _titulo('PARA QUEM É O MENTALL', azul),
        pw.SizedBox(height: 4),
        _texto('Psicólogos clínicos que atendem regularmente, valorizam seu tempo, desejam registros de qualidade com mínimo esforço, trabalham com diferentes abordagens, precisam de segurança real nos dados e querem um app que se adapta à sua rotina.'),

        pw.SizedBox(height: 12),
        _titulo('O QUE O MENTALL NÃO É', azul),
        pw.SizedBox(height: 4),
        _texto('Não é um prontuário genérico adaptado da medicina. Não substitui o julgamento clínico. Não armazena dados em nuvens públicas. Não gera conteúdo sem supervisão. Não é um robô-terapeuta — é um assistente de documentação.'),

        pw.SizedBox(height: 12),
        _titulo('COMEÇAR É SIMPLES', azul),
        pw.SizedBox(height: 4),
        _texto('1. Instale o app no Android  2. Configure seu perfil e abordagem  3. Cadastre seu primeiro paciente  4. Agende na agenda integrada  5. Após o atendimento, grave um relato em áudio  6. Revise a transcrição e síntese da IA  7. Marque como revisado — pronto.'),

        pw.SizedBox(height: 16),
        _linha(azul),
        pw.SizedBox(height: 6),
        pw.Center(
          child: pw.Text('"A tecnologia deve servir à clínica, e não o contrário."', style: pw.TextStyle(
            fontSize: 9, color: cinza, fontStyle: pw.FontStyle.italic,
          )),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text('github.com/rodrigolemospsi/mentall-api', style: pw.TextStyle(
            fontSize: 8, color: cinza,
          )),
        ),
      ],
    ),
  );

  final bytes = await doc.save();
  await File('MentAll_Apresentacao.pdf').writeAsBytes(bytes);
  print('PDF gerado: MentAll_Apresentacao.pdf (${(bytes.length / 1024).toStringAsFixed(1)} KB)');
}

pw.Widget _linha(PdfColor cor) {
  return pw.Container(height: 1.5, color: cor);
}

pw.Widget _titulo(String texto, PdfColor cor) {
  return pw.Text(texto.toUpperCase(), style: pw.TextStyle(
    fontSize: 10, fontWeight: pw.FontWeight.bold, color: cor, letterSpacing: 0.8,
  ));
}

pw.Widget _topico(String texto, PdfColor cor) {
  return pw.Text(texto, style: pw.TextStyle(
    fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: cor,
  ));
}

pw.Widget _texto(String texto) {
  return pw.Text(texto, style: const pw.TextStyle(
    fontSize: 9, height: 1.5, color: PdfColors.grey900,
  ));
}

pw.Widget _tabelaFuncionalidades(PdfColor bg, PdfColor borda, PdfColor azul) {
  final itens = [
    ['Gravação de áudio', 'Relato pós-sessão (até 5 min)'],
    ['Transcrição automática', 'OpenAI Whisper — fala para texto'],
    ['Síntese clínica com IA', 'GPT-4.1 organiza campos do prontuário'],
    ['Artigos científicos', 'IA sugere 2 artigos por sessão'],
    ['14 abordagens', 'Campos adaptados à sua linha teórica'],
    ['Agenda integrada', 'Compromissos com status e navegação'],
    ['Foto do paciente', 'Armazenamento local com criptografia'],
    ['WhatsApp integrado', 'Conversa direta pelo contato'],
    ['PDF profissional', '5 formatos de exportação'],
    ['Criptografia AES-256', 'Proteção local dos dados'],
    ['PIN de acesso', 'Bloqueio de tela com senha'],
    ['JWT + backend seguro', 'Autenticação nas chamadas de IA'],
    ['Backup e restauração', 'Export/import JSON completo'],
    ['Privacidade LGPD', 'Auditoria, arquivamento, revisão'],
    ['Offline-first', 'Funciona sem internet para registros'],
  ];

  return pw.Table(
    border: pw.TableBorder.all(color: borda, width: 0.5),
    columnWidths: {
      0: const pw.FlexColumnWidth(2.5),
      1: const pw.FlexColumnWidth(3.5),
    },
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: azul),
        children: [
          _celula('Funcionalidade', bold: true, cor: PdfColors.white),
          _celula('Descrição', bold: true, cor: PdfColors.white),
        ],
      ),
      ...itens.map((item) => pw.TableRow(
        decoration: pw.BoxDecoration(color: itens.indexOf(item).isEven ? bg : PdfColors.white),
        children: [
          _celula(item[0], bold: true, cor: PdfColors.grey900),
          _celula(item[1]),
        ],
      )),
    ],
  );
}

pw.Widget _celula(String texto, {bool bold = false, PdfColor? cor}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: pw.Text(texto, style: pw.TextStyle(
      fontSize: 7.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: cor,
    )),
  );
}
