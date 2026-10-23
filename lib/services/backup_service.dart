import 'dart:convert';

import 'package:hive_ce/hive.dart';

import '../models/compromisso.dart';
import '../models/paciente.dart';
import '../models/pacote.dart';
import '../models/perfil_profissional.dart';
import '../models/progresso_sessao.dart';
import '../models/sessao.dart';
import '../models/contrato_terapeutico.dart';
import 'encrypted_service_mixin.dart';
import 'encryption_service.dart';

class BackupService with EncryptedServiceMixin {
  @override
  final EncryptionService? encryption;

  BackupService({this.encryption});

  String _encrypt(String value) => encrypt(value);
  String _decrypt(String value) => decrypt(value);

  bool get _podeCifrar => encryption != null && encryption!.configurado;

  Map<String, dynamic> _montarDados() {
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
          if (p.fotoBase64.isNotEmpty) 'foto_base64': _decrypt(p.fotoBase64),
          'tratamento': p.tratamento,
          if (p.enderecoJson.isNotEmpty)
            'endereco_json': _decrypt(p.enderecoJson),
          'valor_sessao': p.valorSessao,
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
          'valor_sessao': s.valorSessao,
          'status_pagamento': s.statusPagamento,
          if (s.dataPagamento != null)
            'data_pagamento': s.dataPagamento!.toIso8601String(),
          'metodo_pagamento': s.metodoPagamento,
        };
      }).toList(),
      'compromissos':
          (Hive.isBoxOpen('compromissos')
                  ? Hive.box<Compromisso>('compromissos').values
                  : const <Compromisso>[])
              .map((c) {
                return {
                  'id': c.id,
                  'paciente_id': c.pacienteId,
                  'data_hora_inicio': c.dataHoraInicio.toIso8601String(),
                  'data_hora_fim': c.dataHoraFim.toIso8601String(),
                  'titulo': _decrypt(c.titulo),
                  'observacoes': _decrypt(c.observacoes),
                  'status': c.status,
                  if (c.sessaoId != null) 'sessao_id': c.sessaoId,
                  'data_criacao': c.dataCriacao.toIso8601String(),
                  if (c.dataAtualizacao != null)
                    'data_atualizacao': c.dataAtualizacao!.toIso8601String(),
                  'lembrete_ativado': c.lembreteAtivado,
                  'minutos_antecedencia': c.minutosAntecedencia,
                  'mensagem_lembrete': _decrypt(c.mensagemLembrete),
                  'recorrencia': c.recorrencia,
                  if (c.dataLimiteRecorrencia != null)
                    'data_limite_recorrencia': c.dataLimiteRecorrencia!
                        .toIso8601String(),
                  if (c.compromissoPaiId != null)
                    'compromisso_pai_id': c.compromissoPaiId,
                  'canal_lembrete': c.canalLembrete,
                  'tipo_evento': c.tipoEvento,
                  'modalidade': c.modalidade,
                  'sala': c.sala,
                  'servico': c.servico,
                  'link_online': c.linkOnline,
                  'google_event_id': c.googleEventId,
                  'google_calendar_id': c.googleCalendarId,
                  if (c.googleSyncedAt != null)
                    'google_synced_at': c.googleSyncedAt!.toIso8601String(),
                };
              })
              .toList(),
      'contratos': Hive.box<ContratoTerapeutico>('contratos').values.map((c) {
        return {
          'id': c.id,
          'paciente_id': c.pacienteId,
          'token': _decrypt(c.token),
          'data_criacao': c.dataCriacao.toIso8601String(),
          if (c.dataEnvio != null) 'data_envio': c.dataEnvio!.toIso8601String(),
          if (c.dataAceite != null)
            'data_aceite': c.dataAceite!.toIso8601String(),
          'status': c.status,
          'nome_aceite': _decrypt(c.nomeAceite),
          'url': _decrypt(c.url),
          'arquivado': c.arquivado,
        };
      }).toList(),
      'pacotes': Hive.box<Pacote>('pacotes').values.map((p) {
        return {
          'id': p.id,
          'paciente_id': p.pacienteId,
          'total_sessoes': p.totalSessoes,
          'sessoes_restantes': p.sessoesRestantes,
          'valor_total': p.valorTotal,
          'data_criacao': p.dataCriacao.toIso8601String(),
          'ativo': p.ativo,
          'observacoes': p.observacoes,
        };
      }).toList(),
      'progresso_sessoes': Hive.box<ProgressoSessao>('progresso_sessoes').values
          .map((p) {
            return {
              'id': p.id,
              'paciente_id': p.pacienteId,
              'sessao_id': p.sessaoId,
              'numero_sessao': p.numeroSessao,
              'sintomas_json': p.sintomasJson,
              'metas_json': p.metasJson,
              'avaliacao_geral': p.avaliacaoGeral,
              'tendencia': p.tendencia,
              'data_processamento': p.dataProcessamento.toIso8601String(),
            };
          })
          .toList(),
    };

    return dados;
  }

  String exportarParaJson() {
    if (!_podeCifrar) {
      throw StateError('Desbloqueie o app antes de exportar o backup.');
    }
    final jsonClaro = const JsonEncoder.withIndent('  ').convert(_montarDados());
    final envelope = encryption!.criptografarEnvelope(jsonClaro);
    if (envelope == null) {
      throw StateError('Nao foi possivel proteger o backup.');
    }
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(envelope));
  }

  /// Backup portátil: cifrado com a SENHA do usuário (PBKDF2 + AES-GCM).
  /// Diferente do backup padrão, NÃO depende da chave deste aparelho — pode ser
  /// restaurado em qualquer aparelho/reinstalação, desde que a senha seja lembrada.
  Future<String> exportarParaJsonPortavel(String senha) async {
    if (!_podeCifrar) {
      throw StateError('Desbloqueie o app antes de exportar o backup.');
    }
    if (senha.trim().length < 8) {
      throw StateError('A senha do backup deve ter pelo menos 8 caracteres.');
    }
    final jsonClaro = const JsonEncoder.withIndent('  ').convert(_montarDados());
    final envelope = await encryption!.criptografarEnvelopeComSenha(jsonClaro, senha);
    if (envelope == null) {
      throw StateError('Nao foi possivel proteger o backup com senha.');
    }
    return envelope;
  }

  /// True quando o arquivo é um backup portátil (protegido por senha).
  static bool ehBackupComSenha(String jsonString) {
    try {
      final dados = jsonDecode(jsonString) as Map<String, dynamic>;
      return dados['tipo'] == 'mentall_backup_v2';
    } catch (_) {
      return false;
    }
  }

  /// Exporta a chave mestra embrulhada por senha (arquivo de recuperação).
  Future<String?> exportarChaveRecuperacao(String senha) async =>
      await encryption?.exportarChaveProtegida(senha);

  /// Importa a chave de recuperação (substitui a chave deste aparelho).
  Future<bool> importarChaveRecuperacao(String envelope, String senha) async =>
      await encryption?.importarChaveProtegida(envelope, senha) ?? false;

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

  Future<String> importarDeJson(String jsonString, {String? senha}) async {
    try {
      if (!_podeCifrar) {
        return 'Backup criptografado: configure o PIN ou desbloqueie o app para restaurar.';
      }
      // O agendamento antigo emitiu duas camadas. Nao aceitar aninhamento ilimitado.
      for (var camada = 0; camada < 2; camada++) {
        final dados = jsonDecode(jsonString) as Map<String, dynamic>;
        final tipo = dados['tipo'];

        if (tipo == 'mentall_backup_v2') {
          if (senha == null || senha.isEmpty) {
            return 'Backup protegido por senha: informe a senha para restaurar.';
          }
          final jsonClaro =
              await encryption!.descriptografarEnvelopeComSenha(jsonString, senha);
          if (jsonClaro == null) {
            return 'Senha incorreta ou arquivo de backup corrompido. Verifique a senha e o arquivo original.';
          }
          jsonString = jsonClaro;
          continue;
        }

        if (tipo != 'mentall_backup_v1') break;
        final jsonClaro = encryption!.descriptografarEnvelope(jsonString);
        if (jsonClaro == null) {
          return 'Nao foi possivel abrir o backup: chave diferente ou integridade comprometida. Preserve o arquivo e o aparelho original.';
        }
        jsonString = jsonClaro;
      }

      return await _importarJsonClaro(jsonString);
    } catch (e) {
      return 'Erro ao importar: $e';
    }
  }

  Future<String> _importarJsonClaro(String jsonString) async {
    try {
      final dados = jsonDecode(jsonString) as Map<String, dynamic>;

      if (dados.containsKey('versao') == false) {
        return 'Arquivo de backup inv\u00e1lido: vers\u00e3o n\u00e3o encontrada.';
      }
      if (dados['versao'] != '1.0' && dados['versao'] != '2.0') {
        return 'Arquivo de backup invalido: versao nao suportada.';
      }
      for (final secao in [
        'pacientes',
        'sessoes',
        'compromissos',
        'perfil_profissional',
        'contratos',
        'pacotes',
        'progresso_sessoes',
      ]) {
        final ids = <String>{};
        for (final item in dados[secao] as List<dynamic>? ?? []) {
          final id = (item as Map<String, dynamic>)['id'] as String;
          if (id.trim().isEmpty || !ids.add(id)) {
            throw const FormatException('ID vazio ou duplicado no backup.');
          }
        }
      }

      // Construa/valide todos os modelos antes de iniciar qualquer escrita Hive.
      final gravacoes = <Future<void> Function()>[];

      final pacientesBox = Hive.box<Paciente>('pacientes');
      final sessoesBox = Hive.box<Sessao>('sessoes');
      final compromissosBox = Hive.isBoxOpen('compromissos')
          ? Hive.box<Compromisso>('compromissos')
          : null;
      final perfilBox = Hive.box<PerfilProfissional>('perfil_profissional');
      final contratosBox = Hive.box<ContratoTerapeutico>('contratos');
      final pacotesBox = Hive.box<Pacote>('pacotes');
      final progressosBox = Hive.box<ProgressoSessao>('progresso_sessoes');

      final pacienteIdToKey = <String, dynamic>{};
      for (final entry in pacientesBox.toMap().entries) {
        pacienteIdToKey[entry.value.id] = entry.key;
      }
      final sessaoIdToKey = <String, dynamic>{};
      for (final entry in sessoesBox.toMap().entries) {
        sessaoIdToKey[entry.value.id] = entry.key;
      }
      final compromissoIdToKey = <String, dynamic>{};
      if (compromissosBox != null) {
        for (final entry in compromissosBox.toMap().entries) {
          compromissoIdToKey[entry.value.id] = entry.key;
        }
      }
      final perfilIdToKey = <String, dynamic>{};
      for (final entry in perfilBox.toMap().entries) {
        perfilIdToKey[entry.value.id] = entry.key;
      }
      final contratoIdToKey = <String, dynamic>{};
      for (final entry in contratosBox.toMap().entries) {
        contratoIdToKey[entry.value.id] = entry.key;
      }
      final pacoteIdToKey = <String, dynamic>{};
      for (final entry in pacotesBox.toMap().entries) {
        pacoteIdToKey[entry.value.id] = entry.key;
      }
      final progressoIdToKey = <String, dynamic>{};
      for (final entry in progressosBox.toMap().entries) {
        progressoIdToKey[entry.value.id] = entry.key;
      }

      int pacientesImportados = 0;
      int sessoesImportadas = 0;
      int compromissosImportados = 0;
      int perfisImportados = 0;
      int contratosImportados = 0;
      int pacotesImportados = 0;
      int progressosImportados = 0;

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
          fotoBase64: _encrypt(map['foto_base64'] as String? ?? ''),
          tratamento: map['tratamento'] as String? ?? 'masculino',
          enderecoJson: _encrypt(map['endereco_json'] as String? ?? ''),
          valorSessao: (map['valor_sessao'] as num?)?.toDouble() ?? 0.0,
        );

        gravacoes.add(
          () => _salvarSobrescrevendo<Paciente>(
            pacientesBox,
            paciente,
            (existente) => existente.id == paciente.id,
            pacienteIdToKey,
          ),
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
          eventosImportantes: _encrypt(
            map['eventos_importantes'] as String? ?? '',
          ),
          pensamentosAutomaticos: _encrypt(
            map['pensamentos_automaticos'] as String? ?? '',
          ),
          emocoes: _encrypt(map['emocoes'] as String? ?? ''),
          comportamentos: _encrypt(map['comportamentos'] as String? ?? ''),
          intervencoes: _encrypt(map['intervencoes'] as String? ?? ''),
          tecnicasTcc: _encrypt(map['tecnicas_tcc'] as String? ?? ''),
          tarefaCasa: _encrypt(map['tarefa_casa'] as String? ?? ''),
          evolucaoClinica: _encrypt(map['evolucao_clinica'] as String? ?? ''),
          planoProximaSessao: _encrypt(
            map['plano_proxima_sessao'] as String? ?? '',
          ),
          observacoes: _encrypt(map['observacoes'] as String? ?? ''),
          relatoPosSessao: _encrypt(map['relato_pos_sessao'] as String? ?? ''),
          apontamentosCopiloto: _encrypt(
            map['apontamentos_copiloto'] as String? ?? '',
          ),
          arquivada: map['arquivada'] as bool? ?? false,
          audioRelatoPath: _encrypt(map['audio_relato_path'] as String? ?? ''),
          transcricaoRelato: _encrypt(
            map['transcricao_relato'] as String? ?? '',
          ),
          transcricaoRevisada: _encrypt(
            map['transcricao_revisada'] as String? ?? '',
          ),
          dataProcessamentoIa: map['data_processamento_ia'] != null
              ? DateTime.parse(map['data_processamento_ia'] as String)
              : null,
          geradoComIa: map['gerado_com_ia'] as bool? ?? false,
          statusProcessamento:
              map['status_processamento'] as String? ?? 'manual',
          audioMantido: map['audio_mantido'] as bool? ?? false,
          revisadoPeloProfissional:
              map['revisado_pelo_profissional'] as bool? ?? false,
          erroProcessamentoIa: _encrypt(
            map['erro_processamento_ia'] as String? ?? '',
          ),
          origemRelato: map['origem_relato'] as String? ?? 'manual',
          audioRelatoBase64: _encrypt(
            map['audio_relato_base64'] as String? ?? '',
          ),
          artigosSugeridos: _encrypt(map['artigos_sugeridos'] as String? ?? ''),
          valorSessao: (map['valor_sessao'] as num?)?.toDouble() ?? 0.0,
          statusPagamento: map['status_pagamento'] as String? ?? 'pendente',
          dataPagamento: map['data_pagamento'] != null
              ? DateTime.parse(map['data_pagamento'] as String)
              : null,
          metodoPagamento: map['metodo_pagamento'] as String? ?? '',
        );

        gravacoes.add(
          () => _salvarSobrescrevendo<Sessao>(
            sessoesBox,
            sessao,
            (existente) => existente.id == sessao.id,
            sessaoIdToKey,
          ),
        );
        sessoesImportadas++;
      }

      if (compromissosBox != null) {
        for (final item in dados['compromissos'] as List<dynamic>? ?? []) {
          final map = item as Map<String, dynamic>;
          final inicio = map['data_hora_inicio'] != null
              ? DateTime.parse(map['data_hora_inicio'] as String)
              : DateTime.now();
          final compromisso = Compromisso(
            id: map['id'] as String,
            pacienteId: map['paciente_id'] as String? ?? '',
            dataHoraInicio: inicio,
            dataHoraFim: map['data_hora_fim'] != null
                ? DateTime.parse(map['data_hora_fim'] as String)
                : inicio.add(const Duration(minutes: 50)),
            titulo: _encrypt(map['titulo'] as String? ?? ''),
            observacoes: _encrypt(map['observacoes'] as String? ?? ''),
            status: map['status'] as String? ?? 'agendado',
            sessaoId: map['sessao_id'] as String?,
            dataCriacao: map['data_criacao'] != null
                ? DateTime.parse(map['data_criacao'] as String)
                : DateTime.now(),
            dataAtualizacao: map['data_atualizacao'] != null
                ? DateTime.parse(map['data_atualizacao'] as String)
                : null,
            lembreteAtivado: map['lembrete_ativado'] as bool? ?? false,
            minutosAntecedencia:
                (map['minutos_antecedencia'] as num?)?.toInt() ?? 1440,
            mensagemLembrete: _encrypt(
              map['mensagem_lembrete'] as String? ?? '',
            ),
            recorrencia: map['recorrencia'] as String? ?? '',
            dataLimiteRecorrencia: map['data_limite_recorrencia'] != null
                ? DateTime.parse(map['data_limite_recorrencia'] as String)
                : null,
            compromissoPaiId: map['compromisso_pai_id'] as String?,
            canalLembrete: map['canal_lembrete'] as String? ?? 'whatsapp',
            tipoEvento: map['tipo_evento'] as String? ?? 'sessao',
            modalidade: map['modalidade'] as String? ?? 'presencial',
            sala: map['sala'] as String? ?? '',
            servico: map['servico'] as String? ?? '',
            linkOnline: map['link_online'] as String? ?? '',
            googleEventId: map['google_event_id'] as String? ?? '',
            googleCalendarId: map['google_calendar_id'] as String? ?? '',
            googleSyncedAt: map['google_synced_at'] != null
                ? DateTime.parse(map['google_synced_at'] as String)
                : null,
          );

          gravacoes.add(
            () => _salvarSobrescrevendo<Compromisso>(
              compromissosBox,
              compromisso,
              (existente) => existente.id == compromisso.id,
              compromissoIdToKey,
            ),
          );
          compromissosImportados++;
        }
      }

      for (final item in dados['perfil_profissional'] as List<dynamic>? ?? []) {
        final map = item as Map<String, dynamic>;
        final perfil = PerfilProfissional(
          id: map['id'] as String,
          nome: _encrypt(map['nome'] as String? ?? ''),
          registroProfissional: _encrypt(
            map['registro_profissional'] as String? ?? '',
          ),
          abordagemClinica:
              map['abordagem_clinica'] as String? ?? 'Integrativa',
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

        gravacoes.add(
          () => _salvarSobrescrevendo<PerfilProfissional>(
            perfilBox,
            perfil,
            (existente) => existente.id == perfil.id,
            perfilIdToKey,
          ),
        );
        perfisImportados++;
      }

      for (final item in dados['contratos'] as List<dynamic>? ?? []) {
        final map = item as Map<String, dynamic>;
        final contrato = ContratoTerapeutico(
          id: map['id'] as String,
          pacienteId: map['paciente_id'] as String,
          token: _encrypt(map['token'] as String? ?? ''),
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
          nomeAceite: _encrypt(map['nome_aceite'] as String? ?? ''),
          url: _encrypt(map['url'] as String? ?? ''),
          arquivado: map['arquivado'] as bool? ?? false,
        );

        gravacoes.add(
          () => _salvarSobrescrevendo<ContratoTerapeutico>(
            contratosBox,
            contrato,
            (existente) => existente.id == contrato.id,
            contratoIdToKey,
          ),
        );
        contratosImportados++;
      }

      for (final item in dados['pacotes'] as List<dynamic>? ?? []) {
        final map = item as Map<String, dynamic>;
        final pacote = Pacote(
          id: map['id'] as String,
          pacienteId: map['paciente_id'] as String,
          totalSessoes: map['total_sessoes'] as int? ?? 0,
          sessoesRestantes: map['sessoes_restantes'] as int? ?? 0,
          valorTotal: (map['valor_total'] as num?)?.toDouble() ?? 0.0,
          dataCriacao: map['data_criacao'] != null
              ? DateTime.parse(map['data_criacao'] as String)
              : DateTime.now(),
          ativo: map['ativo'] as bool? ?? true,
          observacoes: map['observacoes'] as String? ?? '',
        );

        gravacoes.add(
          () => _salvarSobrescrevendo<Pacote>(
            pacotesBox,
            pacote,
            (existente) => existente.id == pacote.id,
            pacoteIdToKey,
          ),
        );
        pacotesImportados++;
      }

      for (final item in dados['progresso_sessoes'] as List<dynamic>? ?? []) {
        final map = item as Map<String, dynamic>;
        final progresso = ProgressoSessao(
          id: map['id'] as String,
          pacienteId: map['paciente_id'] as String,
          sessaoId: map['sessao_id'] as String,
          numeroSessao: map['numero_sessao'] as int? ?? 0,
          sintomasJson: map['sintomas_json'] as String? ?? '[]',
          metasJson: map['metas_json'] as String? ?? '[]',
          avaliacaoGeral: map['avaliacao_geral'] as String? ?? '',
          tendencia: map['tendencia'] as String? ?? 'estavel',
          dataProcessamento: map['data_processamento'] != null
              ? DateTime.parse(map['data_processamento'] as String)
              : DateTime.now(),
        );

        gravacoes.add(
          () => _salvarSobrescrevendo<ProgressoSessao>(
            progressosBox,
            progresso,
            (existente) => existente.id == progresso.id,
            progressoIdToKey,
          ),
        );
        progressosImportados++;
      }

      final pacientesDisponiveis = {
        ...pacienteIdToKey.keys,
        for (final item in dados['pacientes'] as List<dynamic>? ?? [])
          item['id'] as String,
      };
      for (final secao in [
        'sessoes',
        'compromissos',
        'contratos',
        'pacotes',
        'progresso_sessoes',
      ]) {
        for (final item in dados[secao] as List<dynamic>? ?? []) {
          if (!pacientesDisponiveis.contains(item['paciente_id'])) {
            throw const FormatException(
              'Referencia a paciente ausente no backup.',
            );
          }
        }
      }
      final pacientePorSessao = {
        for (final sessao in sessoesBox.values) sessao.id: sessao.pacienteId,
        for (final item in dados['sessoes'] as List<dynamic>? ?? [])
          item['id'] as String: item['paciente_id'] as String,
      };
      for (final item in dados['progresso_sessoes'] as List<dynamic>? ?? []) {
        final sessaoId = item['sessao_id'] as String;
        // O app ja persiste progresso antes de salvar a sessao. Preserve esse
        // estado legado, mas nunca vincule a uma sessao conhecida de outro paciente.
        if (sessaoId.trim().isEmpty ||
            (pacientePorSessao.containsKey(sessaoId) &&
                pacientePorSessao[sessaoId] != item['paciente_id'])) {
          throw const FormatException(
            'Referencia de sessao invalida no progresso.',
          );
        }
      }

      for (final gravar in gravacoes) {
        await gravar();
      }

      return 'Importa\u00e7\u00e3o conclu\u00edda: $perfisImportados perfil(is), '
          '$pacientesImportados paciente(s), $sessoesImportadas sess\u00e3o(\u00f5es), '
          '$compromissosImportados compromisso(s), '
          '$contratosImportados contrato(s), $pacotesImportados pacote(s), '
          '$progressosImportados registro(s) de progresso.';
    } catch (e) {
      return 'Erro ao importar: $e';
    }
  }
}
