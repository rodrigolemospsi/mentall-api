// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'compromisso.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CompromissoAdapter extends TypeAdapter<Compromisso> {
  @override
  final typeId = 4;

  @override
  Compromisso read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Compromisso(
      id: fields[0] as String,
      pacienteId: fields[1] as String,
      dataHoraInicio: fields[2] as DateTime,
      dataHoraFim: fields[3] as DateTime?,
      titulo: fields[4] == null ? '' : fields[4] as String,
      observacoes: fields[5] == null ? '' : fields[5] as String,
      status: fields[6] == null ? 'agendado' : fields[6] as String,
      sessaoId: fields[7] as String?,
      dataCriacao: fields[8] as DateTime?,
      dataAtualizacao: fields[9] as DateTime?,
      lembreteAtivado: fields[10] == null ? false : fields[10] as bool,
      minutosAntecedencia: fields[11] == null
          ? 1440
          : (fields[11] as num).toInt(),
      mensagemLembrete: fields[12] == null ? '' : fields[12] as String,
      recorrencia: fields[13] == null ? '' : fields[13] as String,
      dataLimiteRecorrencia: fields[14] as DateTime?,
      compromissoPaiId: fields[15] as String?,
      canalLembrete: fields[16] == null ? 'whatsapp' : fields[16] as String,
      tipoEvento: fields[17] == null ? 'sessao' : fields[17] as String,
      modalidade: fields[18] == null ? 'presencial' : fields[18] as String,
      sala: fields[19] == null ? '' : fields[19] as String,
      servico: fields[20] == null ? '' : fields[20] as String,
      linkOnline: fields[21] == null ? '' : fields[21] as String,
      googleEventId: fields[22] == null ? '' : fields[22] as String,
      googleCalendarId: fields[23] == null ? '' : fields[23] as String,
      googleSyncedAt: fields[24] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Compromisso obj) {
    writer
      ..writeByte(25)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.pacienteId)
      ..writeByte(2)
      ..write(obj.dataHoraInicio)
      ..writeByte(3)
      ..write(obj.dataHoraFim)
      ..writeByte(4)
      ..write(obj.titulo)
      ..writeByte(5)
      ..write(obj.observacoes)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.sessaoId)
      ..writeByte(8)
      ..write(obj.dataCriacao)
      ..writeByte(9)
      ..write(obj.dataAtualizacao)
      ..writeByte(10)
      ..write(obj.lembreteAtivado)
      ..writeByte(11)
      ..write(obj.minutosAntecedencia)
      ..writeByte(12)
      ..write(obj.mensagemLembrete)
      ..writeByte(13)
      ..write(obj.recorrencia)
      ..writeByte(14)
      ..write(obj.dataLimiteRecorrencia)
      ..writeByte(15)
      ..write(obj.compromissoPaiId)
      ..writeByte(16)
      ..write(obj.canalLembrete)
      ..writeByte(17)
      ..write(obj.tipoEvento)
      ..writeByte(18)
      ..write(obj.modalidade)
      ..writeByte(19)
      ..write(obj.sala)
      ..writeByte(20)
      ..write(obj.servico)
      ..writeByte(21)
      ..write(obj.linkOnline)
      ..writeByte(22)
      ..write(obj.googleEventId)
      ..writeByte(23)
      ..write(obj.googleCalendarId)
      ..writeByte(24)
      ..write(obj.googleSyncedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompromissoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
