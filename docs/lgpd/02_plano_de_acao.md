# Plano de ação LGPD — MentAll PRO

**Versão:** 1.0 (rascunho) · **Data:** 09/10/2026
**Regra de leitura:** cada item tem **evidência** (por que existe), **ação**, **critério de pronto**
(como você sabe que acabou) e **esforço**. Itens marcados ⚖️ dependem de validação jurídica.

Legenda de prioridade:

- **P0 — antes do próximo release/loja**: exposição atual ou afirmação falsa ao titular.
- **P1 — 30 dias**: instrumento obrigatório ausente.
- **P2 — 90 dias**: robustez e governança.
- **P3 — melhoria contínua**.

---

## P0 — Bloqueadores (semanas 1 e 2)

| # | Ação | Evidência do problema | Critério de pronto | Esforço |
|---|---|---|---|---|
| P0.1 | **Corrigir a descrição de terceiros nos textos públicos e in-app**: listar Groq, OpenAI, DeepSeek (e Gemini, se voltar), com o que cada um recebe, país e finalidade. | `politica_privacidade_page.dart:71-73`; `termos_uso_page.dart:35-36` | Textos dos documentos 05 e 06 publicados em URL, sem nome de provedor que não esteja em uso | 4 h |
| P0.2 | **Decidir o DeepSeek**: remover da ordem de provedores (`IA_PROVIDER_ORDER`) **ou** implementar consentimento específico e destacado por pessoa atendida + RIPD específico. | `ia_clinica.py:648`; `AGENTS.md:191` | Decisão registrada no documento 17; se mantido, consentimento e RIPD publicados | 2 h (remoção) / 3 d (manter) ⚖️ |
| P0.3 | **Decidir a localização do banco**: migrar Turso para região brasileira/servidor nacional **ou** documentar a transferência com salvaguarda. | `backend/.env` (`aws-us-west-2.turso.io`) vs `fly.toml:2-3` (`gru`) | Documento 09 com a decisão e o mecanismo do art. 33; ou banco em região nacional | 1 d (decisão) + migração |
| P0.4 | **Cifrar o conteúdo no servidor** dos dados já persistidos (contrato, anamnese, telefone/lembrete) ou **parar de persistir** o que o app pode guardar local. | `contrato_service.py:14-15` (`json.dumps` sem cifra); `db.py:180-213` | Nenhum campo de dado pessoal sensível legível no banco; teste que prove | 2–3 d |
| P0.5 | **Publicar Política de Privacidade e Termos em URL** no site institucional. | `tasks/lojas_app.md:32-34` (site irmão só tem `index.html`) | Duas URLs públicas, versionadas e linkadas no app e na loja | 1 d |
| P0.6 | **Remover a afirmação "não são armazenados para treinamento"** enquanto não houver comprovação documental por provedor. | `politica_privacidade_page.dart:105-108` | Texto substituído por declaração verificável (ou comprovante arquivado por provedor) | 2 h ⚖️ |
| P0.7 | **Fechar o desbloqueio fail-open**: lockout/erro de hardware **não** pode carregar a chave mestra sem autenticação. | `auth_service.dart:203-215,237-250` | Teste que prove: sem autenticação bem-sucedida, o prontuário permanece cifrado | 1 d |
| P0.8 | **Áudio nunca em claro**: gravar já em contêiner cifrado (ou cifrar em blocos durante a gravação) e varrer órfãos no boot. | `audio_relato_service.dart:92` vs `:171`; sem varredura | Arquivo em claro não existe em nenhum instante; teste de kill no meio da gravação | 2 d |
| P0.9 | **Bloqueio real**: limpar a chave da memória ao bloquear, adicionar `FLAG_SECURE` e desativar a pré-visualização de tarefas. | `encryption_service.dart:656-663` (sem chamador); `app_lock_gate.dart:95-113` | Bloqueio testado com captura de tela e troca de app | 1 d |
| P0.10 | **Corrigir ou remover a afirmação de pinning** (e o item SEC-05 do changelog): hoje é `badCertificateCallback`, que não fixa certificado. | `main.dart:45-68`; `SECURITY_CHANGELOG.md` (SEC-05) | Pinning efetivo implementado **ou** texto/changelog corrigidos | 4 h |
| P0.11 | **Retirar a cópia local em texto claro com dados reais** (`backend/data/mentall.db`) e definir o descarte. | auditoria de backend | Arquivo eliminado; nenhum dado de titular em claro fora do aparelho | 2 h |

