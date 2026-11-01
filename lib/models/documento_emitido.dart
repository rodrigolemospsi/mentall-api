import 'package:hive_ce/hive.dart';

part 'documento_emitido.g.dart';

/// Registro de documento gerado pelo app (declaração, comprovante, informe ou
/// arquivo de lote do Receita Saúde). Guarda apenas metadados + snapshot em
/// JSON (cifrado no Hive); o PDF/CSV é gerado a partir do snapshot.
@HiveType(typeId: 13)
class DocumentoEmitido extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String pacienteId;

  /// declaracao_comparecimento | comprovante_pagamento | informe_pagamentos |
  /// arquivo_receita_saude
  @HiveField(2)
  String tipo;

  @HiveField(3)
  int numero;

  @HiveField(4)
  int ano;

  @HiveField(5)
  DateTime criadoEm;

  @HiveField(6, defaultValue: '')
  String codigo;

  @HiveField(7, defaultValue: '')
  String hash;

  @HiveField(8, defaultValue: '')
  String snapshotJson;

  DocumentoEmitido({
    required this.id,
    required this.pacienteId,
    required this.tipo,
    required this.numero,
    required this.ano,
    required this.criadoEm,
    this.codigo = '',
    this.hash = '',
    this.snapshotJson = '',
  });

  String get tipoExibicao {
    switch (tipo) {
      case 'declaracao_comparecimento':
        return 'Declaração de comparecimento';
      case 'comprovante_pagamento':
        return 'Comprovante de pagamento';
      case 'informe_pagamentos':
        return 'Informe de pagamentos';
      case 'arquivo_receita_saude':
        return 'Arquivo Receita Saúde (lote)';
      default:
        return tipo;
    }
  }

  String get numeroFormatado =>
      '${tipo == 'arquivo_receita_saude' ? 'LOTE' : 'DOC'}-$ano-${numero.toString().padLeft(4, '0')}';

  DocumentoEmitido copyWith({
    String? id,
    String? pacienteId,
    String? tipo,
    int? numero,
    int? ano,
    DateTime? criadoEm,
    String? codigo,
    String? hash,
    String? snapshotJson,
  }) {
    return DocumentoEmitido(
      id: id ?? this.id,
      pacienteId: pacienteId ?? this.pacienteId,
      tipo: tipo ?? this.tipo,
      numero: numero ?? this.numero,
      ano: ano ?? this.ano,
      criadoEm: criadoEm ?? this.criadoEm,
      codigo: codigo ?? this.codigo,
      hash: hash ?? this.hash,
      snapshotJson: snapshotJson ?? this.snapshotJson,
    );
  }
}
