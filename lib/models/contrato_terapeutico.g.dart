// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contrato_terapeutico.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ContratoTerapeuticoAdapter extends TypeAdapter<ContratoTerapeutico> {
  @override
  final typeId = 5;

  @override
  ContratoTerapeutico read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ContratoTerapeutico(
      id: fields[0] as String,
      pacienteId: fields[1] as String,
      token: fields[2] as String,
      dataCriacao: fields[3] as DateTime,
      dataEnvio: fields[4] as DateTime?,
      dataAceite: fields[5] as DateTime?,
      status: fields[6] == null ? 'pendente' : fields[6] as String,
      nomeAceite: fields[7] == null ? '' : fields[7] as String,
      url: fields[8] == null ? '' : fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ContratoTerapeutico obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.pacienteId)
      ..writeByte(2)
      ..write(obj.token)
      ..writeByte(3)
      ..write(obj.dataCriacao)
      ..writeByte(4)
      ..write(obj.dataEnvio)
      ..writeByte(5)
      ..write(obj.dataAceite)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.nomeAceite)
      ..writeByte(8)
      ..write(obj.url);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContratoTerapeuticoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
