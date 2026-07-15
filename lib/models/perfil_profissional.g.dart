// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'perfil_profissional.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PerfilProfissionalAdapter extends TypeAdapter<PerfilProfissional> {
  @override
  final typeId = 3;

  @override
  PerfilProfissional read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PerfilProfissional(
      id: fields[0] as String,
      nome: fields[1] as String,
      registroProfissional: fields[2] == null ? '' : fields[2] as String,
      abordagemClinica: fields[3] == null ? 'Integrativa' : fields[3] as String,
      termoPessoaAtendida: fields[4] == null ? 'paciente' : fields[4] as String,
      dataCriacao: fields[5] as DateTime?,
      dataAtualizacao: fields[6] as DateTime?,
      modalidadesAtendimentoJson: fields[7] == null
          ? '[]'
          : fields[7] as String,
      enderecosConsultoriosJson: fields[8] == null ? '[]' : fields[8] as String,
      fotoBase64: fields[9] == null ? '' : fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PerfilProfissional obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nome)
      ..writeByte(2)
      ..write(obj.registroProfissional)
      ..writeByte(3)
      ..write(obj.abordagemClinica)
      ..writeByte(4)
      ..write(obj.termoPessoaAtendida)
      ..writeByte(5)
      ..write(obj.dataCriacao)
      ..writeByte(6)
      ..write(obj.dataAtualizacao)
      ..writeByte(7)
      ..write(obj.modalidadesAtendimentoJson)
      ..writeByte(8)
      ..write(obj.enderecosConsultoriosJson)
      ..writeByte(9)
      ..write(obj.fotoBase64);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PerfilProfissionalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
