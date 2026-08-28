import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../config/configuracao_abordagem_clinica.dart';
import '../models/anamnese_enviada.dart';
import '../models/paciente.dart';
import '../models/perfil_profissional.dart';
import '../models/sessao.dart';
import 'anamnese_labels.dart';
import 'logger.dart';
import '../utils/tipografia.dart';

class PdfExportService {
  static const PdfColor _primaria = PdfColor.fromInt(0xFF8806CE);
  static const PdfColor _primariaClara = PdfColor.fromInt(0xFFA10AF5);
  static const PdfColor _titulo = PdfColor.fromInt(0xFF3C096C);
  static const PdfColor _marca = PdfColor.fromInt(0xFFC77DFF);
  static const PdfColor _secundaria = PdfColor.fromInt(0xFF64748B);
  static const PdfColor _fundo = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor _superficie = PdfColor.fromInt(0xFFF1F5F9);
  static const PdfColor _linha = PdfColor.fromInt(0xFFE2E8F0);

  static Uint8List? _logoBytes;
  static pw.MemoryImage? _logoImage;

  static Future<void> _carregarLogo() async {
    if (_logoBytes != null) return;
    try {
      _logoBytes = (await rootBundle.load('assets/images/logo_mentallpro_fundoclaro_01.png'))
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

  /// Exporta o questionário de anamnese respondido pelo paciente, com todas
  /// as seções/perguntas do template e as respostas preenchidas.
  Future<void> exportarAnamnese({
    required Paciente paciente,
    required AnamneseEnviada anamnese,
    required PerfilProfissional perfil,
    required String templateJson,
  }) async {
    try {
      final pdf = await _gerarPdfAnamnese(
        paciente: paciente,
        anamnese: anamnese,
        perfil: perfil,
        templateJson: templateJson,
      );
      await _salvarOuImprimir(
        pdf: pdf,
        nomeArquivo: 'anamnese_${paciente.nome}.pdf',
      );
    } catch (e) {
      Log.erro(e, contexto: 'PdfExportService.exportarAnamnese');
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
                fontSize: Tipografia.base,
                fontWeight: pw.FontWeight.bold,
                color: _titulo,
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
                fontSize: Tipografia.sm,
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
        perfil.nomeExibicao,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: _secundaria,
        ),
      ),
    ];
    if (perfil.possuiRegistroProfissional) {
      final registroLimpo = perfil.registroProfissional
          .replaceFirst(RegExp(r'^CRP\s*', caseSensitive: false), '');
      final textoCrp = perfil.crpVerificado
          ? 'CRP $registroLimpo \u2713 Verificado'
          : 'CRP $registroLimpo';
      infoProfissional.add(
        pw.Text(
          textoCrp,
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
            pw.Image(_logoImage!, height: 35)
          else
            pw.Text(
              'MentAll PRO',
              style: pw.TextStyle(
                fontSize: Tipografia.smMd,
                fontWeight: pw.FontWeight.bold,
                color: _marca,
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
        _tituloDocumento('Registro de Sessão'),
        pw.SizedBox(height: 2),
        pw.Text(
          paciente.nomeExibicao,
          style: pw.TextStyle(
            fontSize: Tipografia.md,
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
                _quebrarTextosLongos(texto),
                textAlign: pw.TextAlign.left,
                style: const pw.TextStyle(
                  fontSize: Tipografia.xxs,
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
                  fontSize: Tipografia.xxs,
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
              'Sim - a IA foi utilizada como apoio à documentação clínica. '
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
        'Documento exportado do MentAll PRO em '
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
        'julgamento do profissional de saúde. Todo o conteúdo aqui presente foi '
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
              mainAxisAlignment: pw.MainAxisAlignment.start,
              children: [
                pw.Text(
                  '${_formatarData(sessao.data)} às '
                  '${_formatarHorario(sessao.data)}',
                  style: pw.TextStyle(
                    fontSize: Tipografia.xs,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaria,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            if (sessao.relatoPosSessao.trim().isNotEmpty)
              pw.Text(
                _quebrarTextosLongos(sessao.relatoPosSessao),
                textAlign: pw.TextAlign.left,
                style: const pw.TextStyle(
                  fontSize: Tipografia.xxs,
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

  pw.Widget _tituloDocumento(String texto) {
    return pw.Text(
      texto.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: _titulo,
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
          _tituloDocumento('Relatório Clínico'),
          pw.SizedBox(height: 12),
          _dadosPaciente(paciente),
          pw.SizedBox(height: 8),
          _dadosProfissionalResumido(perfil, config),
          pw.SizedBox(height: 8),
          _linhaSeparadora(),
          pw.SizedBox(height: 16),
          _tituloSecao('Evolução Clínica'),
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
                    _tituloDocumento('Síntese Revisada'),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Sessão ${sessao.numeroSessao} - ${paciente.nomeExibicao}',
                      style: pw.TextStyle(
                        fontSize: Tipografia.md,
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
            _tituloSecao('Relato Clínico Organizado'),
            pw.SizedBox(height: 4),
            _blocoTexto(sessao.relatoPosSessao),
            pw.SizedBox(height: 12),
          ],
          if (sessao.transcricaoRevisada.trim().isNotEmpty) ...[
            _tituloSecao('Transcrição Revisada'),
            pw.SizedBox(height: 4),
            _blocoTexto(sessao.transcricaoRevisada),
            pw.SizedBox(height: 12),
          ] else if (sessao.transcricaoRelato.trim().isNotEmpty) ...[
            _tituloSecao('Transcrição'),
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
                  fontSize: Tipografia.xxs,
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
          _tituloDocumento('Prontuário Completo'),
          pw.SizedBox(height: 4),
          pw.Text(
            paciente.nomeExibicao,
            style: pw.TextStyle(
              fontSize: Tipografia.md,
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
              'Nenhuma sessão registrada.',
              style: pw.TextStyle(
                color: _secundaria,
                fontSize: Tipografia.sm,
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

  Future<Uint8List> _gerarPdfAnamnese({
    required Paciente paciente,
    required AnamneseEnviada anamnese,
    required PerfilProfissional perfil,
    required String templateJson,
  }) async {
    final doc = pw.Document();
    final respostas = anamnese.respostas;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _cabecalhoPagina(perfil),
        footer: (context) => _rodapePagina(context),
        build: (context) => [
          _tituloDocumento('Anamnese'),
          pw.SizedBox(height: 4),
          pw.Text(
            paciente.nomeExibicao,
            style: pw.TextStyle(
              fontSize: Tipografia.md,
              fontWeight: pw.FontWeight.bold,
              color: _primaria,
            ),
          ),
          pw.SizedBox(height: 8),
          _dadosPaciente(paciente),
          pw.SizedBox(height: 8),
          _dadosProfissionalResumido(
            perfil,
            ConfiguracaoAbordagemClinica.porNome(perfil.abordagemClinica),
          ),
          pw.SizedBox(height: 4),
          if (anamnese.dataResposta != null) ...[
            pw.Text(
              'Respondido em ${_formatarData(anamnese.dataResposta!)} às '
                  '${_formatarHorario(anamnese.dataResposta!)}',
              style: pw.TextStyle(
                fontSize: Tipografia.xs,
                color: _secundaria,
              ),
            ),
          ],
          pw.SizedBox(height: 8),
          _linhaSeparadora(),
          pw.SizedBox(height: 16),
          ..._secoesAnamnesePdf(templateJson, respostas),
          pw.SizedBox(height: 16),
          _secaoExportacao(),
        ],
      ),
    );
    return doc.save();
  }

  /// Converte o template JSON da anamnese em widgets de seções, cruzando cada
  /// pergunta com a resposta do paciente.
  List<pw.Widget> _secoesAnamnesePdf(
    String templateJson,
    Map<String, dynamic> respostas,
  ) {
    List<Map<String, dynamic>> secoes;
    try {
      final decoded = jsonDecode(templateJson) as Map<String, dynamic>;
      secoes = (decoded['secoes'] as List<dynamic>? ?? [])
          .map((s) => s as Map<String, dynamic>)
          .toList();
    } catch (_) {
      secoes = [];
    }

    if (secoes.isEmpty) {
      return [
        pw.Text(
          'Nenhuma resposta disponível.',
          style: pw.TextStyle(color: _secundaria, fontSize: Tipografia.sm),
        ),
      ];
    }

    final widgets = <pw.Widget>[];
    for (final secao in secoes) {
      final titulo = (secao['titulo'] as String? ?? '')
          .toString()
          .toUpperCase();
      final perguntas = (secao['perguntas'] as List<dynamic>? ?? [])
          .map((p) => p as Map<String, dynamic>)
          .toList();

      final ehSeguranca = titulo.toLowerCase().contains('seguran');

      widgets.add(_tituloSecao(titulo));
      widgets.add(pw.SizedBox(height: 6));

      for (final pergunta in perguntas) {
        final id = (pergunta['id'] as String? ?? '').toString();
        final label = (pergunta['label'] as String? ?? anamneseLabels[id] ?? id)
            .toString();
        final valor = respostas[id];

        // Campo condicional (ex.: "Quais?" quando a resposta anterior é Sim).
        final condicional = pergunta['condicional_sim'];
        final condId = condicional is Map
            ? (condicional['id'] as String? ?? '').toString()
            : '';
        final condLabel = condicional is Map
            ? (condicional['label'] as String? ?? anamneseLabels[condId] ?? condId)
                .toString()
            : '';

        if (ehSeguranca) {
          final isRisco = id != 'esta_seguro' && valor == true;
          widgets.add(_campoRespostaSeguranca(
            label: label,
            valor: formatarValorResposta(valor),
            isRisco: isRisco,
          ));
        } else {
          widgets.add(_campoPerguntaResposta(
            label: label,
            valor: formatarValorResposta(valor),
          ));
        }

        // Se a resposta do campo condicional existir, exibe como sub-resposta.
        if (condId.isNotEmpty && condLabel.isNotEmpty && respostas.containsKey(condId)) {
          widgets.add(_campoPerguntaResposta(
            label: condLabel,
            valor: formatarValorResposta(respostas[condId]),
            indentado: true,
          ));
        }
      }
      widgets.add(pw.SizedBox(height: 12));
    }
    return widgets;
  }

  pw.Widget _campoPerguntaResposta({
    required String label,
    required String valor,
    bool indentado = false,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 8, left: indentado ? 16 : 0),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: Tipografia.xs,
              fontWeight: pw.FontWeight.bold,
              color: _secundaria,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            _quebrarTextosLongos(valor),
            textAlign: pw.TextAlign.left,
            style: const pw.TextStyle(fontSize: Tipografia.xxs, height: 1.4),
          ),
        ],
      ),
    );
  }

  pw.Widget _campoRespostaSeguranca({
    required String label,
    required String valor,
    required bool isRisco,
  }) {
    final cor = isRisco ? PdfColors.orange : _secundaria;
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: isRisco
            ? PdfColor.fromInt(0xFFFFF3E0)
            : PdfColor.fromInt(0xFFF1F5F9),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  label,
                  style: pw.TextStyle(
                    fontSize: Tipografia.xs,
                    fontWeight: pw.FontWeight.bold,
                    color: cor,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  valor,
                  style: pw.TextStyle(
                    fontSize: Tipografia.xxs,
                    fontWeight: isRisco ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: isRisco ? PdfColors.orange : _secundaria,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
                'Sessão dia ${_formatarData(s.data)}',
                style: pw.TextStyle(
                  fontSize: Tipografia.xxs,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaria,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                _quebrarTextosLongos(sintese),
                textAlign: pw.TextAlign.left,
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
          'Nenhuma evolução clínica registrada.',
          style: pw.TextStyle(
            color: _secundaria,
            fontSize: Tipografia.xxs,
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
                'Sessão ${sessao.numeroSessao} - ${_formatarData(sessao.data)} às ${_formatarHorario(sessao.data)}',
                style: pw.TextStyle(
                  fontSize: Tipografia.sm,
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

  Future<void> exportarRelatorioFinanceiro({
    required DateTime mes,
    required List<Sessao> sessoes,
    required double recebido,
    required double pendente,
    required double convenio,
    required double pacote,
    required double total,
    required PerfilProfissional perfil,
    required Map<String, String> nomesPacientes,
    bool temaEscuro = false,
  }) async {
    final doc = pw.Document();
    await _carregarLogo();

    final meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            child: pw.Row(
              children: [
                if (_logoImage != null)
                  pw.Image(_logoImage!, width: 32, height: 32),
                pw.SizedBox(width: 8),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(perfil.nomeExibicao, style: pw.TextStyle(fontSize: Tipografia.base, fontWeight: pw.FontWeight.bold)),
                    pw.Text(perfil.registroProfissional, style: pw.TextStyle(fontSize: 9, color: _secundaria)),
                  ],
                ),
                pw.Spacer(),
                pw.Text('Relatório Financeiro', style: pw.TextStyle(fontSize: Tipografia.sm, color: _titulo)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Center(
            child: pw.Text(
              '${meses[mes.month - 1]} de ${mes.year}',
              style: pw.TextStyle(fontSize: Tipografia.md, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _cardFinanceiroPdf('Recebido', 'R\$ ${recebido.toStringAsFixed(2)}', PdfColors.green),
              _cardFinanceiroPdf('A receber', 'R\$ ${pendente.toStringAsFixed(2)}', PdfColors.orange),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _cardFinanceiroPdf('Convênio', 'R\$ ${convenio.toStringAsFixed(2)}', PdfColors.blue),
              _cardFinanceiroPdf('Pacote', 'R\$ ${pacote.toStringAsFixed(2)}', PdfColors.teal),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _cardFinanceiroPdf('Total', 'R\$ ${total.toStringAsFixed(2)}', PdfColors.black),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('Sessões', style: pw.TextStyle(fontSize: Tipografia.sm, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          ...sessoes.map((s) {
            final nome = nomesPacientes[s.pacienteId] ?? 'Paciente';
            final statusTexto = s.statusPagamento == 'pago' ? 'Pago'
                : s.statusPagamento == 'convenio' ? 'Convênio'
                : s.statusPagamento == 'pacote' ? 'Pacote'
                : 'Pendente';
            final statusColor = s.statusPagamento == 'pago' ? PdfColors.green
                : s.statusPagamento == 'convenio' ? PdfColors.blue
                : s.statusPagamento == 'pacote' ? PdfColors.teal
                : PdfColors.orange;
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                children: [
                  pw.Expanded(child: pw.Text('$nome - Sessão ${s.numeroSessao}', style: const pw.TextStyle(fontSize: 9))),
                  pw.Text('${s.data.day.toString().padLeft(2, '0')}/${s.data.month.toString().padLeft(2, '0')}', style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(width: 8),
                  pw.Text('R\$ ${s.valorSessao.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(width: 8),
                  pw.Text(statusTexto, style: pw.TextStyle(fontSize: 8, color: statusColor)),
                ],
              ),
            );
          }),
        ],
      ),
    );

    final pdf = await doc.save();
    final nome = 'financeiro_${mes.year}_${mes.month.toString().padLeft(2, '0')}.pdf';
    await _salvarOuImprimir(pdf: pdf, nomeArquivo: nome);
  }

  pw.Widget _cardFinanceiroPdf(String titulo, String valor, PdfColor cor) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 4),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _fundo,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border.all(color: _linha, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(titulo, style: pw.TextStyle(fontSize: 8, color: _secundaria)),
            pw.SizedBox(height: 4),
            pw.Text(valor, style: pw.TextStyle(fontSize: Tipografia.base, fontWeight: pw.FontWeight.bold, color: cor)),
          ],
        ),
      ),
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
        _quebrarTextosLongos(texto),
        textAlign: pw.TextAlign.left,
        style: const pw.TextStyle(fontSize: Tipografia.xxs, height: 1.5),
      ),
    );
  }

  /// Quebra tokens longos sem espaço (ex.: URLs de artigos sugeridos) para o
  /// layout do pacote `pdf` não cair em um algoritmo de quebra O(n²), que
  /// congela a UI na geração do PDF (principalmente em "Prontuário completo").
  /// Quebra tokens longos sem espaço (ex.: URLs de artigos sugeridos) para o
  /// layout do pacote `pdf` não cair em um algoritmo de quebra O(n²), que
  /// congela a UI na geração do PDF (principalmente em "Prontuário completo").
  static String quebrarTextosLongos(String texto, {int limite = 60}) {
    return _quebrarTextosLongos(texto, limite: limite);
  }

  /// Apenas para testes: gera os bytes do "Prontuário completo" sem abrir o
  /// share sheet, permitindo validar o desempenho da geração.
  static Future<Uint8List?> gerarPdfProntuarioCompletoParaTeste({
    required Paciente paciente,
    required List<Sessao> sessoes,
    required PerfilProfissional perfil,
  }) async {
    return PdfExportService()._gerarPdfProntuarioCompleto(
      paciente: paciente,
      sessoes: sessoes,
      perfil: perfil,
    );
  }

  /// Apenas para testes: gera os bytes da "Anamnese" sem abrir o share sheet.
  static Future<Uint8List?> gerarPdfAnamneseParaTeste({
    required Paciente paciente,
    required AnamneseEnviada anamnese,
    required PerfilProfissional perfil,
    required String templateJson,
  }) async {
    return PdfExportService()._gerarPdfAnamnese(
      paciente: paciente,
      anamnese: anamnese,
      perfil: perfil,
      templateJson: templateJson,
    );
  }

  static String _quebrarTextosLongos(String texto, {int limite = 60}) {
    if (texto.length <= limite * 2) return texto;
    final partes = texto.split(RegExp(r'\s+'));
    if (partes.length == 1) {
      return _quebrarToken(partes.first, limite);
    }
    return partes.map((p) => p.length > limite ? _quebrarToken(p, limite) : p).join(' ');
  }

  static String _quebrarToken(String token, int limite) {
    if (token.length <= limite) return token;
    final sb = StringBuffer();
    var i = 0;
    while (i < token.length) {
      if (i > 0) sb.write('\n');
      sb.write(token.substring(i, i + limite > token.length ? token.length : i + limite));
      i += limite;
    }
    return sb.toString();
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
