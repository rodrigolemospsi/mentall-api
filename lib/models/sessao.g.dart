// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sessao.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SessaoAdapter extends TypeAdapter<Sessao> {
  @override
  final typeId = 2;

  @override
  Sessao read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Sessao(
      id: fields[0] as String,
      pacienteId: fields[1] as String,
      numeroSessao: (fields[2] as num).toInt(),
      data: fields[3] as DateTime,
      humor: fields[4] == null ? 5 : (fields[4] as num).toInt(),
      temaPrincipal: fields[5] == null ? '' : fields[5] as String,
      eventosImportantes: fields[6] == null ? '' : fields[6] as String,
      pensamentosAutomaticos: fields[7] == null ? '' : fields[7] as String,
      emocoes: fields[8] == null ? '' : fields[8] as String,
      comportamentos: fields[9] == null ? '' : fields[9] as String,
      intervencoes: fields[10] == null ? '' : fields[10] as String,
      tecnicasTcc: fields[11] == null ? '' : fields[11] as String,
      tarefaCasa: fields[12] == null ? '' : fields[12] as String,
      evolucaoClinica: fields[13] == null ? '' : fields[13] as String,
      planoProximaSessao: fields[14] == null ? '' : fields[14] as String,
      observacoes: fields[15] == null ? '' : fields[15] as String,
      relatoPosSessao: fields[16] == null ? '' : fields[16] as String,
      apontamentosCopiloto: fields[17] == null ? '' : fields[17] as String,
      arquivada: fields[18] == null ? false : fields[18] as bool,
      audioRelatoPath: fields[19] == null ? '' : fields[19] as String,
      transcricaoRelato: fields[20] == null ? '' : fields[20] as String,
      transcricaoRevisada: fields[29] == null ? '' : fields[29] as String,
      dataProcessamentoIa: fields[21] as DateTime?,
      geradoComIa: fields[22] == null ? false : fields[22] as bool,
      statusProcessamento: fields[23] == null ? 'manual' : fields[23] as String,
      audioMantido: fields[24] == null ? false : fields[24] as bool,
      revisadoPeloProfissional: fields[25] == null ? false : fields[25] as bool,
      erroProcessamentoIa: fields[26] == null ? '' : fields[26] as String,
      origemRelato: fields[27] == null ? 'manual' : fields[27] as String,
      audioRelatoBase64: fields[28] == null ? '' : fields[28] as String,
      artigosSugeridos: fields[30] == null ? '' : fields[30] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Sessao obj) {
    writer
      ..writeByte(31)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.pacienteId)
      ..writeByte(2)
      ..write(obj.numeroSessao)
      ..writeByte(3)
      ..write(obj.data)
      ..writeByte(4)
      ..write(obj.humor)
      ..writeByte(5)
      ..write(obj.temaPrincipal)
      ..writeByte(6)
      ..write(obj.eventosImportantes)
      ..writeByte(7)
      ..write(obj.pensamentosAutomaticos)
      ..writeByte(8)
      ..write(obj.emocoes)
      ..writeByte(9)
      ..write(obj.comportamentos)
      ..writeByte(10)
      ..write(obj.intervencoes)
      ..writeByte(11)
      ..write(obj.tecnicasTcc)
      ..writeByte(12)
      ..write(obj.tarefaCasa)
      ..writeByte(13)
      ..write(obj.evolucaoClinica)
      ..writeByte(14)
      ..write(obj.planoProximaSessao)
      ..writeByte(15)
      ..write(obj.observacoes)
      ..writeByte(16)
      ..write(obj.relatoPosSessao)
      ..writeByte(17)
      ..write(obj.apontamentosCopiloto)
      ..writeByte(18)
      ..write(obj.arquivada)
      ..writeByte(19)
      ..write(obj.audioRelatoPath)
      ..writeByte(20)
      ..write(obj.transcricaoRelato)
      ..writeByte(21)
      ..write(obj.dataProcessamentoIa)
      ..writeByte(22)
      ..write(obj.geradoComIa)
      ..writeByte(23)
      ..write(obj.statusProcessamento)
      ..writeByte(24)
      ..write(obj.audioMantido)
      ..writeByte(25)
      ..write(obj.revisadoPeloProfissional)
      ..writeByte(26)
      ..write(obj.erroProcessamentoIa)
      ..writeByte(27)
      ..write(obj.origemRelato)
      ..writeByte(28)
      ..write(obj.audioRelatoBase64)
      ..writeByte(29)
      ..write(obj.transcricaoRevisada)
      ..writeByte(30)
      ..write(obj.artigosSugeridos);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessaoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
