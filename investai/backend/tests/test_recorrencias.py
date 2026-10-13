import unittest
from datetime import date

from tests.base import TesteComBanco
from models import Movimentacao, Recorrencia
from services.auth_service import AuthService
from services.recorrencia.criar_recorrencia_service import CriarRecorrenciaService
from services.recorrencia.atualizar_recorrencia_service import AtualizarRecorrenciaService
from services.recorrencia.deletar_recorrencia_service import DeletarRecorrenciaService
from services.recorrencia.lancar_recorrencias_pendentes_service import (
    LancarRecorrenciasPendentesService,
)


class TesteRecorrencias(TesteComBanco):
    """Contas que se repetem todo mês precisam entrar sozinhas, uma vez
    por mês e na data certa - nem faltando, nem em dobro."""

    def setUp(self):
        super().setUp()
        self.usuario = self.criar_usuario()
        self.lancar = LancarRecorrenciasPendentesService()

    def _recorrencia(self, dia_mes, data_inicio, **campos):
        """Cria direto na Model, sem o lançamento automático da Service,
        para o teste controlar a data de 'hoje'."""
        dados = {
            "descricao": "Aluguel",
            "tipo": "gasto",
            "valor": 1500.0,
            "categoria": "contas_fixas",
            "dia_mes": dia_mes,
            "data_inicio": data_inicio,
            "ativa": True,
            "usuario_id": self.usuario.id,
        }
        dados.update(campos)
        recorrencia = Recorrencia(**dados)
        recorrencia.salvar()
        return recorrencia

    def _datas_lancadas(self):
        return sorted(m.data for m in Movimentacao.query.all())

    def test_lanca_quando_o_dia_chega(self):
        self._recorrencia(dia_mes=10, data_inicio="2026-03-01")

        self.lancar.executar(self.usuario.id, hoje=date(2026, 3, 9))
        self.assertEqual(self._datas_lancadas(), [])

        self.lancar.executar(self.usuario.id, hoje=date(2026, 3, 10))
        self.assertEqual(self._datas_lancadas(), ["2026-03-10"])

    def test_movimentacao_copia_os_dados_da_recorrencia(self):
        self._recorrencia(dia_mes=10, data_inicio="2026-03-01")

        self.lancar.executar(self.usuario.id, hoje=date(2026, 3, 10))

        movimentacao = Movimentacao.query.one()
        self.assertEqual(movimentacao.descricao, "Aluguel")
        self.assertEqual(movimentacao.tipo, "gasto")
        self.assertEqual(movimentacao.valor, 1500.0)
        self.assertEqual(movimentacao.categoria, "contas_fixas")
        self.assertEqual(movimentacao.usuario_id, self.usuario.id)

    def test_nao_lanca_duas_vezes_no_mesmo_mes(self):
        self._recorrencia(dia_mes=10, data_inicio="2026-03-01")

        for dia in (10, 11, 25):
            self.lancar.executar(self.usuario.id, hoje=date(2026, 3, dia))

        self.assertEqual(self._datas_lancadas(), ["2026-03-10"])

    def test_recupera_os_meses_em_que_o_app_ficou_fechado(self):
        self._recorrencia(dia_mes=5, data_inicio="2026-01-01")

        self.lancar.executar(self.usuario.id, hoje=date(2026, 3, 20))

        self.assertEqual(
            self._datas_lancadas(), ["2026-01-05", "2026-02-05", "2026-03-05"]
        )

    def test_dia_31_cai_no_ultimo_dia_de_meses_curtos(self):
        self._recorrencia(dia_mes=31, data_inicio="2026-01-01")

        self.lancar.executar(self.usuario.id, hoje=date(2026, 4, 30))

        self.assertEqual(
            self._datas_lancadas(),
            ["2026-01-31", "2026-02-28", "2026-03-31", "2026-04-30"],
        )

    def test_nao_lanca_antes_da_data_de_inicio(self):
        """Criada no dia 20 para vencer todo dia 5: o dia 5 deste mês já
        passou e a pessoa não pediu para lançar o passado."""
        self._recorrencia(dia_mes=5, data_inicio="2026-03-20")

        self.lancar.executar(self.usuario.id, hoje=date(2026, 3, 25))
        self.assertEqual(self._datas_lancadas(), [])

        self.lancar.executar(self.usuario.id, hoje=date(2026, 4, 5))
        self.assertEqual(self._datas_lancadas(), ["2026-04-05"])

    def test_vira_o_ano(self):
        self._recorrencia(dia_mes=15, data_inicio="2025-12-01")

        self.lancar.executar(self.usuario.id, hoje=date(2026, 1, 15))

        self.assertEqual(self._datas_lancadas(), ["2025-12-15", "2026-01-15"])

    def test_pausada_nao_lanca(self):
        self._recorrencia(dia_mes=10, data_inicio="2026-03-01", ativa=False)

        self.lancar.executar(self.usuario.id, hoje=date(2026, 3, 15))

        self.assertEqual(self._datas_lancadas(), [])

    def test_nao_lanca_recorrencia_de_outro_usuario(self):
        outro = self.criar_usuario()
        self._recorrencia(dia_mes=10, data_inicio="2026-03-01")

        self.lancar.executar(outro.id, hoje=date(2026, 3, 15))

        self.assertEqual(self._datas_lancadas(), [])

    def test_criar_ja_lanca_a_primeira_se_o_dia_chegou(self):
        hoje = date.today()

        resultado = CriarRecorrenciaService().executar(self.usuario.id, {
            "descricao": "Streaming",
            "valor": 39.9,
            "categoria": "lazer",
            "data_inicio": hoje.isoformat(),
        })

        self.assertEqual(resultado["dia_mes"], hoje.day)
        self.assertEqual(resultado["ultimo_mes_lancado"], hoje.strftime("%Y-%m"))
        self.assertEqual(self._datas_lancadas(), [hoje.isoformat()])

    def test_criar_recusa_dados_invalidos(self):
        base = {"descricao": "Aluguel", "valor": 1500, "dia_mes": 10}
        invalidos = [
            {"descricao": "  "},
            {"valor": 0},
            {"valor": "abc"},
            {"dia_mes": 32},
            {"tipo": "transferencia"},
            {"data_inicio": "10/03/2026"},
        ]
        for campos in invalidos:
            with self.subTest(campos=campos), self.assertRaises(ValueError):
                CriarRecorrenciaService().executar(self.usuario.id, {**base, **campos})

        self.assertEqual(Recorrencia.query.count(), 0)

    def test_retomar_nao_lanca_os_meses_pausados(self):
        hoje = date.today()
        # Dia de amanhã (ou 28, para existir em qualquer mês): ainda não
        # venceu neste mês, então retomar hoje não deve lançar nada.
        recorrencia = self._recorrencia(
            dia_mes=28 if hoje.day < 28 else 1,
            data_inicio="2020-01-01",
            ativa=False,
        )

        resultado = AtualizarRecorrenciaService().executar(
            recorrencia.id, self.usuario.id, {"ativa": True}
        )

        self.assertTrue(resultado["ativa"])
        self.assertEqual(resultado["data_inicio"], hoje.isoformat())
        self.assertEqual(
            [d for d in self._datas_lancadas() if d < hoje.isoformat()], []
        )

    def test_nao_edita_nem_exclui_recorrencia_de_outro_usuario(self):
        outro = self.criar_usuario()
        recorrencia = self._recorrencia(dia_mes=10, data_inicio="2026-03-01")

        self.assertIsNone(
            AtualizarRecorrenciaService().executar(recorrencia.id, outro.id, {"valor": 1})
        )
        self.assertFalse(DeletarRecorrenciaService().executar(recorrencia.id, outro.id))
        self.assertEqual(Recorrencia.buscar_por_id(recorrencia.id).valor, 1500.0)

    def test_excluir_mantem_o_que_ja_foi_lancado(self):
        recorrencia = self._recorrencia(dia_mes=10, data_inicio="2026-03-01")
        self.lancar.executar(self.usuario.id, hoje=date(2026, 3, 10))

        self.assertTrue(DeletarRecorrenciaService().executar(recorrencia.id, self.usuario.id))

        self.assertEqual(self._datas_lancadas(), ["2026-03-10"])

    def test_qualquer_rota_autenticada_dispara_o_lancamento(self):
        """O saldo é a primeira coisa que o app pede: precisa sair já com
        a conta do mês descontada, sem o usuário abrir a tela de
        recorrências."""
        hoje = date.today()
        self._recorrencia(dia_mes=hoje.day, data_inicio=hoje.isoformat())
        token = AuthService.gerar_token(self.usuario.id)

        resposta = self.app.test_client().get(
            "/api/movimentacoes/saldo", headers={"Authorization": f"Bearer {token}"}
        )

        self.assertEqual(resposta.status_code, 200)
        self.assertEqual(resposta.get_json()["saldo"], -1500.0)

    def test_rotas_criam_editam_pausam_e_excluem(self):
        cliente = self.app.test_client()
        cabecalho = {"Authorization": f"Bearer {AuthService.gerar_token(self.usuario.id)}"}

        criada = cliente.post("/api/recorrencias", headers=cabecalho, json={
            "descricao": "Internet", "valor": 120, "categoria": "contas_fixas", "dia_mes": 10,
        })
        self.assertEqual(criada.status_code, 201)
        id_ = criada.get_json()["id"]

        invalida = cliente.post("/api/recorrencias", headers=cabecalho, json={"valor": 120})
        self.assertEqual(invalida.status_code, 400)
        self.assertIn("erro", invalida.get_json())

        editada = cliente.put(f"/api/recorrencias/{id_}", headers=cabecalho,
                              json={"valor": 135.5, "ativa": False})
        self.assertEqual(editada.status_code, 200)
        self.assertEqual(editada.get_json()["valor"], 135.5)
        self.assertFalse(editada.get_json()["ativa"])
        self.assertEqual(editada.get_json()["descricao"], "Internet")

        lista = cliente.get("/api/recorrencias", headers=cabecalho).get_json()
        self.assertEqual([r["id"] for r in lista], [id_])

        self.assertEqual(
            cliente.delete(f"/api/recorrencias/{id_}", headers=cabecalho).status_code, 200
        )
        self.assertEqual(
            cliente.delete(f"/api/recorrencias/{id_}", headers=cabecalho).status_code, 404
        )
        self.assertEqual(cliente.get("/api/recorrencias").status_code, 401)


if __name__ == "__main__":
    unittest.main()
