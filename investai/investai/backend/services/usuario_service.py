from models import Usuario
from repositories import UsuarioRepository


class UsuarioService:

    @staticmethod
    def listar_todos():
        return Usuario.listar()

    @staticmethod
    def buscar_por_id(id):
        return Usuario.buscar(id)

    @staticmethod
    def criar(dados):
        usuario = Usuario(
            nome=dados.get("nome"),
            email=dados.get("email"),
            perfil_risco=dados.get("perfil_risco", "conservador"),
            renda_mensal=float(dados.get("renda_mensal") or 0),
        )
        return usuario.salvar()

    @staticmethod
    def atualizar(id, dados):
        usuario = Usuario.buscar(id)
        if not usuario:
            return None
        usuario.nome = dados.get("nome", usuario.nome)
        usuario.email = dados.get("email", usuario.email)
        usuario.perfil_risco = dados.get("perfil_risco", usuario.perfil_risco)
        if dados.get("renda_mensal") is not None:
            usuario.renda_mensal = float(dados.get("renda_mensal"))
        return usuario.salvar()

    @staticmethod
    def deletar(id):
        usuario = Usuario.buscar(id)
        if not usuario:
            return False
        usuario.deletar()
        return True

    @staticmethod
    def buscar_por_email(email):
        return UsuarioRepository.buscar_por_email(email)
