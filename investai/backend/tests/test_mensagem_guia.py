import unittest

from tests.base import TesteComBanco
from services.usuario.gerar_guia_financeiro_service import GerarGuiaFinanceiroService


class TesteMensagemGuia(TesteComBanco):
    """RF16 - os números que o guia escreve para a pessoa precisam fazer
    sentido: no formato brasileiro, na escala mensal e sem "sobram R$ -500"."""

    def _guia(self, usuario):
        return GerarGuiaFinanceiroService().executar(usuario.id)

    def test_valores_no_formato_brasileiro(self):
        usuario = self.criar_usuario(renda_mensal=10000)
        for dias in (10, 40, 70):
            self.criar_renda(usuario, 10000, dias_atras=dias)
            self.criar_gasto(usuario, 1295.93, categoria="contas_fixas", dias_atras=dias)

        guia = self._guia(usuario)

        self.assertEqual(guia["passo"], "construir_reserva")
        self.assertIn("R$ 3.887,79", guia["mensagem"])  # 3x a despesa média
        self.assertNotIn("3887.79", guia["mensagem"])

    def test_gastos_maiores_que_a_renda_nao_viram_sobra_negativa(self):
        usuario = self.criar_usuario(renda_mensal=3000)
        for dias in (10, 40, 70):
            self.criar_renda(usuario, 3000, dias_atras=dias)
            self.criar_gasto(usuario, 1000, categoria="contas_fixas", dias_atras=dias)
            self.criar_gasto(usuario, 1500, categoria="alimentacao", dias_atras=dias)
        # Uma renda extra antiga deixa o saldo positivo, mas o mês a mês
        # continua no vermelho.
        self.criar_renda(usuario, 5000, dias_atras=200)
        self.criar_gasto(usuario, 3000, categoria="lazer", dias_atras=5)

        guia = self._guia(usuario)

        self.assertEqual(guia["passo"], "construir_reserva")
        self.assertNotIn("sobram R$ -", guia["mensagem"])
        self.assertIn("seus gastos passam da sua renda em R$ 500,00 por mês", guia["mensagem"])

    def test_usa_a_renda_registrada_e_nao_a_do_cadastro(self):
        """Cadastro desatualizado (R$ 3.000) com salário registrado de
        R$ 5.200: o guia deve calcular a sobra com o salário real."""
        usuario = self.criar_usuario(renda_mensal=3000)
        for dias in (10, 40, 70):
            self.criar_renda(usuario, 5200, dias_atras=dias)
            self.criar_gasto(usuario, 3500, categoria="contas_fixas", dias_atras=dias)

        guia = self._guia(usuario)

        self.assertIn("Guardando os R$ 1.700,00 que sobram por mês", guia["mensagem"])


if __name__ == "__main__":
    unittest.main()
