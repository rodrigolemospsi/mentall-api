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
  });

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
    );
  }
}