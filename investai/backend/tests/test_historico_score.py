import unittest
from datetime import date, timedelta

from tests.base import TesteComBanco
from models import ScoreHistorico
from services.auth_service import AuthService
from services.usuario.calcular_score_financeiro_service import CalcularScoreFinanceiroService
from services.usuario.listar_historico_score_service import ListarHistoricoScoreService


class TesteHistoricoScore(TesteComBanco):
    """Evolução do score financeiro (RF20) ao longo do tempo."""

    def setUp(self):
        super().setUp()
        self.usuario = self.criar_usuario()
        self.service = ListarHistoricoScoreService()

    def _retrato(self, dias_atras, score, usuario=None):
        ScoreHistorico(
            usuario_id=(usuario or self.usuario).id,
            data=(date.today() - timedelta(days=dias_atras)).isoformat(),
            score=score,
        ).salvar()

    def test_primeira_consulta_registra_o_score_de_hoje(self):
        atual = CalcularScoreFinanceiroService().executar(self.usuario.id)["score"]

        resultado = self.service.executar(self.usuario.id)

        self.assertEqual(
            resultado["historico"],
            [{"data": date.today().isoformat(), "score": atual}],
        )
        self.assertEqual(resultado["variacao"], 0)

    def test_consultar_varias_vezes_no_dia_mantem_um_ponto_so(self):
        for _ in range(3):
            self.service.executar(self.usuario.id)

        self.assertEqual(ScoreHistorico.query.count(), 1)

    def test_ponto_de_hoje_acompanha_a_mudanca_do_score(self):
        self.service.executar(self.usuario.id)
        # Saldo negativo derruba os 250 pontos do critério de saldo.
        self.criar_gasto(self.usuario, 100)

        resultado = self.service.executar(self.usuario.id)

        atual = CalcularScoreFinanceiroService().executar(self.usuario.id)["score"]
        self.assertEqual(len(resultado["historico"]), 1)
        self.assertEqual(resultado["historico"][0]["score"], atual)

    def test_historico_vem_em_ordem_e_com_a_variacao_do_periodo(self):
        self._retrato(dias_atras=10, score=300)
        self._retrato(dias_atras=30, score=200)

        resultado = self.service.executar(self.usuario.id)

        atual = CalcularScoreFinanceiroService().executar(self.usuario.id)["score"]
        self.assertEqual(
            [p["score"] for p in resultado["historico"]], [200, 300, atual]
        )
        self.assertEqual(resultado["variacao"], atual - 200)

    def test_respeita_o_periodo_pedido(self):
        self._retrato(dias_atras=100, score=100)
        self._retrato(dias_atras=20, score=300)

        resultado = self.service.executar(self.usuario.id, dias=30)

        self.assertEqual(len(resultado["historico"]), 2)
        self.assertEqual(resultado["historico"][0]["score"], 300)

    def test_nao_mistura_historico_de_outro_usuario(self):
        outro = self.criar_usuario()
        self._retrato(dias_atras=5, score=999, usuario=outro)

        resultado = self.service.executar(self.usuario.id)

        self.assertNotIn(999, [p["score"] for p in resultado["historico"]])

    def test_rota_devolve_o_historico(self):
        self._retrato(dias_atras=5, score=400)
        token = AuthService.gerar_token(self.usuario.id)

        resposta = self.app.test_client().get(
            "/api/orientacao/score/historico?dias=30",
            headers={"Authorization": f"Bearer {token}"},
        )

        self.assertEqual(resposta.status_code, 200)
        corpo = resposta.get_json()
        self.assertEqual(corpo["dias"], 30)
        self.assertEqual(len(corpo["historico"]), 2)


if __name__ == "__main__":
    unittest.main()
