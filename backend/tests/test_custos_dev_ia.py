"""Custos de IA de desenvolvimento (construção do site, chave separada)."""
import unittest

from services import custos, db


class CustosDevIaTests(unittest.TestCase):
    def setUp(self):
        db.executar("DELETE FROM custos_dev_ia").commit()

    def tearDown(self):
        db.executar("DELETE FROM custos_dev_ia").commit()

    def test_registrar_listar_e_somar(self):
        custo_id = custos.registrar_custo_dev_ia(
            "Construção do site", "DeepSeek", "2026-11", 42.5,
            "DeepSeek — chave separada (site)", "créditos de novembro",
        )
        self.assertTrue(custo_id)
        itens = custos.listar_custos_dev_ia()
        self.assertEqual(len(itens), 1)
        item = itens[0]
        self.assertEqual(item["descricao"], "Construção do site")
        self.assertEqual(item["fornecedor"], "DeepSeek")
        self.assertEqual(item["competencia"], "2026-11")
        self.assertAlmostEqual(float(item["valor_brl"]), 42.5, places=2)
        self.assertEqual(item["api_key_ref"], "DeepSeek — chave separada (site)")

        total, do_mes = custos._dev_ia_mensal_brl("2026-11")
        self.assertAlmostEqual(total, 42.5, places=2)
        self.assertEqual(len(do_mes), 1)
        self.assertAlmostEqual(custos._dev_ia_mensal_brl("2026-12")[0], 0.0)

    def test_painel_nao_mistura_dev_com_operacional(self):
        custos.registrar_custo_dev_ia("Site — outubro", "DeepSeek", "2026-10", 100.0)
        painel = custos.painel("2026-10")
        self.assertAlmostEqual(painel["dev_ia_brl"], 100.0, places=2)
        self.assertAlmostEqual(
            painel["total_com_dev_brl"], round(painel["total_brl"] + 100.0, 2), places=2
        )
        # O total operacional continua sem o custo de desenvolvimento.
        self.assertNotAlmostEqual(
            painel["total_brl"], painel["total_com_dev_brl"], places=2
        )

    def test_competencia_invalida_cai_no_mes_atual(self):
        custo_id = custos.registrar_custo_dev_ia(
            "Site — competência inválida", "DeepSeek", "junho", 5.0
        )
        item = next(i for i in custos.listar_custos_dev_ia() if i["id"] == custo_id)
        self.assertEqual(item["competencia"], custos._mes_brt())

    def test_remover(self):
        custo_id = custos.registrar_custo_dev_ia("Site", "DeepSeek", "2026-11", 1.0)
        self.assertTrue(custos.remover_custo_dev_ia(custo_id))
        self.assertEqual(custos.listar_custos_dev_ia(), [])
        self.assertFalse(custos.remover_custo_dev_ia(custo_id))


if __name__ == "__main__":
    unittest.main()
