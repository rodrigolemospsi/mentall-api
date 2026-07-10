// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paciente.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PacienteAdapter extends TypeAdapter<Paciente> {
  @override
  final typeId = 1;

  @override
  Paciente read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Paciente(
      id: fields[0] as String,
      nome: fields[1] as String,
      dataNascimento: fields[2] as DateTime?,
      contato: fields[3] == null ? '' : fields[3] as String,
      email: fields[8] == null ? '' : fields[8] as String,
      tipoAtendimento: fields[4] == null ? 'Particular' : fields[4] as String,
      modoAtendimento: fields[10] == null ? '' : fields[10] as String,
      fotoBase64: fields[11] == null ? '' : fields[11] as String,
      observacoes: fields[5] == null ? '' : fields[5] as String,
      ativo: fields[6] == null ? true : fields[6] as bool,
      dataCadastro: fields[7] as DateTime?,
      dataAtualizacao: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Paciente obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nome)
      ..writeByte(2)
      ..write(obj.dataNascimento)
      ..writeByte(3)
      ..write(obj.contato)
      ..writeByte(4)
      ..write(obj.tipoAtendimento)
      ..writeByte(5)
      ..write(obj.observacoes)
      ..writeByte(6)
      ..write(obj.ativo)
      ..writeByte(7)
      ..write(obj.dataCadastro)
      ..writeByte(8)
      ..write(obj.email)
      ..writeByte(9)
      ..write(obj.dataAtualizacao)
      ..writeByte(10)
      ..write(obj.modoAtendimento)
      ..writeByte(11)
      ..write(obj.fotoBase64);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PacienteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
