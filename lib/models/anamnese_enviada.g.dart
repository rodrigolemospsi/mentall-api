// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'anamnese_enviada.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AnamneseEnviadaAdapter extends TypeAdapter<AnamneseEnviada> {
  @override
  final typeId = 8;

  @override
  AnamneseEnviada read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AnamneseEnviada(
      id: fields[0] as String,
      pacienteId: fields[1] as String,
      token: fields[2] as String,
      abordagem: fields[3] as String,
      status: fields[4] as String,
      url: fields[5] as String,
      respostasJson: fields[6] == null ? '' : fields[6] as String,
      dataCriacao: fields[7] as DateTime,
      dataEnvio: fields[8] as DateTime?,
      dataResposta: fields[9] as DateTime?,
      chaveCripto: fields[10] == null ? '' : fields[10] as String,
      e2e: fields[11] == null ? false : fields[11] as bool,
      falhaDecifrar: fields[12] == null ? false : fields[12] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AnamneseEnviada obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.pacienteId)
      ..writeByte(2)
      ..write(obj.token)
      ..writeByte(3)
      ..write(obj.abordagem)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.url)
      ..writeByte(6)
      ..write(obj.respostasJson)
      ..writeByte(7)
      ..write(obj.dataCriacao)
      ..writeByte(8)
      ..write(obj.dataEnvio)
      ..writeByte(9)
      ..write(obj.dataResposta)
      ..writeByte(10)
      ..write(obj.chaveCripto)
      ..writeByte(11)
      ..write(obj.e2e)
      ..writeByte(12)
      ..write(obj.falhaDecifrar);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnamneseEnviadaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
