# Anamnese com criptografia ponta-a-ponta (E2E)

Implementado em novembro/2026 (app 2.0.7+67; backend com colunas `e2e`/`cifrada`).

## Problema

O fluxo antigo gravava as respostas da anamnese em **texto claro** no servidor
(`anamneses.respostas`): dado pessoal sensível de saúde (LGPD art. 5º, II e
art. 11) legível por qualquer acesso ao banco/backup. A auditoria de LGPD do
projeto classificou o item como risco crítico (P0.4).

## Desenho escolhido — chave no fragmento do link

1. **App (profissional)**: ao criar a ficha, gera uma chave aleatória de 32
   bytes (AES-256-GCM) e a guarda **somente no aparelho**, cifrada pelo
   `EncryptionService` (AES-256-GCM com chave mestra no cofre do sistema).
2. O app envia ao backend apenas `e2e: true` (nenhum material de chave). O
   backend marca a ficha e passa a aceitar **somente** envelope cifrado.
3. O link enviado ao paciente é `https://.../anamneses/<token>#k=<chave>`.
   O **fragmento** (`#...`) não é enviado ao servidor pelo navegador — nem em
   requisições, nem em logs, nem no header `Referer`.
4. **Página pública**: lê a chave do fragmento, cifra o JSON das respostas com
   WebCrypto (AES-GCM, IV de 12 bytes, tag de 128 bits) e envia
   `{cifrada: true, iv, ct}`. O servidor valida apenas formato/tamanho e grava
   o envelope.
5. **Sync do app**: `GET /anamneses/{token}/status` devolve o envelope
   (`cifrada: true`, `iv`, `ct`); o app decifra localmente e grava as respostas
   em texto claro apenas no Hive local (cifrado em repouso).
6. Após o envio o navegador remove a chave da barra de endereço/histórico
   (`history.replaceState`).

O servidor nunca vê a chave nem o conteúdo em texto claro: mesmo com acesso
total ao banco, um vazamento não expõe as respostas.

## Compatibilidade

- Fichas criadas **antes** da atualização (`e2e = 0`) continuam funcionando no
  caminho legado em texto claro validado (necessário para links já enviados).
- A página pública usa `const E2E` injetado pelo backend para decidir o modo;
  uma ficha E2E aberta **sem** a chave no fragmento mostra "Link incompleto" e
  bloqueia o envio (o backend também rejeita com 422).
- A página mostra aviso "Suas respostas serão cifradas neste navegador".

## Limitações deliberadas

- **Perda do aparelho/dados do app = perda da chave.** As respostas cifradas
  no servidor tornam-se ilegíveis para sempre (nem o suporte consegue abrir).
  É o mesmo modelo de confiança do prontuário local-first; a UI avisa
  (`falhaDecifrar`) quando uma resposta não pode ser decifrada.
- O profissional deve reenviar o link **com a chave** (mensagem gerada pelo
  app). Copiar a URL sem o fragmento quebra o envio para fichas E2E.
- Fichas legadas pendentes que o paciente ainda não respondeu aceitam texto
  claro; recomendação: reenviar/criar uma nova ficha após a atualização e, no
  futuro, aplicar TTL/limpeza nas respostas antigas.
- Não há rotação de chave nem recuperação por terceiro (por design).

## Arquivos

- App: `lib/services/anamnese_e2e_crypto.dart` (AES-GCM via pointycastle),
  `lib/models/anamnese_enviada.dart` (campos `chaveCripto`, `e2e`,
  `falhaDecifrar`; campos 10–12 do adapter Hive), `lib/services/anamnese_enviada_service.dart`
  (gera chave no `criar`, decifra no `verificarStatus`, grava cópia cifrada),
  `lib/widgets/paciente_resumo_tab.dart` (`urlComChave` no WhatsApp e aviso de falha).
- Backend: `models/schemas.py` (`e2e`, `cifrada`, `iv`, `ct`), `services/db.py`
  (colunas + migrações), `services/anamnese_service.py` (`validar_payload_cifrado`,
  `registrar_resposta(cifrada=True)`), `main.py` (rotas e flag `E2E` na página),
  `templates/anamnese.html` (WebCrypto).
- Testes: `backend/tests/test_anamnese_e2e.py` (9),
  `test/services/anamnese_e2e_crypto_test.dart` (roundtrip + fixture WebCrypto),
  `test/services/anamnese_e2e_service_test.dart` (sync/cifra em repouso),
  fixture `test/fixtures/anamnese_e2e_webcrypto.json` gerado por
  `tool/gerar_fixture_anamnese_e2e.mjs`.
- Validação manual (01/11/2026): ficha E2E criada em backend local, aberta no
  Chrome via fragmento, respostas enviadas → banco com envelope `A256GCM`
  (sem texto claro) e decifração no WebCrypto retornando exatamente o enviado.

## Próximos passos (não incluídos)

- TTL/limpeza das respostas legadas em texto claro e das cifradas já entregues.
- Expiração/revogação dos links (P1.11).
- Migração opcional de fichas legadas pendentes para E2E quando reenviadas.
