import unittest

from tests.base import TesteComBanco
from services.movimentacao.analisar_composicao_gastos_service import (
    AnalisarComposicaoGastosService,
)


class TesteComposicaoGastos(TesteComBanco):
    """O guia muda de conselho conforme o motivo da sobra ser pequena:
    quem tem gasto flexível consegue cortar, quem só tem gasto fixo não.
    Sugerir 'corte gastos' para o segundo caso é inútil e soa como
    julgamento."""

    def setUp(self):
        super().setUp()
        self.service = AnalisarComposicaoGastosService()

    def test_sobra_confortavel_segue_no_ritmo(self):
        usuario = self.criar_usuario(renda_mensal=5000,
                                     despesa_mensal_estimada=2000,
                                     despesa_fixa_estimada=1500)

        r = self.service.executar(usuario.id)

        self.assertEqual(r["foco"], "no_ritmo")
        self.assertAlmostEqual(r["capacidade_mensal"], 3000.0, places=2)

    def test_sobra_pequena_com_gasto_flexivel_sugere_cortar(self):
        usuario = self.criar_usuario(renda_mensal=5000,
                                     despesa_mensal_estimada=4800,
                                     despesa_fixa_estimada=2000)

        r = self.service.executar(usuario.id)

        self.assertEqual(r["foco"], "reduzir_flexivel")

    def test_sobra_pequena_com_gasto_todo_fixo_aponta_renda(self):
        """Caso de quem tem moradia, escola e transporte consumindo quase
        tudo: cortar não resolve, e o app precisa admitir isso."""
        usuario = self.criar_usuario(renda_mensal=5000,
                                     despesa_mensal_estimada=4800,
                                     despesa_fixa_estimada=4700)

        r = self.service.executar(usuario.id)

        self.assertEqual(r["foco"], "aumentar_renda")

    def test_separa_obrigatorio_de_flexivel_pelos_gastos_reais(self):
        usuario = self.criar_usuario(renda_mensal=5000)
        # 3 meses de histórico: 3000 fixos e 1500 flexíveis por mês.
        for dias in (10, 40, 70):
            self.criar_gasto(usuario, 2000, categoria="contas_fixas", dias_atras=dias)
            self.criar_gasto(usuario, 1000, categoria="transporte", dias_atras=dias)
            self.criar_gasto(usuario, 1500, categoria="lazer", dias_atras=dias)

        r = self.service.executar(usuario.id)

        self.assertAlmostEqual(r["despesa_obrigatoria"], 3000.0, delta=1)
        self.assertAlmostEqual(r["despesa_flexivel"], 1500.0, delta=1)

    def test_aponta_a_maior_categoria_ajustavel(self):
        usuario = self.criar_usuario(renda_mensal=2000)
        self.criar_gasto(usuario, 5400, categoria="contas_fixas")
        self.criar_gasto(usuario, 1200, categoria="alimentacao")
        self.criar_gasto(usuario, 2400, categoria="lazer")

        r = self.service.executar(usuario.id)

        self.assertEqual(r["maior_gasto_flexivel"]["categoria"], "lazer")

    def test_moradia_e_transporte_contam_como_obrigatorios(self):
        usuario = self.criar_usuario(renda_mensal=3000)
        self.criar_gasto(usuario, 3000, categoria="contas_fixas")
        self.criar_gasto(usuario, 900, categoria="saude")

        r = self.service.executar(usuario.id)

        self.assertAlmostEqual(r["despesa_flexivel"], 0.0, places=2)
        self.assertGreater(r["despesa_obrigatoria"], 0)


if __name__ == "__main__":
    unittest.main()
