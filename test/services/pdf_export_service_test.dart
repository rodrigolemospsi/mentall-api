import 'package:flutter_test/flutter_test.dart';
import 'package:prontuario_tcc/models/anamnese_enviada.dart';
import 'package:prontuario_tcc/models/paciente.dart';
import 'package:prontuario_tcc/models/perfil_profissional.dart';
import 'package:prontuario_tcc/models/sessao.dart';
import 'package:prontuario_tcc/services/pdf_export_service.dart';

void main() {
  group('PdfExportService._quebrarTextosLongos', () {
    test('quebra token unico muito longo (URL de artigo)', () {
      final url =
          'https://www.periodicos.capes.gov.br/index.php/acervo/buscador.html?'
          'q=terapia+cognitiva+ansiedade+social+e+populacao+adulta&lang=pt';
      final resultado = PdfExportService.quebrarTextosLongos(url);
      expect(resultado.contains('\n'), isTrue);
      // Nenhuma linha deve exceder o limite.
      for (final linha in resultado.split('\n')) {
        expect(linha.length, lessThanOrEqualTo(60));
      }
    });

    test('texto curto permanece inalterado', () {
      const texto = 'Relato curto do profissional.';
      expect(PdfExportService.quebrarTextosLongos(texto), texto);
    });

    test('quebra apenas tokens longos em texto com espacos', () {
      final texto =
          'Visite https://www.periodicos.capes.gov.br/index.php/acervo/'
          'buscador.html?q=terapia+cognitiva+ansiedade+social+e+populacao+adulta '
          'e continue o relato.';
      final resultado = PdfExportService.quebrarTextosLongos(texto);
      expect(resultado.split('\n').length, greaterThanOrEqualTo(3));
    });
  });

  group('PdfExportService.exportarProntuarioCompleto', () {
    test('gera PDF sem travar com URL longa de artigo', () async {
      final paciente = Paciente(id: 'p1', nome: 'Linda Tester');
      final perfil = PerfilProfissional(
        id: 'pr1',
        nome: 'Dr. Teste',
        registroProfissional: 'CRP 00/00000',
        abordagemClinica: 'TCC',
      );

      final urlLonga =
          'https://www.periodicos.capes.gov.br/index.php/acervo/buscador.html?'
          'q=terapia+cognitiva+ansiedade+social+e+populacao+adulta&lang=pt';
      final sessao = Sessao(
        id: 's1',
        pacienteId: 'p1',
        numeroSessao: 1,
        data: DateTime(2026, 8, 1, 14, 0),
        relatoPosSessao: 'Relato de ansiedade social.',
        artigosSugeridos: '1. Terapia cognitiva (2026) - Autor\n   $urlLonga',
      );

      // Sem timeout curto, a geração que antes travava com justify+URL longa
      // agora deve completar rapidamente.
      final pdf = await PdfExportService.gerarPdfProntuarioCompletoParaTeste(
        paciente: paciente,
        sessoes: [sessao],
        perfil: perfil,
      ).timeout(const Duration(seconds: 20));

      expect(pdf, isNotNull);
      expect(pdf!.length, greaterThan(1000));
    });
  });

  group('PdfExportService.exportarAnamnese', () {
    const template = '''
    {
      "secoes": [
        {
          "titulo": "Dados b\\u00e1sicos",
          "perguntas": [
            {"id": "nome", "label": "Nome completo", "tipo": "text"},
            {"id": "telefone", "label": "Telefone", "tipo": "text"}
          ]
        },
        {
          "titulo": "Seguran\\u00e7a emocional",
          "perguntas": [
            {"id": "pensou_morte", "label": "Pensamentos de n\\u00e3o querer viver", "tipo": "yesno"},
            {"id": "esta_seguro", "label": "Est\\u00e1 em seguran\\u00e7a", "tipo": "yesno"}
          ]
        },
        {
          "titulo": "Objetivos",
          "perguntas": [
            {"id": "objetivos", "label": "O que espera alcan\\u00e7ar", "tipo": "checklist"},
            {"id": "usa_medicacao", "label": "Usa medica\\u00e7\\u00e3o", "tipo": "yesno",
             "condicional_sim": {"id": "usa_medicacao_quais", "label": "Quais?"}}
          ]
        }
      ]
    }
    ''';

    test('gera PDF com secoes e respostas do paciente', () async {
      final paciente = Paciente(id: 'p1', nome: 'Linda Tester');
      final perfil = PerfilProfissional(
        id: 'pr1',
        nome: 'Dr. Teste',
        registroProfissional: 'CRP 00/00000',
        abordagemClinica: 'TCC',
      );
      final anamnese = AnamneseEnviada(
        id: 'a1',
        pacienteId: 'p1',
        token: 'tok',
        abordagem: 'TCC',
        status: 'respondido',
        url: 'https://x',
        respostasJson:
            '{"nome":"Linda","telefone":"(11) 99999-9999","pensou_morte":false,'
            '"esta_seguro":true,"objetivos":["Reduzir ansiedade","Melhorar autoestima"],'
            '"usa_medicacao":true,"usa_medicacao_quais":"Sertralina"}',
        dataCriacao: DateTime(2026, 8, 1),
        dataResposta: DateTime(2026, 8, 10, 15, 30),
      );

      final pdf = await PdfExportService.gerarPdfAnamneseParaTeste(
        paciente: paciente,
        anamnese: anamnese,
        perfil: perfil,
        templateJson: template,
      ).timeout(const Duration(seconds: 20));

      expect(pdf, isNotNull);
      expect(pdf!.length, greaterThan(1000));
    });

    test('gera PDF mesmo sem respostas (template completo com marcadores)', () async {
      final paciente = Paciente(id: 'p1', nome: 'Linda Tester');
      final perfil = PerfilProfissional(
        id: 'pr1',
        nome: 'Dr. Teste',
        registroProfissional: 'CRP 00/00000',
        abordagemClinica: 'TCC',
      );
      final anamnese = AnamneseEnviada(
        id: 'a1',
        pacienteId: 'p1',
        token: 'tok',
        abordagem: 'TCC',
        status: 'respondido',
        url: 'https://x',
        respostasJson: '{"nome":"Linda"}',
        dataCriacao: DateTime(2026, 8, 1),
        dataResposta: DateTime(2026, 8, 10, 15, 30),
      );

      final pdf = await PdfExportService.gerarPdfAnamneseParaTeste(
        paciente: paciente,
        anamnese: anamnese,
        perfil: perfil,
        templateJson: template,
      ).timeout(const Duration(seconds: 20));

      expect(pdf, isNotNull);
      expect(pdf!.length, greaterThan(1000));
    });
  });
}
