Rodrigo, este relatorio transforma a revisao do codigo atual em demandas verificaveis. A prioridade e preservar dados clinicos, impedir acesso indevido e corrigir fluxos antes de investir em acabamento visual.

> Registro historico anterior as correcoes. Primeiro lote implementado depois da auditoria:
> [situacao, testes e pendencias](../tasks/todo_auditoria_2026-09-06.md).

**Escopo**
- Data: 06/09/2026. Base: HEAD `958e38e`, incluindo as alteracoes locais presentes no inicio da revisao. Versao declarada: `1.0.35+36`.
- Alteracoes preexistentes preservadas: `AGENTS.md`, `lib/screens/configuracoes_page.dart`, `lib/services/auth_service.dart`, `pubspec.yaml`, `test/services/auth_service_test.dart`.
- Revisao ampla de Flutter, backend, templates HTML, persistencia, autenticacao, integracoes, testes e configuracao de entrega. Quatro frentes independentes, seguidas de conferencia dos encadeamentos mais importantes.
- Nao significa leitura individual integral de arquivos gerados, binarios, assets e dependencias. Nao foram lidos segredos, prontuarios ou logs reais.
- Nenhuma funcionalidade corrigida; nenhum deploy, commit, pentest em producao ou envio real de mensagem. Somente este documento foi acrescentado ao workspace.
- Nao houve renderizacao em aparelho/navegador, auditoria de CVEs atualizada, inspecao da infraestrutura efetivamente implantada nem medicao de heap, frames ou p95.

**Evidencias**
- `R`: comportamento reproduzido localmente, com dados sinteticos e dependencias externas isoladas.
- `C`: encadeamento identificado no codigo; nao reproduzido ponta a ponta em aparelho/HTTP.
- `V`: risco ou demanda que precisa de verificacao contextual, visual ou de carga. Nao e vulnerabilidade explorada.
- `P1`: resolver antes de ampliar o uso ou publicar; `P2`: proximo ciclo de estabilizacao; `P3`: melhoria planejada. Prioridade nao e classificacao CVSS.
- Referencias apontam para as linhas da arvore revisada. Podem mudar em futuras edicoes.

**Verificacao**
| Verificacao | Resultado | Ressalva |
| --- | --- | --- |
| `flutter analyze --no-pub` | Sem erros; 1 warning | `_todosBlocos` sem uso em `tools/gerar_prompts_ia_pdf.dart:36`; comando nao retorna analise totalmente limpa |
| `flutter test --no-pub --reporter expanded` | 177/177 aprovados | Houve warning de tap fora da tela, logs de Hive ausente em testes de perfil e avisos de fonte PDF |
| Backend via unittest isolado | 137 testes aprovados, em duas execucoes | Primeira: 132 aprovados e 5 bloqueados pelo harness; segunda: esses 5 aprovados apos permitir leitura do template de teste |
| Reproducoes adicionais Flutter | 4/4 confirmaram os defeitos atuais | Nao sao testes de correcao; exercitam comportamento defeituoso com asserts correspondentes |
| Reproducoes adicionais backend | 2 encadeamentos confirmados | Handlers e SQL em memoria, sem servidor externo, SMTP ou middleware HTTP real |

O backend foi executado com ambiente limpo, `load_dotenv` neutralizado antes dos imports, SQLite `:memory:`, rede/SMTP bloqueados e scheduler nao iniciado. A liberacao posterior foi somente para leitura de `backend/templates/anamnese.html` pelos cinco testes.

O teste temporario Flutter fica fora do repositorio em `/var/folders/kg/mgdw56q15lqdrfp77z7p2b7m0000gn/T/opencode/backup_auditoria_temporaria_test.dart`. Executado com `flutter test --no-pub <caminho-absoluto> --reporter expanded`. Hive e arquivos sinteticos foram removidos pelo teardown.

**Dados E Acesso**

**01. P1 / R: backup automatico nao restaura pelo fluxo atual**
- Evidencia: `lib/services/backup_service.dart:153-164,183-209`; `lib/services/backup_agendamento_service.dart:46-63`.
- Causa: exportar ja cifra; agendamento cifra novamente; importacao abre apenas uma camada. O arquivo e a data de sucesso sao gravados, mas a restauracao retorna "versao nao encontrada".
- Demanda: uma unica camada responsavel pelo envelope; tratar explicitamente arquivos duplamente envelopados ja produzidos, sem aceitar recursao ilimitada.
- Aceite: agendamento real -> arquivo -> importacao restaura todos os registros. O teste deve usar os servicos reais com criptografia ativa, nao exportador fake em claro.

