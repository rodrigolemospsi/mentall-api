import 'dart:convert';

class AnamneseTemplates {
  AnamneseTemplates._();

  static const Map<String, String> _nomeExibicao = {
    'TCC': 'Terapia Cognitivo-Comportamental',
    'Análise do Comportamento': 'Análise do Comportamento',
    'Psicanálise': 'Psicanálise',
    'Psicodinâmica': 'Psicodinâmica',
    'Humanista': 'Humanista',
    'Fenomenológico-existencial': 'Fenomenológico-existencial',
    'Logoterapia': 'Logoterapia',
    'Gestalt-terapia': 'Gestalt-terapia',
    'Sistêmica': 'Sistêmica',
    'ACT': 'Terapia de Aceitação e Compromisso',
    'DBT': 'Terapia Comportamental Dialética',
    'Terapia do Esquema': 'Terapia do Esquema',
    'Integrativa': 'Integrativa',
    'Outra': 'Outra',
  };

  static String nomeExibicao(String abordagem) =>
      _nomeExibicao[abordagem] ?? abordagem;

  static const String _secaoDadosBasicos = '''
    {
      "titulo": "Dados básicos",
      "descricao": "Apenas o essencial para te conhecermos melhor.",
      "perguntas": [
        {"id": "nome",             "tipo": "text",   "label": "Nome completo",                         "required": true},
        {"id": "nascimento",       "tipo": "date",   "label": "Data de nascimento"},
        {"id": "telefone",         "tipo": "text",   "label": "Telefone"},
        {"id": "email",            "tipo": "text",   "label": "E-mail"},
        {"id": "cidade",           "tipo": "text",   "label": "Cidade"},
        {"id": "como_chamar",      "tipo": "text",   "label": "Como prefere ser chamado(a)?"}
      ]
    }''';

  static const String _secaoMotivoProcura = '''
    {
      "titulo": "Motivo da procura",
      "perguntas": [
        {"id": "motivos",         "tipo": "checklist", "label": "O que te trouxe à terapia?", "required": true,
         "opcoes": ["Ansiedade", "Tristeza", "Estresse", "Relacionamentos", "Trabalho/estudos", "Autoestima", "Luto", "Trauma", "Outro"]},
        {"id": "motivo_aberto",   "tipo": "textarea",  "label": "Com suas palavras, o que fez você procurar terapia agora?"}
      ]
    }''';

  static const String _secaoIntensidade = '''
    {
      "titulo": "Intensidade e impacto",
      "perguntas": [
        {"id": "sofrimento",      "tipo": "scale",  "label": "Nível de sofrimento atual",   "min": 0, "max": 10,
         "minLabel": "Nenhum", "maxLabel": "Muito intenso"},
        {"id": "frequencia",      "tipo": "radio",  "label": "Frequência do problema",
         "opcoes": ["Raramente", "Às vezes", "Frequentemente", "Todos os dias"]},
        {"id": "afeta_rotina",    "tipo": "scale",  "label": "Quanto afeta sua rotina diária?", "min": 0, "max": 10,
         "minLabel": "Não afeta", "maxLabel": "Afeta totalmente"},
        {"id": "afeta_relacoes",  "tipo": "scale",  "label": "Quanto afeta seus relacionamentos?", "min": 0, "max": 10,
         "minLabel": "Não afeta", "maxLabel": "Afeta totalmente"},
        {"id": "afeta_trabalho",  "tipo": "scale",  "label": "Quanto afeta seu trabalho/estudos?", "min": 0, "max": 10,
         "minLabel": "Não afeta", "maxLabel": "Afeta totalmente"}
      ]
    }''';

