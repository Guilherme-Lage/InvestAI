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

    def test_renda_registrada_tem_prioridade_sobre_a_do_cadastro(self):
        """Caso real da conta demo: cadastro com R$ 3.000, salário registrado
        de R$ 5.200 e despesa de R$ 3.500. Comparando o cadastro com a
        despesa real, o guia dizia que sobravam R$ -500 por mês."""
        usuario = self.criar_usuario(renda_mensal=3000)
        for dias in (10, 40, 70):
            self.criar_renda(usuario, 5200, dias_atras=dias)
            self.criar_gasto(usuario, 3500, categoria="contas_fixas", dias_atras=dias)

        r = self.service.executar(usuario.id)

        self.assertAlmostEqual(r["renda_mensal"], 5200.0, places=2)
        self.assertAlmostEqual(r["capacidade_mensal"], 1700.0, places=2)

    def test_sem_renda_registrada_usa_a_do_cadastro(self):
        usuario = self.criar_usuario(renda_mensal=4000)
        for dias in (10, 40, 70):
            self.criar_gasto(usuario, 3000, categoria="contas_fixas", dias_atras=dias)

        r = self.service.executar(usuario.id)

        self.assertAlmostEqual(r["renda_mensal"], 4000.0, places=2)
        self.assertAlmostEqual(r["capacidade_mensal"], 1000.0, places=2)

    def test_maior_gasto_ajustavel_vem_em_valor_mensal(self):
        """O total por categoria é do histórico inteiro; mostrado cru, três
        meses de mercado pareciam um gasto de um mês só."""
        usuario = self.criar_usuario(renda_mensal=5000)
        for dias in (10, 40, 70):
            self.criar_gasto(usuario, 1000, categoria="alimentacao", dias_atras=dias)
            self.criar_gasto(usuario, 2000, categoria="contas_fixas", dias_atras=dias)

        r = self.service.executar(usuario.id)

        self.assertEqual(r["maior_gasto_flexivel"]["categoria"], "alimentacao")
        self.assertAlmostEqual(r["maior_gasto_flexivel"]["total"], 1000.0, delta=1)

    def test_ajuste_de_saldo_do_extrato_nao_conta_como_renda_nem_gasto(self):
        """A importação de extrato grava o dinheiro que já estava na conta
        como um lançamento `saldo_inicial`. Ele conta no saldo, mas não é
        renda nem despesa do mês: somado às médias, R$ 9.000 na conta
        viravam R$ 3.000 de "renda" por mês."""
        usuario = self.criar_usuario(renda_mensal=0)
        for dias in (10, 40, 70):
            self.criar_renda(usuario, 4000, dias_atras=dias)
            self.criar_gasto(usuario, 3000, categoria="contas_fixas", dias_atras=dias)
        ajuste = self.criar_renda(usuario, 9000, dias_atras=80)
        ajuste.atualizar(categoria="saldo_inicial")
        ajuste_negativo = self.criar_gasto(usuario, 6000, categoria="saldo_inicial", dias_atras=80)

        r = self.service.executar(usuario.id)

        self.assertAlmostEqual(r["renda_mensal"], 4000.0, places=2)
        self.assertAlmostEqual(r["despesa_mensal"], 3000.0, places=2)
        self.assertAlmostEqual(r["capacidade_mensal"], 1000.0, places=2)
        self.assertIsNone(r["maior_gasto_flexivel"])  # só gasto fixo além do ajuste
        self.assertIsNotNone(ajuste_negativo.id)


if __name__ == "__main__":
    unittest.main()
