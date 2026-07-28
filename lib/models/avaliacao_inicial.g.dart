// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'avaliacao_inicial.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AvaliacaoInicialAdapter extends TypeAdapter<AvaliacaoInicial> {
  @override
  final typeId = 6;

  @override
  AvaliacaoInicial read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AvaliacaoInicial(
      id: fields[0] as String,
      pacienteId: fields[1] as String,
      queixaPrincipal: fields[2] == null ? '' : fields[2] as String,
      historicoClinico: fields[3] == null ? '' : fields[3] as String,
      medicamentos: fields[4] == null ? '' : fields[4] as String,
      hipoteseDiagnostica: fields[5] == null ? '' : fields[5] as String,
      objetivosTerapeuticos: fields[6] == null ? '' : fields[6] as String,
      observacoes: fields[7] == null ? '' : fields[7] as String,
      dataCriacao: fields[8] as DateTime,
      dataAtualizacao: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AvaliacaoInicial obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.pacienteId)
      ..writeByte(2)
      ..write(obj.queixaPrincipal)
      ..writeByte(3)
      ..write(obj.historicoClinico)
      ..writeByte(4)
      ..write(obj.medicamentos)
      ..writeByte(5)
      ..write(obj.hipoteseDiagnostica)
      ..writeByte(6)
      ..write(obj.objetivosTerapeuticos)
      ..writeByte(7)
      ..write(obj.observacoes)
      ..writeByte(8)
      ..write(obj.dataCriacao)
      ..writeByte(9)
      ..write(obj.dataAtualizacao);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvaliacaoInicialAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
