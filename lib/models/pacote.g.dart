// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pacote.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PacoteAdapter extends TypeAdapter<Pacote> {
  @override
  final typeId = 11;

  @override
  Pacote read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Pacote(
      id: fields[0] as String,
      pacienteId: fields[1] as String,
      totalSessoes: (fields[2] as num).toInt(),
      sessoesRestantes: (fields[3] as num).toInt(),
      valorTotal: (fields[4] as num).toDouble(),
      dataCriacao: fields[5] as DateTime,
      ativo: fields[6] == null ? true : fields[6] as bool,
      observacoes: fields[7] == null ? '' : fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Pacote obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.pacienteId)
      ..writeByte(2)
      ..write(obj.totalSessoes)
      ..writeByte(3)
      ..write(obj.sessoesRestantes)
      ..writeByte(4)
      ..write(obj.valorTotal)
      ..writeByte(5)
      ..write(obj.dataCriacao)
      ..writeByte(6)
      ..write(obj.ativo)
      ..writeByte(7)
      ..write(obj.observacoes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PacoteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
