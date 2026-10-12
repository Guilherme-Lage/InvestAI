import unittest

from tests.base import TesteComBanco, TAXAS_FIXAS
from services.investimento.simular_aporte_service import SimularAporteService


class TesteSimuladorAporte(TesteComBanco):
    """Projeção de aportes: a conta precisa fechar na mão, senão o app
    estaria mostrando número errado para quem vai decidir com ele."""

    def setUp(self):
        super().setUp()
        self.service = SimularAporteService()

    def test_sem_aporte_rende_juro_composto_sobre_o_valor_inicial(self):
        r = self.service.executar(valor_inicial=1000, aporte_mensal=0,
                                  prazos_meses=[12])
        selic = next(a for a in r["aplicacoes"] if a["nome"] == "Tesouro Selic")
        projecao = selic["projecoes"][0]

        # 1000 a 10% ao ano por 12 meses = 1100.
        self.assertAlmostEqual(projecao["valor_final"], 1100.0, delta=0.5)
        self.assertAlmostEqual(projecao["total_investido"], 1000.0, places=2)
        self.assertAlmostEqual(projecao["rendimento"], 100.0, delta=0.5)

    def test_total_investido_soma_os_aportes(self):
        r = self.service.executar(valor_inicial=500, aporte_mensal=100,
                                  prazos_meses=[12])
        projecao = r["aplicacoes"][0]["projecoes"][0]

        self.assertAlmostEqual(projecao["total_investido"], 1700.0, places=2)

    def test_rendimento_cresce_com_o_prazo(self):
        r = self.service.executar(valor_inicial=1000, aporte_mensal=100,
                                  prazos_meses=[12, 60])
        projecoes = r["aplicacoes"][0]["projecoes"]

        self.assertLess(projecoes[0]["rendimento"], projecoes[1]["rendimento"])

    def test_poupanca_segue_a_regra_do_banco_central(self):
        """Com Selic acima de 8,5% a poupança rende 0,5% ao mês, o que dá
        cerca de 6,17% ao ano - e não 70% da Selic."""
        r = self.service.executar(valor_inicial=1000, prazos_meses=[12])
        poupanca = next(a for a in r["aplicacoes"] if a["nome"] == "Poupança")

        self.assertAlmostEqual(poupanca["taxa_anual"], 6.17, delta=0.02)

    def test_poupanca_usa_setenta_por_cento_da_selic_quando_ela_e_baixa(self):
        from services.mercado import buscar_taxas_mercado_service
        buscar_taxas_mercado_service._cache["dados"] = {
            **TAXAS_FIXAS, "selic": 6.0,
        }

        r = self.service.executar(valor_inicial=1000, prazos_meses=[12])
        poupanca = next(a for a in r["aplicacoes"] if a["nome"] == "Poupança")

        self.assertAlmostEqual(poupanca["taxa_anual"], 4.2, delta=0.01)

    def test_poupanca_rende_menos_que_tesouro_selic(self):
        """É a comparação que dá sentido à tela: se um dia inverter, é bug."""
        r = self.service.executar(valor_inicial=1000, aporte_mensal=100)
        por_nome = {a["nome"]: a["projecoes"][-1]["valor_final"]
                    for a in r["aplicacoes"]}

        self.assertLess(por_nome["Poupança"], por_nome["Tesouro Selic"])

    def test_melhor_opcao_vem_primeiro(self):
        r = self.service.executar(valor_inicial=1000, aporte_mensal=100)
        finais = [a["projecoes"][-1]["valor_final"] for a in r["aplicacoes"]]

        self.assertEqual(finais, sorted(finais, reverse=True))

    def test_recusa_simulacao_sem_valor(self):
        with self.assertRaises(ValueError):
            self.service.executar(valor_inicial=0, aporte_mensal=0)

    def test_recusa_valor_negativo(self):
        with self.assertRaises(ValueError):
            self.service.executar(valor_inicial=-100, aporte_mensal=0)

    def test_recusa_prazo_absurdo(self):
        with self.assertRaises(ValueError):
            self.service.executar(valor_inicial=1000, prazos_meses=[9999])


if __name__ == "__main__":
    unittest.main()
