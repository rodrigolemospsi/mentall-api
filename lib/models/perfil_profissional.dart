import 'package:hive_ce/hive.dart';

import 'enums.dart';

part 'perfil_profissional.g.dart';

@HiveType(typeId: 3)
class PerfilProfissional extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String nome;

  @HiveField(2)
  String registroProfissional;

  @HiveField(3)
  String abordagemClinica;

  @HiveField(4)
  String termoPessoaAtendida;

  @HiveField(5)
  DateTime dataCriacao;

  PerfilProfissional({
    required this.id,
    required this.nome,
    this.registroProfissional = '',
    this.abordagemClinica = 'Integrativa',
    this.termoPessoaAtendida = 'paciente',
    DateTime? dataCriacao,
  }) : dataCriacao = dataCriacao ?? DateTime.now();

  static const String abordagemClinicaPadrao = 'Integrativa';
  static const String termoPessoaAtendidaPadrao = 'paciente';

  static const List<AbordagemClinica> abordagensDisponiveis =
      AbordagemClinica.disponiveis;

  static const List<TermoPessoaAtendida> termosPessoaAtendidaDisponiveis =
      TermoPessoaAtendida.disponiveis;

  AbordagemClinica get abordagemClinicaEnum =>
      AbordagemClinica.fromString(abordagemClinica);

  set abordagemClinicaEnum(AbordagemClinica v) => abordagemClinica = v.value;

  TermoPessoaAtendida get termoPessoaAtendidaEnum =>
      TermoPessoaAtendida.fromString(termoPessoaAtendida);

  set termoPessoaAtendidaEnum(TermoPessoaAtendida v) =>
      termoPessoaAtendida = v.value;

  bool get possuiRegistroProfissional {
    return registroProfissional.trim().isNotEmpty;
  }

  String get nomeExibicao {
    final nomeLimpo = nome.trim();

    if (nomeLimpo.isEmpty) {
      return 'Profissional';
    }

    return nomeLimpo;
  }

  AbordagemClinica get abordagemClinicaNormalizada =>
      AbordagemClinica.fromString(abordagemClinica);

  bool get usaAbordagemTcc =>
      abordagemClinicaNormalizada == AbordagemClinica.tcc;

  bool get usaLogoterapia =>
      abordagemClinicaNormalizada == AbordagemClinica.logoterapia;

  bool get usaAbordagemIntegrativa =>
      abordagemClinicaNormalizada == AbordagemClinica.integrativa;

  String get termoSingular => termoPessoaAtendidaEnum.value;

  String get termoSingularCapitalizado =>
      _capitalizarPrimeiraLetra(termoSingular);

  String get termoPlural => termoPessoaAtendidaEnum.termoPlural;

  String get termoPluralCapitalizado =>
      _capitalizarPrimeiraLetra(termoPlural);

  String get artigoDefinidoSingular =>
      termoPessoaAtendidaEnum.artigoDefinidoSingular;

  String get artigoDefinidoPlural =>
      termoPessoaAtendidaEnum.artigoDefinidoPlural;

  String get artigoIndefinidoSingular =>
      termoPessoaAtendidaEnum.artigoIndefinidoSingular;

  String get novoRegistroLabel {
    return 'Novo $termoSingular';
  }

  String get novoRegistroLabelCapitalizado {
    return 'Novo $termoSingular';
  }

  String get editarRegistroLabel {
    return 'Editar $termoSingular';
  }

  String get listaRegistrosTitulo {
    return termoPluralCapitalizado;
  }

  String get dadosRegistroTitulo {
    return 'Dados do $termoSingular';
  }

  String get dadosRegistroTituloComArtigo {
    return 'Dados d$artigoDefinidoSingular $termoSingular';
  }

  String get historicoRegistroTitulo {
    return 'Histórico do $termoSingular';
  }

  String get historicoRegistroTituloComArtigo {
    return 'Histórico d$artigoDefinidoSingular $termoSingular';
  }

  String get sessoesRegistroTitulo {
    return 'Sessões do $termoSingular';
  }

  String get sessoesRegistroTituloComArtigo {
    return 'Sessões d$artigoDefinidoSingular $termoSingular';
  }

  String get nenhumaPessoaCadastradaMensagem {
    switch (termoPessoaAtendidaEnum) {
      case TermoPessoaAtendida.cliente:
        return 'Nenhum cliente cadastrado ainda.';
      case TermoPessoaAtendida.pessoaAtendida:
        return 'Nenhuma pessoa atendida cadastrada ainda.';
      case TermoPessoaAtendida.paciente:
        return 'Nenhum paciente cadastrado ainda.';
    }
  }

  String get buscarPessoaHint {
    return 'Buscar $termoSingular';
  }

  String get nomePessoaLabel {
    return 'Nome do $termoSingular';
  }

  String get nomePessoaLabelComArtigo {
    return 'Nome d$artigoDefinidoSingular $termoSingular';
  }

  String get confirmarArquivamentoSessaoMensagem {
    return 'Deseja arquivar esta sessão? Ela poderá ser restaurada posteriormente.';
  }

  String get sessaoArquivadaMensagem {
    return 'Sessão arquivada com sucesso.';
  }

  String get sessaoRestauradaMensagem {
    return 'Sessão restaurada com sucesso.';
  }

  String get sessoesArquivadasTitulo {
    return 'Sessões arquivadas';
  }

  String get nenhumaSessaoArquivadaMensagem {
    return 'Nenhuma sessão arquivada.';
  }

  PerfilProfissional copyWith({
    String? id,
    String? nome,
    String? registroProfissional,
    String? abordagemClinica,
    String? termoPessoaAtendida,
    DateTime? dataCriacao,
  }) {
    return PerfilProfissional(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      registroProfissional: registroProfissional ?? this.registroProfissional,
      abordagemClinica: abordagemClinica ?? this.abordagemClinica,
      termoPessoaAtendida: termoPessoaAtendida ?? this.termoPessoaAtendida,
      dataCriacao: dataCriacao ?? this.dataCriacao,
    );
  }

  static String _capitalizarPrimeiraLetra(String texto) {
    final textoLimpo = texto.trim();

    if (textoLimpo.isEmpty) {
      return '';
    }

    return textoLimpo[0].toUpperCase() + textoLimpo.substring(1);
  }
}