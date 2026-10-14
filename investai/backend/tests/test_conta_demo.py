import unittest
from datetime import date

from tests.base import TesteComBanco
from criar_conta_demo import EMAIL_DEMO, SENHA_DEMO, criar_conta_demo
from models import Movimentacao, Recorrencia, Usuario
from services.meta.calcular_status_reserva_emergencia_service import (
    CalcularStatusReservaEmergenciaService,
)
from services.movimentacao.calcular_saldo_service import CalcularSaldoService
from services.movimentacao.gerar_alertas_service import GerarAlertasService
from services.usuario.autenticar_usuario_service import AutenticarUsuarioService
from services.usuario.gerar_guia_financeiro_service import GerarGuiaFinanceiroService
from services.usuario.listar_historico_score_service import ListarHistoricoScoreService


class TesteContaDemo(TesteComBanco):
    """A conta de demonstração precisa mostrar o que o app promete: se o
    script quebrar ou os dados não dispararem os alertas, a apresentação
    abre com telas vazias."""

    def test_da_para_entrar_com_a_conta_criada(self):
        criar_conta_demo()

        resultado = AutenticarUsuarioService().executar(EMAIL_DEMO, SENHA_DEMO)

        self.assertIn("token", resultado)

    def test_dados_mostram_as_regras_principais_do_app(self):
        usuario_id = criar_conta_demo()

        self.assertGreater(CalcularSaldoService().executar(usuario_id), 0)

        alertas = GerarAlertasService().executar(usuario_id)
        self.assertFalse(alertas["alerta_inatividade"])
        self.assertEqual([a["categoria"] for a in alertas["alertas_categoria"]], ["lazer"])

        # Reserva incompleta: investimentos seguem bloqueados (RF14/RF15).
        reserva = CalcularStatusReservaEmergenciaService().executar(usuario_id)
        self.assertTrue(reserva["possui_reserva"])
        self.assertFalse(reserva["sugestoes_investimento_liberadas"])
        self.assertEqual(
            GerarGuiaFinanceiroService().executar(usuario_id)["passo"], "construir_reserva"
        )

        historico = ListarHistoricoScoreService().executar(usuario_id)
        self.assertGreater(len(historico["historico"]), 2)
        self.assertGreater(historico["variacao"], 0)

    def test_tem_tres_meses_de_historico_sem_data_no_futuro(self):
        usuario_id = criar_conta_demo()

        datas = [m.data for m in Movimentacao.query.filter_by(usuario_id=usuario_id)]

        self.assertEqual(len({d[:7] for d in datas}), 3)
        self.assertLessEqual(max(datas), date.today().isoformat())

    def test_rodar_de_novo_recria_sem_duplicar(self):
        criar_conta_demo()
        movimentacoes = Movimentacao.query.count()

        criar_conta_demo()

        self.assertEqual(Usuario.query.filter_by(email=EMAIL_DEMO).count(), 1)
        self.assertEqual(Movimentacao.query.count(), movimentacoes)
        self.assertEqual(Recorrencia.query.count(), 4)

    def test_nao_mexe_nas_outras_contas(self):
        outro = self.criar_usuario()
        self.criar_gasto(outro, 50)

        criar_conta_demo()
        criar_conta_demo()

        self.assertIsNotNone(Usuario.buscar_por_id(outro.id))
        self.assertEqual(Movimentacao.query.filter_by(usuario_id=outro.id).count(), 1)


if __name__ == "__main__":
    unittest.main()
