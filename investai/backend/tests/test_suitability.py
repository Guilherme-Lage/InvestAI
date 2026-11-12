from tests.base import TesteComBanco
from models import Usuario
from services.auth_service import AuthService
from services.usuario.criar_usuario_service import CriarUsuarioService
from services.usuario.questionario_suitability import (
    PERGUNTAS,
    avaliar_respostas,
    questionario_atual,
)


def _todas(indice):
    """Respostas com a mesma opção em todas as perguntas."""
    return {p["id"]: indice for p in PERGUNTAS}


class TesteAvaliacaoSuitability(TesteComBanco):
    """RF18 - o perfil sai da soma dos pontos do questionário."""

    def test_respostas_mais_cautelosas_dao_conservador(self):
        self.assertEqual(avaliar_respostas(_todas(0))["perfil"], "conservador")

    def test_respostas_intermediarias_dao_moderado(self):
        self.assertEqual(avaliar_respostas(_todas(1))["perfil"], "moderado")
        self.assertEqual(avaliar_respostas(_todas(2))["perfil"], "moderado")

    def test_respostas_mais_arrojadas_dao_arrojado(self):
        self.assertEqual(avaliar_respostas(_todas(3))["perfil"], "arrojado")

    def test_recusa_questionario_incompleto(self):
        respostas = _todas(1)
        respostas.pop(PERGUNTAS[0]["id"])
        with self.assertRaises(ValueError):
            avaliar_respostas(respostas)

    def test_recusa_opcao_inexistente(self):
        with self.assertRaises(ValueError):
            avaliar_respostas(_todas(9))
        with self.assertRaises(ValueError):
            avaliar_respostas(_todas(True))

    def test_questionario_publico_nao_revela_os_pontos(self):
        resposta = self.app.test_client().get("/api/usuarios/suitability")
        self.assertEqual(resposta.status_code, 200)
        corpo = resposta.get_json()
        self.assertEqual(len(corpo["perguntas"]), len(PERGUNTAS))
        self.assertEqual(corpo, questionario_atual())
        self.assertNotIn("pontos", str(corpo))


class TesteSuitabilityNoCadastro(TesteComBanco):

    def _dados(self, **campos):
        dados = {
            "nome": "Maria Teste",
            "email": "maria@exemplo.com",
            "senha": "Senha@123",
            "renda_mensal": 3000,
            "consentimento_aceito": True,
        }
        dados.update(campos)
        return dados

    def test_cadastro_pulando_fica_conservador_e_pendente(self):
        usuario = CriarUsuarioService().executar(self._dados())["usuario"]
        self.assertEqual(usuario["perfil_risco"], "conservador")
        self.assertFalse(usuario["suitability_respondido"])

    def test_cadastro_com_respostas_define_o_perfil(self):
        usuario = CriarUsuarioService().executar(
            self._dados(respostas_suitability=_todas(3)))["usuario"]
        self.assertEqual(usuario["perfil_risco"], "arrojado")
        self.assertTrue(usuario["suitability_respondido"])
        self.assertEqual(usuario["suitability_pontuacao"], 4 * len(PERGUNTAS))

    def test_cadastro_com_respostas_incompletas_e_recusado(self):
        with self.assertRaises(ValueError):
            CriarUsuarioService().executar(
                self._dados(respostas_suitability={"objetivo": 1}))


class TesteResponderSuitabilityDepois(TesteComBanco):

    def setUp(self):
        super().setUp()
        self.usuario = self.criar_usuario(perfil_risco="conservador")
        self.cliente = self.app.test_client()
        self.cabecalho = {
            "Authorization": f"Bearer {AuthService.gerar_token(self.usuario.id)}"
        }

    def test_responder_grava_o_perfil_calculado(self):
        resposta = self.cliente.post(
            f"/api/usuarios/{self.usuario.id}/suitability",
            json={"respostas": _todas(2)},
            headers=self.cabecalho,
        )
        self.assertEqual(resposta.status_code, 200)
        corpo = resposta.get_json()
        self.assertEqual(corpo["resultado"]["perfil"], "moderado")
        self.assertTrue(corpo["usuario"]["suitability_respondido"])

        usuario = Usuario.buscar_por_id(self.usuario.id)
        self.assertEqual(usuario.perfil_risco, "moderado")
        self.assertTrue(usuario.suitability_respondido)

    def test_respostas_invalidas_respondem_400(self):
        resposta = self.cliente.post(
            f"/api/usuarios/{self.usuario.id}/suitability",
            json={"respostas": {}},
            headers=self.cabecalho,
        )
        self.assertEqual(resposta.status_code, 400)

    def test_nao_responde_pelo_perfil_de_outra_pessoa(self):
        outro = self.criar_usuario()
        resposta = self.cliente.post(
            f"/api/usuarios/{outro.id}/suitability",
            json={"respostas": _todas(3)},
            headers=self.cabecalho,
        )
        self.assertEqual(resposta.status_code, 404)
        self.assertEqual(Usuario.buscar_por_id(outro.id).perfil_risco, "moderado")

    def test_perfil_nao_muda_mais_pela_edicao_do_usuario(self):
        """Sem o questionário, o perfil não pode ser escolhido direto."""
        self.cliente.put(
            f"/api/usuarios/{self.usuario.id}",
            json={"perfil_risco": "arrojado", "renda_mensal": 4000},
            headers=self.cabecalho,
        )
        usuario = Usuario.buscar_por_id(self.usuario.id)
        self.assertEqual(usuario.perfil_risco, "conservador")
        self.assertAlmostEqual(usuario.renda_mensal, 4000.0)


