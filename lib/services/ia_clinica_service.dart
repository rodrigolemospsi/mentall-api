import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'logger.dart';

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
    required String temaPrincipal,
    required int humor,
  }) async {
    final transcricaoLimpa = transcricaoRelato.trim();
    final relatoManualLimpo = relatoManual.trim();
    final temaLimpo = temaPrincipal.trim();
    final nomeLimpo = nomePessoaAtendida.trim();
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

    try {
      final response = await http
          .post(
            Uri.parse('${ApiClient.baseUrl}/gerar-sintese'),
            headers: ApiClient.defaultHeaders(),
            body: jsonEncode({
              'sessao_id': sessaoId,
              'numero_sessao': numeroSessao,
              'nome_pessoa_atendida': nomeLimpo.isNotEmpty ? nomeLimpo : nomePessoaAtendida,
              'termo_pessoa_atendida': termoLimpo.isNotEmpty ? termoLimpo : termoPessoaAtendida,
              'abordagem_clinica': abordagemLimpa.isNotEmpty ? abordagemLimpa : 'Integrativa',
              'transcricao_relato': transcricaoLimpa,
              'relato_manual': relatoManualLimpo,
              'tema_principal': temaLimpo,
              'humor': humor,
            }),
          )
          .timeout(ApiClient.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final sucesso = data['sucesso'] as bool;

        if (sucesso) {
          return ResultadoIaClinica.sucesso(
            relatoClinicoOrganizado:
                data['relato_clinico_organizado'] as String? ?? '',
            apontamentosCopiloto:
                data['apontamentos_copiloto'] as String? ?? '',
            eventosImportantes:
                data['eventos_importantes'] as String? ?? '',
            evolucaoClinica:
                data['evolucao_clinica'] as String? ?? '',
            observacoes: data['observacoes'] as String? ?? '',
            pensamentosAutomaticos:
                data['pensamentos_automaticos'] as String? ?? '',
            emocoes: data['emocoes'] as String? ?? '',
            comportamentos: data['comportamentos'] as String? ?? '',
            intervencoes: data['intervencoes'] as String? ?? '',
            tecnicas: data['tecnicas'] as String? ?? '',
            tarefaCasa: data['tarefa_casa'] as String? ?? '',
            planoProximaSessao:
                data['plano_proxima_sessao'] as String? ?? '',
          );
        } else {
          return ResultadoIaClinica.falha(
            erro: data['erro'] as String? ?? 'Erro do servidor.',
          );
        }
      }

      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final erroDetalhado = data['detail'] as String? ??
            data['erro'] as String? ??
            '';

        if (erroDetalhado.isNotEmpty) {
          return ResultadoIaClinica.falha(
            erro: 'Servidor retornou código ${response.statusCode}: $erroDetalhado',
          );
        }
      } catch (erro) {
        Log.erro(erro, contexto: 'ia_clinica_service:parseErrorResponse');
      }

      return ResultadoIaClinica.falha(
        erro: 'Servidor retornou código ${response.statusCode}.',
      );
    } catch (erro) {
      return ResultadoIaClinica.falha(
        erro: 'Não foi possível gerar a síntese clínica. Detalhes: $erro',
      );
    }
  }
}
