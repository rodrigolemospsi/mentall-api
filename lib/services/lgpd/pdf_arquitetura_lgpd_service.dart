import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfArquiteturaLgpdService {
  static const _azul = PdfColor.fromInt(0xFF2563EB);
  static const _azulClaro = PdfColor.fromInt(0xFFDBEAFE);
  static const _azulBg = PdfColor.fromInt(0xFFEFF6FF);
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
      title: 'Arquitetura LGPD - MentAll',
      author: 'MentAll',
    );

    _addSecao(pdf, '1. Identificacao do documento', _conteudoSecao1());
    _addSecao(pdf, '2. Premissa central', _conteudoSecao2());
    _addSecao(pdf, '3. Principios LGPD aplicados', _conteudoSecao3());
    _addSecao(pdf, '4. Classificacao dos dados', _conteudoSecao4());
    _addSecao(pdf, '5. Regra do audio pos-sessao', _conteudoSecao5());
    _addSecao(pdf, '6. Papeis LGPD no MentAll', _conteudoSecao6());
    _addSecao(pdf, '7. Modulos LGPD dentro do app', _conteudoSecao7());
    _addSecao(pdf, '8. IA, privacidade e responsabilidade clinica',
        _conteudoSecao8());
    _addSecao(pdf, '9. Revisao profissional obrigatoria',
        _conteudoSecao9());
    _addSecao(pdf, '10. Estrutura tecnica (Flutter)', _conteudoSecao10());
    _addSecao(pdf, '11. Backlog LGPD', _conteudoSecao11());
    _addSecao(pdf, '12. Documentos necessarios', _conteudoSecao12());
    _addSecao(pdf, '13. Posicionamento recomendado',
        _conteudoSecao13());
    _addSecao(pdf, '14. Resumo executivo', _conteudoSecao14());

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Arquitetura_LGPD_MentAll.pdf',
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
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: _azul)),
          pw.SizedBox(height: 4),
          pw.Container(width: 40, height: 3, color: _azul),
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
          pw.Text('MentAll',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _azul)),
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
          pw.Text('Documento tecnico de trabalho',
              style:
                  const pw.TextStyle(fontSize: 7, color: _subtitulo)),
          pw.Text(
              'Pagina ${context.pageNumber} de ${context.pagesCount}',
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
          _campo('Produto', 'MentAll'),
          _campo('Documento', 'Arquitetura LGPD do Produto'),
          _campo('Versao', '1.0 — documento tecnico de trabalho'),
          pw.SizedBox(height: 12),
          _paragrafo(
              'Este documento estrutura a base de privacidade, seguranca, '
              'responsabilidade clinica, uso de IA, audio pos-sessao, '
              'retencao, auditoria e tratamento de dados sensiveis no MentAll.'),
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
          'O MentAll deve ser desenvolvido como um prontuario psicologico '
          'inteligente com privacidade desde a concepcao.',
          style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _azul),
        ),
      ),
      pw.SizedBox(height: 14),
      _paragrafo(
          'Como o app envolve dados de pessoas atendidas, registros clinicos, '
          'audio pos-sessao, transcricao, sintese por IA e revisao profissional, '
          'a protecao de dados deve fazer parte da arquitetura desde o inicio.'),
      pw.SizedBox(height: 16),
      _status('Status', true),
    ]);
  }

  pw.Widget _conteudoSecao3() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _principio('1. Finalidade clara', 'Cada dado deve ter finalidade compreensivel no uso clinico.', true),
      _principio('2. Necessidade', 'Coletar somente o necessario para cadastro e registro clinico.', true),
      _principio('3. Adequacao', 'Uso dos dados compativel com apoio documental ao psicologo.', true),
      _principio('4. Seguranca', 'Dados clinicos, audio, transcricao e IA com protecao reforcada.', true),
      _principio('5. Prevencao', 'Evitar perda de dados, exposicao indevida e logs clinicos.', true),
      _principio('6. Transparencia', 'Profissional entende como o app usa audio, IA e armazenamento.', true),
      _principio('7. Responsabilizacao', 'Registros minimos de auditoria sobre eventos relevantes.', true),
      pw.SizedBox(height: 10),
      _status('Todos os 7 principios aplicados', true),
    ]);
  }

  pw.Widget _conteudoSecao4() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _subTitulo('4.1 Dados do profissional'),
      _paragrafo('Nome, e-mail, registro profissional, abordagem clinica, termo preferido.'),
      _status('Protecao padrao, autenticacao', true),
      pw.SizedBox(height: 14),
      _subTitulo('4.2 Dados da pessoa atendida'),
      _paragrafo('Nome, data de nascimento, telefone, e-mail, observacoes.'),
      _status('Campos opcionais, criptografia AES-256-CBC', true),
      pw.SizedBox(height: 14),
      _subTitulo('4.3 Dados clinicos sensiveis'),
      _paragrafo('Relato clinico, audio, transcricao, sintese IA, apontamentos.'),
      _status('Protecao maxima, auditoria, revisao obrigatoria, criptografia', true),
      pw.SizedBox(height: 14),
      _subTitulo('4.4 Dados tecnicos'),
      _paragrafo('Status de processamento, erros, datas.'),
      _status('Logs tecnicos NAO contem conteudo clinico', true),
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
          'Audio pos-sessao limitado a 5 minutos para registro breve do relato do profissional.',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _avisoTexto),
        ),
      ),
      pw.SizedBox(height: 14),
      _subTitulo('Regras tecnicas'),
      _check('Limitar gravacao a 5 minutos', true),
      _check('Exibir contador regressivo/progressivo', true),
      _check('Impedir gravacao alem do limite', true),
      _check('Pausar, retomar, ouvir, remover e regravar', true),
      _check('Invalidar IA e revisao apos alteracao do audio', true),
      _check('Registrar auditoria em gravacao/remocao/regravacao', true),
      _check('Opcao futura de apagar audio apos transcricao', false),
      pw.SizedBox(height: 12),
      _subTitulo('Microtexto na tela'),
      _paragrafo('"Relato breve do profissional apos a sessao. Limite: 5 minutos."'),
    ]);
  }

  pw.Widget _conteudoSecao6() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _subTitulo('6.1 Psicologo autonomo'),
      _paragrafo('Psicologo: Controlador dos dados. MentAll: Operador tecnologico.'),
      pw.SizedBox(height: 10),
      _subTitulo('6.2 Clinica ou equipe'),
      _paragrafo('Clinica: Controladora. Profissionais: Usuarios autorizados.'),
      pw.SizedBox(height: 10),
      _subTitulo('6.3 Diretriz'),
      _paragrafo('Decisao clinica e do profissional. IA nao substitui o psicologo.'),
      pw.SizedBox(height: 10),
      _status('Implementado', true),
    ]);
  }

  pw.Widget _conteudoSecao7() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _modulo('7.1 Privacidade e Seguranca', 'Tela central com PIN, politica, termos, audio, IA, retencao.', true),
      _modulo('7.2 Consentimentos', 'Registro de ciencia sobre ferramenta digital e IA.', false),
      _modulo('7.3 Auditoria', 'Registra criacao, edicao, audio, transcricao, IA, revisao.', true),
      _modulo('7.4 Retencao e arquivamento', 'Arquivar em vez de excluir. Exclusao futura com protecao.', true),
      _modulo('7.5 Exportacao segura', 'PDF de sessoes com aviso de dados sensiveis.', true),
      _modulo('7.6 Solicitacoes LGPD', 'Tela futura para acesso, correcao, exportacao e eliminacao.', false),
    ]);
  }

  pw.Widget _conteudoSecao8() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(color: _azulBg, borderRadius: pw.BorderRadius.circular(8), border: pw.Border.all(color: _azulClaro)),
        child: pw.Text('A IA atua apenas como apoio documental. Todo conteudo gerado deve ser revisado pelo profissional.',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _azul)),
      ),
      pw.SizedBox(height: 14),
      _subTitulo('A IA pode'),
      _check('Organizar relatos', true),
      _check('Gerar sintese objetiva', true),
      _check('Sugerir pontos de atencao', true),
      _check('Gerar apontamentos clinicos auxiliares', true),
      pw.SizedBox(height: 10),
      _subTitulo('A IA nao pode'),
      _check('Dar diagnostico definitivo', true),
      _check('Substituir julgamento profissional', true),
      _check('Dispensar revisao humana', true),
      _check('Assumir responsabilidade terapeutica', true),
      pw.SizedBox(height: 10),
      _status('Regras operacionais implementadas', true),
    ]);
  }

  pw.Widget _conteudoSecao9() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _paragrafo('A sessao so e considerada finalizada quando revisada pelo profissional.'),
      pw.SizedBox(height: 12),
      _subTitulo('Eventos que tornam revisao pendente'),
      _check('Nova gravacao, remocao ou regravacao de audio', true),
      _check('Alteracao da transcricao', true),
      _check('Alteracao do relato manual', true),
      _check('Nova geracao de IA', true),
      _check('Edicao da sintese ou apontamentos', true),
      pw.SizedBox(height: 12),
      _subTitulo('Fluxo de status'),
      _paragrafo('manual → audio_gravado → transcrevendo → transcrito → ia_processando → ia_processada → revisado'),
      pw.SizedBox(height: 10),
      _status('Dashboard de pendencias na Home', true),
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
      _backlog('P0 — Antes de usar com dados reais', true, [
        'Limitar audio a 5 minutos',
        'Revisao profissional obrigatoria',
        'Arquivamento em vez de exclusao',
        'Logs sem conteudo clinico',
        'Tela Privacidade e Seguranca',
        'Bloqueio local por PIN',
        'Auditoria inicial',
        'Invalidacao de IA apos alteracoes',
      ]),
      pw.SizedBox(height: 14),
      _backlog('P1 — Antes de beta externo', false, [
        'Criptografia local (AES-256-CBC)',
        'Registro de ciencia/consentimento',
        'Exportacao segura (PDF)',
        'Auditoria completa',
        'Tela de solicitacoes LGPD',
        'Politica de privacidade e termos de uso',
      ]),
      pw.SizedBox(height: 14),
      _backlog('P2 — Antes de comercializar', false, [
        'Revisao juridica completa',
        'Acordo de tratamento de dados',
        'Backup criptografado',
        'Sincronizacao segura',
        'Biometria',
        'Gestao de incidentes',
      ]),
    ]);
  }

  pw.Widget _conteudoSecao12() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _check('1. Arquitetura LGPD do MentAll (este documento)', true),
      _check('2. Politica de Privacidade', true),
      _check('3. Termos de Uso', true),
      _check('4. Acordo de Tratamento de Dados', false),
      _check('5. Politica de Seguranca da Informacao', false),
      _check('6. Politica de Retencao e Exclusao', false),
      _check('7. Politica de Uso de IA', false),
      _check('8. Politica de Suboperadores', false),
      _check('9. Plano de Resposta a Incidentes', false),
    ]);
  }

  pw.Widget _conteudoSecao13() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(color: _azulBg, borderRadius: pw.BorderRadius.circular(8), border: pw.Border.all(color: _azulClaro)),
        child: pw.Text(
          'O MentAll e um prontuario psicologico inteligente com privacidade desde '
          'a concepcao, protecao reforcada de dados clinicos sensiveis, IA apenas '
          'como apoio documental e revisao humana obrigatoria pelo profissional.',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _azul),
        ),
      ),
      pw.SizedBox(height: 20),
      _status('Posicionamento refletido em toda a arquitetura do app', true),
    ]);
  }

  pw.Widget _conteudoSecao14() {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _paragrafo('A estrutura LGPD do MentAll se apoia em sete pilares:'),
      pw.SizedBox(height: 16),
      _pilar('1', 'Dados minimos', 'Coleta apenas do necessario para uso clinico.'),
      _pilar('2', 'Protecao reforcada', 'Criptografia AES-256-CBC, controle via PIN.'),
      _pilar('3', 'Audio 5 min', 'Audio pos-sessao limitado, com contador e parada automatica.'),
      _pilar('4', 'IA como apoio', 'IA documental, nunca substitui julgamento clinico.'),
      _pilar('5', 'Revisao obrigatoria', 'Sessoes finalizadas apenas apos revisao profissional.'),
      _pilar('6', 'Arquivamento', 'Nunca exclusao impulsiva. Dados preservados.'),
      _pilar('7', 'Auditoria', 'Registro LGPD, exportacao segura, transparencia.'),
    ]);
  }

  pw.Widget _paragrafo(String t) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(t, style: const pw.TextStyle(fontSize: 10, color: _texto)));

  pw.Widget _subTitulo(String t) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(t,
          style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold, color: _azul)));

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
                    fontSize: 10, color: ok ? _texto : _futuro))),
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
                    fontSize: 10,
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
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: _texto)),
              pw.SizedBox(height: 2),
              pw.Text(d,
                  style: const pw.TextStyle(
                      fontSize: 10, color: _subtitulo)),
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
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: _texto))),
          _chip(ok ? 'Ativo' : 'Futuro', ok ? _sucesso : _futuro,
              ok ? PdfColor.fromInt(0xFFE8F5E9) : PdfColor.fromInt(0xFFF1F5F9)),
        ]),
        pw.SizedBox(height: 4),
        pw.Text(d,
            style:
                const pw.TextStyle(fontSize: 10, color: _subtitulo)),
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
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: ok ? _sucesso : _avisoTexto))),
              _chip(ok ? 'Concluido' : 'Pendente',
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
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)))),
        pw.SizedBox(width: 12),
        pw.Expanded(
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
              pw.Text(t,
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: _texto)),
              pw.SizedBox(height: 2),
              pw.Text(d,
                  style: const pw.TextStyle(
                      fontSize: 10, color: _subtitulo)),
            ])),
      ]));

  pw.Widget _campo(String label, String valor) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(
            width: 80,
            child: pw.Text('$label:',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _subtitulo))),
        pw.Expanded(
            child: pw.Text(valor,
                style:
                    const pw.TextStyle(fontSize: 11, color: _texto))),
      ]));
}
