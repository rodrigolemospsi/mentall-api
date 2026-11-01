# Assinatura eletrônica simples + documentos (Fase A)

Implementado em 01/11/2026 (app 2.0.8+68; backend com colunas de evidência em
`contratos`). Complementa `docs/ANAMNESE_E2E.md`.

## O que o paciente assina hoje (antes)

Apenas digitava o nome e clicava "Li e aceito"; o servidor guardava nome e
data/hora. Sem IP, navegador, hash do documento, código de verificação nem
comprovante.

## Fase A — assinatura eletrônica com evidências

Fluxo novo:

1. A página pública do contrato (modelo padrão e modelo personalizado) mostra
   **nome completo + CPF opcional + checkbox "Li e concordo"** e botão
   **"Assinar documento"**.
2. O backend registra: nome, CPF (opcional, validado com dígitos
   verificadores), data/hora UTC, IP real (respeitando `TRUSTED_PROXIES`),
   User-Agent, **versão do documento** (`contrato-v1`), **hash SHA-256 do
   conteúdo canônico** e um **código público de verificação** (`XXXXX-XXXXX`,
   alfabeto sem letras ambíguas, 10 caracteres).
3. O paciente vê o comprovante na própria página (código, data, hash curto e
   link de verificação).
4. O app mostra no card "Acordo Terapêutico assinado": nome, CPF mascarado,
   data/hora, código, hash e botão **"Comprovante em PDF"**.
5. O PDF do contrato assinado contém:
   - cabeçalho com profissional (nome, CRP, CPF/CNPJ);
   - dados do paciente (nome/CPF);
   - texto canônico assinado (modelo padrão com as cláusulas do acordo ou o
     texto personalizado pelo profissional);
   - página de **Comprovante de assinatura eletrônica**: assinado por, CPF
     mascarado, data/hora, código, versão, IP, navegador, hash completo e
     **QR code** para a verificação pública.
6. Página pública `GET /verificar/<código>` confirma a autenticidade sem expor
   o nome completo do paciente (só primeiro nome + reticências) e sem CPF.

### Escopo legal (documentado)

É **assinatura eletrônica simples** (MP 2.200-2/2001): as partes podem contratar
livremente a forma, e o conjunto de evidências (identificação, data/hora, IP,
navegador, hash e código de terceiro) serve como prova de autoria/integridade.
Não substitui assinatura digital ICP-Brasil (não implementada nesta fase).

## Dados novos no cadastro

- **Paciente:** CPF (opcional no cadastro; obrigatório para recibos de IR).
- **Profissional:** CPF e CNPJ (opcionais), exibidos no contrato e usados nos
  recibos/notas.

## Recibos e declarações (Fase 2 — pesquisa concluída em 01/11/2026)

### O que o CFP orienta (fontes oficiais)

- **CFP (17/01/2025):** desde 1º/1/2025, recibos de despesas de saúde por
  **pessoa física** (incluindo psicólogas/os) são emitidos **exclusivamente pelo
  Receita Saúde** (RFB). O Receita Saúde é para autônomos que emitem com o
  próprio CPF; clínicas/hospitais usam a DMED. Exige CRP ativo, um recibo por
  pagamento, emitido no momento do pagamento; pode ser exportado em PDF.
  https://site.cfp.org.br/profissionais-da-psicologia-confira-orientacoes-sobre-o-receita-saude/
- **CRP-SP (07/04/2026):** PF = Receita Saúde; **PJ (CNPJ) = nota fiscal de
  prestação de serviços (NFS-e) conforme o município**. Recibos/notas **não
  devem conter dados clínicos, diagnósticos ou sensíveis** — só identificação,
  dados do profissional, registro, data e valor.
  https://crpsp.org/noticia/view/3619/recibos-e-notas-fiscais-na-psicologia-orientacoes-gerais-sobre-seguranca-etica-e-fiscal
- **PJ de Psicologia** precisa de registro/cadastro no CRP (Resolução CFP
  nº 16/2019). https://site.cfp.org.br/cfp-publica-nova-resolucao-sobre-pessoa-juridica/

### Caminho técnico para o Receita Saúde

A RFB disponibilizou em nov/2025 **emissão em lote por arquivo de integração**
para sistemas de gestão: o app gera o arquivo no leiaute oficial, o profissional
importa no Receita Saúde/Carnê-Leão Web, conclui e devolve o arquivo de retorno
para o app marcar os recibos como emitidos. O app **não** emite recibo oficial
por conta própria (não há API pública de emissão).
- https://www.gov.br/receitafederal/pt-br/assuntos/noticias/2025/novembro/disponibilizada-nova-funcionalidade-para-emissao-em-lote-de-recibos-do-receita-saude
- https://www.gov.br/receitafederal/pt-br/assuntos/meu-imposto-de-renda/pagamento/carne-leao/manual/formato-arquivo

### Produto (a implementar)

- **Modo PF — Receita Saúde:** seleção de pagamentos do período → arquivo de
  integração → importar retorno → recibos mensais/anuais + PDF/relatório.
- **Modo PJ — NFS-e:** registrar número/PDF emitido no município (integração
  futura com provedor/prefeitura) + relatório para a contabilidade.
- **Declaração de comparecimento:** nome/CPF do paciente, data, **hora de
  entrada e saída**, local, profissional (nome/CPF/CRP), finalidade, assinatura
  eletrônica com código/QR — **sem CID/diagnóstico**.
- **Retenção:** recibos/notas/comprovantes guardados por 5 anos, como snapshot
  independente do cadastro do paciente (não apagar na exclusão do paciente);
  nunca incluir conteúdo clínico.
- Numeração e verificação preferencialmente emitidas pelo backend.

## Arquivos

- Backend: `services/contrato_service.py` (hash/código/CPF/validação),
  `services/db.py` (colunas + migrações), `models/schemas.py`,
  `main.py` (rotas, bloco de assinatura, `/verificar/{codigo}`),
  `templates/contrato.html`.
- App: `models/contrato_terapeutico.dart` (campos 10–17), `models/paciente.dart`
  (`cpf`), `models/perfil_profissional.dart` (`cpf`/`cnpj`),
  `services/contrato_service.dart` (evidências + correção de cache do Hive),
  `services/pdf_export_service.dart` (`exportarContratoAssinado` + QR),
  `widgets/paciente_resumo_tab.dart` (diálogo com comprovante),
  `screens/perfil_profissional_form_page.dart`, `widgets/novo_paciente_dialog.dart`,
  `screens/paciente_detail_page.dart`, `utils/documentos.dart`.
- Testes: `backend/tests/test_contrato_assinatura.py` (10),
  `test/services/contrato_assinatura_service_test.dart` (4).

## Pendências

- Fase 2: recibos (arquivo de lote Receita Saúde) + declaração de
  comparecimento + retenção/tela de documentos.
- OTP por e-mail (fase opcional de reforço) e ICP-Brasil/plataforma certificada
  (upgrade futuro).