class TesteQuestionarioDaContaDemo(TesteComBanco):
    """Na conta demo o questionário volta a ficar pendente a cada sessão,
    para poder ser apresentado de novo. Contas reais não são afetadas."""

    def setUp(self):
        super().setUp()
        from criar_conta_demo import criar_conta_demo
        self.demo_id = criar_conta_demo()
        self.cliente = self.app.test_client()

    def _responder(self, usuario_id):
        cabecalho = {"Authorization": f"Bearer {AuthService.gerar_token(usuario_id)}"}
        resposta = self.cliente.post(f"/api/usuarios/{usuario_id}/suitability",
                                     json={"respostas": _todas(3)}, headers=cabecalho)
        self.assertEqual(resposta.status_code, 200)
        return cabecalho

    def _login(self, email, senha):
        return self.cliente.post("/api/usuarios/login",
                                 json={"email": email, "senha": senha}).get_json()

    def test_demo_nasce_com_o_questionario_pendente(self):
        self.assertFalse(Usuario.buscar_por_id(self.demo_id).suitability_respondido)

    def test_login_da_demo_reabre_o_questionario(self):
        from services.usuario.conta_demo import EMAIL_DEMO, SENHA_DEMO
        self._responder(self.demo_id)
        self.assertEqual(Usuario.buscar_por_id(self.demo_id).perfil_risco, "arrojado")

        usuario = self._login(EMAIL_DEMO, SENHA_DEMO)["usuario"]

        self.assertFalse(usuario["suitability_respondido"])
        self.assertEqual(usuario["perfil_risco"], "conservador")
        self.assertNotIn("senha_hash", usuario)

    def test_reabrir_o_app_com_a_sessao_salva_reabre_o_questionario(self):
        cabecalho = self._responder(self.demo_id)

        # Consultar /me no meio do uso não mexe em nada...
        me = self.cliente.get("/api/usuarios/me", headers=cabecalho).get_json()
        self.assertTrue(me["suitability_respondido"])

        # ...só a abertura do app conta como nova sessão.
        me = self.cliente.get("/api/usuarios/me?abertura=1", headers=cabecalho).get_json()
        self.assertFalse(me["suitability_respondido"])

    def test_contas_reais_mantem_o_questionario_respondido(self):
        resultado = CriarUsuarioService().executar({
            "nome": "Maria", "email": "maria@exemplo.com", "senha": "Senha@123",
            "consentimento_aceito": True, "respostas_suitability": _todas(3),
        })
        usuario_id = resultado["usuario"]["id"]
        cabecalho = {"Authorization": f"Bearer {resultado['token']}"}

        login = self._login("maria@exemplo.com", "Senha@123")["usuario"]
        self.assertTrue(login["suitability_respondido"])
        self.assertEqual(login["perfil_risco"], "arrojado")

        me = self.cliente.get("/api/usuarios/me?abertura=1", headers=cabecalho).get_json()
        self.assertTrue(me["suitability_respondido"])
        self.assertEqual(Usuario.buscar_por_id(usuario_id).perfil_risco, "arrojado")

    def _reserva(self, usuario_id):
        from models import Meta
        return Meta.query.filter_by(usuario_id=usuario_id, tipo="reserva_emergencia").first()

    def test_login_da_demo_desfaz_aportes_na_reserva(self):
        from services.usuario.conta_demo import EMAIL_DEMO, RESERVA_DEMO, SENHA_DEMO
        reserva = self._reserva(self.demo_id)
        self.assertEqual(reserva.valor_atual, RESERVA_DEMO["valor_atual"])

        # Aporte feito durante a apresentação completa a reserva...
        reserva.atualizar(valor_atual=11800.0)

        # ...e o próximo login devolve ao meio do caminho.
        self._login(EMAIL_DEMO, SENHA_DEMO)
        reserva = self._reserva(self.demo_id)
        self.assertEqual(reserva.valor_atual, RESERVA_DEMO["valor_atual"])
        self.assertEqual(reserva.valor_alvo, RESERVA_DEMO["valor_alvo"])

    def test_reabrir_o_app_recria_a_reserva_apagada(self):
        from services.usuario.conta_demo import RESERVA_DEMO
        cabecalho = {"Authorization": f"Bearer {AuthService.gerar_token(self.demo_id)}"}
        self._reserva(self.demo_id).deletar()
        self.assertIsNone(self._reserva(self.demo_id))

        self.cliente.get("/api/usuarios/me?abertura=1", headers=cabecalho)

        self.assertEqual(self._reserva(self.demo_id).valor_atual, RESERVA_DEMO["valor_atual"])

    def test_reserva_de_conta_real_nao_e_mexida(self):
        from models import Meta
        usuario = self.criar_usuario(email="real@exemplo.com")
        Meta(titulo="Reserva", valor_alvo=1000, valor_atual=900, prazo="2027-01-01",
             tipo="reserva_emergencia", usuario_id=usuario.id).salvar()
        cabecalho = {"Authorization": f"Bearer {AuthService.gerar_token(usuario.id)}"}

        self.cliente.get("/api/usuarios/me?abertura=1", headers=cabecalho)

        self.assertEqual(self._reserva(usuario.id).valor_atual, 900)
