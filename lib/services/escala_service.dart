import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/resposta_escala.dart';
import 'encrypted_service_mixin.dart';
import 'encryption_service.dart';

class EscalaService with EncryptedServiceMixin {
  @override
  final EncryptionService? encryption;
  Box get _box => Hive.box('respostas_escalas');

  EscalaService({EncryptionService? encryption}) : encryption = encryption;

  String _encrypt(String value) => encrypt(value);
  String _decrypt(String value) => decrypt(value);

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
    final lista = _box.values.whereType<RespostaEscala>().where((r) =>
      r.pacienteId == pacienteId && r.escalaId == escalaId,
    ).toList();
    for (final r in lista) {
      r.observacoes = _decrypt(r.observacoes);
    }
    return lista;
  }

  Future<void> remover(String id) async {
    await _box.delete(id);
  }

  Stream<BoxEvent> observar() {
    return _box.watch();
  }

  Future<void> removerCriptografiaExistente() async {
    final enc = encryption; if (enc == null || !enc.configurado) return;
    for (final r in _box.values.whereType<RespostaEscala>()) {
      r.observacoes = _decrypt(r.observacoes);
      await r.save();
    }
  }

  static const Map<String, Map<String, dynamic>> _escalas = {
    'phq9': {
      'nome': 'PHQ-9 \u2014 Question\u00e1rio de Sa\u00fade do Paciente',
      'descricao': 'Avalia a gravidade da depress\u00e3o nas \u00faltimas 2 semanas.',
      'instrucoes': 'Com que frequ\u00eancia voc\u00ea foi incomodado(a) por cada um dos problemas abaixo nas \u00faltimas 2 semanas?',
      'faixas': [
        {'min': 0, 'max': 4, 'rotulo': 'Depress\u00e3o m\u00ednima/ausente'},
        {'min': 5, 'max': 9, 'rotulo': 'Depress\u00e3o leve'},
        {'min': 10, 'max': 14, 'rotulo': 'Depress\u00e3o moderada'},
        {'min': 15, 'max': 19, 'rotulo': 'Depress\u00e3o moderadamente grave'},
        {'min': 20, 'max': 27, 'rotulo': 'Depress\u00e3o grave'},
      ],
      'questoes': [
        'Pouco interesse ou prazer em fazer as coisas',
        'Sentir-se para baixo, deprimido(a) ou sem esperan\u00e7a',
        'Dificuldade para dormir ou sono excessivo',
        'Cansa\u00e7o ou pouca energia',
        'Falta de apetite ou comer em excesso',
        'Sentir-se mal consigo mesmo(a) \u2014 ou achar que \u00e9 um fracasso',
        'Dificuldade de concentra\u00e7\u00e3o',
        'Agita\u00e7\u00e3o ou lentid\u00e3o nos movimentos',
        'Pensamentos de que seria melhor estar morto(a) ou de se ferir',
      ],
      'opcoes': ['Nenhuma vez', 'V\u00e1rios dias', 'Mais da metade dos dias', 'Quase todos os dias'],
    },
    'gad7': {
      'nome': 'GAD-7 \u2014 Transtorno de Ansiedade Generalizada',
      'descricao': 'Avalia a gravidade da ansiedade nas \u00faltimas 2 semanas.',
      'instrucoes': 'Com que frequ\u00eancia voc\u00ea foi incomodado(a) por cada um dos problemas abaixo nas \u00faltimas 2 semanas?',
      'faixas': [
        {'min': 0, 'max': 4, 'rotulo': 'Ansiedade m\u00ednima'},
        {'min': 5, 'max': 9, 'rotulo': 'Ansiedade leve'},
        {'min': 10, 'max': 14, 'rotulo': 'Ansiedade moderada'},
        {'min': 15, 'max': 21, 'rotulo': 'Ansiedade grave'},
      ],
      'questoes': [
        'Sentir-se nervoso(a), ansioso(a) ou no limite',
        'N\u00e3o conseguir parar de se preocupar ou controlar a preocupa\u00e7\u00e3o',
        'Preocupar-se demais com coisas diferentes',
        'Dificuldade para relaxar',
        'Ficar t\u00e3o inquieto(a) que \u00e9 dif\u00edcil ficar parado(a)',
        'Ficar facilmente irritado(a) ou aborrecido(a)',
        'Sentir medo como se algo terr\u00edvel fosse acontecer',
      ],
      'opcoes': ['Nenhuma vez', 'V\u00e1rios dias', 'Mais da metade dos dias', 'Quase todos os dias'],
    },
    'dass21': {
      'nome': 'DASS-21 \u2014 Escala de Depress\u00e3o, Ansiedade e Estresse',
      'descricao': 'Avalia sintomas de depress\u00e3o, ansiedade e estresse na \u00faltima semana.',
      'instrucoes': 'Indique o quanto cada afirma\u00e7\u00e3o se aplicou a voc\u00ea durante a \u00faltima semana.',
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
        'Achei dif\u00edcil me acalmar',
        'Senti minha boca seca',
        'N\u00e3o consegui sentir nenhum sentimento positivo',
        'Tive dificuldade para respirar (ex: respira\u00e7\u00e3o muito r\u00e1pida, falta de ar sem esfor\u00e7o f\u00edsico)',
        'Achei dif\u00edcil tomar iniciativa para fazer as coisas',
        'Tive tend\u00eancia a reagir exageradamente \u00e0s situa\u00e7\u00f5es',
        'Senti tremores (ex: nas m\u00e3os)',
        'Senti que estava sempre nervoso(a)',
        'Preocupei-me com situa\u00e7\u00f5es em que poderia entrar em p\u00e2nico',
        'Senti que n\u00e3o tinha nada a desejar',
        'Senti-me agitado(a)',
        'Achei dif\u00edcil relaxar',
        'Senti-me depressivo(a) e sem \u00e2nimo',
        'Fui intolerante com coisas que me impediam de continuar o que estava fazendo',
        'Senti que ia entrar em p\u00e2nico',
        'N\u00e3o consegui me entusiasmar com nada',
        'Senti que n\u00e3o tinha muito valor como pessoa',
        'Senti que estava muito irritado(a)',
        'Percebi as batidas do meu cora\u00e7\u00e3o mesmo sem esfor\u00e7o f\u00edsico',
        'Senti medo sem motivo',
        'Senti que a vida n\u00e3o tinha sentido',
      ],
      'opcoes': ['N\u00e3o se aplicou', 'Aplicou-se um pouco', 'Aplicou-se bastante', 'Aplicou-se na maior parte do tempo'],
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