---

## P1 — Instrumentos obrigatórios (30 dias)

| # | Ação | Evidência | Critério de pronto | Esforço |
|---|---|---|---|---|
| P1.1 | **Nomear encarregado (DPO)** e publicar identidade + canal. | `politica_privacidade_page.dart:119-122` (sem DPO/e-mail) | Documento 13 publicado; canal respondendo; nome no site | 4 h |
| P1.2 | **Assinar o DPA** (controlador-operador) com cada psicólogo cliente. | `pdf_arquitetura_lgpd_service.dart:354` (marca "ausente") | Documento 04 anexado ao aceite no cadastro | 1 d ⚖️ |
| P1.3 | **Registro das operações (ROPA)** preenchido e mantido. | Art. 37; inexistente | Documento 03 completo, com responsável e revisão semestral | 1 d |
| P1.4 | **RIPD** do tratamento com IA (dado sensível + transferência). | Art. 38; inexistente; caso típico exigível | Documento 08 aprovado e arquivado | 2 d ⚖️ |
| P1.5 | **Termo de consentimento e aviso de privacidade do titular** entregue pelo psicólogo. | `pdf_arquitetura_lgpd_service.dart:241` ("Consentimentos" não implementado) | Documento 07 entregue; app registra a ciência | 1 d ⚖️ |
| P1.6 | **Política de retenção e descarte**, incluindo áudio e guarda legal do prontuário. | `politica_privacidade_page.dart:82-84` | Documento 10 publicado; prazos declarados | 1 d ⚖️ |
| P1.7 | **Plano de resposta a incidentes** com prazo regulatório e formulário de registro. | Inexistente | Documento 11 + planilha de registro de incidentes; simulação feita | 1 d |
| P1.8 | **Canal e procedimento do titular** (art. 18), com prazo de resposta. | `politica_privacidade_page.dart:89-98` empurra tudo ao psicólogo | Documento 13; formulário/e-mail; registro de solicitações | 1 d |
| P1.9 | **Fluxo e URL de exclusão de conta** (exigência de loja + art. 18, VI). | `tasks/lojas_app.md`; `excluirPaciente` sem chamador | Exclusão de conta funciona ponta a ponta e é declarada na loja | 2 d |
| P1.10 | **Material de loja**: Data Safety (Play) e App Privacy (Apple) coerentes com os fluxos reais. | Textos atuais levariam a declaração incorreta | Documento 15 preenchido e conferido contra o código | 1 d |
| P1.11 | **Links públicos de anamnese e contrato com expiração e revogação** (e sem o nome do titular embutido). | `main.py:1468,1530,1650-1658`; `db.py:180-198` (sem coluna de expiração) | Link expira; rota de cancelamento; nome não exposto na página pública | 1 d |
| P1.12 | **Integridade de dados no servidor**: fixar `APP_USER_ID`, desligar `ALLOW_SQLITE_FALLBACK` em produção e fazer `/health` reprovar em fallback. | `main.py:241`; `db.py:15-17`; `main.py:688-700` | Restart não orfana dados; escrita nunca confirma sucesso em banco volátil | 4 h |
| P1.13 | **Segredos fora de URL e expurgo de log**: mover o token do webhook para header, rotacionar, expurgar os 21 MB de log com segredos/PII e mascarar o nome em `contrato_service.py:66`. | `wuzapi_admin.py:47-49`; `contrato_service.py:66`; `backend.launchd.log` | Nenhum segredo/PII em log; política de retenção de log aplicada | 4 h |
| P1.14 | **Telemetria com opt-out e aviso claro** no primeiro uso. | `telemetria_service.dart:16-40,72-90` | Toggle funcional; aviso exibido e registrado | 4 h |
| P1.15 | **Menores de idade**: campo de responsável legal, autorização e consentimento específico (art. 14). | Nenhum campo encontrado no app | Fluxo implementado e explicado no material do psicólogo | 2 d ⚖️ |
| P1.16 | **PDF e backup protegidos**: senha/cifra opcional no arquivo, aviso de sigilo no documento e evento de auditoria em cada exportação; backup com confirmação explícita no import. | `pdf_export_service.dart:1544-1552`; `backup_service.dart:166-180` | Exportação rastreada; arquivo protegido; import pede confirmação | 2 d |

