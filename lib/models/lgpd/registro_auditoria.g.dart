// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'registro_auditoria.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RegistroAuditoriaAdapter extends TypeAdapter<RegistroAuditoria> {
  @override
  final typeId = 10;

  @override
  RegistroAuditoria read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RegistroAuditoria(
      id: fields[0] as String,
      tipoEvento: fields[1] as String,
      descricao: fields[2] as String,
      dataHora: fields[3] as DateTime,
      pacienteId: fields[4] == null ? '' : fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, RegistroAuditoria obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tipoEvento)
      ..writeByte(2)
      ..write(obj.descricao)
      ..writeByte(3)
      ..write(obj.dataHora)
      ..writeByte(4)
      ..write(obj.pacienteId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegistroAuditoriaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
