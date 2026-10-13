# Pacote de conformidade LGPD — MentAll PRO

**Versão:** 1.1 · **Data:** 13/10/2026 · **Responsável pela elaboração:** diagnóstico técnico assistido
**Base analisada:** repositório `/Users/rodrigolemos/mentall-pro-app` — app `1.0.49+50`, backend FastAPI, configuração de produção

> **O que este pacote é:** um diagnóstico técnico de conformidade com LGPD **e** o conjunto de
> documentos que dão sustentação a ele. Cada afirmação sobre o produto foi verificada **no código**,
> com indicação de `arquivo:linha`.
>
> **O que este pacote não é:** **parecer jurídico**. Todos os pontos marcados com ⚖️ precisam de
> revisão de advogado especializado em proteção de dados antes de virarem compromisso público,
> contrato assinado ou declaração de loja.

---

## 1. Comece por aqui

| Ordem | Documento | Para que serve | Tempo de leitura |
|---|---|---|---|
| 1º | **`01_diagnostico_lgpd.md`** | O retorno sobre LGPD: o que está bom, o que está exposto e por quê | 20 min |
| 2º | **`02_plano_de_acao.md`** | O que fazer, em que ordem, com critério de pronto | 10 min |
| 3º | **`17_registro_de_decisoes_e_revisoes.md`** | As decisões que **só você** pode tomar | 5 min |
| 4º | Demais documentos | Instrumentos, políticas e materiais | consulta |

**Se você ler apenas uma página:** leia o *Sumário executivo* do documento 01.

---

## 2. Índice completo

| # | Arquivo | Conteúdo | Estado |
|---|---|---|---|
| 00 | `00_LEIA-ME.md` | Este índice e guia de uso | ✅ |
| 01 | `01_diagnostico_lgpd.md` | Diagnóstico completo: achados com severidade, evidência `arquivo:linha`, matriz de risco e referências normativas verificadas | ✅ |
| 02 | `02_plano_de_acao.md` | Plano priorizado P0/P1/P2/P3, com evidência, ação, critério de pronto e esforço | ✅ |
| 03 | `03_data_mapping_e_ropa.md` | Data mapping e Registro das Operações de Tratamento (art. 37) | ✅ |
| 04 | `04_papeis_e_contrato_controlador_operador.md` | Enquadramento de papéis e minuta do Contrato de Tratamento de Dados (DPA) | ⚖️ minuta |
| 05 | `05_politica_de_privacidade.md` | Política de Privacidade para o app e para o site (versão publicável) | ⚖️ revisar |
| 06 | `06_termos_de_uso.md` | Termos de Uso (versão publicável) | ⚖️ revisar |
| 07 | `07_aviso_de_privacidade_e_termo_de_consentimento.md` | Material do psicólogo: aviso de privacidade e termos de consentimento (adulto e menor) | ⚖️ revisar |
| 08 | `08_ripd_relatorio_de_impacto.md` | Relatório de Impacto à Proteção de Dados (art. 38) — IA, dado sensível e transferência | ⚖️ revisar |
| 09 | `09_transferencia_internacional.md` | Mapa das transferências, salvaguardas e cenários de decisão | ⚖️ decidir |
| 10 | `10_politica_de_retencao_e_descarte.md` | Prazos de guarda por categoria e descarte seguro | ⚖️ revisar |
| 11 | `11_plano_de_resposta_a_incidentes.md` | Plano de resposta, prazos regulatórios, modelos de comunicação | ⚖️ revisar |
| 12 | `12_politica_de_seguranca_da_informacao.md` | Controles existentes e ausentes, gestão de acessos e segredos | — |
| 13 | `13_encarregado_dpo_e_canal_do_titular.md` | Como nomear o encarregado e operar o canal do titular | ⚖️ decidir |
| 14 | `14_guia_lgpd_do_psicologo.md` | Guia prático de LGPD para o psicólogo cliente | — |
| 15 | `15_lojas_google_play_e_app_store.md` | Data Safety, App Privacy, nota LGPD e textos de loja | — |
| 16 | `16_checklist_de_conformidade.md` | Checklist verificável com semáforo executivo | — |
| 17 | `17_registro_de_decisoes_e_revisoes.md` | Decisões pendentes, histórico de revisões e calendário | — |
| 18 | `18_comparativo_concorrentes.md` | Comparativo de LGPD com concorrentes brasileiros (PsiLuz, Zenklub, Copilloto, ProntusCare, PsicoPront) — padrão de mercado para calibrar os documentos públicos | ✅ |
| — | `_base_factual.md` | Documento de trabalho interno: as verificações que sustentam tudo | interno |

