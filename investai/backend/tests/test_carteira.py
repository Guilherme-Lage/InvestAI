import unittest

from tests.base import TesteComBanco
from services.investimento.calcular_rendimento_service import (
    CalcularRendimentoInvestimentoService,
)
from services.investimento.comparar_carteira_service import CompararCarteiraService
from services.investimento.listar_investimentos_service import (
    ListarInvestimentosService,
)


class TesteRendimentoAutomatico(TesteComBanco):
    """O rendimento é calculado a partir do indexador e da data, porque
    ninguém mantém esse número atualizado na mão."""

    def setUp(self):
        super().setUp()
        self.service = CalcularRendimentoInvestimentoService()

    def test_calcula_pelo_indexador_e_pelo_tempo(self):
        usuario = self.criar_usuario()
        inv = self.criar_investimento(usuario, 1000, indexador="selic",
                                      dias_atras=365)

        r = self.service.executar(inv.to_dict())

        # 1000 a 10% ao ano (Selic fixa dos testes) por 1 ano = 1100.
        self.assertAlmostEqual(r["valor_atual"], 1100.0, delta=1)
        self.assertTrue(r["calculado_automaticamente"])

    def test_metade_do_ano_rende_menos_que_o_ano_inteiro(self):
        usuario = self.criar_usuario()
        meio = self.criar_investimento(usuario, 1000, indexador="selic",
                                       dias_atras=182)
        ano = self.criar_investimento(usuario, 1000, indexador="selic",
                                      dias_atras=365)

        self.assertLess(self.service.executar(meio.to_dict())["rendimento"],
                        self.service.executar(ano.to_dict())["rendimento"])

    def test_percentual_do_cdi_reduz_a_taxa(self):
        usuario = self.criar_usuario()
        inv = self.criar_investimento(usuario, 1000, indexador="cdi",
                                      percentual_indexador=80.0, dias_atras=365)

        r = self.service.executar(inv.to_dict())

        # CDI fixo dos testes é 9%; 80% dele dá 7,2%.
        self.assertAlmostEqual(r["taxa_anual"], 7.2, delta=0.01)

    def test_sem_indexador_mantem_o_valor_digitado(self):
        usuario = self.criar_usuario()
        inv = self.criar_investimento(usuario, 1000, indexador=None,
                                      rendimento_atual=250.0)

        r = self.service.executar(inv.to_dict())

        self.assertAlmostEqual(r["valor_atual"], 1250.0, places=2)
        self.assertFalse(r["calculado_automaticamente"])

    def test_listagem_traz_o_valor_ja_calculado(self):
        usuario = self.criar_usuario()
        self.criar_investimento(usuario, 1000, indexador="selic", dias_atras=365)

        itens = ListarInvestimentosService().executar(usuario.id)

        self.assertAlmostEqual(itens[0]["valor_atual"], 1100.0, delta=1)


class TesteComparacaoCarteira(TesteComBanco):
    """Compara o que a pessoa tem com a melhor alternativa equivalente."""

    def setUp(self):
        super().setUp()
        self.service = CompararCarteiraService()

    def test_aponta_quanto_deixa_de_ganhar_na_poupanca(self):
        usuario = self.criar_usuario()
        self.criar_investimento(usuario, 10000, indexador="poupanca")

        r = self.service.executar(usuario.id)

        self.assertEqual(len(r["comparacoes"]), 1)
        comparacao = r["comparacoes"][0]
        self.assertEqual(comparacao["alternativa"], "Tesouro Selic")
        # 10% da Selic contra 6,17% da poupança, sobre 10 mil.
        self.assertAlmostEqual(comparacao["ganho_anual"], 383.0, delta=2)

    def test_nao_sugere_trocar_quem_ja_esta_na_melhor_taxa(self):
        usuario = self.criar_usuario()
        self.criar_investimento(usuario, 10000, indexador="selic")

        r = self.service.executar(usuario.id)

        self.assertEqual(r["comparacoes"], [])

    def test_ignora_investimento_sem_indexador(self):
        """Sem indexador o app não sabe a taxa real - comparar seria chute."""
        usuario = self.criar_usuario()
        self.criar_investimento(usuario, 10000, indexador=None,
                                rendimento_atual=10.0)

        r = self.service.executar(usuario.id)

        self.assertEqual(r["comparacoes"], [])

    def test_ignora_diferenca_irrelevante(self):
        """Avisar por alguns reais ao ano seria ruído."""
        usuario = self.criar_usuario()
        self.criar_investimento(usuario, 100, indexador="poupanca")

        r = self.service.executar(usuario.id)

        self.assertEqual(r["comparacoes"], [])

    def test_soma_o_ganho_possivel_de_toda_a_carteira(self):
        usuario = self.criar_usuario()
        self.criar_investimento(usuario, 10000, indexador="poupanca")
        self.criar_investimento(usuario, 5000, indexador="poupanca")

        r = self.service.executar(usuario.id)

        total = sum(c["ganho_anual"] for c in r["comparacoes"])
        self.assertAlmostEqual(r["ganho_anual_possivel"], total, places=2)

    def test_carteira_vazia_nao_quebra(self):
        usuario = self.criar_usuario()

        r = self.service.executar(usuario.id)

        self.assertEqual(r["comparacoes"], [])
        self.assertEqual(r["ganho_anual_possivel"], 0.0)


if __name__ == "__main__":
    unittest.main()