---

## P2 — Robustez do produto (90 dias)

| # | Ação | Evidência | Critério de pronto | Esforço |
|---|---|---|---|---|
| P2.1 | **Trilha de auditoria sem expurgo dos mais antigos** (exportar/arquivar antes de podar). | `auditoria_service.dart:10,94-102` | Trilha exportável e sem perda silenciosa; teste | 1 d |
| P2.2 | **Novos eventos de auditoria**: eliminação, acesso/consulta, exportação, backup/restauração, remoção/regravação de áudio, alteração cadastral. | `auditoria_service.dart:19-34`; `AGENTS.md` (falta evento de áudio) | Eventos emitidos e visíveis no relatório | 1 d |
| P2.3 | **`_registrarAuditoria` com `await`** e falha visível. | `AGENTS.md` (auditoria backend) | Sem Future solto; falha gera alerta | 2 h |
| P2.4 | **Desligar o fallback silencioso do banco** em produção e fazer `/health` refletir a realidade. | `AGENTS.md` (`ALLOW_SQLITE_FALLBACK` default `true`) | `/health` reprova em fallback; escrita nunca confirma sucesso em banco volátil | 4 h |
| P2.5 | **Áudio**: política explícita de retenção, exclusão aguardada (`await`) e evento de auditoria. | `AGENTS.md` (`unawaited`); `politica_privacidade_page.dart` (nada sobre áudio) | Comportamento declarado = comportamento real | 1 d |
| P2.6 | **Menores de idade**: campos de responsável legal e consentimento específico (art. 14). | Nada encontrado no app | Fluxo implementado e documentado no material do psicólogo | 2 d ⚖️ |
| P2.7 | **WhatsApp**: alternativa oficial ou consentimento específico do titular + registro. | `compromisso.dart:159-171`; `lembrete_service.py:92-114` | Decisão registrada; consentimento coletado quando aplicável | 3 d ⚖️ |
| P2.8 | **Log de erro de provedor sem conteúdo**: nunca gravar `resp.text` com eco de material clínico. | `ia_clinica.py:673-676` | Log revisado; nenhum conteúdo clínico em log | 2 h |
| P2.9 | **Backup/exportação revisados**: cifra, aviso, destino e rastreio de compartilhamento. | `politica_privacidade_page.dart:52`; `pdf_export_service.dart` | Documento 12 e 14 refletem o comportamento verificado | 2 d |
| P2.10 | **Tela do titular no app** (ou link externo) para pedidos dos arts. 18 e 20. | `pdf_arquitetura_lgpd_service.dart:245` (previsto, não implementado) | Solicitação registrada e rastreável | 3 d |
| P2.11 | **Restringir CORS de produção** (remover `localhost`, limitar métodos/headers). | `main.py:647-664` | Lista de origens apenas de produção | 2 h |
| P2.12 | **Cifrar os campos hoje em claro no Hive**: data de nascimento, tipo/modo de atendimento, valores/status/forma de pagamento, data da sessão, flags. | `models/paciente.dart:13-14,19-20,49-50`; `models/sessao.dart:20,119-120,158-168`; `sessao_service.dart:80` | Nenhum campo sensível em claro no armazenamento | 2 d |
| P2.13 | **Vincular a chave mestra à autenticação do usuário** e definir rekey/recuperação (hoje a perda do Keystore é irreversível e o backup só abre no mesmo aparelho). | `encryption_service.dart:70,252-264`; `backup_service.dart:191-194` | Recuperação documentada e testada | 3 d |
| P2.14 | **Remover ou cercar código morto perigoso**: `removerCriptografiaExistente` em 11 serviços, `excluirPaciente`, `onboarding_page.dart`, `migrarParaGcm`. | `paciente_service.dart:168`; `sessao_service.dart:252`; `configuracoes_service.dart:178`; `AGENTS.md:1698-1706` | Código removido ou protegido por teste que impede uso acidental | 1 d |
| P2.15 | **Backup completo** (hoje não inclui compromissos, anamnese, escalas, avaliação inicial nem auditoria) e **teste de restauração** periódico. | `backup_service.dart:33-154`; `docs/auditoria_app_2026-09-06.md:36-52` | Restauração de prontuário completo validada em teste | 2 d |
| P2.16 | **iOS em conformidade**: `NSFaceIDUsageDescription`, `ITSAppUsesNonExemptEncryption` e nome de exibição corrigido. | `ios/Runner/Info.plist:10` | App aprovado sem pendência de privacidade | 4 h |
| P2.17 | **Isolar dados de demonstração** de dados reais (seed "Linda M. Tester"). | `demo_data_service.dart:35-78`; `main.dart:192` | Demo em espaço próprio, jamais misturado ao prontuário | 4 h |
| P2.18 | **Aceite do profissional com data e versão** no onboarding (e remover o onboarding morto). | `perfil_profissional_form_page.dart:918-922`; `onboarding_page.dart:9-21` | Aceite versionado, recuperável e auditável | 1 d |
| P2.19 | **iOS: excluir o prontuário do backup do iCloud** (`NSURLIsExcludedFromBackupKey`) — a diretriz Apple 5.1.3(ii) veda dado de saúde no iCloud. | Não encontrado no código | Diretório do Hive marcado como excluído de backup e verificado em aparelho | 4 h |
| P2.20 | **Declaração de app de saúde no Play Console** (formulário obrigatório) coerente com o produto. | Exigência de loja | Formulário preenchido e conferido com o documento 15 | 2 h |