**02. P1 / R+C: backup nao tem recuperacao independente da chave original**
- Evidencia: `lib/services/encryption_service.dart:244-260,501-562`; `lib/services/backup_service.dart:183-198`; `lib/services/backup_storage_io.dart:17-24`.
- Causa: envelope depende da chave aleatoria da instalacao; conta, senha e biometria nao reconstituem essa chave. A rejeicao com uma chave B foi reproduzida. Sobrevivencia especifica do Keystore/Keychain a reinstalacao nao foi testada.
- Demanda: segredo de recuperacao/senha de backup independente, com desenho criptografico revisado; copia externa ao armazenamento do app; mensagem clara para chave incorreta. Nao enfraquecer o backup exportando a chave mestra em claro.
- Aceite: restaurar em instalacao limpa, com chave local diferente, usando somente arquivo e segredo de recuperacao. Confirmar perda do aparelho como cenario, nao apenas reimportacao na mesma instalacao.

**03. P1 / C: backup nao cobre o prontuario completo**
- Evidencia: `lib/main.dart:91-107`; `lib/services/backup_service.dart:30-151,212-217,439-461`; `lib/services/progresso_service.dart:29-40,60-71`.
- Faltam conjuntos como avaliacoes iniciais, anamneses enviadas/respondidas, escalas, compromissos e auditoria. Progresso e copiado do Hive sem abrir os campos cifrados pela chave de origem. Audio mobile exporta caminho, nao o arquivo correspondente.
- Demanda: inventario de recuperabilidade de cada box/campo/arquivo, incluindo exclusoes deliberadas informadas ao profissional. Abrir dados na origem e cifrar novamente no destino.
- Aceite: round-trip por conjunto, com contagem, relacoes e conteudo verificados sob chave nova; audio omitido nunca deve parecer recuperavel por um caminho antigo.

**04. P1 / R: importacao invalida modifica parcialmente o banco**
- Evidencia: `lib/services/backup_service.dart:204-284,286-349,468-469`; `lib/screens/backup_restore_page.dart:127-131`.
- Causa: basta existir `versao`; registros sao sobrescritos antes de validar os proximos. Reproduzido: primeiro paciente alterado e persistido, segundo item invalido causa erro, sem rollback.
- Demanda: validar schema, versao suportada, IDs e relacoes antes de escrever; restauracao atomica ou rollback; diferenciar sucesso/erro com resultado tipado. Legado em claro deve ter aviso explicito de autenticidade ausente.
- Aceite: qualquer erro conserva integralmente o banco anterior, inclusive apos fechar/reabrir Hive; UI nunca apresenta erro como sucesso verde.

**05. P1 / C: bloqueio local nao protege toda a navegacao**
- Evidencia: `lib/screens/login_page.dart:72-84`; `lib/screens/app_start_page.dart:81-89,103-128,161-171`; `lib/screens/configuracoes_page.dart:170-177`; `lib/services/auth_service.dart:266-272`.
- Causa: `pushReplacement` do login substitui a rota contendo `AppStartPage`, removendo observer/timer. Enquanto a rota existe, reconstruir seu conteudo tambem nao cobre as fichas/editores empilhados acima dela. Bloquear nao descarrega a chave.
- Demanda: controlador persistente de autenticacao acima do Navigator, cobrindo rotas e dialogs; politica coordenada para chave, caches, tarefas e reautenticacao remota.
- Aceite: pausa, retorno, inatividade e bloqueio manual protegem Home, ficha, editor e exportacao, inclusive depois de varios desbloqueios, sem depender da rota inicial ainda existir.

**06. P1 / C: lockout biometrico pode conceder acesso**
- Evidencia: `lib/services/auth_service.dart:172-190,213-225`; `lib/services/encryption_service.dart:287-320`.
- Causa: `biometricLockout`, `temporaryLockout`, `unknownError` e outros erros levam a leitura do cofre sem autenticar. Rejeicao simples e cancelamento sao tratados de outra forma.
- Contexto: o fallback de disponibilidade foi uma decisao de produto documentada; este achado explicita seu custo de seguranca. Nao tratar essa escolha como uma regressao acidental nem muda-la silenciosamente.
- Demanda: separar "sem biometria cadastrada" de "autenticacao bloqueada/erro"; usar credencial alternativa realmente verificada ou recuperacao explicita. Definir com Rodrigo a politica para aparelho sem bloqueio.
- Aceite: excesso de tentativas ou erro desconhecido nunca equivale a sucesso; validar os codigos reais emitidos pelos aparelhos suportados.

