import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/resposta_escala.dart';
import 'encryption_service.dart';

class EscalaService {
  final EncryptionService? _encryption;
  Box get _box => Hive.box('respostas_escalas');

  EscalaService({EncryptionService? encryption}) : _encryption = encryption;

  String _encrypt(String value) {
    if (_encryption == null || value.isEmpty) return value;
    return _encryption.criptografar(value);
  }

  String _decrypt(String value) {
    if (_encryption == null || value.isEmpty) return value;
    return _encryption.descriptografar(value);
  }

  Future<void> salvarResposta(RespostaEscala resposta) async {
    resposta.observacoes = _encrypt(resposta.observacoes);
    if (resposta.id.isEmpty) {
      resposta.id = const Uuid().v4();
    }
    await _box.put(resposta.id, resposta);
  }

  List<RespostaEscala> listarPorPaciente(String pacienteId) {
    final lista = _box.values
        .whereType<RespostaEscala>()
        .where((r) => r.pacienteId == pacienteId)
        .toList();
    for (final r in lista) {
      r.observacoes = _decrypt(r.observacoes);
    }
    lista.sort((a, b) => b.dataAplicacao.compareTo(a.dataAplicacao));
    return lista;
  }

  List<RespostaEscala> listarPorPacienteEEscala(String pacienteId, String escalaId) {
    return _box.values.whereType<RespostaEscala>().where((r) =>
      r.pacienteId == pacienteId && r.escalaId == escalaId,
    ).toList();
  }

  Future<void> remover(String id) async {
    await _box.delete(id);
  }

  Stream<BoxEvent> observar() {
    return _box.watch();
  }

  void removerCriptografiaExistente() {
    if (_encryption == null || !_encryption.configurado) return;
    for (final r in _box.values.whereType<RespostaEscala>()) {
      r.observacoes = _decrypt(r.observacoes);
    }
  }

  /// --- SCALE DEFINITIONS ---

