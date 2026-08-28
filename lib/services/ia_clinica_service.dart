import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class ResultadoIaClinica {
  final bool sucesso;

  final String relatoClinicoOrganizado;
  final String apontamentosCopiloto;

  final String sinteseClinica;
  final String formulacaoClinica;

  final String intervencoes;
  final String planoProximaSessao;
  final String artigosSugeridos;
  final List<dynamic> temasPesquisa;

  final String erro;

  const ResultadoIaClinica({
    required this.sucesso,
    required this.relatoClinicoOrganizado,
    required this.apontamentosCopiloto,
    required this.sinteseClinica,
    required this.formulacaoClinica,
    required this.intervencoes,
    required this.planoProximaSessao,
    required this.artigosSugeridos,
    required this.temasPesquisa,
    required this.erro,
  });

  factory ResultadoIaClinica.sucesso({
    required String relatoClinicoOrganizado,
    required String apontamentosCopiloto,
    required String sinteseClinica,
    required String formulacaoClinica,
    required String intervencoes,
    required String planoProximaSessao,
    required String artigosSugeridos,
    List<dynamic> temasPesquisa = const [],
  }) {
    return ResultadoIaClinica(
      sucesso: true,
      relatoClinicoOrganizado: relatoClinicoOrganizado,
      apontamentosCopiloto: apontamentosCopiloto,
      sinteseClinica: sinteseClinica,
      formulacaoClinica: formulacaoClinica,
      intervencoes: intervencoes,
      planoProximaSessao: planoProximaSessao,
      artigosSugeridos: artigosSugeridos,
      temasPesquisa: temasPesquisa,
      erro: '',
    );
  }

  factory ResultadoIaClinica.falha({
    required String erro,
  }) {
    return ResultadoIaClinica(
      sucesso: false,
      relatoClinicoOrganizado: '',
      apontamentosCopiloto: '',
      sinteseClinica: '',
      formulacaoClinica: '',
      intervencoes: '',
      planoProximaSessao: '',
      artigosSugeridos: '',
      temasPesquisa: const [],
      erro: erro,
    );
  }
}

class IaClinicaService {
  Future<ResultadoIaClinica> gerarSinteseClinica({
    required String sessaoId,
    required int numeroSessao,
    required String nomePessoaAtendida,
    required String termoPessoaAtendida,
    required String abordagemClinica,
    required String transcricaoRelato,
    required String relatoManual,
  }) async {
    final transcricaoLimpa = transcricaoRelato.trim();
    final relatoManualLimpo = relatoManual.trim();
    final termoLimpo = termoPessoaAtendida.trim();
    final abordagemLimpa = abordagemClinica.trim();

    final existeMaterialClinico =
        transcricaoLimpa.isNotEmpty || relatoManualLimpo.isNotEmpty;

    if (!existeMaterialClinico) {
      return ResultadoIaClinica.falha(
        erro:
            'Não há relato ou transcrição suficiente para gerar uma síntese clínica.',
      );
    }

    final nomePseudonimizado = _pseudonimizarNome(nomePessoaAtendida.trim());

    try {
      final resultado = await _fazerRequisicaoComRetry(
        endpoint: '/gerar-sintese',
        body: {
          'sessao_id': sessaoId,
          'numero_sessao': numeroSessao,
          'nome_pessoa_atendida': nomePseudonimizado,
          'termo_pessoa_atendida': termoLimpo.isNotEmpty ? termoLimpo : termoPessoaAtendida,
          'abordagem_clinica': abordagemLimpa.isNotEmpty ? abordagemLimpa : 'Integrativa',
          'transcricao_relato': transcricaoLimpa,
          'relato_manual': relatoManualLimpo,
        },
      );

      if (resultado['status'] == 200) {
        final data = resultado['data'] as Map<String, dynamic>?;
        if (data == null) {
          return ResultadoIaClinica.falha(erro: 'Resposta inválida do servidor.');
        }
        final sucesso = data['sucesso'] as bool? ?? false;
        if (sucesso) {
          return ResultadoIaClinica.sucesso(
            relatoClinicoOrganizado: data['relato_clinico_organizado'] as String? ?? '',
            apontamentosCopiloto: data['apontamentos_copiloto'] as String? ?? '',
            sinteseClinica: data['sintese_clinica'] as String? ?? '',
            formulacaoClinica: data['formulacao_clinica'] as String? ?? '',
            intervencoes: data['intervencoes'] as String? ?? '',
            planoProximaSessao: data['plano_proxima_sessao'] as String? ?? '',
            artigosSugeridos: data['artigos_sugeridos'] as String? ?? '',
            temasPesquisa: data['temas_pesquisa'] as List<dynamic>? ?? const [],
          );
        }
        return ResultadoIaClinica.falha(erro: data['erro'] as String? ?? 'Erro do servidor.');
      }

      final status = resultado['status'] as int? ?? 0;
      if (status == 0 || status >= 500) {
        return ResultadoIaClinica.falha(
          erro:
              'Serviço de IA temporariamente indisponível. Tente novamente em instantes.',
        );
      }
      return ResultadoIaClinica.falha(
        erro: 'Servidor retornou código $status.',
      );
    } catch (_) {
      return ResultadoIaClinica.falha(
        erro:
            'Serviço de IA temporariamente indisponível. Verifique sua conexão e tente novamente.',
      );
    }
  }