**07. P1 / R+C: fail-closed nao e garantido na persistencia**
- Evidencia: `lib/screens/app_start_page.dart:239-243`; `lib/services/encryption_service.dart:225-238,244-284,323-332,483-484`; `lib/services/encrypted_service_mixin.dart:6-15`; `lib/services/backup_service.dart:156-164`.
- Causa: retry so limpa uma flag; chave pode existir apenas em memoria; marcador de durabilidade e gravado antes da prova de migracao. Servicos e backup aceitam texto puro quando nao ha chave; export tambem retorna JSON claro se a tentativa de envelope falhar.
- Reproducao: backup sem chave foi gravado em claro pelos servicos e registrado como bem-sucedido. Isso prova o comportamento da camada de servico, nao que todo boot normal chega a esse estado.
- Demanda: invariante de escrita segura no servico, nao apenas na UI; retry real e marcador somente apos persistencia confirmada. Migracao de legado deve ser explicita e separada da escrita normal.
- Aceite: falha do storage/envelope nunca confirma escrita clinica desprotegida; nao perder chave existente ao retentar.

**08. P1 / R: POST publico da anamnese revela respostas anteriores**
- Evidencia: `backend/main.py:1375-1395`; `backend/services/anamnese_service.py:46-61`; contraste com owner no GET em `backend/main.py:1403-1414`.
- Reproducao: para anamnese ja respondida, POST com `{}` como respostas retornou conteudo clinico anterior sem JWT. Exige conhecer o token/link; nao demonstra adivinhacao de token.
- Demanda: retorno publico minimo de confirmacao, nunca respostas; leitura clinica somente autorizada; expirar/revogar links e aplicar `Cache-Control: no-store` onde adequado.
- Aceite: repetir POST nao revela respostas; owner correto le pelo endpoint protegido, outro owner nao; link expirado/revogado nao permite operacao.

**09. P1 / R: pre-cadastro pode ativar senha escolhida por terceiro**
- Evidencia: `backend/main.py:695-712`; `backend/services/usuarios.py:37-75,78-103`.
- Reproducao: dois cadastros pendentes para mesmo email, com senhas distintas; segundo link ativa a conta com a primeira senha. Primeira senha obtem JWT e segunda retorna 401.
- Condicao: terceiro inicia cadastro com email da vitima e esta depois confirma o cadastro legitimo. Nao e tomada de conta ja ativa nem ataque sem interacao.
- Demanda: associar verificacao de email a tentativa correta de definicao de credenciais; considerar verificar email antes de definir senha. Sobrescrever irrestritamente senha pendente nao resolve a disputa.
- Aceite: uma tentativa anterior nao consegue autenticar depois da ativacao legitima do titular.

**10. P1 / C contextual: WhatsApp global sobrepoe isolamento por profissional**
- Evidencia: `backend/services/lembrete_service.py:57-72,87-110`; `backend/main.py:947-955,1239-1255`.
- Causa: `WUZAPI_TOKEN`, se configurado, vence a busca por `owner_id`; outra conta pode usar a identidade WhatsApp global. Nao foi consultada a configuracao em producao.
- Demanda: resolver instancia pelo owner; eventual token legado precisa estar vinculado a um unico owner. Owner sem instancia nao envia.
- Aceite: A e B nunca enviam pela credencial um do outro, tanto no envio imediato como no scheduler.

**11. P1 / C: troca de credenciais mistura conta, JWT e dados locais**
- Evidencia: `lib/screens/configuracoes_page.dart:504-560`; `lib/services/api_client.dart:24-27,57-72,90-99,166-177`; `lib/main.dart:91-107`.
- Causa: mudar credenciais nao invalida coordenadamente token antigo nem troca as boxes/identidade local. Depois da reautenticacao, os mesmos pacientes podem alimentar outra conta. Mudar origem tambem exige impedir encaminhamento do JWT antigo.
- Demanda: fluxo explicito de conta/origem, com invalidacao e separacao dos dados ou bloqueio da troca sem migracao autorizada.
- Aceite: nenhuma requisicao usa token de outra origem; conta B nao herda silenciosamente prontuario de A.

**12. P1 / C: retencao real de audio diverge da escolha do usuario**
- Evidencia: `lib/services/audio_relato_service.dart:89-95,154-172,258-275,339-345,389-405,419-424,477-484`; `lib/screens/sessao_form_page.dart:1440-1445,1780-1782`.
- Causa: gravacao nasce em claro, cifra ao finalizar; playback produz temporario claro; remover limpa referencias; "nao manter" altera flag mas nao elimina caminho/conteudo. Cache claro nao e purgado no bloqueio.
- Impacto: residuos e retencao nao esperada, especialmente em encerramento abrupto. Nao se afirma acesso por qualquer aplicativo comum ao sandbox.
- Demanda: ciclo de vida de arquivos e cache, limpeza no fim/bloqueio/boot, tratamento de gravacao interrompida e cumprimento da escolha de retencao sem perder material ainda nao salvo.
- Aceite: cenarios normais e crash deixam somente os arquivos autorizados; sem temporarios claros apos finalizar o uso; politica auditavel e comunicada.

