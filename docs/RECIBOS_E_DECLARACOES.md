# Recibos e declarações (Fase 2)

Implementado em 01/11/2026 (app 2.0.9+69). Complementa
`docs/ASSINATURA_ELETRONICA.md` e `docs/ANAMNESE_E2E.md`.

## O que foi entregue

Tela **Documentos** na aba Resumo do paciente:

1. **Declaração de comparecimento** (PDF): paciente/CPF, data, **hora de
   entrada e saída**, local, profissional (nome/CRP/CPF), finalidade
   "comprovação de comparecimento junto ao empregador", assinatura eletrônica
   simples do profissional, número do documento (DOC-AAAA-0001), código de
   verificação e hash SHA-256. **Sem CID, diagnóstico ou conteúdo clínico.**
   Os horários são pré-preenchidos com o compromisso vinculado à sessão; sem
   compromisso, usa a hora da sessão + 50 min (editável).
2. **Arquivo Receita Saúde (lote CSV)**: gera o arquivo no **leiaute oficial**
   para importar no e-CAC → Carnê-Leão → Escrituração → Importar Escrituração.
   Inclui apenas sessões com `statusPagamento == 'pago'` no mês/ano escolhido;
   valida CPF do profissional e do paciente, valor > 0, mesmo ano e limite de
   1000 linhas; descrição genérica ("Sessão de psicoterapia em DD/MM/AAAA"),
   **sem conteúdo clínico**.
3. **Comprovante de pagamento (PDF)**: documento **não fiscal** para
   conferência (paciente, data da sessão/pagamento, valor, forma de pagamento,
   número/código/hash), com aviso de que o documento fiscal oficial é o recibo
   do Receita Saúde (PF) ou a NFS-e (PJ/CNPJ).
4. **Informe anual de pagamentos (PDF)**: tabela das sessões pagas no ano,
   total e aviso fiscal, para conferência do paciente/contador.

Cada documento gerado é registrado na box Hive `documentos_emitidos`
(`DocumentoEmitido`, typeId 13) com numeração sequencial por tipo/ano
(`DOC-AAAA-0001`; arquivos `LOTE-AAAA-0001`), código de verificação e hash
SHA-256; snapshot e código/hash são gravados **cifrados** no Hive. O card mostra
os três últimos documentos emitidos.

## Leiaute oficial do arquivo (Manual Receita Saúde v2.1, pergunta 24)

Fonte: https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/publicacoes/manuais/orientacao-tributaria/receita-saude-2.1.pdf
e https://www.gov.br/receitafederal/pt-br/assuntos/meu-imposto-de-renda/pagamento/carne-leao/manual/formato-arquivo

- **CSV**, campos separados por **ponto e vírgula (`;`)**, **até 1000 linhas**,
  todos os pagamentos do **mesmo ano**.
- 16 campos, nesta ordem:
  1. Data do pagamento (DD/MM/AAAA)
  2. Código do rendimento = `R01.001.001`
  3. Código da ocupação = `255` (Psicólogo)
  4. Valor do pagamento (ex.: `250,00` — sem separador de milhar)
  5. Valor da dedução = vazio
  6. Descrição (até 255 caracteres; aqui genérica, sem dado clínico)
  7. Recebido de = `PF`
  8. CPF do pagador (11 dígitos)
  9. CPF do beneficiário do serviço (11 dígitos)
  10. Ind. CPF não informado = vazio
  11. CNPJ = vazio
  12. Indicador de IRRF = vazio
  13. Valor IRRF = vazio
  14. Indicador de recibo = `S`
  15. CPF do profissional (o mesmo do Carnê-Leão)
  16. Registro profissional (até 15 caracteres; CRP, se houver)

O app gera o CSV + registra o lote; o **recibo oficial** é emitido no Receita
Saúde após a importação (a RFB não expõe API pública de emissão direta).

## Orientações exibidas/uso

- PF: emitir pelo Receita Saúde (obrigatório desde 1º/1/2025 — CFP).
- PJ/CNPJ: NFS-e municipal (registro do número/PDF, integração futura);
  PJ de Psicologia precisa de registro no CRP (Res. CFP 16/2019).
- Recibos/notas **não devem conter dados clínicos/diagnóstico** (CFP/CRP-SP).
- Retenção: guardar documentos fiscais por **5 anos**. O app mantém o registro
  local; incluir a box `documentos_emitidos` no backup e preservar os
  documentos na exclusão do paciente são pendências da Fase 2.1.

## Pendências (Fase 2.1)

- Incluir `documentos_emitidos` no backup/restauração e na política de retenção
  (não apagar ao excluir paciente).
- Verificação pública de comprovantes/declarações (hash/código no backend).
- Envio por e-mail/WhatsApp do PDF ao paciente.
- NFS-e para PJ (integração municipal/provedor) e registro de número/PDF.
- OTP por e-mail / ICP-Brasil como reforço opcional.

## Testes

- `test/services/documento_fiscal_service_test.dart` (7): linhas do CSV com 16
  campos no formato oficial, CPF ausente bloqueia, período sem pagamento,
  formatação de valores (sem milhar, vírgula), numeração sequencial, snapshot
  cifrado no Hive e formatadores de CPF.

## Validação (01/11/2026)

- **Testes:** `flutter analyze` sem issues; **Flutter 376 OK** (7 novos do serviço de
  documentos) e backend **551 OK** (sem mudanças no backend nesta fase).
- **Emulador (build 2.0.9+69):** card "Documentos" renderizou corretamente no
  Resumo do paciente com as quatro ações (declaração, arquivo Receita Saúde,
  comprovante e informe).
- **CI/deploy:** run `41339526378` verde (Flutter, backend isolado, dependency
  scan e deploy Fly); `/health` 200 após o deploy (mesmo backend da 2.0.8).
- **Artefatos 2.0.9+69:** `MentAllPRO-v2.0.9-debugsign.apk` (SHA-256
  `bf8afec55ad4…f0b8b4`), `MentAllPRO-v2.0.9-release.apk` (upload key; instala
  por cima da 2.0.8) e `MentAllPRO-v2.0.9.aab`.
