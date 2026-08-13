import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/avaliacao_inicial.dart';
import '../models/paciente.dart';
import '../models/sessao.dart';
import 'avaliacao_inicial_service.dart';
import 'configuracoes_service.dart';
import 'encryption_service.dart';
import 'logger.dart';
import 'paciente_service.dart';
import 'sessao_service.dart';

class DemoDataService {
  static const String pacienteDemoId = 'demo-linda-tester';
  static const String anamneseDemoId = 'demo-linda-tester-anamnese';
  static const String fotoDemoAsset = 'assets/images/paciente_mulher_negra.jpeg';

  final EncryptionService encryption;
  final Future<String> Function()? fotoLoader;

  late final PacienteService _pacienteService;
  late final SessaoService _sessaoService;
  late final AvaliacaoInicialService _avaliacaoService;
  late final ConfiguracoesService _config;

  DemoDataService({required this.encryption, this.fotoLoader}) {
    _pacienteService = PacienteService(encryption: encryption);
    _sessaoService = SessaoService(encryption: encryption);
    _avaliacaoService = AvaliacaoInicialService(encryption: encryption);
    _config = ConfiguracoesService();
  }

  Future<void> semearSeNecessario() async {
    if (_config.demoCriado) return;
    if (_pacienteService.existePacienteComId(pacienteDemoId)) {
      await _config.setDemoCriado(true);
      return;
    }

    try {
      await _semearPaciente();
      await _semearAnamnese();
      await _semearSessoes();
      await _config.setDemoCriado(true);
    } catch (e) {
      Log.erro(e, contexto: 'DemoDataService.semearSeNecessario');
    }
  }

  Future<void> _semearPaciente() async {
    String fotoBase64 = '';
    try {
      final loader = fotoLoader;
      if (loader != null) {
        fotoBase64 = await loader();
      } else {
        final byteData = await rootBundle.load(fotoDemoAsset);
        fotoBase64 = base64Encode(byteData.buffer.asUint8List());
      }
    } catch (e) {
      Log.erro(e, contexto: 'DemoDataService._semearPaciente (foto)');
    }

    final paciente = Paciente(
      id: pacienteDemoId,
      nome: 'Linda M. Tester',
      dataNascimento: DateTime(1991, 1, 25),
      tratamento: 'feminino',
      tipoAtendimento: 'Particular',
      fotoBase64: fotoBase64,
      ehDemo: true,
      observacoes:
          'Paciente fict\u00edcia de demonstra\u00e7\u00e3o \u2014 criada como exemplo para teste do aplicativo.',
      dataCadastro: DateTime(2026, 7, 8),
    );

    await _pacienteService.adicionarPaciente(paciente);
  }

  Future<void> _semearAnamnese() async {
    final anamnese = AvaliacaoInicial(
      id: anamneseDemoId,
      pacienteId: pacienteDemoId,
      queixaPrincipal:
          'Ansiedade associada a dificuldades no ambiente de trabalho, com '
          'preocupa\u00e7\u00f5es excessivas, autocr\u00edtica intensa e medo de '
          'n\u00e3o corresponder \u00e0s expectativas profissionais.',
      historicoClinico:
          'Hist\u00f3rico de elevada autocr\u00edtica e cobran\u00e7a desde a '
          'adolesc\u00eancia; busca constante por padr\u00f5es altos de desempenho. '
          'Sem hist\u00f3rico m\u00e9dico ou psiqui\u00e1trico relevante relatado.',
      medicamentos: 'Nenhum medicamento em uso no momento.',
      hipoteseDiagnostica:
          'Quadro compat\u00edvel com Transtorno de Ansiedade Generalizada, '
          'associado a perfeccionismo e medo de avalia\u00e7\u00e3o negativa '
          '(a confirmar).',
      objetivosTerapeuticos:
          'Reduzir a preocupa\u00e7\u00e3o excessiva e a autocr\u00edtica; '
          'diferenciar desempenho de valor pessoal; desenvolver autocompaix\u00e3o '
          'e estrat\u00e9gias de regula\u00e7\u00e3o emocional.',
      observacoes: _resumoPrimeiroMes,
      dataCriacao: DateTime(2026, 7, 8),
    );

    await _avaliacaoService.salvar(anamnese);
  }