**13. P1 / C: fallback do banco pode abandonar escritas confirmadas**
- Evidencia: `backend/services/db.py:70-113`.
- Causa: queda do Turso habilita SQLite local; retorno troca a fonte ativa, sem reconciliar operacoes locais. Dados podem continuar no arquivo local, mas ficam fora da fonte consultada; disco efemero agrava risco de perda.
- Demanda: falhar explicitamente em escrita quando persistencia nao e garantida, ou construir fila duravel com replay e reconciliacao. Nao adicionar uma segunda base "temporaria" como se fosse alta disponibilidade.
- Aceite: toda operacao confirmada durante indisponibilidade reaparece apos recuperacao/reinicio; teste com duas bases isoladas.

**Fluxos Clinicos**

**14. P1 / C: editar sessao de pacote debita novamente**
- Evidencia: `lib/screens/sessao_form_page.dart:1372-1393`; `lib/services/pacote_service.dart:57-67`.
- Causa: criacao e edicao consomem sempre que o status final e `pacote`; consumo nao recebe identidade da sessao nem aguarda a gravacao.
- Demanda: consumo idempotente vinculado a sessao, transicoes financeiras explicitas e persistencia consistente.
- Aceite: criar e editar tres vezes consome um credito; falha ao salvar e mudanca de forma de pagamento nao corrompem saldo.

**15. P1 / C: anamnese transforma falta de resposta em resposta clinica**
- Evidencia: `backend/templates/anamnese.html:402-415,455-477`; `lib/services/anamnese_templates.dart:85-94`.
- Causa: Sim/Nao inicia em Nao e escalas com valor; obrigatoriedade so confere a existencia desse valor. Inclui seguranca emocional.
- Demanda: estado "nao respondido" distinto de escolha explicita; validacao no cliente e no servidor conforme o template.
- Aceite: enviar sem responder perguntas obrigatorias e bloqueado; campo intocado nao vira ausencia de risco ou intensidade avaliada.

**16. P1 / C: erro de abertura recomenda apagar dados do app**
- Evidencia: `lib/screens/sessao_form_page.dart:1458-1482`.
- Impacto: erro recuperavel de tela pode levar o profissional a apagar o prontuario. A causa nao foi diagnosticada e nao existe precondicao de backup restauravel nessa orientacao.
- Demanda: retirar instrucao destrutiva; oferecer retorno, suporte e diagnostico seguro. Procedimento de recuperacao destrutiva deve ser separado e exigir backup validado.
- Aceite: nenhum erro generico recomenda limpar armazenamento; dados permanecem intactos ao sair da tela.

**17. P2 / C: URL de progresso e concatenada duas vezes**
- Evidencia: `lib/services/ia_clinica_service.dart:211-217,303-326`.
- Causa: caller passa URL completa a helper que prefixa novamente `ApiClient.baseUrl`.
- Demanda: um unico contrato para caminho relativo ou `Uri`, com transporte injetavel.
- Aceite: teste verifica a URI efetivamente enviada e resposta realista de progresso, nao apenas parser de resultado.

**18. P2 / C: player compartilhado e descartado pela primeira tela**
- Evidencia: `lib/providers/service_providers.dart:109-113`; `lib/screens/sessao_form_page.dart:265,371-386`.
- Causa: provider persistente devolve a mesma instancia; `dispose` da tela fecha o player. Proxima sessao pode receber objeto descartado.
- Demanda: definir propriedade do recurso: instancia por editor ou provider com ciclo de vida coerente; um unico responsavel pelo descarte.
- Aceite: abrir A -> ouvir -> sair -> abrir B -> ouvir no mesmo `ProviderScope`; fake deve detectar uso apos descarte.

**19. P2 / C: Financeiro nao acompanha mudancas das sessoes**
- Evidencia: `lib/screens/financeiro_page.dart:30-37,340-344,386-412`; `lib/screens/main_shell.dart:30-39`.
- Causa: leitura por mes sem observar revisoes das sessoes; tela preservada no `IndexedStack`. Lista com objetos mutaveis e totais calculados podem divergir no callback de exportacao.
- Demanda: snapshot reativo por periodo, com lista e totais da mesma revisao.
- Aceite: mudar valor/status e voltar atualiza tela e dados do PDF sem trocar mes ou reiniciar.

