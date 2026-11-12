from tests.base import TesteComBanco
from services.usuario.gerar_guia_financeiro_service import (
    CARTEIRA_POR_PERFIL,
    SUGESTOES_POR_PERFIL,
    GerarGuiaFinanceiroService,
)

PERFIS = ("conservador", "moderado", "arrojado")


class TesteSugestoesPorPerfil(TesteComBanco):
    """RF16/RF18 - com a reserva completa, o guia traz várias sugestões e
    uma carteira de referência, diferentes para cada perfil."""

    def _guia(self, perfil):
        usuario = self.criar_usuario(perfil_risco=perfil, despesa_mensal_estimada=1000.0)
        self.criar_renda(usuario, 5000)
        self.criar_reserva(usuario, valor_atual=3000.0)  # meta é 3000
        return GerarGuiaFinanceiroService().executar(usuario.id)

    def test_cada_perfil_recebe_varias_sugestoes_completas(self):
        for perfil in PERFIS:
            with self.subTest(perfil=perfil):
                guia = self._guia(perfil)
                self.assertEqual(guia["passo"], "pronto_para_investir")
                self.assertEqual(guia["perfil_risco"], perfil)
                sugestoes = guia["sugestoes_investimento"]
                self.assertGreaterEqual(len(sugestoes), 6)
                for s in sugestoes:
                    self.assertTrue(s["motivo"], s["nome"])
                    self.assertIn(s["risco"], ("baixo", "medio", "alto"))
                    self.assertIn(s["prazo"], ("curto", "medio", "longo"))

    def test_sugestoes_mudam_conforme_o_perfil(self):
        nomes = {p: [s["nome"] for s in self._guia(p)["sugestoes_investimento"]] for p in PERFIS}
        self.assertNotEqual(nomes["conservador"][0], nomes["arrojado"][0])
        # Conservador nunca recebe sugestão de risco alto.
        conservador = self._guia("conservador")["sugestoes_investimento"]
        self.assertTrue(all(s["risco"] == "baixo" for s in conservador))
        # Arrojado tem renda variável entre as sugestões.
        arrojado = self._guia("arrojado")["sugestoes_investimento"]
        self.assertTrue(any(s["tipo"] == "Renda variável" for s in arrojado))

    def test_carteira_sugerida_soma_100_por_cento(self):
        for perfil in PERFIS:
            with self.subTest(perfil=perfil):
                carteira = self._guia(perfil)["carteira_sugerida"]
                self.assertEqual(sum(c["percentual"] for c in carteira), 100)

    def test_catalogos_cobrem_os_mesmos_perfis(self):
        self.assertEqual(set(SUGESTOES_POR_PERFIL), set(PERFIS))
        self.assertEqual(set(CARTEIRA_POR_PERFIL), set(PERFIS))

    def test_sem_reserva_completa_nao_ha_sugestoes(self):
        usuario = self.criar_usuario(perfil_risco="arrojado", despesa_mensal_estimada=1000.0)
        self.criar_renda(usuario, 5000)
        self.criar_reserva(usuario, valor_atual=100.0)
        guia = GerarGuiaFinanceiroService().executar(usuario.id)
        self.assertNotIn("sugestoes_investimento", guia)
        self.assertNotIn("carteira_sugerida", guia)
