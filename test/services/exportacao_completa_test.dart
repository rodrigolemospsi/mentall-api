import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prontuario_tcc/models/anamnese_enviada.dart';
import 'package:prontuario_tcc/models/contrato_terapeutico.dart';
import 'package:prontuario_tcc/models/exportacao_paciente.dart';
import 'package:prontuario_tcc/models/paciente.dart';
import 'package:prontuario_tcc/models/perfil_profissional.dart';
import 'package:prontuario_tcc/models/sessao.dart';
import 'package:prontuario_tcc/services/pdf_export_service.dart';

PerfilProfissional _perfil() {
  return PerfilProfissional(
    id: 'prof-1',
    nome: 'Dra. Teste',
    registroProfissional: 'CRP 00/00000',
    abordagemClinica: 'Integrativa',
  );
}

Paciente _paciente() {
  return Paciente(
    id: 'pac-1',
    nome: 'Ana Teste',
    ativo: true,
    dataCadastro: DateTime(2026, 1, 10),
  );
}

Sessao _sessao({
  required String id,
  required DateTime data,
  required String statusPagamento,
  double valor = 150,
}) {
  return Sessao(
    id: id,
    pacienteId: 'pac-1',
    numeroSessao: 1,
    data: data,
    temaPrincipal: 'Ansiedade no trabalho',
    evolucaoClinica: 'Boa adesão à tarefa de casa.',
    valorSessao: valor,
    statusPagamento: statusPagamento,
  );
}

ContratoTerapeutico _contrato() {
  return ContratoTerapeutico(
    id: 'contrato-1',
    pacienteId: 'pac-1',
    token: 'token-1',
    dataCriacao: DateTime(2026, 2, 1),
    dataEnvio: DateTime(2026, 2, 1),
    dataAceite: DateTime(2026, 2, 2),
    status: 'aceito',
    nomeAceite: 'Ana Teste',
  );
}

AnamneseEnviada _anamneseRespondida() {
  return AnamneseEnviada(
    id: 'anamnese-1',
    pacienteId: 'pac-1',
    token: 'token-2',
    abordagem: 'Integrativa',
    status: 'respondido',
    url: '',
    dataCriacao: DateTime(2026, 2, 3),
    dataResposta: DateTime(2026, 2, 4),
    respostasJson: jsonEncode(<String, dynamic>{
      'queixa_principal': 'Ansiedade',
      'historico_familiar': 'Sem relatos relevantes',
    }),
  );
}

ExportacaoPaciente _itemCompleto() {
  return ExportacaoPaciente(
    paciente: _paciente(),
    sessoes: [
      _sessao(
        id: 'sessao-1',
        data: DateTime(2026, 9, 10),
        statusPagamento: 'pago',
      ),
      _sessao(
        id: 'sessao-2',
        data: DateTime(2026, 10, 5),
        statusPagamento: 'pendente',
        valor: 200,
      ),
    ],
    contrato: _contrato(),
    anamnese: _anamneseRespondida(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await PdfExportService.carregarAssets();
  });

  test('gera o PDF consolidado com contrato, anamnese e sessões', () async {
    final bytes = await PdfExportService().gerarPdfTudoConsolidado(
      perfil: _perfil(),
      pacientes: [_itemCompleto()],
      contratoTemplate: 'Modelo do acordo terapêutico configurado.',
    );

    expect(bytes.length, greaterThan(2000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });


  test('PDF embute a fonte Unicode (travessão não vira quadrado)', () async {
    final bytes = await PdfExportService().gerarPdfTudoConsolidado(
      perfil: _perfil(),
      pacientes: [
        ExportacaoPaciente(
          paciente: _paciente(),
          sessoes: [
            _sessao(
              id: 'sessao-travessao',
              data: DateTime(2026, 10, 1),
              statusPagamento: 'pago',
            )..temaPrincipal =
                'Ansiedade — relato com “aspas” e … reticências',
          ],
        ),
      ],
    );

    // TTF embutido no PDF: garante que o texto usa a fonte Unicode, e não a
    // Helvetica sem glifos (que transformava o travessão em quadrado).
    expect(String.fromCharCodes(bytes).contains('/FontFile2'), isTrue);
  });

  test('gera o PDF consolidado mesmo sem pacientes', () async {
    final bytes = await PdfExportService().gerarPdfTudoConsolidado(
      perfil: _perfil(),
      pacientes: const [],
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('gera o resumo financeiro por mês com os totais', () async {
    final bytes = await PdfExportService().gerarPdfFinanceiroConsolidado(
      perfil: _perfil(),
      sessoes: [
        _sessao(
          id: 'sessao-1',
          data: DateTime(2026, 9, 10),
          statusPagamento: 'pago',
        ),
        _sessao(
          id: 'sessao-2',
          data: DateTime(2026, 10, 5),
          statusPagamento: 'pendente',
          valor: 200,
        ),
        _sessao(
          id: 'sessao-3',
          data: DateTime(2026, 10, 12),
          statusPagamento: 'convenio',
          valor: 100,
        ),
      ],
    );

    expect(bytes.length, greaterThan(1500));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('gera o resumo financeiro sem sessões (totais zerados)', () async {
    final bytes = await PdfExportService().gerarPdfFinanceiroConsolidado(
      perfil: _perfil(),
      sessoes: const [],
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