---

## P3 — Melhoria contínua

| # | Ação | Critério de pronto |
|---|---|---|
| P3.1 | **RIPD e ROPA revisados a cada mudança relevante** (novo provedor, novo campo, novo país). | Revisão trimestral registrada no documento 17 |
| P3.2 | **Treinamento do psicólogo** sobre o material do titular (documento 14). | Material publicado e linkado no onboarding |
| P3.3 | **Teste de restauração de backup** e simulacro de incidente. | Registro de execução anual |
| P3.4 | **Revisão de dependências e CVEs** com impacto em privacidade. | Ciclo contínuo do projeto (já existe) |
| P3.5 | **Acompanhar a regulamentação da ANPD** sobre IA e dados sensíveis. | Nota de atualização semestral |

---

## Ordem recomendada de execução

```
Semana 1   P0.1  P0.5  P0.6  P0.7  P0.10  P0.11
Semana 2   P0.8  P0.9  + decisões P0.2 / P0.3  → reavaliar o RIPD com a decisão tomada
Semana 3   P0.4  P1.1  P1.2  P1.3  P1.8
Semana 4   P1.4  P1.5  P1.6  P1.7  P1.12  P1.13
Semana 5   P1.9  P1.10  P1.11  P1.14  P1.16  →  publicar nas lojas
Semanas 6+ P1.15  P2 e P3
```

> Os itens P0.7 a P0.9 são de **segurança do dado no aparelho** (desbloqueio fail-open, áudio em
> claro, chave em memória) e devem entrar **antes** de qualquer release, mesmo que o release não seja
> para as lojas: são falhas que já expõem o prontuário hoje.

**Regra de ouro:** nenhuma afirmação em documento público sem comportamento correspondente no
código. Se o comportamento ainda não existe, o texto descreve o estado atual — e a mudança entra
no plano, não na promessa.
