# Security Changelog — MentAll PRO

> Registro de vulnerabilidades identificadas, correções planejadas e status de execução.  
> Data da auditoria: 17/08/2026  
> Referência: Skill `security-and-hardening` + análise completa do codebase

---

## 🔴 CRÍTICO — Correção Obrigatória (Bloqueia Produção)

| ID | Título | Arquivo(s) | Status | Prioridade |
|----|--------|------------|--------|------------|
| SEC-01 | Remover fallback hardcoded `admin`/`admin` | `lib/services/api_client.dart:16-17`, `lib/services/auth_service.dart:70-72` | ✅ Concluído | P0 |
| **Commit:** `7ba0fdd` — Remove hardcoded credentials, exige configuração explícita
| SEC-02 | Exigir PIN antes de exportar backup | `lib/services/encryption_service.dart`, `lib/services/auth_service.dart`, `lib/screens/backup_restore_page.dart` | ✅ Concluído | P0 |
| **Commit:** `9defcfe` — Adiciona validarPin(), dialog de PIN antes de exportar
| SEC-03 | Eliminar fallback de áudio em texto puro | `lib/services/audio_relato_service.dart:386-409` | ✅ Concluído | P0 |
| **Commit:** `e613626` — Remove fallback, lança exceção se PIN não configurado
| SEC-04 | Criptografar log em arquivo | `lib/services/logger.dart`, `lib/main.dart` | ✅ Concluído | P0 |
| **Commit:** `9b85d2b` — Criptografa linhas antes de escrever no arquivo se PIN ativo
| SEC-05 | Implementar certificate pinning | `lib/main.dart:28-49` | ✅ Concluído | P0 |
| **Commit:** `a73d7dd` — Usa cert.der (DER), formata SHA-256, instruções para obter fingerprint
| SEC-06 | Migrar AES-CBC legado → AES-GCM | `lib/services/encryption_service.dart`, `lib/services/encrypted_service_mixin.dart` | ✅ Concluído | P0 |
| **Commit:** `9775ae3` — Adiciona migrarParaGcm() e migrarCamposLegados() para migração proativa
| SEC-07 | Lockout de PIN com backoff exponencial | `lib/services/encryption_service.dart`, `lib/screens/login_page.dart` | ✅ Concluído | P0 |
| **Commit:** `ff2f527` — 5 tentativas → backoff 1s,2s,4s,8s,16s,32s,60s; reseta no sucesso
| SEC-08 | Criptografar campos de auditoria | `lib/services/lgpd/auditoria_service.dart` | ✅ Concluído | P0 |
| **Commit:** (já implementado) — EncryptedServiceMixin criptografa `descricao` em RegistroAuditoria
| SEC-02 | Exigir PIN antes de exportar backup | `lib/screens/backup_restore_page*.dart`, `lib/services/backup_service.dart` | 🟡 Planejado | P0 |
| SEC-03 | Eliminar fallback de áudio em texto puro | `lib/services/audio_relato_service.dart:403-405` | 🟡 Planejado | P0 |
| SEC-04 | Criptografar ou desabilitar log em arquivo | `lib/services/logger.dart:66-82` | 🟡 Planejado | P0 |
| SEC-05 | Implementar certificate pinning real | `lib/main.dart:28` | 🟡 Planejado | P0 |
| SEC-06 | Migrar AES-CBC legado → AES-GCM com autenticação | `lib/services/encryption_service.dart:320-328` | 🟡 Planejado | P0 |
| SEC-07 | Implementar lockout de PIN com backoff exponencial | `lib/services/encryption_service.dart`, `lib/services/auth_service.dart`, `lib/screens/login_page.dart` | 🟡 Planejado | P0 |
| SEC-08 | Criptografar campos de auditoria (nomes de pacientes) | `lib/services/auditoria_service.dart` | 🟡 Planejado | P0 |

---

## 🟠 ALTO — Hardening de Transporte e Configuração

