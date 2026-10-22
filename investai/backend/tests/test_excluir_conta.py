import unittest

from tests.base import TesteComBanco
from models import (
    Meta, Movimentacao, Recorrencia, ScoreHistorico, TokenRevogado,
    TransacaoImportada, Usuario,
)
from services.auth_service import AuthService


class TesteExcluirConta(TesteComBanco):
    """O termo de consentimento promete que o titular pode excluir a conta
    pelo app e que, com ela, saem todos os seus dados."""

    def setUp(self):
        super().setUp()
        self.usuario = self.criar_usuario()  # senha "senha123", ver tests/base.py
        self.cliente = self.app.test_client()

    def _excluir(self, usuario, senha, id_alvo=None):
        token = AuthService.gerar_token(usuario.id)
        return self.cliente.delete(
            f"/api/usuarios/{id_alvo or usuario.id}",
            headers={"Authorization": f"Bearer {token}"},
            json={"senha": senha} if senha is not None else None,
        )

    def test_exclui_a_conta_e_tudo_o_que_e_dela(self):
        uid = self.usuario.id
        self.criar_gasto(self.usuario, 50)
        self.criar_reserva(self.usuario, 100)
        Recorrencia(descricao="Aluguel", tipo="gasto", valor=1000, categoria="contas_fixas",
                    dia_mes=10, data_inicio="2026-01-01", usuario_id=uid).salvar()
        ScoreHistorico(usuario_id=uid, data="2026-01-01", score=500).salvar()
        TransacaoImportada(usuario_id=uid, identificador="banco:conta:1").salvar()
        TokenRevogado(jti="token-antigo", usuario_id=uid).salvar()

        resposta = self._excluir(self.usuario, "senha123")

        self.assertEqual(resposta.status_code, 200)
        self.assertIsNone(Usuario.buscar_por_id(uid))
        for modelo in (Movimentacao, Meta, Recorrencia, ScoreHistorico,
                       TransacaoImportada, TokenRevogado):
            with self.subTest(modelo=modelo.__name__):
                self.assertEqual(modelo.query.filter_by(usuario_id=uid).count(), 0)

    def test_senha_errada_ou_ausente_nao_exclui(self):
        for senha in ("errada", "", None):
            with self.subTest(senha=senha):
                resposta = self._excluir(self.usuario, senha)

                # 400 e não 401: no app, 401 derruba a sessão.
                self.assertEqual(resposta.status_code, 400)
                self.assertIn("erro", resposta.get_json())
                self.assertIsNotNone(Usuario.buscar_por_id(self.usuario.id))

    def test_nao_exclui_a_conta_de_outra_pessoa(self):
        outro = self.criar_usuario()

        resposta = self._excluir(self.usuario, "senha123", id_alvo=outro.id)

        self.assertEqual(resposta.status_code, 404)
        self.assertIsNotNone(Usuario.buscar_por_id(outro.id))

    def test_depois_de_excluir_o_token_deixa_de_valer(self):
        token = AuthService.gerar_token(self.usuario.id)
        self._excluir(self.usuario, "senha123")

        resposta = self.cliente.get(
            "/api/usuarios/me", headers={"Authorization": f"Bearer {token}"}
        )

        self.assertEqual(resposta.status_code, 401)

    def test_as_outras_contas_continuam_intactas(self):
        outro = self.criar_usuario()
        self.criar_gasto(outro, 70)

        self._excluir(self.usuario, "senha123")

        self.assertIsNotNone(Usuario.buscar_por_id(outro.id))
        self.assertEqual(Movimentacao.query.filter_by(usuario_id=outro.id).count(), 1)


if __name__ == "__main__":
    unittest.main()
