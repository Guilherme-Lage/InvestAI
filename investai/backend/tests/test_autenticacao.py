import unittest

from tests.base import TesteComBanco
from models import Usuario
from services.usuario.criar_usuario_service import CriarUsuarioService
from services.usuario.autenticar_usuario_service import AutenticarUsuarioService


class TesteCadastroELogin(TesteComBanco):
    """RF01/RF02 - cadastro e login seguros."""

    def setUp(self):
        super().setUp()
        self.criar = CriarUsuarioService()
        self.autenticar = AutenticarUsuarioService()

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

    def test_senha_nunca_e_guardada_em_texto(self):
        resultado = self.criar.executar(self._dados())

        usuario = Usuario.buscar_por_id(resultado["usuario"]["id"])
        self.assertNotEqual(usuario.senha_hash, "Senha@123")
        self.assertNotIn("senha", resultado["usuario"])
        self.assertNotIn("senha_hash", resultado["usuario"])

    def test_login_devolve_token(self):
        self.criar.executar(self._dados())

        resultado = self.autenticar.executar("maria@exemplo.com", "Senha@123")

        self.assertIn("token", resultado)
        self.assertNotIn("senha_hash", resultado["usuario"])

    def test_login_recusa_senha_errada(self):
        self.criar.executar(self._dados())

        with self.assertRaises(Exception):
            self.autenticar.executar("maria@exemplo.com", "errada")

    def test_nao_aceita_email_repetido(self):
        self.criar.executar(self._dados())

        with self.assertRaises(ValueError):
            self.criar.executar(self._dados(nome="Outra Pessoa"))

    def test_recusa_senha_curta(self):
        with self.assertRaises(ValueError):
            self.criar.executar(self._dados(senha="a1@"))

    def test_senha_precisa_de_letra_numero_e_caractere_especial(self):
        casos = {
            "senha@abc": "número",          # sem número
            "123456@#": "letra",            # sem letra
            "senha123": "caractere especial",
            "senha 123": "caractere especial",  # espaço não conta como especial
        }
        for senha, falta in casos.items():
            with self.subTest(senha=senha), self.assertRaises(ValueError) as erro:
                self.criar.executar(self._dados(senha=senha))
            self.assertIn(falta, str(erro.exception))

    def test_aceita_senha_com_letra_numero_e_caractere_especial(self):
        for indice, senha in enumerate(("Senha@123", "abc_123", "ção#9x", "a1-b2c3")):
            with self.subTest(senha=senha):
                resultado = self.criar.executar(
                    self._dados(senha=senha, email=f"maria{indice}@exemplo.com")
                )
                self.assertIn("token", resultado)

    def test_recusa_email_invalido(self):
        with self.assertRaises(ValueError):
            self.criar.executar(self._dados(email="nao-e-email"))

    def test_recusa_perfil_de_risco_invalido(self):
        with self.assertRaises(ValueError):
            self.criar.executar(self._dados(perfil_risco="agressivo_demais"))

    def test_recusa_despesa_fixa_maior_que_a_total(self):
        """A parte obrigatória não pode passar do total informado."""
        with self.assertRaises(ValueError):
            self.criar.executar(self._dados(despesa_mensal_estimada=1000,
                                            despesa_fixa_estimada=2000))

    def test_guarda_a_estimativa_de_gastos_do_cadastro(self):
        resultado = self.criar.executar(
            self._dados(despesa_mensal_estimada=1500, despesa_fixa_estimada=900))

        usuario = Usuario.buscar_por_id(resultado["usuario"]["id"])
        self.assertAlmostEqual(usuario.despesa_mensal_estimada, 1500.0, places=2)
        self.assertAlmostEqual(usuario.despesa_fixa_estimada, 900.0, places=2)

    def test_recusa_cadastro_sem_aceitar_os_termos(self):
        with self.assertRaises(ValueError):
            self.criar.executar(self._dados(consentimento_aceito=False))

    def test_registra_a_decisao_e_a_versao_aceita(self):
        resultado = self.criar.executar(self._dados())

        usuario = Usuario.buscar_por_id(resultado["usuario"]["id"])
        self.assertTrue(usuario.consentimento_aceito)
        self.assertIsNotNone(usuario.consentimento_versao)
        self.assertIsNotNone(usuario.consentimento_em)


if __name__ == "__main__":
    unittest.main()