**Legenda:** ✅ completo · ⚖️ depende de validação jurídica · as linhas sem marcador são documentos
técnicos/operacionais.

---

## 3. As seis decisões que só o dono pode tomar

Estão detalhadas no documento 17. Resumo:

1. **DeepSeek**: remover da cascata de IA **ou** obter consentimento específico e destacado para envio
   à China? Hoje o fallback é automático e silencioso.
2. **Banco nos EUA**: migrar o Turso para região brasileira **ou** documentar a transferência com
   cláusulas-padrão e RIPD?
3. **Cifra no servidor**: cifrar os dados já persistidos (contrato, anamnese, telefone) **ou** parar de
   persisti-los no servidor?
4. **WhatsApp**: manter o gateway não oficial com consentimento específico **ou** migrar para canal
   oficial?
5. **Retenção**: adotar o piso de **5 anos** (Resolução CFP nº 001/2009) ou o entendimento regional de
   20 anos? ⚖️
6. **Encarregado (DPO)**: nomear pessoa interna, terceirizar ou usar pessoa jurídica — e publicar
   canal? ⚖️

---

## 4. Método e limites

**Como os fatos foram obtidos:** auditoria somente-leitura do cliente Flutter, do backend, da
configuração de deploy e da documentação interna, com três verificações independentes
(cliente, servidor e documentação) e conferência direta dos pontos críticos. As normas foram
verificadas em **fontes oficiais** (LGPD, resoluções da ANPD, resoluções do CFP, exigências de
Google Play e App Store), com URL registrada no documento 01.

**O que ficou fora:** o APK compilado byte a byte; os servidores de Turso, Fly, Groq, OpenAI, Google,
DeepSeek e Sentry; contratos comerciais; o site institucional em produção; e a validação jurídica.

**Itens que permanecem como "não confirmado"** estão listados no fim dos documentos 01, 03 e 09 e não
devem ser usados como fato em documento público.

---

## 5. Antes de publicar qualquer coisa

Três regras que evitam o pior cenário (declarar algo que o produto não faz):

1. **Nenhuma afirmação pública sem comportamento correspondente no código.** Se ainda não existe,
   entra no plano — não na promessa.
2. **Nunca** use "LGPD compliant", "certificado" ou "100% seguro". Use **"em adequação"**.
3. **A versão publicada deve ser idêntica à versão exibida no app.** Divergência entre site e app é
   ela mesma uma infração de transparência.

---

## 6. Alerta sobre a documentação interna do próprio projeto

O repositório tem documentação rica, mas com **contradições internas** que precisam ser resolvidas —
uma delas já foi corrigida nesta análise:

- `SECURITY_CHANGELOG.md` declara pinning de certificado (SEC-05) e migração automática para GCM que
  **não correspondem ao código atual**;
- `pdf_arquitetura_lgpd_service.dart` afirma AES-256-**CBC** (o código usa **GCM**) e marca princípios
  LGPD como "todos aplicados" (`:171`) e eventos de auditoria como existentes (`:215`) que **não
  existem**;
- `privacidade_seguranca_page.dart:151` afirma que os registros de auditoria "não contêm dados
  clínicos", mas `auditoria_service.dart:86-87` admite que a descrição contém identificadores;
- `tasks/plan.md:23-27` afirma que "a nuvem só recebe números", enquanto **anamnese e contrato são
  gravados no servidor**;
- `AGENTS.md` mistura estado atual com histórico e tem itens contraditórios entre si.

**Recomendação:** consolidar a documentação de privacidade em **uma fonte única** (este pacote,
em `docs/lgpd/`) e substituir, nas telas e nos PDFs internos, o que hoje afirma conformidade que não
existe. Enquanto a documentação contradiz o código, qualquer auditoria começa mal.

---

## 7. Próximos passos sugeridos

1. Ler o documento 01 e decidir os itens do documento 17.
2. Executar os **P0** do documento 02 (bloqueadores de release/loja).
3. Enviar os documentos ⚖️ para revisão jurídica com os pontos destacados.
4. Publicar a Política e os Termos em URL pública e atualizar as telas in-app (mesmo texto).
5. Nomear o encarregado e abrir o canal do titular.
6. Entregar o material do psicólogo (documentos 07 e 14) a cada cliente.
7. Manter ROPA e RIPD vivos, com revisão trimestral.