**20. P2 / C: cadastro trava com data incompleta e mascara quebra na digitacao**
- Evidencia: `lib/widgets/novo_paciente_dialog.dart:120-138,247-293,327-353`.
- Causa: `substring(4, 8)` e chamado com 5-7 digitos; erro de formato retorna depois de `salvando=true`, sem limpar estado. `DateTime` tambem normaliza componentes invalidos, portanto regex de formato nao basta para validar calendario.
- Demanda: mascara segura, validacao completa antes de processar e finalizacao garantida; erro junto ao campo.
- Aceite: digitar/apagar ano parcial nao lanca; data impossivel e rejeitada; corrigir data incompleta permite salvar no mesmo dialogo.

**Estrutura E Carga**

**21. P2 / C: estado global do editor aceita resultados obsoletos**
- Evidencia: `lib/providers/sessao_form_providers.dart:62-78`; `lib/screens/sessao_form_page.dart:474-511,1788-1893`.
- Causa: identidade da sessao nao distingue duas geracoes na mesma sessao; retornos antecipados deixam flags ativas; reset incompleto. Artigos/progresso podem terminar depois de salvar/sair.
- Demanda: estado por editor e ID de geracao, invalidacao/cancelamento explicitos, `finally` seguro e politica para persistir ou descartar resultados tardios.
- Aceite: completar futures em ordem invertida, fechar durante busca e gerar sem historico nunca deixa spinner permanente nem substitui resultado novo pelo antigo.

**22. P2 / C: concorrencia do banco nao garante transicao unica**
- Evidencia: `backend/services/db.py:12-13,116-140`; `backend/services/anamnese_service.py:46-68`; `backend/services/contrato_service.py:43-64`.
- Causa: conexao global e fluxos SELECT -> UPDATE incondicional; duas submissoes podem ler pendente e sobrescrever a resposta/aceite anterior. No SQLite compartilhado, commit pertence a conexao, nao a requisicao.
- Demanda: unidade de trabalho/transacao e UPDATE condicionado ao estado anterior, com rollback. Separar inicializacao/migracoes dos imports para facilitar isolamento.
- Aceite: duas submissoes simultaneas produzem uma transicao; a perdedora obtem estado consolidado sem sobrescrever a vencedora.

**23. P2 / C: scheduler bloqueia cancelamento durante o lote de envios**
- Evidencia: `backend/services/lembrete_service.py:191-252,282,311-317`; `backend/services/db.py:221-226`.
- Causa: `_LOCK` permanece durante envios sequenciais; agendar/cancelar espera todo o lote. Consulta de vencidos nao possui indice correspondente a status/horario.
- Custo: cresce com soma das duracoes dos envios. Trinta chamadas levando 20 segundos cada significariam aproximadamente dez minutos: exemplo condicional, nao medicao nem teto absoluto.
- Demanda: reservar lote limitado em transacao curta, liberar lock antes de I/O, concorrencia limitada e verificacao de cancelamento antes do despacho; indice adequado.
- Aceite: transporte lento nao bloqueia cancelamento de itens ainda nao despachados nem agendamento pelo tempo total do lote.

**24. P2 / C: retries multiplicam espera e trabalho remoto**
- Evidencia: `lib/services/ia_clinica_service.dart:198-249`; `backend/services/ia_clinica.py:304-312,537-550,606-627`; `backend/main.py:834-846`.
- Causa: timeout Flutter nao aborta explicitamente requisicao/trabalho remoto; retries do app se somam a retries dos SDKs e fallback de provedores.
- Orcamento configurado no caminho de excecoes: tres esperas de 150s + 2s + 4s = 456s, antes de outros custos. Nao e latencia medida. A estimativa historica de 3 x 45s nao e deadline global.
- Demanda: deadline total, retries explicitos numa camada, deduplicacao por operacao e limites de concorrencia/custo.
- Aceite: timeout nao inicia geracoes independentes ilimitadas; deadline e consumo observaveis com transporte/relogio controlados.

**25. P2 / C: contadores mantem assinaturas e varreduras acumuladas**
- Evidencia: `lib/providers/service_providers.dart:222-234`; `lib/services/sessao_service.dart:186-202`.
- Causa: familia sem `autoDispose` observa a box mesmo depois de sair da ficha; cada paciente visitado recalcula duas contagens varrendo sessoes.
- Custo identificado: ordem de V x S por evento, com V pacientes visitados e S sessoes. Nao foi medido impacto em frames.
- Demanda: descarte das assinaturas sem consumidores; depois avaliar contagens agrupadas/indices se necessario.
- Aceite: assinatura encerrada ao sair; numero de inspecoes por evento nao cresce indefinidamente com historico de navegacao.