| ID | Título | Arquivo(s) | Status | Prioridade |
|----|--------|------------|--------|------------|
| SEC-09 | Remover `unsafe-inline` do CSP (usar nonces/hashes) | `backend/main.py:503-506` | 🟡 Planejado | P1 |
| SEC-10 | Adicionar timeout de inatividade (5 min → bloqueio) | `lib/screens/app_start_page.dart`, `lib/main.dart` | 🟡 Planejado | P1 |
| SEC-11 | Restringir CORS a domínios de produção | `backend/main.py:478-487` | 🟡 Planejado | P1 |
| SEC-12 | Verificação de integridade (HMAC) no backup import | `lib/services/backup_service.dart` | 🟡 Planejado | P1 |

---

## 🟡 MÉDIO — Melhorias de Defesa em Profundidade

| ID | Título | Arquivo(s) | Status | Prioridade |
|----|--------|------------|--------|------------|
| SEC-13 | Rate limiting mais restritivo em `/auth/*` (já existe, revisar valores) | `backend/main.py:527, 575, 617` | 🟢 Em revisão | P2 |
| SEC-14 | Sanitização de saída HTML em templates de contrato/anamnese | `backend/main.py` (html.escape já usado) | 🟢 OK | P2 |
| SEC-15 | Validação de entrada em schemas Pydantic (já implementado) | `backend/models/schemas.py` | 🟢 OK | P2 |

---

## ✅ JÁ IMPLEMENTADO / CONFORMIDADE

| Item | Status | Evidência |
|------|--------|-----------|
| Senhas com bcrypt (12+ rounds) | ✅ | `backend/main.py:115`, `backend/services/usuarios.py` |
| JWT com expiração (480 min) + claim `owner` | ✅ | `backend/main.py:113, 423-426` |
| Criptografia local AES-256-GCM (PBKDF2 100k iterações) | ✅ | `lib/services/encryption_service.dart:34-35, 286-297` |
| IV aleatório por registro (formato `3:`) | ✅ | `lib/services/encryption_service.dart:290-292` |
| Migração automática legacy → GCM | ✅ | `lib/services/encryption_service.dart:310-317` |
| Secure Storage (biometria/PIN do dispositivo) para chave mestra | ✅ | `lib/services/encryption_service.dart:38-55, 213-238` |
| `EncryptedServiceMixin` aplicado em 9 services | ✅ | `lib/services/encrypted_service_mixin.dart` |
| Rate limiting por IP em todas rotas sensíveis | ✅ | `backend/main.py:99-106` |
| Security headers (HSTS, X-Frame-Options, CSP, etc.) | ✅ | `backend/main.py:494-507` |
| `usesCleartextTraffic=false` + network_security_config | ✅ | `android/app/src/main/AndroidManifest.xml` |
| Secrets apenas em `.env` (não commitado) | ✅ | `.gitignore`, `backend/.env.example` |
| Logs técnicos sem dados clínicos (separados de auditoria) | ✅ | `lib/services/logger.dart:11-30` |

---

## 📋 Fases de Execução

### Fase 1 — Semana 1 (Crítico)
- [ ] SEC-01
- [ ] SEC-02
- [ ] SEC-03
- [ ] SEC-04
- [ ] SEC-05
- [ ] SEC-06
- [ ] SEC-07
- [ ] SEC-08

### Fase 2 — Semana 1-2 (Alto)
- [ ] SEC-09
- [ ] SEC-10
- [ ] SEC-11
- [ ] SEC-12

### Fase 3 — Contínuo (Médio)
- [ ] SEC-13 (revisão)
- [ ] SEC-14 (confirmado)
- [ ] SEC-15 (confirmado)

---

## 🔄 Como Atualizar

Ao **iniciar** uma correção: mude `Status` para `🔄 Em andamento`  
Ao **concluir** e testar: mude para `✅ Concluído` + adicione commit hash  
Se **bloqueado**: `🔴 Bloqueado` + motivo

> Exemplo:
> | SEC-01 | Remover fallback hardcoded `admin`/`admin` | ... | 🔄 Em andamento | P0 |
> 
> **Commit:** `a1b2c3d` — Remove hardcoded credentials, exige configuração explícita