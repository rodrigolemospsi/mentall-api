# Correções de Segurança - 20/08/2026

## Contexto
Análise de segurança baseada no skill `security-and-hardening` identificou vulnerabilidades críticas/altas no armazenamento local de dados sensíveis.

---

## Vulnerabilidades Corrigidas

### 🔴 CRÍTICO

| # | Vulnerabilidade | Arquivo | Correção |
|---|----------------|---------|----------|
| 1 | Certificate pinning desativado em produção | `lib/main.dart:32-36` | Populado `_certFingerprints` com SHA-256 do certificado Fly.io |
| 2 | CompromissoService sem criptografia (PII) | `lib/services/compromisso_service.dart` | `EncryptedServiceMixin` + criptografia `titulo`, `observacoes` |
| 3 | ProgressoService sem criptografia (dados clínicos) | `lib/services/progresso_service.dart` | `EncryptedServiceMixin` + criptografia `sintomasJson`, `metasJson`, `avaliacaoGeral`, `tendencia` |
| 4 | PacoteService sem criptografia (dados financeiros) | `lib/services/pacote_service.dart` | `EncryptedServiceMixin` + criptografia `observacoes` |
| 5 | ConfiguracoesService sem criptografia (template contrato, URL servidor) | `lib/services/configuracoes_service.dart` | `EncryptedServiceMixin` + criptografia `contratoTemplate` |
| 6 | `tryDecrypt` retorna texto puro na falha | `lib/services/encryption_service.dart:102-109` | Alterado para exigir `configurado == true` e não fazer fallback |
| 7 | Import de backup não exigia PIN | `lib/screens/backup_restore_page.dart:110-128` | Reutilizado `_validarAutenticacaoAntesExportar()` |

### 🟠 ALTO

| # | Vulnerabilidade | Correção |
|---|----------------|----------|
| 8 | Providers não passavam encryption para novos services | `lib/providers/service_providers.dart` | Atualizados: `compromissoServiceProvider`, `configuracoesServiceProvider`, `pacoteServiceProvider`, `progressoServiceProvider` |
| 9 | `removerCriptografiaExistente` vazio em 4 services | Múltiplos | Implementados com migração legado (2:CBC → 3:GCM) |

---

## Serviços que NÃO precisavam de alteração

| Serviço | Motivo |
|---------|--------|
| `LembreteService` | Não armazena dados localmente (só backend + notificações locais) |
| `IaClinicaService` | Não armazena localmente (só HTTPS) |
| `TranscricaoRelatoService` | Não armazena localmente (lê arquivo já criptografado) |
| `AudioRelatoService` | Já criptografa arquivos de áudio no disco (formato MAV1) |

---

## Certificado Fixado (Certificate Pinning)

```dart
// lib/main.dart
static const _certFingerprints = <String>[
  'SHA256 Fingerprint=F6:3E:15:49:6D:97:94:61:45:C9:E5:D5:CC:21:C8:3F:12:DD:2E:35:14:DD:9A:B2:21:40:85:69:53:71:9B:19',
];
```

Obtido via:
```bash
openssl s_client -connect mentall-api.fly.dev:443 -servername mentall-api.fly.dev </dev/null 2>/dev/null | openssl x509 -fingerprint -sha256 -noout
```

**Nota**: Let's Encrypt renova a cada ~90 dias. Atualizar este fingerprint no próximo deploy.

---

## Testes e Build

- `flutter analyze`: 0 erros (47 warnings/info cosméticos)
- `flutter test`: 96/96 passando
- `flutter build apk`: Sucesso (77.1MB)

---

## Próximos Passos (Fase 2 - Médio)

- [ ] Política de complexidade de senha (mín. 8 chars, maiúscula, número, especial)
- [ ] Rate limiting com Redis (se escalar para múltiplas instâncias Fly.io)
- [ ] Documentar necessidade de "Senha de app" Gmail (16 chars) no README