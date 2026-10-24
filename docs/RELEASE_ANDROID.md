# Release Android assinado — MentAll PRO

Procedimento para gerar o **AAB da Play Store** e o **APK de release** assinados com a
upload key de produção. Vale para os itens 4.1/4.2/4.3 do checklist de publicação.

> **A chave e as senhas NUNCA ficam no repositório.** Elas moram em
> `~/.mentall-pro-keys/` (fora do Git, pasta `chmod 700`).

## 1. O que existe hoje (23/10/2026)

| Item | Onde |
|---|---|
| Keystore (PKCS12, RSA 4096, ~27 anos) | `~/.mentall-pro-keys/mentall-upload.jks` |
| Alias | `mentall-upload` |
| Variáveis de build (`MENTALL_*`) | `~/.mentall-pro-keys/release.env` (chmod 600) |
| Senha e instruções de backup | `~/.mentall-pro-keys/LEIA-ME.txt` (chmod 600) |
| Fingerprints SHA-1/SHA-256 | `~/.mentall-pro-keys/fingerprints.txt` |
| Hash do keystore (integridade do backup) | `~/.mentall-pro-keys/keystore.sha256` |

Sem essas variáveis, o build de release cai na assinatura **debug** (não serve para loja).

## 2. Como gerar o AAB/APK assinado

```bash
cd /Users/rodrigolemos/mentall-pro-app
source ~/.mentall-pro-keys/release.env
bash tools/build_release.sh            # analyze + testes + AAB + APK
# ou, para pular as checagens:
SKIP_CHECKS=1 bash tools/build_release.sh
```

Saídas:

- `build/app/outputs/bundle/release/app-release.aab` → upload na Play Store
- `build/app/outputs/flutter-apk/app-release.apk` → teste no aparelho (E2E do item 6.2)

O script valida a assinatura do APK com `apksigner verify --print-certs` antes de terminar.

## 3. Restaurar a chave em outra máquina

1. Copie a pasta `~/.mentall-pro-keys` do backup (gerenciador de senhas/pendrive cifrado).
2. `chmod 700 ~/.mentall-pro-keys && chmod 600 ~/.mentall-pro-keys/*`
3. Confira a integridade: `shasum -a 256 ~/.mentall-pro-keys/mentall-upload.jks`
   (deve bater com `keystore.sha256`).
4. Ajuste o caminho no `release.env` se necessário e rode o build.

## 4. Backup (obrigatório)

Sem a chave não é possível publicar **atualizações** do app. Guarde:

- a pasta `~/.mentall-pro-keys` inteira (keystore + senha + fingerprints);
- uma cópia em local diferente (gerenciador de senhas, cofre ou pendrive cifrado);
- **nunca** em WhatsApp/e-mail comum, GitHub, Drive público ou pasta compartilhada.

## 5. Primeiro upload na Play Store — Play App Signing

1. No Play Console, crie o app e aceite o **Play App Signing**.
2. Envie o `app-release.aab` como **upload key** (a chave local continua sendo a sua; o
   Google passa a custodiar a chave de assinatura do app).
3. Depois do primeiro upload, o Play Console mostra o **SHA-1 da chave de assinatura do app**:
   cadastre-o também no Google Cloud (ver §6).
4. Guarde o certificado de upload (`.der`) que o Play Console oferece na primeira vez.

## 6. Google Cloud — Google Sign-In / Google Calendar

O app usa Google Sign-In com o projeto `938362319829` e o cliente Android
`com.mentall.app`. O Google exige o **SHA-1 do certificado** que assina o build instalado:

1. Cadastre o SHA-1 da **upload key** (`~/.mentall-pro-keys/fingerprints.txt`) no cliente
   Android do projeto (Google Cloud → APIs & Services → Credentials → OAuth client).
2. Após habilitar Play App Signing, cadastre **também** o SHA-1 da **chave de assinatura do
   app** informado pelo Play Console (é o que os builds distribuídos pela loja usam).
3. Sem isso, o login Google/Calendar funciona em builds locais (upload key) mas falha na
   versão instalada pela loja.

## 7. Versionamento (item 4.3)

- `versionName`/`versionCode` vêm do `pubspec.yaml` (`version: X.Y.Z+N`).
- Cada upload na Play Store exige `versionCode` **maior** que o anterior.
- Criar tag no Git para a versão enviada: `git tag -a vX.Y.Z -m "release X.Y.Z"` (somente
  depois do upload aprovado).
