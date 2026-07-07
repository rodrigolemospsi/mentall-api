import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../config/configuracao_abordagem_clinica.dart';
import '../models/paciente.dart';
import '../models/perfil_profissional.dart';
import '../models/sessao.dart';
import 'logger.dart';

class PdfExportService {
  static const PdfColor _corPrimaria = PdfColor.fromInt(0xFF1F6F78);
  static const PdfColor _corSecundaria = PdfColor.fromInt(0xFF455A64);
  static const PdfColor _corFundo = PdfColor.fromInt(0xFFF5F5F5);

  PdfExportService();

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
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _cabecalhoPagina(perfil),
        footer: (context) => _rodapePagina(context),
        build: (context) => [
          _tituloSecao('Histórico Clínico'),
          pw.SizedBox(height: 4),
          pw.Text(
            paciente.nomeExibicao,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: _corPrimaria,
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
                color: _corSecundaria,
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
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _corPrimaria, width: 1.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'MentAll',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _corPrimaria,
            ),
          ),
          pw.Text(
            perfil.nomeExibicao,
            style: pw.TextStyle(
              fontSize: 10,
              color: _corSecundaria,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _rodapePagina(pw.Context context) {
    final pageCount = context.pageNumber;
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _corFundo, width: 1),
        ),
      ),
      child: pw.Text(
        'Página $pageCount',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
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
      margin: const pw.EdgeInsets.all(24),
      header: (context) => _cabecalhoPagina(perfil),
      footer: (context) => _rodapePagina(context),
      build: (context) => [
        _tituloSecao('Registro de Sessão'),
        pw.SizedBox(height: 4),
        pw.Text(
          'Sessão ${sessao.numeroSessao} — ${paciente.nomeExibicao}',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: _corPrimaria,
          ),
        ),
        pw.SizedBox(height: 16),
        _cabecalhoSessao(sessao),
        pw.SizedBox(height: 8),
        _linhaSeparadora(),
        pw.SizedBox(height: 12),
        _secaoClinica(sessao, config),
        pw.SizedBox(height: 16),
        _secaoRevisao(sessao),
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
        color: _corFundo,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _campoInfo('Data', '$data às $hora'),
                _campoInfo('Humor', '${sessao.humor}/10'),
                if (sessao.temaPrincipal.trim().isNotEmpty)
                  _campoInfo('Tema', sessao.temaPrincipal),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: pw.BoxDecoration(
              color: sessao.revisadoPeloProfissional
                  ? PdfColors.green50
                  : PdfColors.orange50,
              borderRadius: const pw.BorderRadius.all(
                pw.Radius.circular(4),
              ),
            ),
            child: pw.Text(
              sessao.revisadoPeloProfissional ? 'Revisado' : 'Pendente',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: sessao.revisadoPeloProfissional
                    ? PdfColors.green700
                    : PdfColors.orange700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _campoInfo(String rotulo, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        children: [
          pw.Text(
            '$rotulo: ',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: _corSecundaria,
            ),
          ),
          pw.Text(
            valor,
            style: const pw.TextStyle(fontSize: 10),
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
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _corPrimaria,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: _corFundo,
                borderRadius: const pw.BorderRadius.all(
                  pw.Radius.circular(4),
                ),
              ),
              child: pw.Text(
                texto,
                style: const pw.TextStyle(
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ));
    }

    addCampo('Relato pós-sessão', sessao.relatoPosSessao);
    addCampo('Transcrição', sessao.transcricaoRelato);
    addCampo(config.eventosLabel, sessao.eventosImportantes);
    addCampo(config.evolucaoLabel, sessao.evolucaoClinica);
    addCampo('Observações', sessao.observacoes);
    addCampo(config.campo1Label, sessao.pensamentosAutomaticos);
    addCampo(config.campo2Label, sessao.emocoes);
    addCampo(config.campo3Label, sessao.comportamentos);
    addCampo(config.intervencoesLabel, sessao.intervencoes);
    addCampo(config.tecnicasLabel, sessao.tecnicasTcc);
    addCampo(config.tarefaLabel, sessao.tarefaCasa);
    addCampo(config.planoLabel, sessao.planoProximaSessao);
    addCampo('Apontamentos do Copiloto', sessao.apontamentosCopiloto);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: campos.isEmpty
          ? [
              pw.Text(
                'Nenhum conteúdo clínico registrado nesta sessão.',
                style: pw.TextStyle(
                  color: _corSecundaria,
                  fontSize: 11,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ]
          : campos,
    );
  }

  pw.Widget _secaoRevisao(Sessao sessao) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _corFundo,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Controle de revisão',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _corPrimaria,
            ),
          ),
          pw.SizedBox(height: 6),
          _campoInfo(
            'Revisado pelo profissional',
            sessao.revisadoPeloProfissional ? 'Sim' : 'Não',
          ),
          _campoInfo(
            'Status de processamento',
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
              'Data do processamento por IA',
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
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        'Documento exportado do MentAll em '
        '${_formatarData(agora)} às ${_formatarHorario(agora)}. '
        'Documento clínico para uso profissional.',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _secaoDisclaimerIa() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _corFundo,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        'Este documento pode conter conteúdo auxiliado por inteligência artificial. '
        'A IA é uma ferramenta de apoio à documentação clínica e não substitui o '
        'julgamento profissional do psicólogo. Todo o conteúdo aqui presente foi '
        'revisado e validado pelo profissional responsável.',
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
        textAlign: pw.TextAlign.justify,
      ),
    );
  }

  pw.Widget _dadosPaciente(Paciente paciente) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _corFundo,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _campoInfo('Nome', paciente.nomeExibicao),
          _campoInfo(
            'Data de cadastro',
            _formatarData(paciente.dataCadastro),
          ),
          if (paciente.possuiDataNascimento)
            _campoInfo(
              'Idade',
              paciente.idadeExibicao,
            ),
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
          color: PdfColors.grey50,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
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
                    color: _corPrimaria,
                  ),
                ),
                pw.Text(
                  '${_formatarData(sessao.data)} às '
                  '${_formatarHorario(sessao.data)}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: _corSecundaria,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            _campoInfo('Tema', sessao.temaPrincipal),
            _campoInfo('Humor', '${sessao.humor}/10'),
            if (sessao.relatoPosSessao.trim().isNotEmpty)
              _campoInfo('Relato', sessao.relatoPosSessao),
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
      texto,
      style: pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: _corPrimaria,
      ),
    );
  }

  pw.Widget _linhaSeparadora() {
    return pw.Container(
      height: 1,
      color: _corFundo,
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
