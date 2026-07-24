enum AbordagemClinica {
  tcc('TCC'),
  analiseDoComportamento('Análise do Comportamento'),
  psicanalise('Psicanálise'),
  psicodinamica('Psicodinâmica'),
  humanista('Humanista'),
  fenomenologicoExistencial('Fenomenológico-existencial'),
  logoterapia('Logoterapia'),
  gestaltTerapia('Gestalt-terapia'),
  sistemica('Sistêmica'),
  act('ACT'),
  dbt('DBT'),
  terapiaDoEsquema('Terapia do Esquema'),
  integrativa('Integrativa'),
  outra('Outra');

  final String value;
  const AbordagemClinica(this.value);

  static AbordagemClinica fromString(String s) {
    final normalizada = s.trim();
    return AbordagemClinica.values.firstWhere(
      (a) => a.value == normalizada,
      orElse: () => AbordagemClinica.integrativa,
    );
  }

  static const List<AbordagemClinica> disponiveis = AbordagemClinica.values;
}

enum TermoPessoaAtendida {
  paciente('paciente'),
  cliente('cliente'),
  pessoaAtendida('pessoa atendida');

  final String value;
  const TermoPessoaAtendida(this.value);

  static TermoPessoaAtendida fromString(String s) {
    final normalizada = s.trim().toLowerCase();
    return TermoPessoaAtendida.values.firstWhere(
      (t) => t.value == normalizada,
      orElse: () => TermoPessoaAtendida.paciente,
    );
  }

  static const List<TermoPessoaAtendida> disponiveis =
      TermoPessoaAtendida.values;

  String get termoPlural {
    switch (this) {
      case TermoPessoaAtendida.cliente:
        return 'clientes';
      case TermoPessoaAtendida.pessoaAtendida:
        return 'pessoas atendidas';
      case TermoPessoaAtendida.paciente:
        return 'pacientes';
    }
  }

  String get artigoDefinidoSingular {
    switch (this) {
      case TermoPessoaAtendida.pessoaAtendida:
        return 'a';
      case TermoPessoaAtendida.cliente:
      case TermoPessoaAtendida.paciente:
        return 'o';
    }
  }

  String get artigoDefinidoPlural {
    switch (this) {
      case TermoPessoaAtendida.pessoaAtendida:
        return 'as';
      case TermoPessoaAtendida.cliente:
      case TermoPessoaAtendida.paciente:
        return 'os';
    }
  }

  String get artigoIndefinidoSingular {
    switch (this) {
      case TermoPessoaAtendida.pessoaAtendida:
        return 'uma';
      case TermoPessoaAtendida.cliente:
      case TermoPessoaAtendida.paciente:
        return 'um';
    }
  }
}

enum StatusProcessamento {
  manual('manual'),
  audioGravado('audio_gravado'),
  transcrevendo('transcrevendo'),
  transcrito('transcrito'),
  iaProcessando('ia_processando'),
  iaProcessada('ia_processada'),
  revisado('revisado'),
  erro('erro');

  final String value;
  const StatusProcessamento(this.value);

  static StatusProcessamento fromString(String s) {
    return StatusProcessamento.values.firstWhere(
      (sp) => sp.value == s,
      orElse: () => StatusProcessamento.manual,
    );
  }

  bool get estaAguardandoRevisao {
    return this == StatusProcessamento.audioGravado ||
        this == StatusProcessamento.transcrevendo ||
        this == StatusProcessamento.transcrito ||
        this == StatusProcessamento.iaProcessando ||
        this == StatusProcessamento.iaProcessada;
  }

  bool get processamentoConcluido => this == StatusProcessamento.revisado;
}

enum StatusCompromisso {
  agendado('agendado'),
  realizado('realizado'),
  cancelado('cancelado'),
  faltou('faltou');

  final String value;
  const StatusCompromisso(this.value);

  static StatusCompromisso fromString(String s) {
    return StatusCompromisso.values.firstWhere(
      (sc) => sc.value == s,
      orElse: () => StatusCompromisso.agendado,
    );
  }
}

enum FrequenciaRecorrencia {
  nenhuma(''),
  semanal('Toda semana'),
  quinzenal('A cada 2 semanas'),
  mensal('Todo mes');

  final String value;
  const FrequenciaRecorrencia(this.value);

  static FrequenciaRecorrencia fromString(String s) {
    return FrequenciaRecorrencia.values.firstWhere(
      (f) => f.value == s || (f.value.isEmpty && s.isEmpty),
      orElse: () => FrequenciaRecorrencia.nenhuma,
    );
  }

  bool get temRecorrencia => this != FrequenciaRecorrencia.nenhuma;
}

enum OrigemRelato {
  manual('manual'),
  audio('audio'),
  transcricao('transcricao'),
  ia('ia'),
  misto('misto'),
  importado('importado');

  final String value;
  const OrigemRelato(this.value);

  static OrigemRelato fromString(String s) {
    return OrigemRelato.values.firstWhere(
      (o) => o.value == s,
      orElse: () => OrigemRelato.manual,
    );
  }
}
