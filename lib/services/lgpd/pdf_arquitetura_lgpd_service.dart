import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../utils/tipografia.dart';

class PdfArquiteturaLgpdService {
  static const _azul = PdfColor.fromInt(0xFF8806CE);
  static const _azulClaro = PdfColor.fromInt(0xFFA10AF5);
  static const _titulo = PdfColor.fromInt(0xFF3C096C);
  static const _marca = PdfColor.fromInt(0xFFC77DFF);
  static const _azulBg = PdfColor.fromInt(0x1FA10AF5);
  static const _texto = PdfColor.fromInt(0xFF1E293B);
  static const _subtitulo = PdfColor.fromInt(0xFF475569);
  static const _linha = PdfColor.fromInt(0xFFE2E8F0);
  static const _aviso = PdfColor.fromInt(0xFFFFF3E0);
  static const _avisoTexto = PdfColor.fromInt(0xFFE65100);
  static const _sucesso = PdfColor.fromInt(0xFF2E7D32);
  static const _pendente = PdfColor.fromInt(0xFFE65100);
  static const _futuro = PdfColor.fromInt(0xFF64748B);

  Future<void> exportar() async {
    final pdf = pw.Document(
      title: 'Arquitetura LGPD - MentAll PRO',
      author: 'MentAll PRO',
    );

    _addSecao(pdf, '1. Identificação do documento', _conteudoSecao1());
    _addSecao(pdf, '2. Premissa central', _conteudoSecao2());
    _addSecao(pdf, '3. Princípios LGPD aplicados', _conteudoSecao3());
    _addSecao(pdf, '4. Classificação dos dados', _conteudoSecao4());
    _addSecao(pdf, '5. Regra do áudio pós-sessão', _conteudoSecao5());
    _addSecao(pdf, '6. Papéis LGPD no MentAll PRO', _conteudoSecao6());
    _addSecao(pdf, '7. Módulos LGPD dentro do app', _conteudoSecao7());
    _addSecao(pdf, '8. IA, privacidade e responsabilidade clínica',
        _conteudoSecao8());
    _addSecao(pdf, '9. Revisão profissional obrigatória',
        _conteudoSecao9());
    _addSecao(pdf, '10. Estrutura técnica (Flutter)', _conteudoSecao10());
    _addSecao(pdf, '11. Backlog LGPD', _conteudoSecao11());
    _addSecao(pdf, '12. Documentos necessários', _conteudoSecao12());
    _addSecao(pdf, '13. Posicionamento recomendado',
        _conteudoSecao13());
    _addSecao(pdf, '14. Resumo executivo', _conteudoSecao14());

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Arquitetura_LGPD_MentAll PRO.pdf',
    );
  }

  void _addSecao(pw.Document pdf, String titulo, pw.Widget conteudo) {
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 36, 48, 48),
        header: _header,
        footer: _footer,
        build: (ctx) => [
          pw.Text(titulo,
              style: pw.TextStyle(
                  fontSize: Tipografia.lg,
                  fontWeight: pw.FontWeight.bold,
                  color: _titulo)),
          pw.SizedBox(height: 4),
          pw.Container(width: 40, height: 3, color: _titulo),
          pw.SizedBox(height: 20),
          conteudo,
        ],
      ),
    );
  }

  pw.Widget _header(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border:
            pw.Border(bottom: pw.BorderSide(color: _linha, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('MentAll PRO',
              style: pw.TextStyle(
                  fontSize: Tipografia.xxs,
                  fontWeight: pw.FontWeight.bold,
                  color: _marca)),
          pw.Text('Arquitetura LGPD v1.0',
              style:
                  const pw.TextStyle(fontSize: 8, color: _subtitulo)),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border:
            pw.Border(top: pw.BorderSide(color: _linha, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Documento técnico de trabalho',
              style:
                  const pw.TextStyle(fontSize: 7, color: _subtitulo)),
          pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style:
                  const pw.TextStyle(fontSize: 7, color: _subtitulo)),
        ],
      ),
    );
  }

  pw.Widget _conteudoSecao1() {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _campo('Produto', 'MentAll PRO'),
          _campo('Documento', 'Arquitetura LGPD do Produto'),
          _campo('Versão', '1.0 - documento técnico de trabalho'),
          pw.SizedBox(height: 12),
          _paragrafo(
              'Este documento estrutura a base de privacidade, segurança, '
              'responsabilidade clínica, uso de IA, áudio pós-sessão, '
              'retenção, auditoria e tratamento de dados sensíveis no MentAll PRO.'),
        ]);
  }

  pw.Widget _conteudoSecao2() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: _azulBg,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: _azulClaro),
        ),
        child: pw.Text(
          'O MentAll PRO deve ser desenvolvido como um prontuário psicológico '
          'inteligente com privacidade desde a concepção.',
          style: pw.TextStyle(
              fontSize: Tipografia.smMd,
              fontWeight: pw.FontWeight.bold,
              color: _azul),
        ),
      ),
      pw.SizedBox(height: 14),
      _paragrafo(
          'Como o app envolve dados de pessoas atendidas, registros clínicos, '
          'áudio pós-sessão, transcrição, síntese por IA e revisão profissional, '
          'a proteção de dados deve fazer parte da arquitetura desde o início.'),
      pw.SizedBox(height: 16),
      _status('Status', true),
    ]);
  }

  pw.Widget _conteudoSecao3() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _principio('1. Finalidade clara', 'Cada dado deve ter finalidade compreensível no uso clínico.', true),
      _principio('2. Necessidade', 'Coletar somente o necessário para cadastro e registro clínico.', true),
      _principio('3. Adequação', 'Uso dos dados compatível com apoio documental ao psicólogo.', true),
      _principio('4. Segurança', 'Dados clínicos, áudio, transcrição e IA com proteção reforçada.', true),
      _principio('5. Prevenção', 'Evitar perda de dados, exposição indevida e logs clínicos.', true),
      _principio('6. Transparência', 'Profissional entende como o app usa áudio, IA e armazenamento.', true),
      _principio('7. Responsabilizacao', 'Registros mínimos de auditoria sobre eventos relevantes.', true),
      pw.SizedBox(height: 10),
      _status('Todos os 7 princípios aplicados', true),
    ]);
  }

  pw.Widget _conteudoSecao4() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _subTitulo('4.1 Dados do profissional'),
      _paragrafo('Nome, e-mail, registro profissional, abordagem clínica, termo preferido.'),
      _status('Proteção padrao, autenticação', true),
      pw.SizedBox(height: 14),
      _subTitulo('4.2 Dados da pessoa atendida'),
      _paragrafo('Nome, data de nascimento, telefone, e-mail, observações.'),
      _status('Campos opcionais, criptografia AES-256-CBC', true),
      pw.SizedBox(height: 14),
      _subTitulo('4.3 Dados clínicos sensíveis'),
      _paragrafo('Relato clínico, áudio, transcrição, síntese IA, apontamentos.'),
      _status('Proteção máxima, auditoria, revisão obrigatória, criptografia', true),
      pw.SizedBox(height: 14),
      _subTitulo('4.4 Dados técnicos'),
      _paragrafo('Status de processamento, erros, datas.'),
      _status('Logs técnicos NÃO contêm conteúdo clínico', true),
    ]);
  }

  pw.Widget _conteudoSecao5() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _aviso,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          'Áudio pós-sessão limitado a 5 minutos para registro breve do relato do profissional.',
          style: pw.TextStyle(fontSize: Tipografia.sm, fontWeight: pw.FontWeight.bold, color: _avisoTexto),
        ),
      ),
      pw.SizedBox(height: 14),
      _subTitulo('Regras técnicas'),
      _check('Limitar gravação a 5 minutos', true),
      _check('Exibir contador regressivo/progressivo', true),
      _check('Impedir gravação alem do limite', true),
      _check('Pausar, retomar, ouvir, remover e regravar', true),
      _check('Invalidar IA e revisão após alteração do áudio', true),
      _check('Registrar auditoria em gravação/remoção/regravação', true),
      _check('Opcao futura de apagar áudio após transcrição', false),
      pw.SizedBox(height: 12),
      _subTitulo('Microtexto na tela'),
      _paragrafo('"Relato breve do profissional após a sessão. Limite: 5 minutos."'),
    ]);
  }

  pw.Widget _conteudoSecao6() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _subTitulo('6.1 Psicólogo autonomo'),
      _paragrafo('Psicólogo: Controlador dos dados. MentAll PRO: Operador tecnologico.'),
      pw.SizedBox(height: 10),
      _subTitulo('6.2 Clínica ou equipe'),
      _paragrafo('Clínica: Controladora. Profissionais: Usuarios autorizados.'),
      pw.SizedBox(height: 10),
      _subTitulo('6.3 Diretriz'),
      _paragrafo('Decisão clínica e do profissional. IA não substitui o psicólogo.'),
      pw.SizedBox(height: 10),
      _status('Implementado', true),
    ]);
  }

  pw.Widget _conteudoSecao7() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _modulo('7.1 Privacidade e Segurança', 'Tela central com PIN, política, termos, áudio, IA, retenção.', true),
      _modulo('7.2 Consentimentos', 'Registro de ciência sobre ferramenta digital e IA.', false),
      _modulo('7.3 Auditoria', 'Registra criação, edição, áudio, transcrição, IA, revisão.', true),
      _modulo('7.4 Retenção e arquivamento', 'Arquivar em vez de excluir. Exclusão futura com proteção.', true),
      _modulo('7.5 Exportação segura', 'PDF de sessões com aviso de dados sensíveis.', true),
      _modulo('7.6 Solicitações LGPD', 'Tela futura para acesso, correcao, exportação e eliminacao.', false),
    ]);
  }

  pw.Widget _conteudoSecao8() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(color: _azulBg, borderRadius: pw.BorderRadius.circular(8), border: pw.Border.all(color: _azulClaro)),
        child: pw.Text('A IA atua apenas como apoio documental. Todo conteúdo gerado deve ser revisado pelo profissional.',
            style: pw.TextStyle(fontSize: Tipografia.sm, fontWeight: pw.FontWeight.bold, color: _azul)),
      ),
      pw.SizedBox(height: 14),
      _subTitulo('A IA pode'),
      _check('Organizar relatos', true),
      _check('Gerar síntese objetiva', true),
      _check('Sugerir pontos de atenção', true),
      _check('Gerar apontamentos clínicos auxiliares', true),
      pw.SizedBox(height: 10),
      _subTitulo('A IA não pode'),
      _check('Dar diagnóstico definitivo', true),
      _check('Substituir julgamento profissional', true),
      _check('Dispensar revisão humana', true),
      _check('Assumir responsabilidade terapêutica', true),
      pw.SizedBox(height: 10),
      _status('Regras operacionais implementadas', true),
    ]);
  }

  pw.Widget _conteudoSecao9() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _paragrafo('A sessão só é considerada finalizada quando revisada pelo profissional.'),
      pw.SizedBox(height: 12),
      _subTitulo('Eventos que tornam revisão pendente'),
      _check('Nova gravação, remoção ou regravação de áudio', true),
      _check('Alteração da transcrição', true),
      _check('Alteração do relato manual', true),
      _check('Nova geracao de IA', true),
      _check('Edição da síntese ou apontamentos', true),
      pw.SizedBox(height: 12),
      _subTitulo('Fluxo de status'),
      _paragrafo('manual → áudio_gravado → transcrevendo → transcrito → ia_processando → ia_processada → revisado'),
      pw.SizedBox(height: 10),
      _status('Dashboard de pendências na Home', true),
    ]);
  }

  pw.Widget _conteudoSecao10() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _subTitulo('Models (lib/models/lgpd/)'),
      _check('registro_auditoria.dart', true),
      _check('consentimento_lgpd.dart', false),
      _check('solicitacao_titular.dart', false),
      pw.SizedBox(height: 12),
      _subTitulo('Services (lib/services/lgpd/)'),
      _check('auditoria_service.dart', true),
      _check('pdf_arquitetura_lgpd_service.dart', true),
      _check('consentimento_service.dart', false),
      pw.SizedBox(height: 12),
      _subTitulo('Screens (lib/screens/lgpd/)'),
      _check('privacidade_seguranca_page.dart', true),
      _check('politica_privacidade_page.dart', true),
      _check('termos_uso_page.dart', true),
      _check('consentimentos_page.dart', false),
      _check('auditoria_page.dart', false),
      pw.SizedBox(height: 12),
      _subTitulo('Widgets (lib/widgets/lgpd/)'),
      _check('aviso_privacidade_ia_card.dart', true),
    ]);
  }

  pw.Widget _conteudoSecao11() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _backlog('P0 - Antes de usar com dados reais', true, [
        'Limitar áudio a 5 minutos',
        'Revisão profissional obrigatória',
        'Arquivamento em vez de exclusão',
        'Logs sem conteúdo clínico',
        'Tela Privacidade e Segurança',
        'Bloqueio local por PIN',
        'Auditoria inicial',
        'Invalidação de IA após alterações',
      ]),
      pw.SizedBox(height: 14),
      _backlog('P1 - Antes de beta externo', false, [
        'Criptografia local (AES-256-CBC)',
        'Registro de ciência/consentimento',
        'Exportação segura (PDF)',
        'Auditoria completa',
        'Tela de solicitações LGPD',
        'Política de privacidade e termos de uso',
      ]),
      pw.SizedBox(height: 14),
      _backlog('P2 - Antes de comercializar', false, [
        'Revisão jurídica completa',
        'Acordo de tratamento de dados',
        'Backup criptografado',
        'Sincronização segura',
        'Biometria',
        'Gestão de incidentes',
      ]),
    ]);
  }

  pw.Widget _conteudoSecao12() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _check('1. Arquitetura LGPD do MentAll PRO (este documento)', true),
      _check('2. Política de Privacidade', true),
      _check('3. Termos de Uso', true),
      _check('4. Acordo de Tratamento de Dados', false),
      _check('5. Política de Segurança da Informação', false),
      _check('6. Política de Retenção e Exclusão', false),
      _check('7. Política de Uso de IA', false),
      _check('8. Política de Suboperadores', false),
      _check('9. Plano de Resposta a Incidentes', false),
    ]);
  }

  pw.Widget _conteudoSecao13() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(color: _azulBg, borderRadius: pw.BorderRadius.circular(8), border: pw.Border.all(color: _azulClaro)),
        child: pw.Text(
          'O MentAll PRO e um prontuário psicológico inteligente com privacidade desde '
          'a concepção, proteção reforçada de dados clínicos sensíveis, IA apenas '
          'como apoio documental e revisão humana obrigatória pelo profissional.',
          style: pw.TextStyle(fontSize: Tipografia.smMd, fontWeight: pw.FontWeight.bold, color: _azul),
        ),
      ),
      pw.SizedBox(height: 20),
      _status('Posicionamento refletido em toda a arquitetura do app', true),
    ]);
  }

  pw.Widget _conteudoSecao14() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _paragrafo('A estrutura LGPD do MentAll PRO se apoia em sete pilares:'),
      pw.SizedBox(height: 16),
      _pilar('1', 'Dados mínimos', 'Coleta apenas do necessário para uso clínico.'),
      _pilar('2', 'Proteção reforçada', 'Criptografia AES-256-CBC, controle via PIN.'),
      _pilar('3', 'Áudio 5 min', 'Áudio pós-sessão limitado, com contador e parada automática.'),
      _pilar('4', 'IA como apoio', 'IA documental, nunca substitui julgamento clínico.'),
      _pilar('5', 'Revisão obrigatória', 'Sessões finalizadas apenas após revisão profissional.'),
      _pilar('6', 'Arquivamento', 'Nunca exclusão impulsiva. Dados preservados.'),
      _pilar('7', 'Auditoria', 'Registro LGPD, exportação segura, transparência.'),
    ]);
  }

  pw.Widget _paragrafo(String t) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(t, style: const pw.TextStyle(fontSize: Tipografia.xxs, color: _texto)));

  pw.Widget _subTitulo(String t) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(t,
          style: pw.TextStyle(
              fontSize: Tipografia.sm, fontWeight: pw.FontWeight.bold, color: _azul)));

  pw.Widget _check(String texto, bool ok) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4, left: 4),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
            margin: const pw.EdgeInsets.only(top: 2),
            width: 12,
            height: 12,
            decoration: pw.BoxDecoration(
                color: ok ? _sucesso : _futuro,
                shape: pw.BoxShape.circle),
            child: pw.Center(
                child: pw.Text(ok ? '✓' : '→',
                    style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold)))),
        pw.SizedBox(width: 8),
        pw.Expanded(
            child: pw.Text(texto,
                style: pw.TextStyle(
                    fontSize: Tipografia.xxs, color: ok ? _texto : _futuro))),
      ]));

  pw.Widget _chip(String t, PdfColor cor, PdfColor bg) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: pw.BoxDecoration(
          color: bg, borderRadius: pw.BorderRadius.circular(10)),
      child: pw.Text(t,
          style: pw.TextStyle(
              fontSize: 8, fontWeight: pw.FontWeight.bold, color: cor)));

  pw.Widget _status(String t, bool ok) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
          color: ok ? PdfColor.fromInt(0xFFE8F5E9) : _aviso,
          borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Row(children: [
        _chip(ok ? 'OK' : 'PEND', ok ? _sucesso : _pendente,
            ok ? PdfColor.fromInt(0xFFC8E6C9) : PdfColor.fromInt(0xFFFFE0B2)),
        pw.SizedBox(width: 8),
        pw.Expanded(
            child: pw.Text(t,
                style: pw.TextStyle(
                    fontSize: Tipografia.xxs,
                    fontWeight: pw.FontWeight.bold,
                    color: ok ? _sucesso : _pendente))),
      ]));

  pw.Widget _principio(String t, String d, bool ok) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
            margin: const pw.EdgeInsets.only(top: 2, right: 8),
            width: 12,
            height: 12,
            decoration: pw.BoxDecoration(
                color: ok ? _sucesso : _pendente,
                shape: pw.BoxShape.circle),
            child: pw.Center(
                child: pw.Text(ok ? '✓' : '!',
                    style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold)))),
        pw.Expanded(
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
              pw.Text(t,
                  style: pw.TextStyle(
                      fontSize: Tipografia.sm,
                      fontWeight: pw.FontWeight.bold,
                      color: _texto)),
              pw.SizedBox(height: 2),
              pw.Text(d,
                  style: const pw.TextStyle(
                      fontSize: Tipografia.xxs, color: _subtitulo)),
            ])),
        pw.SizedBox(width: 8),
        _chip(ok ? 'OK' : 'PEND', ok ? _sucesso : _pendente,
            ok ? PdfColor.fromInt(0xFFC8E6C9) : PdfColor.fromInt(0xFFFFE0B2)),
      ]));

  pw.Widget _modulo(String t, String d, bool ok) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(children: [
          pw.Expanded(
              child: pw.Text(t,
                  style: pw.TextStyle(
                      fontSize: Tipografia.smMd,
                      fontWeight: pw.FontWeight.bold,
                      color: _texto))),
          _chip(ok ? 'Ativo' : 'Futuro', ok ? _sucesso : _futuro,
              ok ? PdfColor.fromInt(0xFFE8F5E9) : PdfColor.fromInt(0xFFF1F5F9)),
        ]),
        pw.SizedBox(height: 4),
        pw.Text(d,
            style:
                const pw.TextStyle(fontSize: Tipografia.xxs, color: _subtitulo)),
      ]));

  pw.Widget _backlog(String t, bool ok, List<String> itens) => pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
          color: ok ? PdfColor.fromInt(0xFFE8F5E9) : _aviso,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(
              color: ok ? _sucesso : _avisoTexto, width: 0.5)),
      child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(children: [
              pw.Expanded(
                  child: pw.Text(t,
                      style: pw.TextStyle(
                          fontSize: Tipografia.smMd,
                          fontWeight: pw.FontWeight.bold,
                          color: ok ? _sucesso : _avisoTexto))),
              _chip(ok ? 'Concluído' : 'Pendente',
                  ok ? _sucesso : _pendente,
                  ok ? PdfColor.fromInt(0xFFC8E6C9) : PdfColor.fromInt(0xFFFFE0B2)),
            ]),
            pw.SizedBox(height: 8),
            ...itens.map((i) => _check(i, ok)),
          ]));

  pw.Widget _pilar(String num, String t, String d) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
            width: 32,
            height: 32,
            decoration: pw.BoxDecoration(
                color: _azul,
                borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Center(
                child: pw.Text(num,
                    style: pw.TextStyle(
                        fontSize: Tipografia.md,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)))),
        pw.SizedBox(width: 12),
        pw.Expanded(
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
              pw.Text(t,
                  style: pw.TextStyle(
                      fontSize: Tipografia.smMd,
                      fontWeight: pw.FontWeight.bold,
                      color: _texto)),
              pw.SizedBox(height: 2),
              pw.Text(d,
                  style: const pw.TextStyle(
                      fontSize: Tipografia.xxs, color: _subtitulo)),
            ])),
      ]));

  pw.Widget _campo(String label, String valor) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(
            width: 80,
            child: pw.Text('$label:',
                style: pw.TextStyle(
                    fontSize: Tipografia.xs,
                    fontWeight: pw.FontWeight.bold,
                    color: _subtitulo))),
        pw.Expanded(
            child: pw.Text(valor,
                style:
                    const pw.TextStyle(fontSize: Tipografia.xs, color: _texto))),
      ]));
}
