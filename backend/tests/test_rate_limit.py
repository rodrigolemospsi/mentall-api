"""Testes do fix de rate-limit bypass (pentest Strix 28/08).

O bucket era global por `client.host` (XFF do atacante com --proxy-headers):
1. XFF rotativo burlava o 429.
2. Um endpoint consumia o orcamento de todos os outros.

Agora: chave `{rota}|{chave_extra}|{ip}`, com IP real = ultimo valor do
X-Forwarded-For (adicionado pelo proxy confiavel) e buckets por rota/conta.
"""
import os
import unittest
from unittest import mock

os.environ.setdefault("JWT_SECRET", "teste-segredo")
os.environ.setdefault("APP_PASSWORD_HASH", "teste-hash")
os.environ.setdefault("SMTP_HOST", "")
os.environ.setdefault("WUZAPI_BASE_URL", "")

import main  # noqa: E402
from fastapi import HTTPException  # noqa: E402


class FakeRequest:
    def __init__(self, path="/auth/login", xff="", host="1.2.3.4"):
        self._path = path
        self._xff = xff
        self._host = host
        self.client = type("C", (), {"host": self._host})()

    @property
    def url(self):
        return type("U", (), {"path": self._path})()

    @property
    def headers(self):
        return {"x-forwarded-for": self._xff}


class TestClienteIp(unittest.TestCase):
    def setUp(self):
        main._rate_limit_store.clear()

    def test_sem_xff_usa_client_host(self):
        req = FakeRequest(xff="")
        self.assertEqual(main._cliente_ip(req), "1.2.3.4")

    def test_peer_publico_ignora_xff(self):
        # Socket peer publico = cliente direto; XFF e controlado pelo atacante
        # e NÃO pode ser usado como chave de rate limit.
        req = FakeRequest(xff="198.51.100.1, 177.50.1.2")
        self.assertEqual(main._cliente_ip(req), "1.2.3.4")

    def test_peer_privado_confia_no_ultimo_xff(self):
        # Socket peer privado (ex.: edge do Fly na rede interna) = proxy que
        # anexa o IP real do cliente ao final do XFF.
        req = FakeRequest(xff="198.51.100.1, 177.50.1.2", host="10.0.0.1")
        self.assertEqual(main._cliente_ip(req), "177.50.1.2")

    def test_peer_privado_xff_invalido_usa_peer(self):
        req = FakeRequest(xff="nao-eh-ip", host="10.0.0.1")
        self.assertEqual(main._cliente_ip(req), "10.0.0.1")

    def test_peer_em_trusted_proxies_confia_no_xff(self):
        main.TRUSTED_PROXIES = {"203.0.113.9"}
        self.addCleanup(lambda: setattr(main, "TRUSTED_PROXIES", set()))
        req = FakeRequest(xff="198.51.100.1, 177.50.1.2", host="203.0.113.9")
        self.assertEqual(main._cliente_ip(req), "177.50.1.2")

    def test_ignora_valores_vazios_no_xff(self):
        req = FakeRequest(xff="200.0.0.1, , 177.50.1.2", host="10.0.0.1")
        self.assertEqual(main._cliente_ip(req), "177.50.1.2")

    def test_sem_client_retorna_unknown(self):
        req = FakeRequest()
        req.client = None
        self.assertEqual(main._cliente_ip(req), "unknown")


class TestRateLimitPorRota(unittest.TestCase):
    def setUp(self):
        main._rate_limit_store.clear()

    def test_buckets_separados_por_rota(self):
        req_a = FakeRequest(path="/auth/login")
        req_b = FakeRequest(path="/transcrever")
        for _ in range(5):
            main._rate_limit_check(req_a, max_requests=5)
        # rota diferente nao foi afetada
        main._rate_limit_check(req_b, max_requests=5)

    def test_estoura_por_conta_nao_por_ip(self):
        req = FakeRequest(path="/auth/login", xff="177.50.1.2")
        for _ in range(5):
            main._rate_limit_check(req, max_requests=5, chave_extra="conta:a@b.com")
        with self.assertRaises(HTTPException):
            main._rate_limit_check(req, max_requests=5, chave_extra="conta:a@b.com")
        # outra conta no mesmo IP segue livre
        main._rate_limit_check(req, max_requests=5, chave_extra="conta:c@d.com")

    def test_xff_rotativo_nao_burla_com_chave_extra(self):
        # mesmo usuario, IPs diferentes -> mesma chave (conta). 2 tentativas
        # por IP x 2 IPs = 4 (abaixo do limite 5); a 6a (IP novo) estoura,
        # provando que rotacionar IP não reseta o bucket da conta.
        for ip_em_xff in ("10.0.0.1", "10.0.0.2"):
            req = FakeRequest(path="/auth/login", xff=ip_em_xff)
            for _ in range(2):
                main._rate_limit_check(req, max_requests=5, chave_extra="conta:alvo@x.com")
        # 5a de um IP novo ainda passa (4 < 5)
        req5 = FakeRequest(path="/auth/login", xff="10.0.0.3")
        main._rate_limit_check(req5, max_requests=5, chave_extra="conta:alvo@x.com")
        # 6a de outro IP novo estoura (bucket da conta chegou a 5)
        req6 = FakeRequest(path="/auth/login", xff="10.0.0.4")
        with self.assertRaises(HTTPException):
            main._rate_limit_check(req6, max_requests=5, chave_extra="conta:alvo@x.com")

    def test_xff_rotativo_em_endpoint_por_ip_nao_burla(self):
        # Endpoint sem chave_extra (ex.: /transcrever) usa o IP do socket peer
        # público. Rotacionar X-Forwarded-For não reseta o bucket.
        for _ in range(10):
            req = FakeRequest(path="/transcrever", xff=f"198.51.100.{_ % 12 + 1}")
            main._rate_limit_check(req, max_requests=10)
        req_final = FakeRequest(path="/transcrever", xff="198.51.100.99")
        with self.assertRaises(HTTPException):
            main._rate_limit_check(req_final, max_requests=10)

    def test_peer_publico_xff_rotativo_nao_burla_limite(self):
        # Cenário exato do Strix: socket peer público + XFF rotativo.
        for i in range(1, 13):
            req = FakeRequest(path="/transcrever", xff=f"198.51.100.{i}")
            if i <= 10:
                main._rate_limit_check(req, max_requests=10)
            else:
                with self.assertRaises(HTTPException):
                    main._rate_limit_check(req, max_requests=10)


if __name__ == "__main__":
    unittest.main()
