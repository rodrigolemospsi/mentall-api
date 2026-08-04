import logging
import os
import re

import requests

log = logging.getLogger("mentall.crp")

CFP_API_BASE = "https://cn-api.cfp.org.br"


def _extrair_regiao_registro(crp: str) -> tuple[str, str]:
    limpo = re.sub(r"[^0-9/]", "", crp.strip())
    partes = limpo.split("/")
    regiao = partes[0] if len(partes) >= 1 else ""
    registro = partes[1] if len(partes) >= 2 else limpo
    if not regiao and len(limpo) >= 6:
        regiao = limpo[:2]
        registro = limpo[2:]
    return regiao, registro


def verificar_crp_online(registro_profissional: str) -> dict:
    if not registro_profissional or not registro_profissional.strip():
        return {"ativo": False, "erro": "CRP nao informado."}

    regiao, numero = _extrair_regiao_registro(registro_profissional)

    if not regiao or not numero:
        return {"ativo": False, "erro": "Formato de CRP invalido. Use XX/XXXXX."}

    try:
        url = (
            f"{CFP_API_BASE}/psi/busca"
            f"?regiao={regiao}"
            f"&registro={numero}"
            f"&tipo=PF"
        )
        log.info("Verificando CRP: regiao=%s registro=%s", regiao, numero)

        resp = requests.get(url, timeout=15)
        if resp.status_code != 200:
            log.warning("CFP API retornou %d: %s", resp.status_code, resp.text[:300])
            return {"ativo": False, "erro": f"Servico indisponivel (HTTP {resp.status_code})."}

        resultados = resp.json()
        if isinstance(resultados, list):
            for r in resultados:
                if isinstance(r, dict) and str(r.get("situacao", "")).lower() == "ativo":
                    nome_oficial = str(r.get("Nome", "")).strip()
                    data_inscricao = str(r.get("dataInscricao", "")).strip()
                    return {
                        "ativo": True,
                        "nome_oficial": nome_oficial,
                        "data_inscricao": data_inscricao,
                        "erro": "",
                    }

        return {"ativo": False, "erro": "CRP nao encontrado ou nao esta ativo."}

    except requests.Timeout:
        log.warning("Timeout ao consultar CFP: regiao=%s registro=%s", regiao, numero)
        return {"ativo": False, "erro": "Tempo excedido ao consultar CFP."}
    except Exception as e:
        log.exception("Erro ao verificar CRP: %s", e)
        return {"ativo": False, "erro": f"Erro ao consultar CFP: {str(e)}"}
