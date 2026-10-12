import unittest

from tests.base import TesteComBanco
from services.movimentacao.calcular_saldo_service import CalcularSaldoService
from services.movimentacao.calcular_sobrevivencia_service import (
    CalcularSobrevivenciaService,
)
from services.usuario.calcular_score_financeiro_service import (
    CalcularScoreFinanceiroService,
)


class TesteSaldo(TesteComBanco):
    """RF05 - saldo é receita menos despesa."""

    def test_saldo_desconta_os_gastos(self):
        usuario = self.criar_usuario()
        self.criar_renda(usuario, 3000)
        self.criar_gasto(usuario, 1200)

        self.assertAlmostEqual(
            CalcularSaldoService().executar(usuario.id), 1800.0, places=2)

    def test_saldo_pode_ficar_negativo(self):
        usuario = self.criar_usuario()
        self.criar_renda(usuario, 1000)
        self.criar_gasto(usuario, 1500)

        self.assertAlmostEqual(
            CalcularSaldoService().executar(usuario.id), -500.0, places=2)


class TesteSobrevivencia(TesteComBanco):
    """RF09 - por quantos meses o saldo cobre as despesas."""

    def test_divide_o_saldo_pela_despesa_media(self):
        usuario = self.criar_usuario()
        self.criar_renda(usuario, 9000)
        # 3 meses de gastos de 1000 = média mensal de 1000.
        for dias in (10, 40, 70):
            self.criar_gasto(usuario, 1000, dias_atras=dias)

        # Saldo 6000 / 1000 por mês = 6 meses.
        self.assertAlmostEqual(
            CalcularSobrevivenciaService().executar(usuario.id), 6.0, delta=0.1)

    def test_sem_despesa_nao_ha_o_que_calcular(self):
        usuario = self.criar_usuario(despesa_mensal_estimada=0)
        self.criar_renda(usuario, 5000)

        self.assertIsNone(CalcularSobrevivenciaService().executar(usuario.id))

    def test_usa_a_estimativa_quando_nao_ha_historico(self):
        usuario = self.criar_usuario(despesa_mensal_estimada=500)
        self.criar_renda(usuario, 5000)

        self.assertAlmostEqual(
            CalcularSobrevivenciaService().executar(usuario.id), 10.0, delta=0.1)


class TesteScoreFinanceiro(TesteComBanco):
    """RF20 - score de 0 a 1000 com classificação."""

    def setUp(self):
        super().setUp()
        self.service = CalcularScoreFinanceiroService()

    def test_score_fica_na_faixa_de_zero_a_mil(self):
        usuario = self.criar_usuario()
        self.criar_renda(usuario, 5000)
        self.criar_gasto(usuario, 1000)

        r = self.service.executar(usuario.id)

        self.assertGreaterEqual(r["score"], 0)
        self.assertLessEqual(r["score"], 1000)
        self.assertEqual(r["score_maximo"], 1000)

    def test_situacao_boa_pontua_mais_que_situacao_ruim(self):
        organizado = self.criar_usuario(email="bom@exemplo.com")
        self.criar_renda(organizado, 8000)
        self.criar_gasto(organizado, 1000)
        self.criar_reserva(organizado, valor_atual=9000, valor_alvo=3000)

        endividado = self.criar_usuario(email="ruim@exemplo.com")
        self.criar_renda(endividado, 1000)
        self.criar_gasto(endividado, 3000)

        self.assertGreater(self.service.executar(organizado.id)["score"],
                           self.service.executar(endividado.id)["score"])

    def test_traz_classificacao_e_detalhes(self):
        usuario = self.criar_usuario()
        self.criar_renda(usuario, 5000)

        r = self.service.executar(usuario.id)

        self.assertIn(r["classificacao"], ["Ruim", "Regular", "Bom", "Excelente"])
        self.assertIn("detalhes", r)


if __name__ == "__main__":
    unittest.main()
