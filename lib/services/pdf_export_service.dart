import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../config/configuracao_abordagem_clinica.dart';
import '../models/paciente.dart';
import '../models/perfil_profissional.dart';
import '../models/sessao.dart';
import 'logger.dart';

class PdfExportService {
  static const PdfColor _primaria = PdfColor.fromInt(0xFF2563EB);
  static const PdfColor _primariaClara = PdfColor.fromInt(0xFFDBEAFE);
  static const PdfColor _secundaria = PdfColor.fromInt(0xFF64748B);
  static const PdfColor _fundo = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor _superficie = PdfColor.fromInt(0xFFF1F5F9);
  static const PdfColor _linha = PdfColor.fromInt(0xFFE2E8F0);

  static Uint8List? _logoBytes;
  static pw.MemoryImage? _logoImage;

  static Future<void> _carregarLogo() async {
    if (_logoBytes != null) return;
    try {
      _logoBytes = (await rootBundle.load('assets/images/logo_mentall.png'))
          .buffer
          .asUint8List();
      _logoImage = pw.MemoryImage(_logoBytes!);
    } catch (_) {}
  }

  PdfExportService() {
    _carregarLogo();
  }

  Future<void> exportarSessao({
    required Sessao sessao,
    required Paciente paciente,
    required PerfilProfissional perfil,
  }) async {
    try {
      final pdf = await _gerarPdfSessao(
        sessao: sessao,
        paciente: paciente,
        perfil: perfil,
      );
      await _salvarOuImprimir(
        pdf: pdf,
        nomeArquivo: 'sessao_${sessao.numeroSessao}_${paciente.nome}.pdf',
      );
    } catch (e) {
      Log.erro(e, contexto: 'PdfExportService.exportarSessao');
      rethrow;
    }
  }

  Future<void> exportarHistoricoPaciente({
    required Paciente paciente,
    required List<Sessao> sessoes,
    required PerfilProfissional perfil,
  }) async {
    try {
      final pdf = await _gerarPdfHistorico(
        paciente: paciente,
        sessoes: sessoes,
        perfil: perfil,
      );
      await _salvarOuImprimir(
        pdf: pdf,
        nomeArquivo: 'historico_${paciente.nome}.pdf',
      );
    } catch (e) {
      Log.erro(e, contexto: 'PdfExportService.exportarHistorico');
      rethrow;
    }
  }

  Future<void> exportarRelatorioClinico({
    required Paciente paciente,
    required List<Sessao> sessoes,
    required PerfilProfissional perfil,
  }) async {
    try {
      final pdf = await _gerarPdfRelatorioClinico(
        paciente: paciente,
        sessoes: sessoes,
        perfil: perfil,
      );
      await _salvarOuImprimir(
        pdf: pdf,
        nomeArquivo: 'relatorio_clinico_${paciente.nome}.pdf',
      );
    } catch (e) {
      Log.erro(e, contexto: 'PdfExportService.exportarRelatorioClinico');
      rethrow;
    }
  }

  Future<void> exportarSinteseRevisada({
    required Sessao sessao,
    required Paciente paciente,
    required PerfilProfissional perfil,
  }) async {
    try {
      final pdf = await _gerarPdfSinteseRevisada(
        sessao: sessao,
        paciente: paciente,
        perfil: perfil,
      );
      await _salvarOuImprimir(
        pdf: pdf,
        nomeArquivo: 'sintese_revisada_sessao_${sessao.numeroSessao}_${paciente.nome}.pdf',
      );
    } catch (e) {
      Log.erro(e, contexto: 'PdfExportService.exportarSinteseRevisada');
      rethrow;
    }
  }

  Future<void> exportarProntuarioCompleto({
    required Paciente paciente,
    required List<Sessao> sessoes,
    required PerfilProfissional perfil,
  }) async {
    try {
      final pdf = await _gerarPdfProntuarioCompleto(
        paciente: paciente,
        sessoes: sessoes,
        perfil: perfil,
      );
      await _salvarOuImprimir(
        pdf: pdf,
        nomeArquivo: 'prontuario_completo_${paciente.nome}.pdf',
      );
    } catch (e) {
      Log.erro(e, contexto: 'PdfExportService.exportarProntuarioCompleto');
      rethrow;
    }
  }

  Future<Uint8List> _gerarPdfSessao({
    required Sessao sessao,
    required Paciente paciente,
    required PerfilProfissional perfil,
  }) async {
    final config = ConfiguracaoAbordagemClinica.porNome(
      perfil.abordagemClinica,
    );

    final doc = pw.Document();
    doc.addPage(
      _paginaSessao(
        sessao: sessao,
        paciente: paciente,
        perfil: perfil,
        config: config,
        habilitarQuebraPagina: false,
      ),
    );
    return doc.save();
  }

