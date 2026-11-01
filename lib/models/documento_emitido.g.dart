// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'documento_emitido.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DocumentoEmitidoAdapter extends TypeAdapter<DocumentoEmitido> {
  @override
  final typeId = 13;

  @override
  DocumentoEmitido read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DocumentoEmitido(
      id: fields[0] as String,
      pacienteId: fields[1] as String,
      tipo: fields[2] as String,
      numero: (fields[3] as num).toInt(),
      ano: (fields[4] as num).toInt(),
      criadoEm: fields[5] as DateTime,
      codigo: fields[6] == null ? '' : fields[6] as String,
      hash: fields[7] == null ? '' : fields[7] as String,
      snapshotJson: fields[8] == null ? '' : fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DocumentoEmitido obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.pacienteId)
      ..writeByte(2)
      ..write(obj.tipo)
      ..writeByte(3)
      ..write(obj.numero)
      ..writeByte(4)
      ..write(obj.ano)
      ..writeByte(5)
      ..write(obj.criadoEm)
      ..writeByte(6)
      ..write(obj.codigo)
      ..writeByte(7)
      ..write(obj.hash)
      ..writeByte(8)
      ..write(obj.snapshotJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentoEmitidoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
