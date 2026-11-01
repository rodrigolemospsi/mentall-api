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
      arquivado: fields[9] == null ? false : fields[9] as bool,
      aceiteCodigo: fields[10] == null ? '' : fields[10] as String,
      aceiteHash: fields[11] == null ? '' : fields[11] as String,
      aceiteVersao: fields[12] == null ? '' : fields[12] as String,
      aceiteCpfMascarado: fields[13] == null ? '' : fields[13] as String,
      aceiteIp: fields[14] == null ? '' : fields[14] as String,
      aceiteUserAgent: fields[15] == null ? '' : fields[15] as String,
      verificacaoUrl: fields[16] == null ? '' : fields[16] as String,
      documentoTexto: fields[17] == null ? '' : fields[17] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ContratoTerapeutico obj) {
    writer
      ..writeByte(18)
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
      ..write(obj.url)
      ..writeByte(9)
      ..write(obj.arquivado)
      ..writeByte(10)
      ..write(obj.aceiteCodigo)
      ..writeByte(11)
      ..write(obj.aceiteHash)
      ..writeByte(12)
      ..write(obj.aceiteVersao)
      ..writeByte(13)
      ..write(obj.aceiteCpfMascarado)
      ..writeByte(14)
      ..write(obj.aceiteIp)
      ..writeByte(15)
      ..write(obj.aceiteUserAgent)
      ..writeByte(16)
      ..write(obj.verificacaoUrl)
      ..writeByte(17)
      ..write(obj.documentoTexto);
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
