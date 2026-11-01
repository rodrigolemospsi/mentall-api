import 'dart:convert';

import 'package:hive_ce/hive.dart';

part 'anamnese_enviada.g.dart';

@HiveType(typeId: 8)
class AnamneseEnviada extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String pacienteId;

  @HiveField(2)
  String token;

  @HiveField(3)
  String abordagem;

  @HiveField(4)
  String status;

  @HiveField(5)
  String url;

  @HiveField(6)
  String respostasJson;

  @HiveField(7)
  DateTime dataCriacao;

  @HiveField(8)
  DateTime? dataEnvio;

  @HiveField(9)
  DateTime? dataResposta;

  /// Chave AES-256-GCM da ficha em base64url (criptografia ponta-a-ponta).
  /// Persistida cifrada pelo [EncryptionService]; nunca vai ao servidor.
  @HiveField(10, defaultValue: '')
  String chaveCripto;

  /// Ficha criada com criptografia ponta-a-ponta (servidor só guarda o
  /// envelope cifrado). Fichas antigas ficam `false` para compatibilidade.
  @HiveField(11, defaultValue: false)
  bool e2e;

  /// Resposta chegou cifrada, mas não foi possível decifrar neste aparelho
  /// (chave ausente/corrompida). A UI avisa o profissional em vez de exibir
  /// respostas vazias silenciosamente.
  @HiveField(12, defaultValue: false)
  bool falhaDecifrar;

  AnamneseEnviada({
    required this.id,
    required this.pacienteId,
    required this.token,
    required this.abordagem,
    required this.status,
    required this.url,
    this.respostasJson = '',
    required this.dataCriacao,
    this.dataEnvio,
    this.dataResposta,
    this.chaveCripto = '',
    this.e2e = false,
    this.falhaDecifrar = false,
  });

  /// Link a ser enviado ao paciente. Em fichas E2E inclui a chave no
  /// fragmento (`#k=...`), que o navegador não transmite ao servidor.
  String get urlComChave =>
      temChaveE2e ? '$url#k=$chaveCripto' : url;

  bool get temChaveE2e => e2e && chaveCripto.isNotEmpty;

  bool get isPendente => status == 'pendente';
  bool get isEnviado => status == 'enviado';
  bool get isRespondido => status == 'respondido';

  Map<String, dynamic> get respostas {
    if (respostasJson.isEmpty) return {};
    try {
      return jsonDecode(respostasJson) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  AnamneseEnviada copyWith({
    String? id,
    String? pacienteId,
    String? token,
    String? abordagem,
    String? status,
    String? url,
    String? respostasJson,
    DateTime? dataCriacao,
    DateTime? dataEnvio,
    DateTime? dataResposta,
    String? chaveCripto,
    bool? e2e,
    bool? falhaDecifrar,
  }) {
    return AnamneseEnviada(
      id: id ?? this.id,
      pacienteId: pacienteId ?? this.pacienteId,
      token: token ?? this.token,
      abordagem: abordagem ?? this.abordagem,
      status: status ?? this.status,
      url: url ?? this.url,
      respostasJson: respostasJson ?? this.respostasJson,
      dataCriacao: dataCriacao ?? this.dataCriacao,
      dataEnvio: dataEnvio ?? this.dataEnvio,
      dataResposta: dataResposta ?? this.dataResposta,
      chaveCripto: chaveCripto ?? this.chaveCripto,
      e2e: e2e ?? this.e2e,
      falhaDecifrar: falhaDecifrar ?? this.falhaDecifrar,
    );
  }
}