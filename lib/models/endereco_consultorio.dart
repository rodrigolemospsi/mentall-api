class EnderecoConsultorio {
  String apelido;
  String logradouro;
  String numero;
  String complemento;
  String bairro;
  String cidade;
  String estado;
  String cep;

  EnderecoConsultorio({
    required this.apelido,
    this.logradouro = '',
    this.numero = '',
    this.complemento = '',
    this.bairro = '',
    this.cidade = '',
    this.estado = '',
    this.cep = '',
  });

  String get enderecoResumido {
    final partes = <String>[];
    if (logradouro.trim().isNotEmpty) {
      partes.add(logradouro.trim());
    }
    if (numero.trim().isNotEmpty) {
      partes.add(numero.trim());
    }
    if (bairro.trim().isNotEmpty) {
      partes.add(bairro.trim());
    }
    if (cidade.trim().isNotEmpty) {
      partes.add(cidade.trim());
    }
    if (estado.trim().isNotEmpty) {
      partes.add(estado.trim());
    }
    return partes.join(', ');
  }

  Map<String, dynamic> toJson() {
    return {
      'apelido': apelido,
      'logradouro': logradouro,
      'numero': numero,
      'complemento': complemento,
      'bairro': bairro,
      'cidade': cidade,
      'estado': estado,
      'cep': cep,
    };
  }

  factory EnderecoConsultorio.fromJson(Map<String, dynamic> json) {
    return EnderecoConsultorio(
      apelido: json['apelido'] as String? ?? '',
      logradouro: json['logradouro'] as String? ?? '',
      numero: json['numero'] as String? ?? '',
      complemento: json['complemento'] as String? ?? '',
      bairro: json['bairro'] as String? ?? '',
      cidade: json['cidade'] as String? ?? '',
      estado: json['estado'] as String? ?? '',
      cep: json['cep'] as String? ?? '',
    );
  }

  EnderecoConsultorio copyWith({
    String? apelido,
    String? logradouro,
    String? numero,
    String? complemento,
    String? bairro,
    String? cidade,
    String? estado,
    String? cep,
  }) {
    return EnderecoConsultorio(
      apelido: apelido ?? this.apelido,
      logradouro: logradouro ?? this.logradouro,
      numero: numero ?? this.numero,
      complemento: complemento ?? this.complemento,
      bairro: bairro ?? this.bairro,
      cidade: cidade ?? this.cidade,
      estado: estado ?? this.estado,
      cep: cep ?? this.cep,
    );
  }
}
