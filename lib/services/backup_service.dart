import 'dart:convert';

import 'package:hive_ce/hive.dart';

import '../models/paciente.dart';
import '../models/perfil_profissional.dart';
import '../models/sessao.dart';
import '../models/contrato_terapeutico.dart';
import 'encryption_service.dart';

class BackupService {
  final EncryptionService? _encryption;

  BackupService({EncryptionService? encryption}) : _encryption = encryption;

  String _encrypt(String value) {
    if (_encryption == null || value.isEmpty) return value;
    return _encryption.criptografar(value);
  }

  String _decrypt(String value) {
    if (_encryption == null || value.isEmpty) return value;
    return _encryption.descriptografar(value);
  }

  String exportarParaJson() {
    final pacientes = Hive.box<Paciente>('pacientes');
    final sessoes = Hive.box<Sessao>('sessoes');
    final perfil = Hive.box<PerfilProfissional>('perfil_profissional');

    final dados = {
      'versao': '2.0',
      'exportado_em': DateTime.now().toIso8601String(),
      'perfil_profissional': perfil.values.map((p) {
        return {
          'id': p.id,
          'nome': _decrypt(p.nome),
          'registro_profissional': _decrypt(p.registroProfissional),
          'abordagem_clinica': p.abordagemClinica,
          'termo_pessoa_atendida': p.termoPessoaAtendida,
          'data_criacao': p.dataCriacao.toIso8601String(),
          if (p.dataAtualizacao != null)
            'data_atualizacao': p.dataAtualizacao!.toIso8601String(),
          'modalidades_atendimento_json': p.modalidadesAtendimentoJson,
          'enderecos_consultorios_json': p.enderecosConsultoriosJson,
          'foto_base64': p.fotoBase64,
        };
      }).toList(),
      'pacientes': pacientes.values.map((p) {
        return {
          'id': p.id,
          'nome': _decrypt(p.nome),
          'data_nascimento': p.dataNascimento?.toIso8601String(),
          'contato': _decrypt(p.contato),
          'email': _decrypt(p.email),
          'tipo_atendimento': p.tipoAtendimento,
          'observacoes': _decrypt(p.observacoes),
          'ativo': p.ativo,
          'data_cadastro': p.dataCadastro.toIso8601String(),
          if (p.dataAtualizacao != null)
            'data_atualizacao': p.dataAtualizacao!.toIso8601String(),
          'modo_atendimento': p.modoAtendimento,
          'foto_base64': p.fotoBase64,
        };
      }).toList(),
      'sessoes': sessoes.values.map((s) {
        final audioB64 = _decrypt(s.audioRelatoBase64);
        final incluirAudio = audioB64.length < 500000;
        return {
          'id': s.id,
          'paciente_id': s.pacienteId,
          'numero_sessao': s.numeroSessao,
          'data': s.data.toIso8601String(),
          'tema_principal': _decrypt(s.temaPrincipal),
          'eventos_importantes': _decrypt(s.eventosImportantes),
          'pensamentos_automaticos': _decrypt(s.pensamentosAutomaticos),
          'emocoes': _decrypt(s.emocoes),
          'comportamentos': _decrypt(s.comportamentos),
          'intervencoes': _decrypt(s.intervencoes),
          'tecnicas_tcc': _decrypt(s.tecnicasTcc),
          'tarefa_casa': _decrypt(s.tarefaCasa),
          'evolucao_clinica': _decrypt(s.evolucaoClinica),
          'plano_proxima_sessao': _decrypt(s.planoProximaSessao),
          'observacoes': _decrypt(s.observacoes),
          'relato_pos_sessao': _decrypt(s.relatoPosSessao),
          'apontamentos_copiloto': _decrypt(s.apontamentosCopiloto),
          'arquivada': s.arquivada,
          'audio_relato_path': _decrypt(s.audioRelatoPath),
          'transcricao_relato': _decrypt(s.transcricaoRelato),
          'transcricao_revisada': _decrypt(s.transcricaoRevisada),
          'data_processamento_ia': s.dataProcessamentoIa?.toIso8601String(),
          'gerado_com_ia': s.geradoComIa,
          'status_processamento': s.statusProcessamento,
          'audio_mantido': s.audioMantido,
          'revisado_pelo_profissional': s.revisadoPeloProfissional,
          'erro_processamento_ia': _decrypt(s.erroProcessamentoIa),
          'origem_relato': s.origemRelato,
          if (incluirAudio) 'audio_relato_base64': audioB64,
          'audio_excluido_do_backup': !incluirAudio,
          'artigos_sugeridos': _decrypt(s.artigosSugeridos),
        };
      }).toList(),
        'contratos': Hive.box<ContratoTerapeutico>('contratos').values.map((c) {
          return {
            'id': c.id,
            'paciente_id': c.pacienteId,
            'token': c.token,
            'data_criacao': c.dataCriacao.toIso8601String(),
            if (c.dataEnvio != null)
              'data_envio': c.dataEnvio!.toIso8601String(),
            if (c.dataAceite != null)
              'data_aceite': c.dataAceite!.toIso8601String(),
            'status': c.status,
            'nome_aceite': c.nomeAceite,
            'url': c.url,
          };
        }).toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(dados);
  }

  Future<void> _salvarSobrescrevendo<T>(
    Box<T> box,
    T novo,
    bool Function(T existente) mesmoId,
    Map<String, dynamic> idToKey,
  ) async {
    final novaId = (novo as dynamic).id as String?;
    final chaveExistente = idToKey[novaId];

    if (chaveExistente != null) {
      await box.put(chaveExistente, novo);
    } else {
      await box.add(novo);
    }
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
      final contratosBox = Hive.box<ContratoTerapeutico>('contratos');

      final pacienteIdToKey = <String, dynamic>{};
      for (final entry in pacientesBox.toMap().entries) {
        pacienteIdToKey[entry.value.id] = entry.key;
      }
      final sessaoIdToKey = <String, dynamic>{};
      for (final entry in sessoesBox.toMap().entries) {
        sessaoIdToKey[entry.value.id] = entry.key;
      }
      final perfilIdToKey = <String, dynamic>{};
      for (final entry in perfilBox.toMap().entries) {
        perfilIdToKey[entry.value.id] = entry.key;
      }
      final contratoIdToKey = <String, dynamic>{};
      for (final entry in contratosBox.toMap().entries) {
        contratoIdToKey[entry.value.id] = entry.key;
      }

      int pacientesImportados = 0;
      int sessoesImportadas = 0;
      int perfisImportados = 0;
      int contratosImportados = 0;

      for (final item in dados['pacientes'] as List<dynamic>? ?? []) {
        final map = item as Map<String, dynamic>;
        final paciente = Paciente(
          id: map['id'] as String,
          nome: _encrypt(map['nome'] as String? ?? ''),
          dataNascimento: map['data_nascimento'] != null
              ? DateTime.parse(map['data_nascimento'] as String)
              : null,
          contato: _encrypt(map['contato'] as String? ?? ''),
          email: _encrypt(map['email'] as String? ?? ''),
          tipoAtendimento: map['tipo_atendimento'] as String? ?? 'Particular',
          observacoes: _encrypt(map['observacoes'] as String? ?? ''),
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

        await _salvarSobrescrevendo<Paciente>(
          pacientesBox,
          paciente,
          (existente) => existente.id == paciente.id,
          pacienteIdToKey,
        );
        pacientesImportados++;
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
          temaPrincipal: _encrypt(map['tema_principal'] as String? ?? ''),
          eventosImportantes:
              _encrypt(map['eventos_importantes'] as String? ?? ''),
          pensamentosAutomaticos:
              _encrypt(map['pensamentos_automaticos'] as String? ?? ''),
          emocoes: _encrypt(map['emocoes'] as String? ?? ''),
          comportamentos: _encrypt(map['comportamentos'] as String? ?? ''),
          intervencoes: _encrypt(map['intervencoes'] as String? ?? ''),
          tecnicasTcc: _encrypt(map['tecnicas_tcc'] as String? ?? ''),
          tarefaCasa: _encrypt(map['tarefa_casa'] as String? ?? ''),
          evolucaoClinica: _encrypt(map['evolucao_clinica'] as String? ?? ''),
          planoProximaSessao:
              _encrypt(map['plano_proxima_sessao'] as String? ?? ''),
          observacoes: _encrypt(map['observacoes'] as String? ?? ''),
          relatoPosSessao: _encrypt(map['relato_pos_sessao'] as String? ?? ''),
          apontamentosCopiloto:
              _encrypt(map['apontamentos_copiloto'] as String? ?? ''),
          arquivada: map['arquivada'] as bool? ?? false,
          audioRelatoPath: _encrypt(map['audio_relato_path'] as String? ?? ''),
          transcricaoRelato:
              _encrypt(map['transcricao_relato'] as String? ?? ''),
          transcricaoRevisada:
              _encrypt(map['transcricao_revisada'] as String? ?? ''),
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
              _encrypt(map['erro_processamento_ia'] as String? ?? ''),
          origemRelato: map['origem_relato'] as String? ?? 'manual',
          audioRelatoBase64:
              _encrypt(map['audio_relato_base64'] as String? ?? ''),
          artigosSugeridos:
              _encrypt(map['artigos_sugeridos'] as String? ?? ''),
        );

        await _salvarSobrescrevendo<Sessao>(
          sessoesBox,
          sessao,
          (existente) => existente.id == sessao.id,
          sessaoIdToKey,
        );
        sessoesImportadas++;
      }

      for (final item
          in dados['perfil_profissional'] as List<dynamic>? ?? []) {
        final map = item as Map<String, dynamic>;
        final perfil = PerfilProfissional(
          id: map['id'] as String,
          nome: _encrypt(map['nome'] as String? ?? ''),
          registroProfissional:
              _encrypt(map['registro_profissional'] as String? ?? ''),
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
          fotoBase64: map['foto_base64'] as String? ?? '',
        );

        await _salvarSobrescrevendo<PerfilProfissional>(
          perfilBox,
          perfil,
          (existente) => existente.id == perfil.id,
          perfilIdToKey,
        );
        perfisImportados++;
      }

      for (final item in dados['contratos'] as List<dynamic>? ?? []) {
        final map = item as Map<String, dynamic>;
        final contrato = ContratoTerapeutico(
          id: map['id'] as String,
          pacienteId: map['paciente_id'] as String,
          token: map['token'] as String,
          dataCriacao: map['data_criacao'] != null
              ? DateTime.parse(map['data_criacao'] as String)
              : DateTime.now(),
          dataEnvio: map['data_envio'] != null
              ? DateTime.parse(map['data_envio'] as String)
              : null,
          dataAceite: map['data_aceite'] != null
              ? DateTime.parse(map['data_aceite'] as String)
              : null,
          status: map['status'] as String? ?? 'pendente',
          nomeAceite: map['nome_aceite'] as String? ?? '',
          url: map['url'] as String? ?? '',
        );

        await _salvarSobrescrevendo<ContratoTerapeutico>(
          contratosBox,
          contrato,
          (existente) => existente.id == contrato.id,
          contratoIdToKey,
        );
        contratosImportados++;
      }

      return 'Importação concluída: $perfisImportados perfil(is), '
          '$pacientesImportados paciente(s), $sessoesImportadas sessão(ões), '
          '$contratosImportados contrato(s).';
    } catch (e) {
      return 'Erro ao importar: $e';
    }
  }
}