**26. P2 / V: PDF extenso precisa de ensaio de paginacao e bloqueio**
- Evidencia: `lib/services/pdf_export_service.dart:419-481,888-892,1197-1228`; `test/services/pdf_export_service_test.dart:38-68`.
- Risco: agrupamentos aninhados grandes podem nao se dividir entre paginas; o teste atual de URL longa nao representa um texto clinico maior que uma pagina. Layout sincrono tambem nao e interrompido por `Future.timeout` no mesmo isolate.
- Demanda: reproduzir com sessoes extensas, campos maiores que pagina e prontuario grande; usar blocos paginaveis. So decidir mudanca de isolate apos medir e separar fontes/dados do trabalho transferivel.
- Aceite: conteudo integral com sentinelas inicio/meio/fim, numero de paginas coerente, processo com limite externo de tempo e UI responsiva. Nao foi confirmado travamento atual em release.

**Design E Acesso**

**27. P2 / C: formularios perdem edicoes sem confirmacao**
- Evidencia: `lib/screens/perfil_profissional_form_page.dart:118-124,314-325`; `lib/widgets/novo_paciente_dialog.dart:36-42`; `lib/widgets/compromisso_form_dialog.dart:22-34`.
- Demanda: detectar alteracoes e confirmar descarte em voltar, Escape e toque externo; preservar formulario quando usuario escolhe continuar.
- Aceite: saida incidental nao perde alteracoes; formulario intocado nao exige confirmacao desnecessaria.

**28. P2 / C: semantica e teclado incompletos no HTML e Flutter**
- Evidencia: `backend/templates/anamnese.html:359-390,410-450,479-481,522-560`; `lib/widgets/paciente_card_home.dart:194-212`; `lib/screens/perfil_profissional_form_page.dart:410-447`; `lib/widgets/sessao_artigos_sugeridos.dart:126-141,180-197`.
- Causa: perguntas nao associadas programaticamente aos inputs, Sim/Nao sem estado acessivel, feedback sem anuncio/foco; algumas acoes Flutter dependem de gesto/text span sem alvo de foco equivalente.
- Demanda: labels/grupos associados, controles nativos ou semantica completa, feedback acessivel e acoes focaveis. Testar TalkBack/VoiceOver e teclado, nao apenas contar widgets `Semantics`.
- Aceite: pergunta, obrigatoriedade e selecao anunciadas; foco encontra erros e todas as acoes podem ser ativadas sem toque.

**29. P2 / C+V: ampliacao de texto limitada e contraste insuficiente**
- Evidencia: `lib/main.dart:309-315`; `backend/templates/anamnese.html:83-104,196,401-407`.
- Codigo limita escala a 150%. Calculo dos pares CSS: `#94A3B8`/branco = 2,56:1; `#E65100`/`#FFF3E0` = 3,46:1, insuficientes para os textos normais identificados.
- Demanda: permitir 200% e adaptar layout; cores de texto informativo/alerta com pelo menos 4,5:1. Manter a identidade violeta, nao redesenhar a marca sem necessidade.
- Aceite: conta, perfil, ficha, sessao e dialogs operaveis a 200%, em 320/600/768 pixels logicos, paisagem e teclado aberto; medir contrastes finais claro/escuro renderizados.

**30. P3 / V: falta matriz visual e de estados de interface**
- Evidencia a exercitar: grid de pacientes com altura fixa, dropdowns longos do perfil, linhas de chips, financeiro e PDFs; testes existentes nao constituem essa matriz.
- Demanda: inventario de telas/estados vazio, carregando, offline, erro, sucesso, permissao negada; screenshots/goldens selecionados e testes em 320/768/1024/1440 quando aplicavel. Validar alvos de toque e foco visivel.
- Aceite: evidencias por plataforma e tamanho; nenhum conteudo/acao cortado. Nao se afirma overflow em telas que nao foram renderizadas.

**Backend E Entrega**

**31. P1 / C contextual: rate limit e proxy precisam de fronteira consistente**
- Evidencia: `backend/main.py:98-189,648-650,695-697,794-795,825-826,873-874,905-906`; `Dockerfile:11`.
- Causa: conta substitui limite por IP, path literal cria bucket por token, IA nao tem cota por owner. Limpeza percorre todos os buckets. Proxy confia automaticamente em IP privado/link-local; CIDRs sao tratados como strings, sem pertencimento de rede. Uvicorn pode reescrever client antes da verificacao.
- Demanda: limites cumulativos origem/conta/owner/rota normalizada, teto global de consumo e cardinalidade; proxy explicitamente autorizado e configuracao coerente com servidor ASGI.
- Aceite: alternar emails/tokens nao evita limite agregado; trocar IP nao renova cota do owner; cliente privado nao autorizado nao escolhe IP por XFF. Validar integrado ao ingresso real antes de afirmar explorabilidade publica.