  Future<void> _semearSessoes() async {
    final sessoes = [
      _SessaoDemo(
        numero: 1,
        data: DateTime(2026, 7, 8, 14, 0),
        transcricao: _sessao1,
      ),
      _SessaoDemo(
        numero: 2,
        data: DateTime(2026, 7, 15, 14, 0),
        transcricao: _sessao2,
      ),
      _SessaoDemo(
        numero: 3,
        data: DateTime(2026, 7, 22, 14, 0),
        transcricao: _sessao3,
      ),
      _SessaoDemo(
        numero: 4,
        data: DateTime(2026, 7, 29, 14, 0),
        transcricao: _sessao4,
      ),
    ];

    for (final s in sessoes) {
      await _sessaoService.adicionarSessao(
        Sessao(
          id: 'demo-linda-tester-s${s.numero}',
          pacienteId: pacienteDemoId,
          numeroSessao: s.numero,
          data: s.data,
          transcricaoRelato: s.transcricao,
          statusProcessamento: 'transcrito',
          origemRelato: 'transcricao',
          geradoComIa: false,
          revisadoPeloProfissional: false,
        ),
      );
    }
  }

  static const String _resumoPrimeiroMes =
      'Linda apresenta quadro de ansiedade relacionado principalmente ao '
      'contexto profissional, marcado por autocobran\u00e7a, perfeccionismo e '
      'receio de avalia\u00e7\u00e3o negativa. Durante o primeiro m\u00eas de '
      'terapia, demonstrou boa ades\u00e3o ao processo, desenvolvendo crescente '
      'consci\u00eancia dos fatores que mant\u00eam sua ansiedade e iniciando a '
      'constru\u00e7\u00e3o de estrat\u00e9gias de enfrentamento mais saud\u00e1veis. '
      'O progn\u00f3stico inicial \u00e9 favor\u00e1vel devido ao engajamento, '
      'capacidade reflexiva e motiva\u00e7\u00e3o para mudan\u00e7as.';

  static const String _sessao1 =
      'Primeiro encontro destinado \u00e0 compreens\u00e3o da demanda principal '
      'da paciente. Linda relatou aumento significativo da ansiedade nos '
      '\u00faltimos meses, especialmente relacionado ao trabalho. Descreveu '
      'sensa\u00e7\u00e3o constante de press\u00e3o por resultados, preocupa\u00e7\u00e3o '
      'excessiva com poss\u00edveis erros e dificuldade para desligar-se das '
      'responsabilidades profissionais fora do expediente.\n\n'
      'Referiu epis\u00f3dios de ins\u00f4nia, tens\u00e3o muscular e pensamentos '
      'recorrentes sobre desempenho e poss\u00edveis cr\u00edticas de colegas e '
      'superiores. Demonstrou elevado n\u00edvel de autocr\u00edtica, frequentemente '
      'interpretando pequenos contratempos como indicadores de fracasso '
      'profissional.\n\n'
      'Foi realizado acolhimento da demanda e psicoeduca\u00e7\u00e3o inicial sobre '
      'ansiedade, destacando a rela\u00e7\u00e3o entre pensamentos, emo\u00e7\u00f5es e '
      'comportamentos. A paciente mostrou boa capacidade de reflex\u00e3o e '
      'motiva\u00e7\u00e3o para o processo terap\u00eautico.\n\n'
      'Impress\u00f5es cl\u00ednicas: ansiedade moderada a intensa associada a '
      'estresse ocupacional e padr\u00f5es cognitivos de perfeccionismo.';