  static const String _secaoSaudeHistorico = '''
    {
      "titulo": "Saúde e histórico",
      "descricao": "Informações importantes para o cuidado.",
      "perguntas": [
        {"id": "fez_terapia",       "tipo": "yesno", "label": "Já fez terapia antes?"},
        {"id": "foi_psiquiatra",    "tipo": "yesno", "label": "Já consultou um psiquiatra?"},
        {"id": "usa_medicacao",     "tipo": "yesno", "label": "Usa medicação atualmente?",
         "condicional_sim": {"id": "usa_medicacao_quais", "tipo": "text", "label": "Quais?"}},
        {"id": "tem_diagnostico",   "tipo": "yesno", "label": "Tem algum diagnóstico anterior?",
         "condicional_sim": {"id": "tem_diagnostico_qual", "tipo": "text", "label": "Qual?"}},
        {"id": "sono",              "tipo": "radio", "label": "Como está seu sono?",
         "opcoes": ["Durmo bem", "Às vezes tenho dificuldade", "Insônia frequente", "Durmo muito", "Quase não durmo"]},
        {"id": "substancias",       "tipo": "yesno", "label": "Usa álcool ou outras substâncias com frequência?",
         "condicional_sim": {"id": "substancias_quais", "tipo": "text", "label": "Quais?"}}
      ]
    }''';

  static const String _secaoSegurancaEmocional = '''
    {
      "titulo": "Segurança emocional",
      "descricao": "Perguntas importantes para o seu cuidado. Por favor, responda com sinceridade.",
      "destaque": true,
      "perguntas": [
        {"id": "pensou_morte",    "tipo": "yesno", "label": "Teve pensamentos de não querer viver nas últimas semanas?", "required": true},
        {"id": "pensou_machucar", "tipo": "yesno", "label": "Pensou em se machucar nas últimas semanas?",               "required": true},
        {"id": "esta_seguro",     "tipo": "yesno", "label": "Neste momento, você está em um lugar seguro?",            "required": true}
      ]
    }''';

  static const String _secaoObjetivos = '''
    {
      "titulo": "Objetivos da terapia",
      "perguntas": [
        {"id": "objetivos",      "tipo": "checklist", "label": "O que você espera alcançar com a terapia?",
         "opcoes": ["Reduzir ansiedade", "Melhorar autoestima", "Organizar a rotina", "Melhorar relacionamentos", "Lidar melhor com pensamentos", "Regular emoções", "Superar uma situação difícil", "Me conhecer melhor", "Outro"]}
      ]
    }''';

  static String _montarTemplate(String secaoEspecifica) {
    final json = {
      'secoes': [
        jsonDecode(_secaoDadosBasicos),
        jsonDecode(_secaoMotivoProcura),
        jsonDecode(_secaoIntensidade),
        jsonDecode(_secaoSaudeHistorico),
        jsonDecode(secaoEspecifica),
        jsonDecode(_secaoSegurancaEmocional),
        jsonDecode(_secaoObjetivos),
      ],
    };
    return jsonEncode(json);
  }

  static const String _secaoEspecificaTCC = '''
    {
      "titulo": "Bloco específico — TCC",
      "descricao": "Perguntas para entender melhor seus pensamentos, emoções e comportamentos.",
      "perguntas": [
        {"id": "situacoes_pioram",   "tipo": "textarea", "label": "Que situações costumam piorar o que você está sentindo?"},
        {"id": "pensamentos",        "tipo": "textarea", "label": "Que pensamentos costumam aparecer nessas situações?"},
        {"id": "emocoes_frequentes", "tipo": "textarea", "label": "Quais emoções você sente com mais frequência?"},
        {"id": "quando_mal",         "tipo": "textarea", "label": "O que costuma fazer quando se sente mal?"},
        {"id": "evita",              "tipo": "yesno",    "label": "Você evita situações por medo ou desconforto?"},
        {"id": "busca_confirmacao",  "tipo": "yesno",    "label": "Busca aprovação ou confirmação dos outros com frequência?"},
        {"id": "se_cobra",           "tipo": "yesno",    "label": "Você se cobra demais?"},
        {"id": "o_que_mudar",        "tipo": "textarea", "label": "O que você mais gostaria de mudar em como se sente?"}
      ]
    }''';

  static String tcc() => _montarTemplate(_secaoEspecificaTCC);

  static String paraAbordagem(String abordagem) {
    switch (abordagem) {
      case 'TCC':
        return tcc();
      default:
        return tcc();
    }
  }

  static String templatePadrao(String abordagem) {
    return paraAbordagem(abordagem);
  }
}