  Future<String?> gerarArtigos({
    required List<dynamic> temasPesquisa,
    required String contextoClinico,
  }) async {
    try {
      final resultado = await _fazerRequisicaoComRetry(
        endpoint: '/gerar-artigos',
        body: {
          'temas_pesquisa': temasPesquisa,
          'contexto_clinico': contextoClinico,
        },
      );

      if (resultado['status'] == 200) {
        final data = resultado['data'] as Map<String, dynamic>?;
        if (data != null && data['sucesso'] == true) {
          return data['artigos_sugeridos'] as String? ?? '';
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String _pseudonimizarNome(String nome) {
    if (nome.isEmpty) return 'Pessoa atendida';
    final partes = nome.split(' ');
    if (partes.length == 1) {
      return '${partes.first[0]}.';
    }
    final primeiroNome = partes.first;
    final iniciais = partes
        .skip(1)
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0]}.')
        .join(' ');
    return '$primeiroNome $iniciais';
  }

  Future<Map<String, dynamic>> _fazerRequisicaoComRetry({
    required String endpoint,
    required Map<String, dynamic> body,
    int tentativa = 0,
  }) async {
    final autenticado = tentativa == 0
        ? await ApiClient.ensureAuthenticated()
        : await ApiClient.forceReauthenticate();
    if (!autenticado) {
      return {'status': 0, 'data': null};
    }

    try {
      final response = await http
          .post(
            Uri.parse('${ApiClient.baseUrl}$endpoint'),
            headers: ApiClient.defaultHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 150));

      if (response.statusCode == 401 && tentativa < 2) {
        return await _fazerRequisicaoComRetry(
            endpoint: endpoint, body: body, tentativa: tentativa + 1);
      }

      if (response.statusCode == 429 && tentativa < 2) {
        await Future.delayed(Duration(seconds: 2 * (tentativa + 1)));
        return await _fazerRequisicaoComRetry(
            endpoint: endpoint, body: body, tentativa: tentativa + 1);
      }

      if (response.statusCode >= 500 && tentativa < 1) {
        await Future.delayed(Duration(seconds: 2 * (tentativa + 1)));
        return await _fazerRequisicaoComRetry(
            endpoint: endpoint, body: body, tentativa: tentativa + 1);
      }

      Map<String, dynamic>? data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      return {'status': response.statusCode, 'data': data};
    } catch (e) {
      if (tentativa < 2) {
        await Future.delayed(Duration(seconds: 2 * (tentativa + 1)));
        return await _fazerRequisicaoComRetry(
            endpoint: endpoint, body: body, tentativa: tentativa + 1);
      }
      return {'status': 0, 'data': null};
    }
  }
}

class ResultadoProgresso {
  final bool sucesso;
  final List<Map<String, dynamic>> sintomas;
  final List<Map<String, dynamic>> metas;
  final String avaliacaoGeral;
  final String tendencia;
  final String recomendacoes;
  final String erro;

  const ResultadoProgresso({
    required this.sucesso,
    required this.sintomas,
    required this.metas,
    required this.avaliacaoGeral,
    required this.tendencia,
    required this.recomendacoes,
    required this.erro,
  });

  factory ResultadoProgresso.sucesso({
    required List<dynamic> sintomas,
    required List<dynamic> metas,
    required String avaliacaoGeral,
    required String tendencia,
    String recomendacoes = '',
  }) {
    return ResultadoProgresso(
      sucesso: true,
      sintomas: sintomas.cast<Map<String, dynamic>>(),
      metas: metas.cast<Map<String, dynamic>>(),
      avaliacaoGeral: avaliacaoGeral,
      tendencia: tendencia,
      recomendacoes: recomendacoes,
      erro: '',
    );
  }

  factory ResultadoProgresso.falha({required String erro}) {
    return ResultadoProgresso(
      sucesso: false,
      sintomas: [],
      metas: [],
      avaliacaoGeral: '',
      tendencia: 'estavel',
      recomendacoes: '',
      erro: erro,
    );
  }
}

extension IaClinicaProgressoService on IaClinicaService {
  Future<ResultadoProgresso> gerarProgresso({
    required String pacienteId,
    required int numeroSessao,
    required List<Map<String, dynamic>> sessoesAnteriores,
    required Map<String, dynamic> sessaoAtual,
    String objetivosTerapeuticos = '',
    String queixaPrincipal = '',
    List<Map<String, dynamic>> escalas = const [],
  }) async {
    final endpoint = '${ApiClient.baseUrl}/gerar-progresso';

    final body = {
      'paciente_id': pacienteId,
      'numero_sessao': numeroSessao,
      'sessoes_anteriores': sessoesAnteriores,
      'sessao_atual': sessaoAtual,
      'objetivos_terapeuticos': objetivosTerapeuticos,
      'queixa_principal': queixaPrincipal,
      'escalas': escalas,
    };

    final response = await _fazerRequisicaoComRetry(
        endpoint: endpoint, body: body, tentativa: 0);

    if (response['status'] == 200) {
      final data = response['data'] as Map<String, dynamic>;
      if (data['sucesso'] == true) {
        return ResultadoProgresso.sucesso(
          sintomas: data['sintomas'] as List<dynamic>? ?? [],
          metas: data['metas'] as List<dynamic>? ?? [],
          avaliacaoGeral: data['avaliacao_geral'] as String? ?? '',
          tendencia: data['tendencia'] as String? ?? 'estavel',
          recomendacoes: data['recomendacoes'] as String? ?? '',
        );
      }
      return ResultadoProgresso.falha(
          erro: data['erro'] as String? ?? 'Erro desconhecido');
    }

    return ResultadoProgresso.falha(
        erro: 'Erro HTTP ${response['status']}');
  }
}
