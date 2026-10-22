from models import Usuario
from services.usuario.deletar_usuario_service import DeletarUsuarioService


class ExcluirPropriaContaService:
    """Exclusão da conta pelo próprio titular, a partir do app (direito de
    eliminação dos dados, art. 18 da LGPD, prometido no termo de
    consentimento).

    Pede a senha de novo: excluir apaga todo o histórico financeiro e não
    tem volta, então não pode bastar alguém pegar o celular já logado.
    """

    def executar(self, usuario_id, senha):
        usuario = Usuario.buscar_por_id(usuario_id)
        if usuario is None:
            return False

        if not senha:
            raise ValueError("Digite sua senha para confirmar a exclusão.")
        if not usuario.verificar_senha(senha):
            raise ValueError("Senha incorreta.")

        # As movimentações, metas e demais dados da conta saem junto, pelo
        # cascade definido nos relacionamentos da Model Usuario.
        return DeletarUsuarioService().executar(usuario_id)
