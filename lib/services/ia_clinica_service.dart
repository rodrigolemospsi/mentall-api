import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class ResultadoIaClinica {
  final bool sucesso;

  final String relatoClinicoOrganizado;
  final String apontamentosCopiloto;

  final String eventosImportantes;
  final String evolucaoClinica;
  final String observacoes;

  final String pensamentosAutomaticos;
  final String emocoes;
  final String comportamentos;

  final String intervencoes;
  final String tecnicas;
  final String tarefaCasa;
  final String planoProximaSessao;
  final String artigosSugeridos;

  final String erro;

  const ResultadoIaClinica({
    required this.sucesso,
    required this.relatoClinicoOrganizado,
    required this.apontamentosCopiloto,
    required this.eventosImportantes,
    required this.evolucaoClinica,
    required this.observacoes,
    required this.pensamentosAutomaticos,
    required this.emocoes,
    required this.comportamentos,
    required this.intervencoes,
    required this.tecnicas,
    required this.tarefaCasa,
    required this.planoProximaSessao,
    required this.artigosSugeridos,
    required this.erro,
  });

  factory ResultadoIaClinica.sucesso({
    required String relatoClinicoOrganizado,
    required String apontamentosCopiloto,
    required String eventosImportantes,
    required String evolucaoClinica,
    required String observacoes,
    required String pensamentosAutomaticos,
    required String emocoes,
    required String comportamentos,
    required String intervencoes,
    required String tecnicas,
    required String tarefaCasa,
    required String planoProximaSessao,
    required String artigosSugeridos,
  }) {
    return ResultadoIaClinica(
      sucesso: true,
      relatoClinicoOrganizado: relatoClinicoOrganizado,
      apontamentosCopiloto: apontamentosCopiloto,
      eventosImportantes: eventosImportantes,
      evolucaoClinica: evolucaoClinica,
      observacoes: observacoes,
      pensamentosAutomaticos: pensamentosAutomaticos,
      emocoes: emocoes,
      comportamentos: comportamentos,
      intervencoes: intervencoes,
      tecnicas: tecnicas,
      tarefaCasa: tarefaCasa,
      planoProximaSessao: planoProximaSessao,
      artigosSugeridos: artigosSugeridos,
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
      eventosImportantes: '',
      evolucaoClinica: '',
      observacoes: '',
      pensamentosAutomaticos: '',
      emocoes: '',
      comportamentos: '',
      intervencoes: '',
      tecnicas: '',
      tarefaCasa: '',
      planoProximaSessao: '',
      artigosSugeridos: '',
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
    String temaPrincipal = '',
  }) async {
    final transcricaoLimpa = transcricaoRelato.trim();
    final relatoManualLimpo = relatoManual.trim();
    final temaLimpo = temaPrincipal.trim();
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
          'tema_principal': temaLimpo,
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
            eventosImportantes: data['eventos_importantes'] as String? ?? '',
            evolucaoClinica: data['evolucao_clinica'] as String? ?? '',
            observacoes: data['observacoes'] as String? ?? '',
            pensamentosAutomaticos: data['pensamentos_automaticos'] as String? ?? '',
            emocoes: data['emocoes'] as String? ?? '',
            comportamentos: data['comportamentos'] as String? ?? '',
            intervencoes: data['intervencoes'] as String? ?? '',
            tecnicas: data['tecnicas'] as String? ?? '',
            tarefaCasa: data['tarefa_casa'] as String? ?? '',
            planoProximaSessao: data['plano_proxima_sessao'] as String? ?? '',
            artigosSugeridos: data['artigos_sugeridos'] as String? ?? '',
          );
        }
        return ResultadoIaClinica.falha(erro: data['erro'] as String? ?? 'Erro do servidor.');
      }

      return ResultadoIaClinica.falha(
        erro: 'Servidor retornou código ${resultado['status']}.',
      );
    } catch (erro) {
      return ResultadoIaClinica.falha(
        erro: 'Não foi possível gerar a síntese clínica. Detalhes: $erro',
      );
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
          .timeout(ApiClient.timeout);

      if (response.statusCode == 401 && tentativa < 2) {
        return _fazerRequisicaoComRetry(
            endpoint: endpoint, body: body, tentativa: tentativa + 1);
      }

      if (response.statusCode >= 500 && tentativa < 2) {
        await Future.delayed(Duration(seconds: 2 * (tentativa + 1)));
        return _fazerRequisicaoComRetry(
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
        return _fazerRequisicaoComRetry(
            endpoint: endpoint, body: body, tentativa: tentativa + 1);
      }
      return {'status': 0, 'data': null};
    }
  }
}
