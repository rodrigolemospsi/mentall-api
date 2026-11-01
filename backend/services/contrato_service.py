"""Contratos terapêuticos + evidências de assinatura eletrônica simples.

A assinatura registra nome, CPF (opcional), data/hora UTC, IP, User-Agent,
versão do documento, hash SHA-256 do conteúdo canônico e um código público de
verificação. O conteúdo clínico NÃO entra no contrato (orientação CFP/CRP).
"""
import hashlib
import json
import logging
import re
import secrets
from datetime import datetime, timezone

from services.db import executar

log = logging.getLogger("mentall.contratos")

VERSAO_ACEITE = "contrato-v1"

# Alfabeto sem caracteres ambíguos (evita confusão em código digitado/impresso).
_ALFABETO_CODIGO = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def criar_contrato(dados: dict, owner_id: str = "") -> str:
    token = secrets.token_urlsafe(32)
    cur = executar(
        "INSERT INTO contratos (token, dados, status, owner_id, criado_em) VALUES (?, ?, 'pendente', ?, ?)",
        (token, json.dumps(dados, ensure_ascii=False), owner_id, datetime.now(timezone.utc).isoformat()),
    )
    cur.commit()
    log.info("Contrato criado: token=%s", token[:8])
    return token


def listar_contratos_por_owner(owner_id: str) -> list:
    cur = executar("SELECT * FROM contratos WHERE owner_id = ?", (owner_id,))
    return cur.fetchall()


def _colunas_contrato(row) -> dict:
    chaves = set(row.keys())
    dados = json.loads(row["dados"]) if row["dados"] else {}
    return {
        "token": row["token"],
        "dados": dados,
        "status": row["status"],
        "owner_id": row["owner_id"],
        "criado_em": row["criado_em"],
        "aceito_em": row["aceito_em"],
        "nome_aceite": row["nome_aceite"],
        "aceite_cpf": row["aceite_cpf"] if "aceite_cpf" in chaves else "",
        "aceite_ip": row["aceite_ip"] if "aceite_ip" in chaves else "",
        "aceite_user_agent": row["aceite_user_agent"] if "aceite_user_agent" in chaves else "",
        "aceite_hash": row["aceite_hash"] if "aceite_hash" in chaves else "",
        "aceite_codigo": row["aceite_codigo"] if "aceite_codigo" in chaves else "",
        "aceite_versao": row["aceite_versao"] if "aceite_versao" in chaves else "",
    }


def obter_contrato(token: str) -> dict | None:
    cur = executar("SELECT * FROM contratos WHERE token = ?", (token,))
    row = cur.fetchone()
    if row is None:
        return None
    return _colunas_contrato(row)


def obter_contrato_por_codigo(codigo: str) -> dict | None:
    """Busca pública por código de verificação (para a página de autenticidade)."""
    normalizado = re.sub(r"[^A-Za-z0-9]", "", (codigo or "")).upper()
    if len(normalizado) < 6:
        return None
    cur = executar("SELECT * FROM contratos WHERE aceite_codigo = ?", (normalizado,))
    row = cur.fetchone()
    if row is None:
        return None
    return _colunas_contrato(row)


def normalizar_cpf(valor: str) -> str:
    return re.sub(r"\D", "", valor or "")


def cpf_valido(cpf: str) -> bool:
    """Validação completa de CPF (dígitos verificadores). Aceita vazio como inválido."""
    numeros = normalizar_cpf(cpf)
    if len(numeros) != 11 or numeros == numeros[0] * 11:
        return False
    for tamanho in (9, 10):
        soma = sum(int(numeros[i]) * (tamanho + 1 - i) for i in range(tamanho))
        digito = (soma * 10) % 11
        if digito == 10:
            digito = 0
        if digito != int(numeros[tamanho]):
            return False
    return True


def mascarar_cpf(cpf: str) -> str:
    numeros = normalizar_cpf(cpf)
    if len(numeros) != 11:
        return ""
    return f"***.***.{numeros[6:9]}-**"


def formatar_cpf(cpf: str) -> str:
    numeros = normalizar_cpf(cpf)
    if len(numeros) != 11:
        return ""
    return f"{numeros[:3]}.{numeros[3:6]}.{numeros[6:9]}-{numeros[9:]}"


def _clausulas_padrao(dados: dict) -> list[str]:
    """Texto canônico das cláusulas do modelo padrão (usado no hash e no PDF).

    Mantém a mesma redação exibida na página pública do acordo terapêutico.
    """
    termo = (dados.get("termo_pessoa") or "paciente").strip()
    termo_cap = termo[0].upper() + termo[1:] if termo else "Paciente"
    psi = "Psicóloga" if dados.get("tratamento") == "feminino" else "Psicólogo"
    nome_prof = (dados.get("nome_profissional") or "").strip()
    return [
        "Este é um espaço de cuidado, escuta e respeito.",
        "Compromissos",
        f"{psi} {nome_prof}: ofereço um atendimento ético, acolhedor e sigiloso, "
        "respeitando sua singularidade e autonomia.",
        f"{termo_cap}: comprometo-me a participar dos atendimentos com responsabilidade, "
        "pontualidade e comunicação sempre que houver dúvidas, imprevistos ou necessidade "
        "de remarcação.",
        "Cancelamentos",
        "Cancelamentos ou remarcações devem ser informados com pelo menos 24 horas de antecedência.",
        "Após esse prazo, ou em caso de falta sem aviso, a sessão poderá ser cobrada integralmente.",
        "Sigilo",
        "Tudo o que for compartilhado será preservado em confidencialidade, exceto nas "
        "situações previstas em lei.",
        "Consentimento",
        "Ao assinar este documento, declaro estar ciente e de acordo com os termos deste "
        "acordo terapêutico.",
    ]