  Future<Uint8List> _gerarPdfHistorico({
    required Paciente paciente,
    required List<Sessao> sessoes,
    required PerfilProfissional perfil,
  }) async {
    final config = ConfiguracaoAbordagemClinica.porNome(
      perfil.abordagemClinica,
    );

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _cabecalhoPagina(perfil),
        footer: (context) => _rodapePagina(context),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'HISTÓRICO CLÍNICO',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: _primaria,
              ),
            ),
          ),
          pw.SizedBox(height: 16),
          _dadosPaciente(paciente),
          pw.SizedBox(height: 8),
          _linhaSeparadora(),
          pw.SizedBox(height: 16),
          if (sessoes.isEmpty)
            pw.Text(
              'Nenhuma sessão registrada.',
              style: pw.TextStyle(
                color: _secundaria,
                fontSize: 12,
              ),
            )
          else
            ...sessoes.map(
              (s) => _cardSessao(
                sessao: s,
                config: config,
                ehPrimeira: s == sessoes.first,
              ),
            ),
          pw.SizedBox(height: 16),
          _secaoDisclaimerIa(),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _cabecalhoPagina(PerfilProfissional perfil) {
    final infoProfissional = <pw.Widget>[
      pw.Text(
        'Psicólogo',
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: _secundaria,
        ),
      ),
      pw.Text(
        perfil.nomeExibicao,
        style: pw.TextStyle(
          fontSize: 8,
          color: _secundaria,
        ),
      ),
    ];
    if (perfil.possuiRegistroProfissional) {
      infoProfissional.add(
        pw.Text(
          'CRP ${perfil.registroProfissional}',
          style: pw.TextStyle(
            fontSize: 7,
            color: _secundaria,
          ),
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border(
          bottom: pw.BorderSide(color: _linha, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          if (_logoImage != null)
            pw.Image(_logoImage!, height: 44)
          else
            pw.Text(
              'MentAll',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _primaria,
                letterSpacing: 1.2,
              ),
            ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: infoProfissional,
          ),
        ],
      ),
    );
  }

  pw.Widget _rodapePagina(pw.Context context) {
    final pageCount = context.pageNumber;
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _linha, width: 0.5),
        ),
      ),
      child: pw.Text(
        'Página $pageCount',
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.MultiPage _paginaSessao({
    required Sessao sessao,
    required Paciente paciente,
    required PerfilProfissional perfil,
    required ConfiguracaoAbordagemClinica config,
    required bool habilitarQuebraPagina,
  }) {
    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (context) => _cabecalhoPagina(perfil),
      footer: (context) => _rodapePagina(context),
      build: (context) => [
        _tituloSecao('Registro de Sessão'),
        pw.SizedBox(height: 2),
        pw.Text(
          paciente.nomeExibicao,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: _primaria,
          ),
        ),
        pw.SizedBox(height: 16),
        _cabecalhoSessao(sessao),
        pw.SizedBox(height: 8),
        _linhaSeparadora(),
        pw.SizedBox(height: 12),
        _secaoClinica(sessao, config),
        pw.SizedBox(height: 16),
        _secaoExportacao(),
        _secaoDisclaimerIa(),
      ],
    );
  }

  pw.Widget _cabecalhoSessao(Sessao sessao) {
    final data = _formatarData(sessao.data);
    final hora = _formatarHorario(sessao.data);

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _superficie,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: _campoInfo('Data', '$data às $hora'),
          ),
          _badgeRevisao(sessao.revisadoPeloProfissional),
        ],
      ),
    );
  }

  pw.Widget _campoInfo(String rotulo, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            rotulo,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _secundaria,
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Text(
              valor,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _secaoClinica(
    Sessao sessao,
    ConfiguracaoAbordagemClinica config,
  ) {
    final campos = <pw.Widget>[];

    void addCampo(String label, String texto) {
      if (texto.trim().isEmpty) return;
      campos.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: _secundaria,
                letterSpacing: 0.8,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.only(left: 10),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(color: _primariaClara, width: 2),
                ),
              ),
              child: pw.Text(
                texto,
                textAlign: pw.TextAlign.justify,
                style: const pw.TextStyle(
                  fontSize: 10,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ));
    }

    final sintese = _concatenarSintese(sessao);
    final formulacao = _concatenarFormulacao(sessao);
    final intervencoes = _concatenarIntervencoes(sessao);

    addCampo('Relato pós-sessão', sessao.relatoPosSessao);
    addCampo('Síntese clínica', sintese);
    addCampo(config.tituloFormulaClinica, formulacao);
    addCampo(config.tituloIntervencoes, intervencoes);
    addCampo('Apontamentos', sessao.apontamentosCopiloto);
    addCampo('Artigos sugeridos', sessao.artigosSugeridos);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: campos.isEmpty
          ? [
              pw.Text(
                'Nenhum conteúdo clínico registrado nesta sessão.',
                style: pw.TextStyle(
                  color: _secundaria,
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ]
          : campos,
    );
  }

  String _concatenarSintese(Sessao s) {
    final partes = <String>[];
    if (s.eventosImportantes.trim().isNotEmpty) partes.add(s.eventosImportantes.trim());
    if (s.evolucaoClinica.trim().isNotEmpty) partes.add(s.evolucaoClinica.trim());
    if (s.observacoes.trim().isNotEmpty) partes.add(s.observacoes.trim());
    return partes.join('\n\n');
  }

  String _concatenarFormulacao(Sessao s) {
    final partes = <String>[];
    if (s.pensamentosAutomaticos.trim().isNotEmpty) partes.add(s.pensamentosAutomaticos.trim());
    if (s.emocoes.trim().isNotEmpty) partes.add(s.emocoes.trim());
    if (s.comportamentos.trim().isNotEmpty) partes.add(s.comportamentos.trim());
    return partes.join('\n\n');
  }

  String _concatenarIntervencoes(Sessao s) {
    final partes = <String>[];
    if (s.intervencoes.trim().isNotEmpty) partes.add(s.intervencoes.trim());
    if (s.tecnicasTcc.trim().isNotEmpty) partes.add(s.tecnicasTcc.trim());
    return partes.join('\n\n');
  }

  pw.Widget _secaoRevisao(Sessao sessao) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _linha, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CONTROLE DE REVISÃO',
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: _secundaria,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 6),
          _campoInfo(
            'Revisado pelo profissional',
            sessao.revisadoPeloProfissional ? 'Sim' : 'Não',
          ),
          _campoInfo(
            'Status',
            sessao.statusProcessamento,
          ),
          _campoInfo(
            'Origem do relato',
            sessao.origemRelato,
          ),
          if (sessao.geradoComIa)
            _campoInfo(
              'IA utilizada',
              'Sim — a IA foi utilizada como apoio à documentação clínica. '
                  'Todo o conteúdo foi revisado pelo profissional responsável.',
            ),
          if (sessao.dataProcessamentoIa != null)
            _campoInfo(
              'Processamento IA',
              '${_formatarData(sessao.dataProcessamentoIa!)} às '
                  '${_formatarHorario(sessao.dataProcessamentoIa!)}',
            ),
        ],
      ),
    );
  }

  pw.Widget _secaoExportacao() {
    final agora = DateTime.now();

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Text(
        'Documento exportado do MentAll em '
        '${_formatarData(agora)} às ${_formatarHorario(agora)}. '
        'Documento clínico para uso profissional.',
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _secaoDisclaimerIa() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _fundo,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Text(
        'Este documento pode conter conteúdo auxiliado por inteligência artificial. '
        'A IA é uma ferramenta de apoio à documentação clínica e não substitui o '
        'julgamento profissional do psicólogo. Todo o conteúdo aqui presente foi '
        'revisado e validado pelo profissional responsável.',
        style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey500, height: 1.4),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _dadosPaciente(Paciente paciente) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _superficie,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _campoInfo('Nome', paciente.nomeExibicao),
          _campoInfo(
            'Cadastro',
            _formatarData(paciente.dataCadastro),
          ),
          if (paciente.possuiDataNascimento)
            _campoInfo('Idade', paciente.idadeExibicao),
          if (paciente.possuiContato)
            _campoInfo('Contato', paciente.contatoExibicao),
          if (paciente.possuiObservacoes)
            _campoInfo('Observações', paciente.observacoesExibicao),
        ],
      ),
    );
  }

  pw.Widget _cardSessao({
    required Sessao sessao,
    required ConfiguracaoAbordagemClinica config,
    required bool ehPrimeira,
  }) {
    final widgets = <pw.Widget>[];

    if (!ehPrimeira) {
      widgets.add(_linhaSeparadora());
      widgets.add(pw.SizedBox(height: 12));
    }

    widgets.add(
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _fundo,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Sessão ${sessao.numeroSessao}',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaria,
                  ),
                ),
                pw.Text(
                  '${_formatarData(sessao.data)} às '
                  '${_formatarHorario(sessao.data)}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: _secundaria,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            if (sessao.relatoPosSessao.trim().isNotEmpty)
              pw.Text(
                sessao.relatoPosSessao,
                textAlign: pw.TextAlign.justify,
                style: const pw.TextStyle(
                  fontSize: 10,
                  height: 1.5,
                ),
              ),
          ],
        ),
      ),
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: widgets,
    );
  }

  pw.Widget _tituloSecao(String texto) {
    return pw.Text(
      texto.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: _secundaria,
        letterSpacing: 0.8,
      ),
    );
  }

  pw.Widget _linhaSeparadora() {
    return pw.Container(
      height: 0.5,
      color: _linha,
    );
  }

  Future<Uint8List> _gerarPdfRelatorioClinico({
    required Paciente paciente,
    required List<Sessao> sessoes,
    required PerfilProfissional perfil,
  }) async {
    final config = ConfiguracaoAbordagemClinica.porNome(
      perfil.abordagemClinica,
    );

    final sessoesAtivas =
        sessoes.where((s) => s.estaAtiva).toList()
          ..sort((a, b) => b.data.compareTo(a.data));

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _cabecalhoPagina(perfil),
        footer: (context) => _rodapePagina(context),
        build: (context) => [
          _tituloSecao('Relatorio Clinico'),
          pw.SizedBox(height: 12),
          _dadosPaciente(paciente),
          pw.SizedBox(height: 8),
          _dadosProfissionalResumido(perfil, config),
          pw.SizedBox(height: 8),
          _linhaSeparadora(),
          pw.SizedBox(height: 16),
          _tituloSecao('Evolucao Clinica'),
          pw.SizedBox(height: 8),
          ..._evolucaoClinicaSessoes(sessoesAtivas),
          pw.SizedBox(height: 16),
          _secaoExportacao(),
        ],
      ),
    );
    return doc.save();
  }

  Future<Uint8List> _gerarPdfSinteseRevisada({
    required Sessao sessao,
    required Paciente paciente,
    required PerfilProfissional perfil,
  }) async {
    final config = ConfiguracaoAbordagemClinica.porNome(
      perfil.abordagemClinica,
    );

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _cabecalhoPagina(perfil),
        footer: (context) => _rodapePagina(context),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _tituloSecao('Sintese Revisada'),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Sessao ${sessao.numeroSessao} — ${paciente.nomeExibicao}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: _primaria,
                      ),
                    ),
                  ],
                ),
              ),
              _badgeRevisao(sessao.revisadoPeloProfissional),
            ],
          ),
          pw.SizedBox(height: 12),
          _cabecalhoSessao(sessao),
          pw.SizedBox(height: 8),
          _linhaSeparadora(),
          pw.SizedBox(height: 12),
          if (sessao.relatoPosSessao.trim().isNotEmpty) ...[
            _tituloSecao('Relato Clinico Organizado'),
            pw.SizedBox(height: 4),
            _blocoTexto(sessao.relatoPosSessao),
            pw.SizedBox(height: 12),
          ],
          if (sessao.transcricaoRevisada.trim().isNotEmpty) ...[
            _tituloSecao('Transcricao Revisada'),
            pw.SizedBox(height: 4),
            _blocoTexto(sessao.transcricaoRevisada),
            pw.SizedBox(height: 12),
          ] else if (sessao.transcricaoRelato.trim().isNotEmpty) ...[
            _tituloSecao('Transcricao'),
            pw.SizedBox(height: 4),
            _blocoTexto(sessao.transcricaoRelato),
            pw.SizedBox(height: 12),
          ],
          if (sessao.apontamentosCopiloto.trim().isNotEmpty) ...[
            _tituloSecao('Apontamentos'),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Text(
                sessao.apontamentosCopiloto,
                style: pw.TextStyle(
                  fontSize: 10,
                  height: 1.4,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
            pw.SizedBox(height: 12),
          ],
          _secaoClinica(sessao, config),
          pw.SizedBox(height: 12),
          _secaoRevisao(sessao),
          pw.SizedBox(height: 12),
          _secaoDisclaimerIa(),
          pw.SizedBox(height: 8),
          _secaoExportacao(),
        ],
      ),
    );
    return doc.save();
  }

  Future<Uint8List> _gerarPdfProntuarioCompleto({
    required Paciente paciente,
    required List<Sessao> sessoes,
    required PerfilProfissional perfil,
  }) async {
    final config = ConfiguracaoAbordagemClinica.porNome(
      perfil.abordagemClinica,
    );

    final sessoesAtivas =
        sessoes.where((s) => s.estaAtiva).toList()
          ..sort((a, b) => b.data.compareTo(a.data));

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _cabecalhoPagina(perfil),
        footer: (context) => _rodapePagina(context),
        build: (context) => [
          _tituloSecao('Prontuario Completo'),
          pw.SizedBox(height: 4),
          pw.Text(
            paciente.nomeExibicao,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _primaria,
            ),
          ),
          pw.SizedBox(height: 12),
          _dadosPaciente(paciente),
          pw.SizedBox(height: 8),
          _dadosProfissionalResumido(perfil, config),
          pw.SizedBox(height: 8),
          _linhaSeparadora(),
          pw.SizedBox(height: 16),
          if (sessoesAtivas.isEmpty)
            pw.Text(
              'Nenhuma sessao registrada.',
              style: pw.TextStyle(
                color: _secundaria,
                fontSize: 12,
              ),
            )
          else
            ...sessoesAtivas.map((s) => _secaoSessaoCompleta(
                  sessao: s,
                  config: config,
                  paciente: paciente,
                )),
          pw.SizedBox(height: 16),
          _secaoDisclaimerIa(),
          pw.SizedBox(height: 8),
          _secaoExportacao(),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _dadosProfissionalResumido(
    PerfilProfissional perfil,
    ConfiguracaoAbordagemClinica config,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _superficie,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _campoInfo('Profissional', perfil.nomeExibicao),
          if (perfil.possuiRegistroProfissional)
            _campoInfo('Registro', perfil.registroProfissional),
          _campoInfo('Abordagem clínica', config.nomeAbordagem),
        ],
      ),
    );
  }

  List<pw.Widget> _evolucaoClinicaSessoes(List<Sessao> sessoes) {
    final widgets = <pw.Widget>[];

    for (final s in sessoes) {
      final sintese = _concatenarSintese(s);
      if (sintese.isEmpty) {
        continue;
      }

      widgets.add(
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          margin: const pw.EdgeInsets.only(bottom: 8),
          decoration: pw.BoxDecoration(
            color: _fundo,
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Sessão — ${_formatarData(s.data)}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaria,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                sintese,
                textAlign: pw.TextAlign.justify,
                style: const pw.TextStyle(fontSize: 9, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    if (widgets.isEmpty) {
      widgets.add(
        pw.Text(
          'Nenhuma evolucao clinica registrada.',
          style: pw.TextStyle(
            color: _secundaria,
            fontSize: 10,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      );
    }

    return widgets;
  }

  pw.Widget _secaoSessaoCompleta({
    required Sessao sessao,
    required ConfiguracaoAbordagemClinica config,
    required Paciente paciente,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _linhaSeparadora(),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(
                'Sessao ${sessao.numeroSessao} — ${_formatarData(sessao.data)} às ${_formatarHorario(sessao.data)}',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaria,
                ),
              ),
            ),
            _badgeRevisao(sessao.revisadoPeloProfissional),
          ],
        ),
        pw.SizedBox(height: 8),
        _secaoClinica(sessao, config),
        pw.SizedBox(height: 8),
        _secaoRevisao(sessao),
        pw.SizedBox(height: 16),
      ],
    );
  }

  pw.Widget _badgeRevisao(bool revisado) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: revisado ? PdfColors.green50 : PdfColors.orange50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(
          color: revisado ? PdfColors.green200 : PdfColors.orange200,
          width: 0.5,
        ),
      ),
      child: pw.Text(
        revisado ? 'Revisado' : 'Pendente',
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: revisado ? PdfColors.green700 : PdfColors.orange700,
        ),
      ),
    );
  }

  pw.Widget _blocoTexto(String texto) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(left: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: _primariaClara, width: 2),
        ),
      ),
      child: pw.Text(
        texto,
        textAlign: pw.TextAlign.justify,
        style: const pw.TextStyle(fontSize: 10, height: 1.5),
      ),
    );
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();
    return '$dia/$mes/$ano';
  }

  String _formatarHorario(DateTime data) {
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');
    return '$hora:$minuto';
  }

  Future<void> _salvarOuImprimir({
    required Uint8List pdf,
    required String nomeArquivo,
  }) async {
    try {
      await Printing.sharePdf(
        bytes: pdf,
        filename: nomeArquivo,
      );
    } catch (e) {
      Log.erro(e, contexto: 'PdfExportService._salvarOuImprimir');
      rethrow;
    }
  }
}