**32. P2 / C: recuperacao enumera emails e suspensao nao e efetiva**
- Evidencia: `backend/main.py:1548-1560,1577-1583,547-564,669-684`; `backend/services/usuarios.py:94-101,117-123`.
- Dois controles a corrigir: respostas de recuperacao diferem para email existente/inexistente/falha SMTP; login rejeita pendente, mas nao exige ativo, JWT nao tem revogacao por estado e confirmacao pode reativar outro status.
- Demanda: mesma resposta externa de recuperacao; estados de conta explicitos, confirmacao somente pendente -> ativo e SLA de revogacao. Suspensao e demanda operacional, nao se presume painel administrativo ja implementado.
- Aceite: respostas indistinguiveis; conta suspensa nao recebe JWT nem e reativada por link; token anterior revogado no prazo definido.

**33. P2 / C+V: webhook e links precisam de endurecimento operacional**
- Evidencia: `backend/main.py:1030-1058`; `backend/services/lembrete_service.py:329-380`; templates e headers de paginas publicas.
- Causa: limite JSON depende de `Content-Length`, lista de `MessageIDs` nao tem teto, DB sincrono roda no handler async e tipos inesperados geram erro. Requer token valido nesse caminho. Query token ainda e aceita; CSP permite inline.
- Demanda: limite real de bytes na leitura, schema/teto por evento, I/O fora do event loop; concluir migracao para header; minimizar tokens em access logs; nonces/hashes ou scripts externos para CSP; revogacao/retencao dos links.
- Aceite: payload sem Content-Length acima do teto e rejeitado antes de materializar; tipos invalidos nao geram 500; excesso de IDs nao multiplica trabalho ilimitado. CSP permissiva isoladamente nao prova XSS.

**34. P1 / C: deploy nao exige testes e ha teste verde sem acionar salvar**
- Evidencia: `.github/workflows/deploy.yml:1-17`; `test/widgets/sessao_form_page_test.dart:183-203`; `test/services/backup_agendamento_service_test.dart:108-123`.
- Causa: push em master dispara deploy diretamente, sem jobs de analise/testes. Na execucao atual, teste de salvar gerou warning de tap fora da tela e passou conferindo conteudo que ja existia. Teste de backup agendado usa fake claro.
- Demanda: gates de Flutter/backend/build antes de deploy e em PR; isolamento de DB/env nos testes; falhar taps perdidos; asserts de mudanca efetiva e testes entre servicos reais.
- Aceite: falha impede deploy; salvar precisa alterar dado e persistir apos reabertura; cenarios 01-24 ganham regressao adequada. Nao medir qualidade so pela contagem de testes.

**35. P1 / C: Android release usa assinatura de debug**
- Evidencia: `android/app/build.gradle.kts:29-32`.
- Demanda: assinatura de producao/upload, protecao e backup da chave, Play App Signing e procedimento de continuidade para instalacoes existentes. Nao substituir/desinstalar no aparelho clinico antes de validar recuperacao.
- Aceite: artefato inspecionado usa certificado esperado; instalacao/atualizacao e continuidade dos dados testadas. A configuracao prova o problema no build, nao a assinatura de cada APK antigo.

**36. P1 / C contextual: contexto Docker inclui residuos locais**
- Evidencia: `Dockerfile:5-8`; `.dockerignore:1-28`; existencia de `backend/.venv/`, `backend/backend.launchd.log` e `backend/backend.launchd.err.log`.
- Causa: `COPY backend/ .` inclui o que nao e excluido; ignore nao cobre `.venv` nem logs launchd. Em build local/remoto a partir deste workspace, residuos podem ser enviados/incorporados. Em checkout limpo de CI, arquivos nao versionados podem nao existir.
- Demanda: permitir somente entradas necessarias ou excluir ambientes/logs/artefatos explicitamente; usuario nao-root no container; imagem/base/actions fixadas conforme politica de supply-chain.
- Aceite: listar contexto e conteudo da imagem sem secrets, logs, DB ou venv local. Nao houve leitura dos logs nem comprovacao de vazamento na imagem de producao.

**37. P2 / C+V: iOS ainda nao tem preparacao equivalente ao Android**
- Evidencia: `ios/Runner/Info.plist:9-18,28-29`; `pubspec.yaml:91-96`.
- Nome ainda e legado, geracao de icone iOS desativada e plist nao declara justificativa Face ID nem camera/fototeca. Necessidade de cada permissao deve seguir os caminhos/plugins realmente usados.
- Demanda: nome/icones, configuracao de permissoes/entitlements, assinatura e validacao de microfone, fotos, biometria, backup e compartilhamento em dispositivo iOS.
- Aceite: build e fluxos reais em aparelho, sem assumir paridade por Flutter compilar no Android. Nao foi executado build iOS nesta auditoria.

