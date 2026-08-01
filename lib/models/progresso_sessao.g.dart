// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progresso_sessao.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProgressoSessaoAdapter extends TypeAdapter<ProgressoSessao> {
  @override
  final typeId = 12;

  @override
  ProgressoSessao read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProgressoSessao(
      id: fields[0] as String,
      pacienteId: fields[1] as String,
      sessaoId: fields[2] as String,
      numeroSessao: (fields[3] as num).toInt(),
      sintomasJson: fields[4] == null ? '[]' : fields[4] as String,
      metasJson: fields[5] == null ? '[]' : fields[5] as String,
      avaliacaoGeral: fields[6] == null ? '' : fields[6] as String,
      tendencia: fields[7] == null ? 'estavel' : fields[7] as String,
      dataProcessamento: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ProgressoSessao obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.pacienteId)
      ..writeByte(2)
      ..write(obj.sessaoId)
      ..writeByte(3)
      ..write(obj.numeroSessao)
      ..writeByte(4)
      ..write(obj.sintomasJson)
      ..writeByte(5)
      ..write(obj.metasJson)
      ..writeByte(6)
      ..write(obj.avaliacaoGeral)
      ..writeByte(7)
      ..write(obj.tendencia)
      ..writeByte(8)
      ..write(obj.dataProcessamento);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgressoSessaoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
