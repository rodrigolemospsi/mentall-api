import 'dart:convert';

import 'package:hive_ce/hive.dart';

import '../models/paciente.dart';
import '../models/perfil_profissional.dart';
import '../models/sessao.dart';

class BackupService {
  String exportarParaJson() {
    final pacientes = Hive.box<Paciente>('pacientes');
    final sessoes = Hive.box<Sessao>('sessoes');
    final perfil = Hive.box<PerfilProfissional>('perfil_profissional');

    final dados = {
      'versao': '1.0',
      'exportado_em': DateTime.now().toIso8601String(),
      'perfil_profissional': perfil.values.map((p) {
        return {
          'id': p.id,
          'nome': p.nome,
          'registro_profissional': p.registroProfissional,
          'abordagem_clinica': p.abordagemClinica,
          'termo_pessoa_atendida': p.termoPessoaAtendida,
          'data_criacao': p.dataCriacao.toIso8601String(),
          if (p.dataAtualizacao != null)
            'data_atualizacao': p.dataAtualizacao!.toIso8601String(),
          'modalidades_atendimento_json': p.modalidadesAtendimentoJson,
          'enderecos_consultorios_json': p.enderecosConsultoriosJson,
        };
      }).toList(),
      'pacientes': pacientes.values.map((p) {
        return {
          'id': p.id,
          'nome': p.nome,
          'data_nascimento': p.dataNascimento?.toIso8601String(),
          'contato': p.contato,
          'email': p.email,
          'tipo_atendimento': p.tipoAtendimento,
          'observacoes': p.observacoes,
          'ativo': p.ativo,
          'data_cadastro': p.dataCadastro.toIso8601String(),
          if (p.dataAtualizacao != null)
            'data_atualizacao': p.dataAtualizacao!.toIso8601String(),
          'modo_atendimento': p.modoAtendimento,
          'foto_base64': p.fotoBase64,
        };
      }).toList(),
      'sessoes': sessoes.values.map((s) {
        return {
          'id': s.id,
          'paciente_id': s.pacienteId,
          'numero_sessao': s.numeroSessao,
          'data': s.data.toIso8601String(),
          'humor': s.humor,
          'tema_principal': s.temaPrincipal,
          'eventos_importantes': s.eventosImportantes,
          'pensamentos_automaticos': s.pensamentosAutomaticos,
          'emocoes': s.emocoes,
          'comportamentos': s.comportamentos,
          'intervencoes': s.intervencoes,
          'tecnicas_tcc': s.tecnicasTcc,
          'tarefa_casa': s.tarefaCasa,
          'evolucao_clinica': s.evolucaoClinica,
          'plano_proxima_sessao': s.planoProximaSessao,
          'observacoes': s.observacoes,
          'relato_pos_sessao': s.relatoPosSessao,
          'apontamentos_copiloto': s.apontamentosCopiloto,
          'arquivada': s.arquivada,
          'audio_relato_path': s.audioRelatoPath,
          'transcricao_relato': s.transcricaoRelato,
          'transcricao_revisada': s.transcricaoRevisada,
          'data_processamento_ia': s.dataProcessamentoIa?.toIso8601String(),
          'gerado_com_ia': s.geradoComIa,
          'status_processamento': s.statusProcessamento,
          'audio_mantido': s.audioMantido,
          'revisado_pelo_profissional': s.revisadoPeloProfissional,
          'erro_processamento_ia': s.erroProcessamentoIa,
          'origem_relato': s.origemRelato,
          'audio_relato_base64': s.audioRelatoBase64,
          'artigos_sugeridos': s.artigosSugeridos,
        };
      }).toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(dados);
  }

  Future<String> importarDeJson(String jsonString) async {
    try {
      final dados = jsonDecode(jsonString) as Map<String, dynamic>;

      if (dados.containsKey('versao') == false) {
        return 'Arquivo de backup inválido: versão não encontrada.';
      }

      final pacientesBox = Hive.box<Paciente>('pacientes');
      final sessoesBox = Hive.box<Sessao>('sessoes');
      final perfilBox = Hive.box<PerfilProfissional>('perfil_profissional');

      int pacientesImportados = 0;
      int sessoesImportadas = 0;
      int perfisImportados = 0;

      for (final item in dados['pacientes'] as List<dynamic>? ?? []) {
        final map = item as Map<String, dynamic>;
        final paciente = Paciente(
          id: map['id'] as String,
          nome: map['nome'] as String? ?? '',
          dataNascimento: map['data_nascimento'] != null
              ? DateTime.parse(map['data_nascimento'] as String)
              : null,
          contato: map['contato'] as String? ?? '',
          email: map['email'] as String? ?? '',
          tipoAtendimento: map['tipo_atendimento'] as String? ?? 'Particular',
          observacoes: map['observacoes'] as String? ?? '',
          ativo: map['ativo'] as bool? ?? true,
          dataCadastro: map['data_cadastro'] != null
              ? DateTime.parse(map['data_cadastro'] as String)
              : DateTime.now(),
          dataAtualizacao: map['data_atualizacao'] != null
              ? DateTime.parse(map['data_atualizacao'] as String)
              : null,
          modoAtendimento: map['modo_atendimento'] as String? ?? '',
          fotoBase64: map['foto_base64'] as String? ?? '',
        );

        if (pacientesBox.values.any((p) => p.id == paciente.id) == false) {
          await pacientesBox.add(paciente);
          pacientesImportados++;
        }
      }

      for (final item in dados['sessoes'] as List<dynamic>? ?? []) {
        final map = item as Map<String, dynamic>;
        final sessao = Sessao(
          id: map['id'] as String,
          pacienteId: map['paciente_id'] as String,
          numeroSessao: map['numero_sessao'] as int? ?? 1,
          data: map['data'] != null
              ? DateTime.parse(map['data'] as String)
              : DateTime.now(),
          humor: map['humor'] as int? ?? 5,
          temaPrincipal: map['tema_principal'] as String? ?? '',
          eventosImportantes: map['eventos_importantes'] as String? ?? '',
          pensamentosAutomaticos:
              map['pensamentos_automaticos'] as String? ?? '',
          emocoes: map['emocoes'] as String? ?? '',
          comportamentos: map['comportamentos'] as String? ?? '',
          intervencoes: map['intervencoes'] as String? ?? '',
          tecnicasTcc: map['tecnicas_tcc'] as String? ?? '',
          tarefaCasa: map['tarefa_casa'] as String? ?? '',
          evolucaoClinica: map['evolucao_clinica'] as String? ?? '',
          planoProximaSessao: map['plano_proxima_sessao'] as String? ?? '',
          observacoes: map['observacoes'] as String? ?? '',
          relatoPosSessao: map['relato_pos_sessao'] as String? ?? '',
          apontamentosCopiloto: map['apontamentos_copiloto'] as String? ?? '',
          arquivada: map['arquivada'] as bool? ?? false,
          audioRelatoPath: map['audio_relato_path'] as String? ?? '',
          transcricaoRelato: map['transcricao_relato'] as String? ?? '',
          transcricaoRevisada: map['transcricao_revisada'] as String? ?? '',
          dataProcessamentoIa: map['data_processamento_ia'] != null
              ? DateTime.parse(map['data_processamento_ia'] as String)
              : null,
          geradoComIa: map['gerado_com_ia'] as bool? ?? false,
          statusProcessamento:
              map['status_processamento'] as String? ?? 'manual',
          audioMantido: map['audio_mantido'] as bool? ?? false,
          revisadoPeloProfissional:
              map['revisado_pelo_profissional'] as bool? ?? false,
          erroProcessamentoIa:
              map['erro_processamento_ia'] as String? ?? '',
          origemRelato: map['origem_relato'] as String? ?? 'manual',
          audioRelatoBase64: map['audio_relato_base64'] as String? ?? '',
          artigosSugeridos: map['artigos_sugeridos'] as String? ?? '',
        );

        if (sessoesBox.values.any((s) => s.id == sessao.id) == false) {
          await sessoesBox.add(sessao);
          sessoesImportadas++;
        }
      }

      for (final item
          in dados['perfil_profissional'] as List<dynamic>? ?? []) {
        final map = item as Map<String, dynamic>;
        final perfil = PerfilProfissional(
          id: map['id'] as String,
          nome: map['nome'] as String? ?? '',
          registroProfissional:
              map['registro_profissional'] as String? ?? '',
          abordagemClinica: map['abordagem_clinica'] as String? ?? 'Integrativa',
          termoPessoaAtendida:
              map['termo_pessoa_atendida'] as String? ?? 'paciente',
          dataCriacao: map['data_criacao'] != null
              ? DateTime.parse(map['data_criacao'] as String)
              : DateTime.now(),
          dataAtualizacao: map['data_atualizacao'] != null
              ? DateTime.parse(map['data_atualizacao'] as String)
              : null,
          modalidadesAtendimentoJson:
              map['modalidades_atendimento_json'] as String? ?? '[]',
          enderecosConsultoriosJson:
              map['enderecos_consultorios_json'] as String? ?? '[]',
        );

        if (perfilBox.values.any((p) => p.id == perfil.id) == false) {
          await perfilBox.add(perfil);
          perfisImportados++;
        }
      }

      return 'Importação concluída: $perfisImportados perfil(is), '
          '$pacientesImportados paciente(s), $sessoesImportadas sessão(ões).';
    } catch (e) {
      return 'Erro ao importar: $e';
    }
  }
}
