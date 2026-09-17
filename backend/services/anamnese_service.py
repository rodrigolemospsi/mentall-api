import json
import logging
import math
import secrets
from datetime import date, datetime, timezone

from services.db import executar

log = logging.getLogger("mentall.anamneses")


def criar_anamnese(template_json: str, owner_id: str, dados_extra: dict | None = None) -> str:
    token = secrets.token_urlsafe(32)
    cur = executar(
        "INSERT INTO anamneses (token, template_json, owner_id, status, criado_em, dados_extra) "
        "VALUES (?, ?, ?, 'pendente', ?, ?)",
        (
            token,
            template_json,
            owner_id,
            datetime.now(timezone.utc).isoformat(),
            json.dumps(dados_extra or {}, ensure_ascii=False),
        ),
    )
    cur.commit()
    log.info("Anamnese criada: token=%s", token[:8])
    return token


def obter_anamnese(token: str) -> dict | None:
    cur = executar("SELECT * FROM anamneses WHERE token = ?", (token,))
    row = cur.fetchone()
    if row is None:
        return None
    return {
        "token": row["token"],
        "template_json": row["template_json"],
        "owner_id": row["owner_id"],
        "status": row["status"],
        "respostas": row["respostas"],
        "criado_em": row["criado_em"],
        "respondido_em": row["respondido_em"],
        "dados_extra": json.loads(row["dados_extra"]) if row["dados_extra"] else {},
    }


def _validar_respostas(template_json: str, respostas_json: str) -> str:
    respostas = json.loads(respostas_json)
    template = json.loads(template_json)
    if not isinstance(respostas, dict) or not isinstance(template, dict):
        raise ValueError("Objeto JSON esperado.")
    respostas = {k: v.strip() if isinstance(v, str) else v for k, v in respostas.items()}
    respostas = {k: v for k, v in respostas.items() if v not in (None, "", [])}
    secoes = template.get("secoes", [])
    if not isinstance(secoes, list):
        raise ValueError("Template invalido.")
    perguntas = []
    for secao in secoes:
        if not isinstance(secao, dict) or not isinstance(secao.get("perguntas", []), list):
            raise ValueError("Template invalido.")
        perguntas.extend((q, None) for q in secao.get("perguntas", []))
    for q, pai in perguntas:
        if not isinstance(q, dict) or not isinstance(q.get("id"), str):
            raise ValueError("Pergunta invalida.")
        campo = q["id"]
        tipo = q.get("tipo")
        if tipo == "yesno" and q.get("condicional_sim"):
            perguntas.append((q["condicional_sim"], campo))
        if pai is not None and respostas.get(pai) is not True:
            respostas.pop(campo, None)
            continue
        if campo not in respostas:
            if q.get("required"):
                raise ValueError("Campo obrigatorio nao respondido.")
            continue
        valor = respostas[campo]
        if tipo == "yesno":
            valido = type(valor) is bool
        elif tipo == "scale":
            minimo, maximo = q.get("min", 0), q.get("max", 10)
            if type(minimo) not in (int, float) or type(maximo) not in (int, float):
                raise ValueError("Limites de escala invalidos.")
            minimo, maximo = sorted((minimo, maximo))
            valido = (type(valor) in (int, float) and minimo <= valor <= maximo
                      and (type(valor) is int or math.isfinite(valor)))
        elif tipo == "checklist":
            valido = (isinstance(valor, list) and bool(valor)
                      and all(isinstance(v, str) and v in (q.get("opcoes") or []) for v in valor))
        elif tipo == "radio":
            valido = isinstance(valor, str) and valor in (q.get("opcoes") or [])
        else:
            valido = isinstance(valor, str) and bool(valor)
            if valido and tipo == "date":
                date.fromisoformat(valor)
        if not valido:
            raise ValueError("Resposta invalida para o tipo de pergunta.")
    return json.dumps(respostas, ensure_ascii=False, allow_nan=False)


def registrar_resposta(token: str, respostas_json: str) -> dict | None:
    cur = executar("SELECT * FROM anamneses WHERE token = ?", (token,))
    row = cur.fetchone()
    if row is None or row["status"] not in ("pendente", "respondido"):
        return None
    if row["status"] == "respondido":
        return {"status": "respondido"}
    respostas_json = _validar_respostas(row["template_json"], respostas_json)
    agora = datetime.now(timezone.utc).isoformat()
    executar(
        "UPDATE anamneses SET status = 'respondido', respostas = ?, respondido_em = ? "
        "WHERE token = ? AND status = 'pendente'",
        (respostas_json, agora, token),
    ).commit()
    log.info("Anamnese respondida: token=%s", token[:8])
    # The public write path never returns clinical data, even on a repeated POST.
    atual = executar("SELECT status FROM anamneses WHERE token = ?", (token,)).fetchone()
    return {"status": "respondido"} if atual and atual["status"] == "respondido" else None


def listar_por_owner(owner_id: str) -> list:
    cur = executar("SELECT * FROM anamneses WHERE owner_id = ?", (owner_id,))
    return cur.fetchall()
