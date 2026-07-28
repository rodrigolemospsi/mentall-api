// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resposta_escala.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RespostaEscalaAdapter extends TypeAdapter<RespostaEscala> {
  @override
  final typeId = 7;

  @override
  RespostaEscala read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RespostaEscala(
      id: fields[0] as String,
      pacienteId: fields[1] as String,
      escalaId: fields[2] as String,
      respostasJson: fields[3] == null ? '[]' : fields[3] as String,
      pontuacao: fields[4] == null ? 0 : (fields[4] as num).toInt(),
      interpretacao: fields[5] == null ? '' : fields[5] as String,
      dataAplicacao: fields[6] as DateTime,
      observacoes: fields[7] == null ? '' : fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, RespostaEscala obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.pacienteId)
      ..writeByte(2)
      ..write(obj.escalaId)
      ..writeByte(3)
      ..write(obj.respostasJson)
      ..writeByte(4)
      ..write(obj.pontuacao)
      ..writeByte(5)
      ..write(obj.interpretacao)
      ..writeByte(6)
      ..write(obj.dataAplicacao)
      ..writeByte(7)
      ..write(obj.observacoes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RespostaEscalaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
