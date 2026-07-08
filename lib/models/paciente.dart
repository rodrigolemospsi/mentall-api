import 'package:hive_ce/hive.dart';

part 'paciente.g.dart';

@HiveType(typeId: 1)
class Paciente extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String nome;

  @HiveField(2)
  DateTime? dataNascimento;

  @HiveField(3)
  String contato;

  @HiveField(4)
  String tipoAtendimento;

  @HiveField(5)
  String observacoes;

  @HiveField(6)
  bool ativo;

  @HiveField(7)
  DateTime dataCadastro;

  @HiveField(8)
  String email;

  @HiveField(9)
  DateTime? dataAtualizacao;

  Paciente({
    required this.id,
    required this.nome,
    this.dataNascimento,
    this.contato = '',
    this.email = '',
    this.tipoAtendimento = 'Particular',
    this.observacoes = '',
    this.ativo = true,
    DateTime? dataCadastro,
    this.dataAtualizacao,
  }) : dataCadastro = dataCadastro ?? DateTime.now();

  static const String tipoAtendimentoPadrao = 'Particular';

  static const List<String> tiposAtendimentoDisponiveis = [
    'Particular',
    'Convênio',
    'Social',
    'Online',
    'Presencial',
    'Híbrido',
    'Outro',
  ];

  bool get possuiEmail {
    return email.trim().isNotEmpty;
  }

  bool get possuiContato {
    return contato.trim().isNotEmpty;
  }

  bool get possuiObservacoes {
    return observacoes.trim().isNotEmpty;
  }

  bool get possuiDataNascimento {
    return dataNascimento != null;
  }

  bool get estaAtivo {
    return ativo;
  }

  bool get estaArquivado {
    return !ativo;
  }

  String get nomeExibicao {
    final nomeLimpo = nome.trim();

    if (nomeLimpo.isEmpty) {
      return 'Sem nome';
    }

    return nomeLimpo;
  }

  String get contatoExibicao {
    final contatoLimpo = contato.trim();

    if (contatoLimpo.isEmpty) {
      return 'Contato não informado';
    }

    return contatoLimpo;
  }

  String get tipoAtendimentoExibicao {
    final tipoLimpo = tipoAtendimento.trim();

    if (tipoLimpo.isEmpty) {
      return tipoAtendimentoPadrao;
    }

    return tipoLimpo;
  }

  String get observacoesExibicao {
    final observacoesLimpas = observacoes.trim();

    if (observacoesLimpas.isEmpty) {
      return 'Nenhuma observação registrada.';
    }

    return observacoesLimpas;
  }

  String get inicial {
    final nomeLimpo = nome.trim();

    if (nomeLimpo.isEmpty) {
      return '?';
    }

    return nomeLimpo[0].toUpperCase();
  }

  int? get idade {
    if (dataNascimento == null) {
      return null;
    }

    final hoje = DateTime.now();

    int idadeCalculada = hoje.year - dataNascimento!.year;

    final aindaNaoFezAniversarioEsteAno =
        hoje.month < dataNascimento!.month ||
            (hoje.month == dataNascimento!.month &&
                hoje.day < dataNascimento!.day);

    if (aindaNaoFezAniversarioEsteAno) {
      idadeCalculada--;
    }

    return idadeCalculada;
  }

  String get idadeExibicao {
    final idadeCalculada = idade;

    if (idadeCalculada == null) {
      return 'Idade não informada';
    }

    if (idadeCalculada == 1) {
      return '1 ano';
    }

    return '$idadeCalculada anos';
  }

  Paciente arquivar() {
    return copyWith(ativo: false);
  }

  Paciente restaurar() {
    return copyWith(ativo: true);
  }

  Paciente copyWith({
    String? id,
    String? nome,
    DateTime? dataNascimento,
    bool limparDataNascimento = false,
    String? contato,
    String? email,
    String? tipoAtendimento,
    String? observacoes,
    bool? ativo,
    DateTime? dataCadastro,
    DateTime? dataAtualizacao,
  }) {
    return Paciente(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      dataNascimento: limparDataNascimento
          ? null
          : dataNascimento ?? this.dataNascimento,
      contato: contato ?? this.contato,
      email: email ?? this.email,
      tipoAtendimento: tipoAtendimento ?? this.tipoAtendimento,
      observacoes: observacoes ?? this.observacoes,
      ativo: ativo ?? this.ativo,
      dataCadastro: dataCadastro ?? this.dataCadastro,
      dataAtualizacao: dataAtualizacao ?? this.dataAtualizacao,
    );
  }
}