def texto_documento_contrato(dados: dict) -> str:
    """Conteúdo canônico (texto) assinado pelo paciente.

    - Modelo personalizado: usa o texto enviado pelo profissional.
    - Modelo padrão: reconstrói as cláusulas fixas (mesma redação da página).
    O hash SHA-256 é calculado sobre este texto + dados de identificação.
    """
    personalizado = (dados.get("template_contrato") or "").strip()
    if personalizado:
        corpo = personalizado
    else:
        corpo = "\n\n".join(_clausulas_padrao(dados))

    registro = formatar_cpf(dados.get("cpf_profissional", "")) or (dados.get("registro_profissional") or "não informado")
    cnpj = (dados.get("cnpj_profissional") or "").strip()
    linhas = [
        "ACORDO TERAPÊUTICO",
        f"Profissional: {dados.get('nome_profissional', '')}",
        f"CRP: {dados.get('registro_profissional', '')}",
    ]
    if cnpj:
        linhas.append(f"CNPJ: {cnpj}")
    if dados.get("cpf_profissional"):
        linhas.append(f"CPF do profissional: {registro}")
    linhas += [
        f"Paciente: {dados.get('nome_paciente', '')}",
        "",
        corpo,
    ]
    return "\n".join(linhas).strip()


def hash_documento_contrato(dados: dict) -> str:
    """SHA-256 do envelope canônico (versão + texto + identificação)."""
    canonico = {
        "versao": VERSAO_ACEITE,
        "texto": texto_documento_contrato(dados),
        "nome_paciente": dados.get("nome_paciente", ""),
        "nome_profissional": dados.get("nome_profissional", ""),
        "registro_profissional": dados.get("registro_profissional", ""),
    }
    serializado = json.dumps(canonico, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(serializado.encode("utf-8")).hexdigest()


def gerar_codigo_verificacao() -> str:
    """Código de 10 caracteres sem hífen (armazenado); exibido formatado."""
    return "".join(secrets.choice(_ALFABETO_CODIGO) for _ in range(10))


def formatar_codigo(codigo: str) -> str:
    """Formata o código para exibição: ``ABCDE-FGHIJ``."""
    bruto = re.sub(r"[^A-Za-z0-9]", "", codigo or "").upper()
    if len(bruto) != 10:
        return bruto
    return f"{bruto[:5]}-{bruto[5:]}"


def registrar_aceite(
    token: str,
    nome: str,
    cpf: str = "",
    ip: str = "",
    user_agent: str = "",
) -> dict | None:
    cur = executar("SELECT * FROM contratos WHERE token = ?", (token,))
    row = cur.fetchone()
    if row is None or row["status"] not in ("pendente", "aceito"):
        return None
    if row["status"] == "aceito":
        return _colunas_contrato(row)

    dados = json.loads(row["dados"]) if row["dados"] else {}
    agora = datetime.now(timezone.utc).isoformat()
    cpf_limpo = normalizar_cpf(cpf)
    evidencia = {
        "aceite_cpf": cpf_limpo,
        "aceite_ip": (ip or "")[:64],
        "aceite_user_agent": (user_agent or "")[:512],
        "aceite_hash": hash_documento_contrato(dados),
        "aceite_codigo": gerar_codigo_verificacao(),
        "aceite_versao": VERSAO_ACEITE,
    }
    # Transição condicionada ao estado anterior: em corrida, a primeira vence e
    # a segunda não sobrescreve nome/CPF/hash/código.
    executar(
        "UPDATE contratos SET status = 'aceito', aceito_em = ?, nome_aceite = ?, "
        "aceite_cpf = ?, aceite_ip = ?, aceite_user_agent = ?, aceite_hash = ?, "
        "aceite_codigo = ?, aceite_versao = ? "
        "WHERE token = ? AND status = 'pendente'",
        (
            agora,
            nome.strip(),
            evidencia["aceite_cpf"],
            evidencia["aceite_ip"],
            evidencia["aceite_user_agent"],
            evidencia["aceite_hash"],
            evidencia["aceite_codigo"],
            evidencia["aceite_versao"],
            token,
        ),
    ).commit()
    log.info("Contrato aceito: token=%s nome=%s", token[:8], nome[:20])
    atual = obter_contrato(token)
    if atual is None or atual["status"] != "aceito":
        return None
    return atual
