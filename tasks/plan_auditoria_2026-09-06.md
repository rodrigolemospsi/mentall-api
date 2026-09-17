Rodrigo, plano de execucao incremental das demandas de `docs/auditoria_app_2026-09-06.md`.

**Regras**
- Preservar alteracoes locais, dados, arquivos de backup e chaves existentes.
- Sem commit, deploy, mudanca de secrets, reinstalacao ou novo APK sem pedido especifico.
- TDD por correcao: reproduzir defeito, corrigir e verificar. Backend isolado de rede, dotenv e bancos reais.
- O relatorio e historico da auditoria; a situacao atual fica no checklist de execucao.

**Lote 1**
1. Backend: retorno publico minimo da anamnese; cadastro pendente vinculado atomicamente a credenciais/token da mesma tentativa; perguntas clinicas sem pre-resposta. Aceite: nenhum conteudo anterior no POST publico, senha antiga nao ativa com link novo, perguntas obrigatorias exigem interacao. Testes unittest isolados. Fronteira independente do Flutter.
2. Backup: uma camada de envelope, leitura limitada do envelope duplo ja emitido, falha explicita se cifragem indisponivel e prevalidacao de todos os registros antes de escrever. Aceite: round-trip real agendado, arquivo invalido deixa banco intacto, falha de cifragem nao cria arquivo/data de sucesso. Testes Flutter de servico. Nao prometer atomicidade contra encerramento de processo sem implementacao duravel.
3. Flutter: retirar instrucao de apagar dados, corrigir mascara/validacao de nascimento, propriedade do player e URL do progresso. Aceite: testes de acao efetiva, digitacao parcial e navegacao repetida; analise estatica.
4. Integracao: revisao independente, suites completas, documentacao de resolvidos/parciais/pendentes. Nao misturar uma reescrita geral de arquitetura a estas correcoes.

**Proximos Lotes**
- Recuperacao portavel e inventario completo do backup; restauracao duravel/rollback entre boxes.
- Gate persistente sobre navegacao, politica de biometria, purga coordenada de chaves/caches, retencao de audio.
- Consumo idempotente de pacotes, financeiro reativo, operacoes async do editor e consistencia de banco remoto.
- Isolamento WhatsApp/contas, rate limit/proxies, CI/release, acessibilidade e performance medida.

**Decisoes Necessarias**
- Recuperacao do backup em aparelho novo: segredo independente precisa ser escolhido, apresentado/confirmado e guardado para backups automaticos; nunca exportar chave em claro como atalho.
- Politica quando biometria falha: nao substituir sem confirmacao a decisao anterior de fallback silencioso por bloqueio absoluto.
- Assinatura de release e infraestrutura: exigem configuracao externa e ensaio de continuidade dos dados, nao mudanca cega no Gradle/producao.