  static const Map<String, Map<String, dynamic>> _escalas = {
    'phq9': {
      'nome': 'PHQ-9 — Questionário de Saúde do Paciente',
      'descricao': 'Avalia a gravidade da depressão nas últimas 2 semanas.',
      'instrucoes': 'Com que frequência você foi incomodado(a) por cada um dos problemas abaixo nas últimas 2 semanas?',
      'faixas': [
        {'min': 0, 'max': 4, 'rotulo': 'Depressão mínima/ausente'},
        {'min': 5, 'max': 9, 'rotulo': 'Depressão leve'},
        {'min': 10, 'max': 14, 'rotulo': 'Depressão moderada'},
        {'min': 15, 'max': 19, 'rotulo': 'Depressão moderadamente grave'},
        {'min': 20, 'max': 27, 'rotulo': 'Depressão grave'},
      ],
      'questoes': [
        'Pouco interesse ou prazer em fazer as coisas',
        'Sentir-se para baixo, deprimido(a) ou sem esperança',
        'Dificuldade para dormir ou sono excessivo',
        'Cansaço ou pouca energia',
        'Falta de apetite ou comer em excesso',
        'Sentir-se mal consigo mesmo(a) — ou achar que é um fracasso',
        'Dificuldade de concentração',
        'Agitação ou lentidão nos movimentos',
        'Pensamentos de que seria melhor estar morto(a) ou de se ferir',
      ],
      'opcoes': ['Nenhuma vez', 'Vários dias', 'Mais da metade dos dias', 'Quase todos os dias'],
    },
    'gad7': {
      'nome': 'GAD-7 — Transtorno de Ansiedade Generalizada',
      'descricao': 'Avalia a gravidade da ansiedade nas últimas 2 semanas.',
      'instrucoes': 'Com que frequência você foi incomodado(a) por cada um dos problemas abaixo nas últimas 2 semanas?',
      'faixas': [
        {'min': 0, 'max': 4, 'rotulo': 'Ansiedade mínima'},
        {'min': 5, 'max': 9, 'rotulo': 'Ansiedade leve'},
        {'min': 10, 'max': 14, 'rotulo': 'Ansiedade moderada'},
        {'min': 15, 'max': 21, 'rotulo': 'Ansiedade grave'},
      ],
      'questoes': [
        'Sentir-se nervoso(a), ansioso(a) ou no limite',
        'Não conseguir parar de se preocupar ou controlar a preocupação',
        'Preocupar-se demais com coisas diferentes',
        'Dificuldade para relaxar',
        'Ficar tão inquieto(a) que é difícil ficar parado(a)',
        'Ficar facilmente irritado(a) ou aborrecido(a)',
        'Sentir medo como se algo terrível fosse acontecer',
      ],
      'opcoes': ['Nenhuma vez', 'Vários dias', 'Mais da metade dos dias', 'Quase todos os dias'],
    },
    'bdi': {
      'nome': 'BDI — Inventário de Depressão de Beck',
      'descricao': 'Avalia a intensidade dos sintomas depressivos.',
      'instrucoes': 'Escolha a afirmação que melhor descreve como você tem se sentido nas últimas 2 semanas, incluindo hoje.',
      'faixas': [
        {'min': 0, 'max': 10, 'rotulo': 'Normal (sem depressão)'},
        {'min': 11, 'max': 19, 'rotulo': 'Depressão leve'},
        {'min': 20, 'max': 30, 'rotulo': 'Depressão moderada'},
        {'min': 31, 'max': 40, 'rotulo': 'Depressão grave'},
        {'min': 41, 'max': 63, 'rotulo': 'Depressão muito grave'},
      ],
      'questoes': [
        'Tristeza',
        'Pessimismo',
        'Sentimento de fracasso',
        'Insatisfação',
        'Culpa',
        'Punição',
        'Autoaversão',
        'Autocrítica',
        'Ideação suicida',
        'Choro',
        'Agitação',
        'Perda de interesse',
        'Indecisão',
        'Desvalorização',
        'Falta de energia',
        'Alteração do sono',
        'Irritabilidade',
        'Alteração do apetite',
        'Dificuldade de concentração',
        'Fadiga',
        'Perda de libido',
      ],
      'opcoes': ['0', '1', '2', '3'],
    },
    'bai': {
      'nome': 'BAI — Inventário de Ansiedade de Beck',
      'descricao': 'Avalia a intensidade dos sintomas de ansiedade na última semana.',
      'instrucoes': 'Indique o quanto cada sintoma abaixo o(a) incomodou durante a última semana, incluindo hoje.',
      'faixas': [
        {'min': 0, 'max': 7, 'rotulo': 'Ansiedade mínima'},
        {'min': 8, 'max': 15, 'rotulo': 'Ansiedade leve'},
        {'min': 16, 'max': 25, 'rotulo': 'Ansiedade moderada'},
        {'min': 26, 'max': 63, 'rotulo': 'Ansiedade grave'},
      ],
      'questoes': [
        'Dormência ou formigamento',
        'Sensação de calor',
        'Tremores nas pernas',
        'Incapacidade de relaxar',
        'Medo que aconteça o pior',
        'Tontura ou atordoamento',
        'Batidas fortes do coração',
        'Falta de equilíbrio',
        'Terror (sensação de pavor)',
        'Nervosismo',
        'Sensação de sufocamento',
        'Tremores nas mãos',
        'Tremores no corpo',
        'Medo de perder o controle',
        'Dificuldade de respirar',
        'Medo de morrer',
        'Assustado(a)',
        'Indigestão ou desconforto abdominal',
        'Sensação de desmaio',
        'Rosto corado ou quente',
        'Suor (não devido ao calor)',
      ],
      'opcoes': ['Absolutamente não', 'Levemente', 'Moderadamente', 'Gravemente'],
    },
    'dass21': {
      'nome': 'DASS-21 — Escala de Depressão, Ansiedade e Estresse',
      'descricao': 'Avalia sintomas de depressão, ansiedade e estresse na última semana.',
      'instrucoes': 'Indique o quanto cada afirmação se aplicou a você durante a última semana.',
      'faixas_depressao': [
        {'min': 0, 'max': 4, 'rotulo': 'Normal'},
        {'min': 5, 'max': 6, 'rotulo': 'Leve'},
        {'min': 7, 'max': 10, 'rotulo': 'Moderada'},
        {'min': 11, 'max': 13, 'rotulo': 'Grave'},
        {'min': 14, 'max': 42, 'rotulo': 'Muito grave'},
      ],
      'faixas_ansiedade': [
        {'min': 0, 'max': 3, 'rotulo': 'Normal'},
        {'min': 4, 'max': 5, 'rotulo': 'Leve'},
        {'min': 6, 'max': 7, 'rotulo': 'Moderada'},
        {'min': 8, 'max': 9, 'rotulo': 'Grave'},
        {'min': 10, 'max': 42, 'rotulo': 'Muito grave'},
      ],
      'faixas_estresse': [
        {'min': 0, 'max': 7, 'rotulo': 'Normal'},
        {'min': 8, 'max': 9, 'rotulo': 'Leve'},
        {'min': 10, 'max': 12, 'rotulo': 'Moderado'},
        {'min': 13, 'max': 16, 'rotulo': 'Grave'},
        {'min': 17, 'max': 42, 'rotulo': 'Muito grave'},
      ],
      'questoes': [
        'Achei difícil me acalmar',
        'Senti minha boca seca',
        'Não consegui sentir nenhum sentimento positivo',
        'Tive dificuldade para respirar (ex: respiração muito rápida, falta de ar sem esforço físico)',
        'Achei difícil tomar iniciativa para fazer as coisas',
        'Tive tendência a reagir exageradamente às situações',
        'Senti tremores (ex: nas mãos)',
        'Senti que estava sempre nervoso(a)',
        'Preocupei-me com situações em que poderia entrar em pânico',
        'Senti que não tinha nada a desejar',
        'Senti-me agitado(a)',
        'Achei difícil relaxar',
        'Senti-me depressivo(a) e sem ânimo',
        'Fui intolerante com coisas que me impediam de continuar o que estava fazendo',
        'Senti que ia entrar em pânico',
        'Não consegui me entusiasmar com nada',
        'Senti que não tinha muito valor como pessoa',
        'Senti que estava muito irritado(a)',
        'Percebi as batidas do meu coração mesmo sem esforço físico',
        'Senti medo sem motivo',
        'Senti que a vida não tinha sentido',
      ],
      'opcoes': ['Não se aplicou', 'Aplicou-se um pouco', 'Aplicou-se bastante', 'Aplicou-se na maior parte do tempo'],
    },
  };

  static Map<String, Map<String, dynamic>> get escalasDisponiveis => _escalas;

  static String interpretar(String escalaId, int pontuacao) {
    final escala = _escalas[escalaId];
    if (escala == null) return '';

    if (escalaId == 'dass21') {
      final dep = _interpretarFaixa(escala['faixas_depressao'] as List, pontuacao);
      return 'DASS-21: $dep';
    }

    return _interpretarFaixa(escala['faixas'] as List, pontuacao);
  }

  static String _interpretarFaixa(List faixas, int pontuacao) {
    for (final faixa in faixas) {
      if (pontuacao >= (faixa['min'] as int) && pontuacao <= (faixa['max'] as int)) {
        return faixa['rotulo'] as String;
      }
    }
    return '';
  }
}