  static const String _sessao2 =
      'Linda relatou semana particularmente dif\u00edcil devido ao recebimento '
      'de novas responsabilidades no trabalho. Referiu ter experimentado '
      'intenso desconforto ao receber uma solicita\u00e7\u00e3o de revis\u00e3o por '
      'parte de sua supervisora, interpretando inicialmente a situa\u00e7\u00e3o como '
      'evid\u00eancia de incompet\u00eancia profissional.\n\n'
      'Durante a sess\u00e3o, foram explorados pensamentos autom\u00e1ticos associados '
      'ao epis\u00f3dio. A paciente identificou frases recorrentes como: '
      '"N\u00e3o sou boa o suficiente" e "Vou decepcionar as pessoas". Demonstrou '
      'perceber que tende a assumir conclus\u00f5es negativas antes de avaliar '
      'objetivamente os fatos.\n\n'
      'Foram iniciados exerc\u00edcios de monitoramento dos pensamentos e '
      'reflex\u00e3o sobre evid\u00eancias favor\u00e1veis e desfavor\u00e1veis \u00e0s '
      'interpreta\u00e7\u00f5es autom\u00e1ticas. A paciente participou ativamente e '
      'demonstrou interesse em desenvolver formas mais equilibradas de avaliar '
      'as situa\u00e7\u00f5es.\n\n'
      'Impress\u00f5es cl\u00ednicas: manuten\u00e7\u00e3o da ansiedade por distor\u00e7\u00f5es '
      'cognitivas relacionadas a perfeccionismo, catastrofiza\u00e7\u00e3o e medo de '
      'avalia\u00e7\u00e3o negativa.';

  static const String _sessao3 =
      'Linda relatou ter observado seus pensamentos ao longo da semana, '
      'identificando diversos momentos em que exigiu de si mesma desempenhos '
      'considerados irreais. Reconheceu dificuldade em aceitar erros ou '
      'limita\u00e7\u00f5es, associando frequentemente seu valor pessoal ao '
      'rendimento profissional.\n\n'
      'A sess\u00e3o concentrou-se na explora\u00e7\u00e3o de cren\u00e7as relacionadas '
      '\u00e0 necessidade de aprova\u00e7\u00e3o e ao medo de falhar. A paciente '
      'compartilhou hist\u00f3rico de elevada cobran\u00e7a desde a adolesc\u00eancia, '
      'relatando que sempre buscou atingir padr\u00f5es muito altos em suas '
      'atividades.\n\n'
      'Foi trabalhada a diferencia\u00e7\u00e3o entre desempenho profissional e valor '
      'pessoal. Discutiram-se estrat\u00e9gias para ado\u00e7\u00e3o de expectativas mais '
      'realistas e desenvolvimento gradual de autocompaix\u00e3o. A paciente '
      'demonstrou insight relevante ao reconhecer que costuma ser mais r\u00edgida '
      'consigo mesma do que seria com outras pessoas.\n\n'
      'Impress\u00f5es cl\u00ednicas: amplia\u00e7\u00e3o da consci\u00eancia sobre padr\u00f5es de '
      'autocobran\u00e7a e poss\u00edvel n\u00facleo relacionado \u00e0 necessidade de '
      'valida\u00e7\u00e3o externa.';

  static const String _sessao4 =
      'Linda relatou leve redu\u00e7\u00e3o da intensidade da ansiedade em '
      'compara\u00e7\u00e3o \u00e0s semanas anteriores. Informou ter conseguido '
      'interromper alguns ciclos de preocupa\u00e7\u00e3o ao questionar pensamentos '
      'autom\u00e1ticos e avaliar alternativas mais realistas para situa\u00e7\u00f5es '
      'estressoras no trabalho.\n\n'
      'Descreveu um epis\u00f3dio em que recebeu feedback construtivo de sua '
      'supervisora e conseguiu interpretar a situa\u00e7\u00e3o de maneira mais '
      'equilibrada, sem assumir imediatamente um cen\u00e1rio de fracasso. Referiu '
      'sensa\u00e7\u00e3o de maior controle emocional e percep\u00e7\u00e3o de que nem toda '
      'cr\u00edtica representa desaprova\u00e7\u00e3o pessoal.\n\n'
      'A sess\u00e3o foi dedicada ao fortalecimento de estrat\u00e9gias de '
      'regula\u00e7\u00e3o emocional, identifica\u00e7\u00e3o de sinais precoces de ansiedade '
      'e planejamento de comportamentos de autocuidado. A paciente mostrou-se '
      'engajada e reconheceu os primeiros sinais de progresso desde o in\u00edcio '
      'do acompanhamento.\n\n'
      'Impress\u00f5es cl\u00ednicas: evolu\u00e7\u00e3o inicial positiva, com maior '
      'capacidade de identificar pensamentos ansiog\u00eanicos e responder de '
      'forma mais adaptativa \u00e0s demandas laborais.';
}

class _SessaoDemo {
  final int numero;
  final DateTime data;
  final String transcricao;

  const _SessaoDemo({
    required this.numero,
    required this.data,
    required this.transcricao,
  });
}