**38. P2 / C+V: dependencias e entrega nao sao totalmente reproduziveis**
- Evidencia: `backend/requirements.txt:1-16`; `Dockerfile:1-6`; `.github/workflows/deploy.yml:13-15`. Flutter possui `pubspec.lock`; backend fixa diretas, nao uma arvore completa com hashes.
- Demanda: resolver/registrar dependencias transitivas, auditar versoes efetivamente instaladas e artefato final, definir politica de atualizacao e pin de actions por commit. Nao fazer upgrades em massa sem testes.
- Aceite: instalacao limpa reproduz a arvore, inventario/SBOM e advisories triados por alcance. A revisao atual nao autoriza afirmar "zero CVEs".

**39. P2 / C+V: arquitetura, documentacao e operacao precisam de fonte atual**
- Evidencia: `README.md:1-17` ainda e template; `backend/main.py` concentra 1705 linhas; `lib/screens/sessao_form_page.dart` 1901; `AGENTS.md` combina decisoes atuais e historico contraditorio sobre auth, stack, estado e deploy.
- Demanda estrutural: separar configuracao/boot, auth e routers por dominio no backend; no Flutter, propriedade de estado/recursos por editor e fronteiras testaveis de HTTP/storage. Nao dividir arquivos apenas para reduzir linhas nem reescrever toda a arquitetura.
- Demanda documental: README operacional curto, arquitetura atual, ADRs de autenticacao/recuperacao e arquivo historico separado; nao usar relatorio de pentest antigo como prova da arvore atual.
- Demanda operacional: metricas sem PII para restauracoes, storage indisponivel, filas, falhas de entrega, latencia/erros/custo de IA; alertas e runbook de recuperacao. Inventariar quais dados vao a Turso/IA/WhatsApp, retencao e contratos de tratamento. "Dados no aparelho" nao descreve sozinho esses fluxos.
- Aceite: outro desenvolvedor sobe ambiente de teste sem tocar producao; procedimentos de incidente e restauracao ensaiados; metricas comprovam o comportamento, nao apenas health HTTP. Validacao juridica/LGPD permanece especializada, nao certificada aqui.

**Ordem Recomendada**
1. Contencao: remover orientacao de apagar dados; tratar exposicao de anamnese, pre-cadastro e token WhatsApp compartilhado; impedir ampliacao do uso com esses riscos.
2. Recuperabilidade: demandas 01-04 e 07. Preservar aparelho, arquivos e chaves existentes ate haver restauracao comprovada. Nao recomendar reinstalacao como diagnostico.
3. Acesso: demandas 05-06 e 11-12, com teste em aparelho e decisao explicita sobre fallback. Integrar estado de autenticacao, navegacao e operacoes, em vez de remendar cada tela.
4. Integridade clinica/financeira: demandas 13-16 e 20; depois 17-19 e 21-22. Testar transicoes e falhas, nao apenas caminho feliz.
5. Portao de entrega em paralelo: 34-36; preparar 37-38 antes da plataforma correspondente. Cada correcao pequena entra com teste de regressao.
6. Carga e interface: 23-33, guiadas por medidas e matriz visual. Finalizar 39 para evitar regressao e dependencia da memoria do projeto.

**O Que Preservar**
- Identidade visual e design system existentes: cores por contexto, tipografia, raio, espacamento e componentes compartilhados. Nao ha justificativa para rebranding nesta auditoria.
- AES-GCM nos caminhos atuais, HMAC do envelope, hashes de senha/token, SQL parametrizado e verificacoes de owner existentes. Os problemas estao nas fronteiras e fluxos, nao exigem abandonar todas essas bases.
- Separacao de artigos reais da geracao de texto e busca assincrona, desde que identidade/cancelamento sejam corrigidos.
- Testes ja existentes, ampliando integracao e qualidade dos asserts. Os 177 + 137 resultados verdes sao uteis, mas nao cobrem os encadeamentos encontrados.

**Conclusao**
Ha uma base aproveitavel e funcionalidades relevantes, mas a prioridade nao e trocar cores nem adicionar mais recursos: e provar restauracao, bloqueio, isolamento de contas e integridade dos registros. A auditoria levanta 39 demandas agrupadas; nao afirma 39 vulnerabilidades exploradas. Parte e defeito reproduzido, parte e conclusao de codigo e parte e verificacao/decisao de produto ainda necessaria.
